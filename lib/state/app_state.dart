import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../models/vpn_config.dart';
import '../services/connectivity_verifier.dart';
import '../services/flutter_v2ray_engine.dart';
import '../services/latency_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../services/vpn_engine.dart';

enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
  switching,
  error,
}

class AppState extends ChangeNotifier {
  AppState({VpnEngine? engine})
      : _engine = engine ??
            FlutterV2rayEngine(
              onStatusChanged: null,
            ) {
    if (_engine is FlutterV2rayEngine) {
      // Native status is additionally refreshed by explicit operations.
    }
    _subscriptions = SubscriptionService(_engine);
    _latency = LatencyService(_engine);
  }

  final StorageService _storage = const StorageService();
  final ConnectivityVerifier _verifier = ConnectivityVerifier();

  final VpnEngine _engine;
  late final SubscriptionService _subscriptions;
  late final LatencyService _latency;

  AppSettings settings = AppSettings();
  List<Subscription> subscriptions = [];
  List<VpnConfig> configs = [];
  String? selectedConfigId;

  VpnConnectionState connectionState = VpnConnectionState.disconnected;
  String? lastError;

  bool isInitialized = false;
  bool isRefreshingSubs = false;
  bool isTestingAll = false;

  Timer? _subscriptionTimer;
  Timer? _liveTimer;

  bool _operationRunning = false;
  bool _liveTickRunning = false;
  int _consecutiveFailures = 0;
  DateTime? _lastSwitchAt;

  VpnEngine get engine => _engine;

  bool get isConnected =>
      connectionState == VpnConnectionState.connected;

  bool get isBusy =>
      connectionState == VpnConnectionState.connecting ||
      connectionState == VpnConnectionState.switching;

  VpnConfig? get selectedConfig {
    final id = selectedConfigId;
    if (id == null) return null;

    for (final config in configs) {
      if (config.id == id) return config;
    }
    return null;
  }

  List<VpnConfig> get activeConfigs {
    final activeId = settings.activeSubscriptionId;
    if (activeId == null) return List.unmodifiable(configs);

    return List.unmodifiable(
      configs.where((e) => e.subscriptionId == activeId),
    );
  }

  List<VpnConfig> get sortedByDelay {
    final result = List<VpnConfig>.from(activeConfigs);
    result.sort(compareByDelay);
    return result;
  }

  Future<void> initialize() async {
    try {
      settings = await _storage.loadSettings();
      subscriptions = await _storage.loadSubscriptions();
      configs = await _storage.loadConfigs();
      selectedConfigId = await _storage.loadSelectedConfigId();
      await _cleanupInvalidState();
      await _engine.initialize();
    } catch (e) {
      lastError = e.toString();
    }

    isInitialized = true;
    notifyListeners();

    _scheduleSubscriptionRefresh();

    if (subscriptions.isNotEmpty) {
      unawaited(refreshAllSubscriptions(silent: true));
    } else if (configs.isNotEmpty) {
      unawaited(_testAndPersist(configs));
    }
  }

  Future<void> _cleanupInvalidState() async {
    if (selectedConfigId != null &&
        !configs.any((e) => e.id == selectedConfigId)) {
      selectedConfigId = null;
      await _storage.saveSelectedConfigId(null);
    }

    final active = settings.activeSubscriptionId;
    if (active != null && !subscriptions.any((e) => e.id == active)) {
      settings = settings.copyWith(clearActiveSubscription: true);
      await _storage.saveSettings(settings);
    }
  }

  void _scheduleSubscriptionRefresh() {
    _subscriptionTimer?.cancel();
    if (subscriptions.isEmpty) return;

    final hours = settings.subscriptionRefreshHours.clamp(1, 24);
    _subscriptionTimer = Timer.periodic(
      Duration(hours: hours),
      (_) => refreshAllSubscriptions(silent: true),
    );
  }

  Future<void> refreshAllSubscriptions({bool silent = false}) async {
    if (subscriptions.isEmpty) {
      if (!silent) {
        lastError = 'اول یک ساب اضافه کن.';
        notifyListeners();
      }
      return;
    }

    if (isRefreshingSubs) return;

    isRefreshingSubs = true;
    if (!silent) notifyListeners();

    final results = <_SubscriptionResult>[];

    // Bounded concurrency: maximum 3 subscriptions at once.
    final queue = List<Subscription>.from(subscriptions);
    final workerCount = math.min(3, queue.length);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final sub = queue.removeLast();
        results.add(await _fetchSubscription(sub));
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));

    final errors = <String>[];

    for (final result in results) {
      final index =
          subscriptions.indexWhere((e) => e.id == result.subscription.id);

      if (result.error != null) {
        errors.add('${result.subscription.name}: ${result.error}');
        if (index >= 0) {
          subscriptions[index] = subscriptions[index].copyWith(
            lastError: result.error,
          );
        }
        continue;
      }

      _applyFreshConfigs(
        result.subscription,
        result.configs!,
      );
    }

    await _persistAll();
    _scheduleSubscriptionRefresh();

    isRefreshingSubs = false;
    lastError = errors.isEmpty ? null : errors.join(' • ');
    notifyListeners();

    if (errors.isEmpty && configs.isNotEmpty) {
      unawaited(_testAndPersist(activeConfigs));
    }
  }

  Future<_SubscriptionResult> _fetchSubscription(
    Subscription subscription,
  ) async {
    try {
      final fresh = await _subscriptions.fetchSubscription(
        subscription.url,
        subscriptionId: subscription.id,
      );
      return _SubscriptionResult(subscription, fresh, null);
    } catch (e) {
      return _SubscriptionResult(subscription, null, e.toString());
    }
  }

  void _applyFreshConfigs(
    Subscription subscription,
    List<VpnConfig> fresh,
  ) {
    final existing = configs
        .where((e) => e.subscriptionId == subscription.id)
        .toList();

    final merged = _subscriptions.mergeWithExisting(fresh, existing);

    configs.removeWhere((e) => e.subscriptionId == subscription.id);
    configs.addAll(merged);

    final index =
        subscriptions.indexWhere((e) => e.id == subscription.id);

    if (index >= 0) {
      subscriptions[index] = subscriptions[index].copyWith(
        serverCount: merged.length,
        lastUpdated: DateTime.now(),
        clearError: true,
      );
    }
  }

  Future<void> addSubscription(String rawUrl) async {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);

    if (uri == null ||
        !uri.isAbsolute ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      lastError = 'لینک ساب معتبر نیست.';
      notifyListeners();
      return;
    }

    final subscription = Subscription.create(url);

    if (subscriptions.any((e) => e.id == subscription.id)) {
      lastError = 'این ساب قبلاً اضافه شده است.';
      notifyListeners();
      return;
    }

    subscriptions.add(subscription);
    await _storage.saveSubscriptions(subscriptions);
    notifyListeners();

    isRefreshingSubs = true;
    notifyListeners();

    final result = await _fetchSubscription(subscription);

    if (result.error == null) {
      _applyFreshConfigs(subscription, result.configs!);
      lastError = null;
    } else {
      final index =
          subscriptions.indexWhere((e) => e.id == subscription.id);
      if (index >= 0) {
        subscriptions[index] = subscriptions[index].copyWith(
          lastError: result.error,
        );
      }
      lastError = '${subscription.name}: ${result.error}';
    }

    isRefreshingSubs = false;
    await _persistAll();
    _scheduleSubscriptionRefresh();
    notifyListeners();

    if (result.error == null) {
      unawaited(_testAndPersist(activeConfigs));
    }
  }

  Future<void> removeSubscription(String id) async {
    if (isConnected &&
        selectedConfig?.subscriptionId == id) {
      await disconnect();
    }

    subscriptions.removeWhere((e) => e.id == id);
    configs.removeWhere((e) => e.subscriptionId == id);

    if (settings.activeSubscriptionId == id) {
      settings = settings.copyWith(clearActiveSubscription: true);
    }

    if (selectedConfigId != null &&
        !configs.any((e) => e.id == selectedConfigId)) {
      selectedConfigId = null;
    }

    await _persistAll();
    _scheduleSubscriptionRefresh();
    notifyListeners();
  }

  Future<void> setActiveSubscription(String? id) async {
    settings = settings.copyWith(
      activeSubscriptionId: id,
      clearActiveSubscription: id == null,
    );

    await _storage.saveSettings(settings);

    if (selectedConfig != null &&
        !activeConfigs.any((e) => e.id == selectedConfigId)) {
      selectedConfigId = null;
      await _storage.saveSelectedConfigId(null);
    }

    notifyListeners();
  }

  Future<void> updateSettings(AppSettings value) async {
    settings = value.normalized();
    await _storage.saveSettings(settings);
    _scheduleSubscriptionRefresh();

    if (isConnected) {
      _startLiveMonitoring();
    }

    notifyListeners();
  }

  Future<void> testAll() async {
    final pool = List<VpnConfig>.from(activeConfigs);
    if (pool.isEmpty || isTestingAll) return;

    isTestingAll = true;
    notifyListeners();

    try {
      await _testAndPersist(pool);
    } finally {
      isTestingAll = false;
      notifyListeners();
    }
  }

  Future<void> _testAndPersist(List<VpnConfig> pool) async {
    await _latency.testAll(pool, concurrency: 3);
    await _storage.saveConfigs(configs);
    notifyListeners();
  }

  Future<void> toggleConnection() async {
    if (_operationRunning) return;

    if (isConnected) {
      await disconnect();
      return;
    }

    await connectFastest();
  }

  Future<bool> connectFastest() async {
    if (_operationRunning) return false;

    return _runConnectionOperation(() async {
      final pool = List<VpnConfig>.from(activeConfigs);

      if (pool.isEmpty) {
        throw const VpnException('سروری برای اتصال وجود ندارد.');
      }

      connectionState = VpnConnectionState.connecting;
      lastError = null;
      notifyListeners();

      if (pool.every((e) => e.isUntested)) {
        await _latency.testAll(pool, concurrency: 3);
        await _storage.saveConfigs(configs);
      }

      final reachable = pool.where((e) => e.isReachable).toList()
        ..sort(compareByDelay);

      final candidate =
          reachable.isNotEmpty ? reachable.first : pool.first;

      return _connectInternal(candidate);
    });
  }

  Future<bool> connectTo(VpnConfig config) async {
    if (_operationRunning) return false;

    return _runConnectionOperation(
      () => _connectInternal(config),
    );
  }

  Future<bool> _runConnectionOperation(
    Future<bool> Function() operation,
  ) async {
    _operationRunning = true;

    try {
      return await operation();
    } catch (e) {
      connectionState = VpnConnectionState.error;
      lastError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _operationRunning = false;
    }
  }

  Future<bool> _connectInternal(VpnConfig config) async {
    final switching = isConnected;

    connectionState = switching
        ? VpnConnectionState.switching
        : VpnConnectionState.connecting;
    lastError = null;
    notifyListeners();

    try {
      final parsed = _engine.parse(config.rawLink);

      final permission = await _engine.requestPermission();
      if (!permission) {
        throw const VpnPermissionException(
          'مجوز VPN داده نشد.',
        );
      }

      if (switching) {
        await _safeStop();
      }

      final excluded = settings.vpnExcludedPackages;
      await _engine.start(
        remark: config.remark,
        config: parsed.fullConfig,
        blockedApps: excluded.isEmpty ? null : excluded,
      );

      final delay = await _latency.connected(
        timeout: const Duration(seconds: 8),
      );

      var verified = delay >= 0;

      if (settings.verifyInternet) {
        verified = await _verifier.verify(
          timeout: const Duration(seconds: 8),
        );
      }

      if (!verified) {
        await _safeStop();
        throw const ConnectionVerificationException(
          'اتصال برقرار شد اما اینترنت از طریق تونل تأیید نشد.',
        );
      }

      if (delay >= 0) {
        config.lastDelayMs = delay;
      }
      config.lastTestedAt = DateTime.now();

      selectedConfigId = config.id;
      _consecutiveFailures = 0;
      _lastSwitchAt = DateTime.now();

      await _storage.saveSelectedConfigId(config.id);
      await _storage.saveConfigs(configs);

      connectionState = VpnConnectionState.connected;
      notifyListeners();

      _startLiveMonitoring();
      return true;
    } catch (e) {
      await _safeStop();
      connectionState = VpnConnectionState.error;
      lastError = e.toString();
      _liveTimer?.cancel();
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_operationRunning) return;

    _operationRunning = true;
    try {
      _liveTimer?.cancel();
      await _safeStop();
      connectionState = VpnConnectionState.disconnected;
      _consecutiveFailures = 0;
      notifyListeners();
    } finally {
      _operationRunning = false;
    }
  }

  Future<void> _safeStop() async {
    try {
      await _engine.stop();
    } catch (_) {
      // Stop is best-effort during cleanup.
    }
  }

  void _startLiveMonitoring() {
    _liveTimer?.cancel();

    final seconds = settings.pingIntervalSeconds.clamp(15, 300);

    _liveTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) => _liveTick(),
    );
  }

  Future<void> _liveTick() async {
    if (_liveTickRunning ||
        _operationRunning ||
        !isConnected) {
      return;
    }

    _liveTickRunning = true;

    try {
      final current = selectedConfig;
      if (current == null) return;

      final delay = await _latency.connected();

      if (delay >= 0) {
        current.lastDelayMs = delay;
        _consecutiveFailures = 0;
      } else {
        _consecutiveFailures++;
      }

      current.lastTestedAt = DateTime.now();
      notifyListeners();

      if (_consecutiveFailures >=
          settings.requiredFailuresForFailover) {
        if (settings.autoSwitchEnabled) {
          await _failover(current);
        }
        return;
      }

      if (settings.autoSwitchEnabled && delay >= 0) {
        await _maybeSwitchToFaster(current);
      }

      await _storage.saveConfigs(configs);
    } finally {
      _liveTickRunning = false;
    }
  }

  Future<void> _maybeSwitchToFaster(VpnConfig current) async {
    final lastSwitch = _lastSwitchAt;
    if (lastSwitch != null &&
        DateTime.now().difference(lastSwitch).inSeconds <
            settings.switchCooldownSeconds) {
      return;
    }

    final candidates = activeConfigs
        .where((e) => e.id != current.id)
        .toList()
      ..sort(compareByDelay);

    final count =
        math.min(settings.maxServersToPingLive - 1, candidates.length);

    if (count <= 0) return;

    final selected = candidates.take(count).toList();

    // Measure candidates with bounded concurrency while the current
    // tunnel remains active.
    await _latency.testAll(
      selected,
      concurrency: math.min(3, selected.length),
      timeout: const Duration(seconds: 5),
    );

    final currentDelay = current.lastDelayMs;
    if (currentDelay == null || currentDelay < 0) return;

    selected.sort(compareByDelay);

    for (final candidate in selected) {
      final candidateDelay = candidate.lastDelayMs;
      if (candidateDelay == null || candidateDelay < 0) continue;

      if (candidateDelay + settings.switchImprovementMs <
          currentDelay) {
        await _runConnectionOperation(
          () => _connectInternal(candidate),
        );
        return;
      }
    }
  }

  Future<void> _failover(VpnConfig dead) async {
    final pool = activeConfigs
        .where((e) => e.id != dead.id)
        .toList();

    if (pool.isEmpty) {
      lastError = 'سرور جایگزین موجود نیست.';
      notifyListeners();
      return;
    }

    connectionState = VpnConnectionState.switching;
    notifyListeners();

    await _safeStop();
    _liveTimer?.cancel();

    await _latency.testAll(
      pool,
      concurrency: 3,
      timeout: const Duration(seconds: 6),
    );

    pool.sort(compareByDelay);

    final candidate = pool.cast<VpnConfig?>().firstWhere(
          (e) => e != null && e.isReachable,
          orElse: () => null,
        );

    if (candidate == null) {
      connectionState = VpnConnectionState.error;
      lastError = 'همه سرورهای جایگزین ناموفق بودند.';
      notifyListeners();
      return;
    }

    _consecutiveFailures = 0;
    await _runConnectionOperation(
      () => _connectInternal(candidate),
    );
  }

  Future<void> _persistAll() async {
    await _storage.saveSubscriptions(subscriptions);
    await _storage.saveConfigs(configs);
    await _storage.saveSettings(settings);
    await _storage.saveSelectedConfigId(selectedConfigId);
  }

  @override
  void dispose() {
    _subscriptionTimer?.cancel();
    _liveTimer?.cancel();
    super.dispose();
  }
}

class _SubscriptionResult {
  const _SubscriptionResult(
    this.subscription,
    this.configs,
    this.error,
  );

  final Subscription subscription;
  final List<VpnConfig>? configs;
  final String? error;
}
