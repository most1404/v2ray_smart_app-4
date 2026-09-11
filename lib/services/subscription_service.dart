import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/errors/app_exception.dart';
import '../models/vpn_config.dart';
import 'vpn_engine.dart';

class SubscriptionService {
  SubscriptionService(this.engine);

  final VpnEngine engine;

  Future<List<VpnConfig>> fetchSubscription(
    String url, {
    required String subscriptionId,
    http.Client? client,
  }) async {
    final uri = Uri.tryParse(url.trim());

    if (uri == null ||
        !uri.isAbsolute ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const SubscriptionException('آدرس ساب‌اسکریپشن معتبر نیست.');
    }

    final ownClient = client == null;
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient
          .get(
            uri,
            headers: const {
              'Accept': 'text/plain, text/*, application/json, */*',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SubscriptionException(
          'سرور ساب HTTP ${response.statusCode} برگرداند.',
        );
      }

      final body = response.body.trim();
      if (body.isEmpty) {
        throw const SubscriptionException('پاسخ ساب خالی بود.');
      }

      final decoded = _decodeBody(body);
      final candidates = decoded
          .split(RegExp(r'[\r\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);

      final result = <VpnConfig>[];
      final seen = <String>{};

      for (final link in candidates) {
        if (!seen.add(link)) continue;

        try {
          final parsed = engine.parse(link);
          final protocol = link.contains('://')
              ? link.split('://').first.toLowerCase()
              : 'unknown';

          result.add(
            VpnConfig.fromLink(
              subscriptionId: subscriptionId,
              rawLink: link,
              remark: parsed.remark.isEmpty
                  ? '$protocol-${result.length + 1}'
                  : parsed.remark,
              protocol: protocol,
            ),
          );
        } catch (_) {
          // One malformed node must not invalidate the whole subscription.
        }
      }

      if (result.isEmpty) {
        throw const SubscriptionException(
          'هیچ کانفیگ قابل استفاده‌ای در ساب پیدا نشد.',
        );
      }

      return result;
    } on SubscriptionException {
      rethrow;
    } on TimeoutException {
      throw const SubscriptionException(
        'دریافت ساب بیش از حد طول کشید.',
      );
    } catch (e) {
      throw SubscriptionException('دریافت ساب ناموفق بود: $e');
    } finally {
      if (ownClient) httpClient.close();
    }
  }

  String _decodeBody(String body) {
    if (body.contains('://')) return body;

    try {
      var normalized = body.replaceAll(RegExp(r'\s+'), '');
      normalized = normalized.replaceAll('-', '+').replaceAll('_', '/');
      normalized += '=' * ((4 - normalized.length % 4) % 4);

      final bytes = base64.decode(normalized);
      final decoded = utf8.decode(bytes);

      if (decoded.contains('://')) return decoded;
    } catch (_) {
      // Fall back to original content.
    }

    return body;
  }

  List<VpnConfig> mergeWithExisting(
    List<VpnConfig> fresh,
    List<VpnConfig> existing,
  ) {
    final oldById = {for (final item in existing) item.id: item};

    for (final item in fresh) {
      final old = oldById[item.id];
      if (old == null) continue;

      item.lastDelayMs = old.lastDelayMs;
      item.lastTestedAt = old.lastTestedAt;
    }

    return fresh;
  }
}
