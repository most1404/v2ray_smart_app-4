import 'dart:async';

import 'package:http/http.dart' as http;

class ConnectivityVerifier {
  static final _endpoints = <Uri>[
    Uri.parse('https://clients3.google.com/generate_204'),
    Uri.parse('https://www.gstatic.com/generate_204'),
    Uri.parse('https://cp.cloudflare.com/generate_204'),
  ];

  Future<bool> verify({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final client = http.Client();

    try {
      for (final endpoint in _endpoints) {
        try {
          final response = await client.get(endpoint).timeout(timeout);
          if (response.statusCode >= 200 && response.statusCode < 400) {
            return true;
          }
        } on TimeoutException {
          continue;
        } catch (_) {
          continue;
        }
      }
      return false;
    } finally {
      client.close();
    }
  }
}
