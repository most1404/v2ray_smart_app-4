import 'dart:async';

import '../models/vpn_config.dart';
import 'vpn_engine.dart';

class LatencyService {
  LatencyService(this.engine);

  final VpnEngine engine;

  Future<void> testAll(
    List<VpnConfig> configs, {
    int concurrency = 3,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (configs.isEmpty) return;

    final queue = List<VpnConfig>.from(configs);
    final workers = concurrency.clamp(1, 8);

    await Future.wait(
      List.generate(
        workers,
        (_) => _worker(queue, timeout),
      ),
    );
  }

  Future<void> _worker(
    List<VpnConfig> queue,
    Duration timeout,
  ) async {
    while (true) {
      if (queue.isEmpty) return;
      final config = queue.removeLast();
      await testOne(config, timeout: timeout);
    }
  }

  Future<int> testOne(
    VpnConfig config, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    var delay = -1;

    try {
      final parsed = engine.parse(config.rawLink);
      delay = await engine
          .getServerDelay(parsed.fullConfig)
          .timeout(timeout);

      if (delay < 0) delay = -1;
    } catch (_) {
      delay = -1;
    }

    config.lastDelayMs = delay;
    config.lastTestedAt = DateTime.now();
    return delay;
  }

  Future<int> connected({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final delay = await engine.getConnectedDelay().timeout(timeout);
      return delay < 0 ? -1 : delay;
    } catch (_) {
      return -1;
    }
  }
}
