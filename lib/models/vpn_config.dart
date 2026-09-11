import 'dart:convert';

class Subscription {
  const Subscription({
    required this.id,
    required this.url,
    required this.name,
    this.lastUpdated,
    this.lastError,
    this.serverCount = 0,
  });

  final String id;
  final String url;
  final String name;
  final DateTime? lastUpdated;
  final String? lastError;
  final int serverCount;

  factory Subscription.create(String rawUrl) {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    final host = uri?.host.trim();
    final name = host == null || host.isEmpty ? 'Subscription' : host;

    // Stable identity based on normalized URL instead of a mutable display field.
    return Subscription(
      id: base64Url.encode(utf8.encode(url)),
      url: url,
      name: name,
    );
  }

  Subscription copyWith({
    String? name,
    DateTime? lastUpdated,
    String? lastError,
    bool clearError = false,
    int? serverCount,
  }) {
    return Subscription(
      id: id,
      url: url,
      name: name ?? this.name,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastError: clearError ? null : (lastError ?? this.lastError),
      serverCount: serverCount ?? this.serverCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'name': name,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'lastError': lastError,
        'serverCount': serverCount,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final url = _string(json['url']);
    final fallback = Subscription.create(url);

    return Subscription(
      id: _string(json['id']).isEmpty ? fallback.id : _string(json['id']),
      url: url,
      name: _string(json['name']).isEmpty ? fallback.name : _string(json['name']),
      lastUpdated: _date(json['lastUpdated']),
      lastError: json['lastError']?.toString(),
      serverCount: _int(json['serverCount']).clamp(0, 100000),
    );
  }
}

class VpnConfig {
  VpnConfig({
    required this.id,
    required this.rawLink,
    required this.subscriptionId,
    required this.remark,
    required this.protocol,
    this.lastDelayMs,
    this.lastTestedAt,
  });

  final String id;
  final String rawLink;
  final String subscriptionId;
  final String remark;
  final String protocol;

  int? lastDelayMs;
  DateTime? lastTestedAt;

  bool get isReachable => lastDelayMs != null && lastDelayMs! >= 0;
  bool get isUntested => lastDelayMs == null;

  factory VpnConfig.fromLink({
    required String subscriptionId,
    required String rawLink,
    required String remark,
    required String protocol,
  }) {
    final normalized = rawLink.trim();
    final id = base64Url.encode(
      utf8.encode('$subscriptionId|$normalized'),
    );

    return VpnConfig(
      id: id,
      rawLink: normalized,
      subscriptionId: subscriptionId,
      remark: remark.trim().isEmpty ? protocol : remark.trim(),
      protocol: protocol.toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawLink': rawLink,
        'subscriptionId': subscriptionId,
        'remark': remark,
        'protocol': protocol,
        'lastDelayMs': lastDelayMs,
        'lastTestedAt': lastTestedAt?.toIso8601String(),
      };

  factory VpnConfig.fromJson(Map<String, dynamic> json) {
    return VpnConfig(
      id: _string(json['id']),
      rawLink: _string(json['rawLink']),
      subscriptionId: _string(json['subscriptionId']),
      remark: _string(json['remark']),
      protocol: _string(json['protocol']),
      lastDelayMs: _nullableInt(json['lastDelayMs']),
      lastTestedAt: _date(json['lastTestedAt']),
    );
  }
}

class AppSettings {
  AppSettings({
    this.subscriptionRefreshHours = 3,
    this.pingIntervalSeconds = 60,
    this.autoSwitchEnabled = true,
    this.switchImprovementMs = 80,
    this.maxServersToPingLive = 6,
    this.verifyInternet = true,
    this.switchCooldownSeconds = 180,
    this.requiredFailuresForFailover = 2,
    List<String>? vpnExcludedPackages,
    this.activeSubscriptionId,
  }) : vpnExcludedPackages = List.unmodifiable(vpnExcludedPackages ?? const []);

  final int subscriptionRefreshHours;
  final int pingIntervalSeconds;
  final bool autoSwitchEnabled;
  final int switchImprovementMs;
  final int maxServersToPingLive;
  final bool verifyInternet;
  final int switchCooldownSeconds;
  final int requiredFailuresForFailover;
  final List<String> vpnExcludedPackages;
  final String? activeSubscriptionId;

  AppSettings normalized() => AppSettings(
        subscriptionRefreshHours:
            subscriptionRefreshHours.clamp(1, 24),
        pingIntervalSeconds:
            pingIntervalSeconds.clamp(15, 300),
        autoSwitchEnabled: autoSwitchEnabled,
        switchImprovementMs:
            switchImprovementMs.clamp(20, 500),
        maxServersToPingLive:
            maxServersToPingLive.clamp(2, 20),
        verifyInternet: verifyInternet,
        switchCooldownSeconds:
            switchCooldownSeconds.clamp(30, 1800),
        requiredFailuresForFailover:
            requiredFailuresForFailover.clamp(1, 5),
        vpnExcludedPackages: vpnExcludedPackages,
        activeSubscriptionId: activeSubscriptionId,
      );

  AppSettings copyWith({
    int? subscriptionRefreshHours,
    int? pingIntervalSeconds,
    bool? autoSwitchEnabled,
    int? switchImprovementMs,
    int? maxServersToPingLive,
    bool? verifyInternet,
    int? switchCooldownSeconds,
    int? requiredFailuresForFailover,
    List<String>? vpnExcludedPackages,
    String? activeSubscriptionId,
    bool clearActiveSubscription = false,
  }) {
    return AppSettings(
      subscriptionRefreshHours:
          subscriptionRefreshHours ?? this.subscriptionRefreshHours,
      pingIntervalSeconds:
          pingIntervalSeconds ?? this.pingIntervalSeconds,
      autoSwitchEnabled:
          autoSwitchEnabled ?? this.autoSwitchEnabled,
      switchImprovementMs:
          switchImprovementMs ?? this.switchImprovementMs,
      maxServersToPingLive:
          maxServersToPingLive ?? this.maxServersToPingLive,
      verifyInternet:
          verifyInternet ?? this.verifyInternet,
      switchCooldownSeconds:
          switchCooldownSeconds ?? this.switchCooldownSeconds,
      requiredFailuresForFailover:
          requiredFailuresForFailover ?? this.requiredFailuresForFailover,
      vpnExcludedPackages:
          vpnExcludedPackages ?? this.vpnExcludedPackages,
      activeSubscriptionId: clearActiveSubscription
          ? null
          : (activeSubscriptionId ?? this.activeSubscriptionId),
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
        'subscriptionRefreshHours': subscriptionRefreshHours,
        'pingIntervalSeconds': pingIntervalSeconds,
        'autoSwitchEnabled': autoSwitchEnabled,
        'switchImprovementMs': switchImprovementMs,
        'maxServersToPingLive': maxServersToPingLive,
        'verifyInternet': verifyInternet,
        'switchCooldownSeconds': switchCooldownSeconds,
        'requiredFailuresForFailover': requiredFailuresForFailover,
        'vpnExcludedPackages': vpnExcludedPackages,
        'activeSubscriptionId': activeSubscriptionId,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      subscriptionRefreshHours: _int(json['subscriptionRefreshHours'], 3),
      pingIntervalSeconds: _int(json['pingIntervalSeconds'], 60),
      autoSwitchEnabled: _bool(json['autoSwitchEnabled'], true),
      switchImprovementMs: _int(json['switchImprovementMs'], 80),
      maxServersToPingLive: _int(json['maxServersToPingLive'], 6),
      verifyInternet: _bool(json['verifyInternet'], true),
      switchCooldownSeconds: _int(json['switchCooldownSeconds'], 180),
      requiredFailuresForFailover:
          _int(json['requiredFailuresForFailover'], 2),
      vpnExcludedPackages: (json['vpnExcludedPackages'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      activeSubscriptionId: json['activeSubscriptionId']?.toString(),
    ).normalized();
  }
}

int compareByDelay(VpnConfig a, VpnConfig b) {
  final aDelay = a.lastDelayMs;
  final bDelay = b.lastDelayMs;

  if (aDelay == null && bDelay == null) {
    return a.remark.compareTo(b.remark);
  }
  if (aDelay == null) return 1;
  if (bDelay == null) return -1;
  if (aDelay < 0 && bDelay < 0) return 0;
  if (aDelay < 0) return 1;
  if (bDelay < 0) return -1;
  return aDelay.compareTo(bDelay);
}

String _string(dynamic value) => value?.toString() ?? '';

int _int(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return _int(value);
}

bool _bool(dynamic value, bool fallback) {
  if (value is bool) return value;
  return fallback;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse('$value');
}
