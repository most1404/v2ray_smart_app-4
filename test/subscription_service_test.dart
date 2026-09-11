import 'package:flutter_test/flutter_test.dart';

import 'package:sinereh_vpn/models/vpn_config.dart';
import 'package:sinereh_vpn/services/subscription_service.dart';
import 'package:sinereh_vpn/services/vpn_engine.dart';

class FakeEngine implements VpnEngine {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  ParsedVpn parse(String rawLink) {
    return ParsedVpn(
      remark: 'test',
      fullConfig: '{}',
    );
  }

  @override
  Future<void> start({
    required String remark,
    required String config,
    List<String>? blockedApps,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<int> getServerDelay(String config) async => 50;

  @override
  Future<int> getConnectedDelay() async => 50;

  @override
  Future<List<String>> getLogs() async => const [];

  @override
  Future<void> clearLogs() async {}
}

void main() {
  test('merge preserves latency', () {
    final engine = FakeEngine();
    final service = SubscriptionService(engine);

    final old = VpnConfig.fromLink(
      subscriptionId: 's',
      rawLink: 'vless://a',
      remark: 'old',
      protocol: 'vless',
    )..lastDelayMs = 123;

    final fresh = VpnConfig.fromLink(
      subscriptionId: 's',
      rawLink: 'vless://a',
      remark: 'new',
      protocol: 'vless',
    );

    final merged = service.mergeWithExisting([fresh], [old]);

    expect(merged.single.lastDelayMs, 123);
  });
}
