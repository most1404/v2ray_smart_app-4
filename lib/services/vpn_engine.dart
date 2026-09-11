enum VpnStatus {
  disconnected,
  connecting,
  connected,
  stopping,
  error,
  unknown,
}

class ParsedVpn {
  const ParsedVpn({
    required this.remark,
    required this.fullConfig,
  });

  final String remark;
  final String fullConfig;
}

abstract interface class VpnEngine {
  Future<void> initialize();
  Future<bool> requestPermission();

  ParsedVpn parse(String rawLink);

  Future<void> start({
    required String remark,
    required String config,
    List<String>? blockedApps,
  });

  Future<void> stop();

  Future<int> getServerDelay(String config);

  Future<int> getConnectedDelay();

  Future<List<String>> getLogs();

  Future<void> clearLogs();
}
