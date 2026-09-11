import 'package:flutter_v2ray_client/flutter_v2ray.dart';

import '../core/errors/app_exception.dart';
import 'vpn_engine.dart';

class FlutterV2rayEngine implements VpnEngine {
  FlutterV2rayEngine({this.onStatusChanged}) {
    _v2ray = V2ray(
      onStatusChanged: (status) {
        onStatusChanged?.call(_mapStatus(status.state));
      },
    );
  }

  final void Function(VpnStatus status)? onStatusChanged;
  late final V2ray _v2ray;

  VpnStatus _mapStatus(String? raw) {
    final value = (raw ?? '').toLowerCase();
    if (value.contains('connect') && !value.contains('disconnect')) {
      return VpnStatus.connected;
    }
    if (value.contains('disconnect') || value.contains('stop')) {
      return VpnStatus.disconnected;
    }
    if (value.contains('start') || value.contains('connect')) {
      return VpnStatus.connecting;
    }
    return VpnStatus.unknown;
  }

  @override
  Future<void> initialize() async {
    try {
      await _v2ray.initialize(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );
    } catch (e) {
      throw VpnException('راه‌اندازی موتور VPN ناموفق بود: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _v2ray.requestPermission();
    } catch (e) {
      throw VpnPermissionException('دریافت مجوز VPN ناموفق بود: $e');
    }
  }

  @override
  ParsedVpn parse(String rawLink) {
    try {
      final parsed = V2ray.parseFromURL(rawLink.trim());
      final config = parsed.getFullConfiguration().toString();

      if (config.trim().isEmpty) {
        throw const VpnException('کانفیگ تولیدشده خالی است.');
      }

      return ParsedVpn(
        remark: parsed.remark.trim(),
        fullConfig: config,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw VpnException('کانفیگ قابل پردازش نیست: $e');
    }
  }

  @override
  Future<void> start({
    required String remark,
    required String config,
    List<String>? blockedApps,
  }) async {
    try {
      await _v2ray.startV2Ray(
        remark: remark,
        config: config,
        blockedApps: blockedApps,
        bypassSubnets: null,
        proxyOnly: false,
        notificationDisconnectButtonName: 'قطع اتصال',
      );
    } catch (e) {
      throw VpnException('شروع اتصال VPN ناموفق بود: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _v2ray.stopV2Ray();
    } catch (e) {
      throw VpnException('قطع اتصال VPN ناموفق بود: $e');
    }
  }

  @override
  Future<int> getServerDelay(String config) async {
    try {
      return await _v2ray.getServerDelay(config: config);
    } catch (e) {
      throw VpnException('تست تاخیر سرور ناموفق بود: $e');
    }
  }

  @override
  Future<int> getConnectedDelay() async {
    try {
      return await _v2ray.getConnectedServerDelay();
    } catch (e) {
      throw VpnException('تست تاخیر اتصال ناموفق بود: $e');
    }
  }

  @override
  Future<List<String>> getLogs() async {
    try {
      final logs = await _v2ray.getLogs();
      return logs.map((e) => e.toString()).toList(growable: false);
    } catch (e) {
      throw VpnException('دریافت لاگ VPN ناموفق بود: $e');
    }
  }

  @override
  Future<void> clearLogs() async {
    try {
      await _v2ray.clearLogs();
    } catch (e) {
      throw VpnException('پاک کردن لاگ ناموفق بود: $e');
    }
  }
}
