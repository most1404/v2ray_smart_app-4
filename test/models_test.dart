import 'package:flutter_test/flutter_test.dart';

import 'package:sinereh_vpn/models/vpn_config.dart';

void main() {
  test('settings are normalized', () {
    final settings = AppSettings(
      subscriptionRefreshHours: 999,
      pingIntervalSeconds: 1,
      switchImprovementMs: 1,
      maxServersToPingLive: 999,
      switchCooldownSeconds: 1,
      requiredFailuresForFailover: 99,
    ).normalized();

    expect(settings.subscriptionRefreshHours, 24);
    expect(settings.pingIntervalSeconds, 15);
    expect(settings.switchImprovementMs, 20);
    expect(settings.maxServersToPingLive, 20);
    expect(settings.switchCooldownSeconds, 30);
    expect(settings.requiredFailuresForFailover, 5);
  });

  test('server comparison puts unreachable servers last', () {
    final a = VpnConfig.fromLink(
      subscriptionId: 's',
      rawLink: 'vless://a',
      remark: 'a',
      protocol: 'vless',
    );
    final b = VpnConfig.fromLink(
      subscriptionId: 's',
      rawLink: 'vless://b',
      remark: 'b',
      protocol: 'vless',
    );

    a.lastDelayMs = 80;
    b.lastDelayMs = -1;

    expect(compareByDelay(a, b), lessThan(0));
  });
}
