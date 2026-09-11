import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/errors/app_exception.dart';
import '../models/vpn_config.dart';

class StorageService {
  const StorageService();

  static const _settingsKey = 'settings_v4';
  static const _configsKey = 'configs_v4';
  static const _subscriptionsKey = 'subscriptions_v4';
  static const _selectedConfigKey = 'selected_config_v4';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw StorageException('خواندن اطلاعات محلی ناموفق بود: $e');
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      throw StorageException('ذخیره اطلاعات محلی ناموفق بود: $e');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw StorageException('حذف اطلاعات محلی ناموفق بود: $e');
    }
  }

  Future<AppSettings> loadSettings() async {
    final raw = await _read(_settingsKey);
    if (raw == null) return AppSettings();

    try {
      final map = jsonDecode(raw);
      if (map is! Map) throw const FormatException();
      return AppSettings.fromJson(Map<String, dynamic>.from(map));
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings value) =>
      _write(_settingsKey, jsonEncode(value.normalized().toJson()));

  Future<List<VpnConfig>> loadConfigs() async {
    final raw = await _read(_configsKey);
    if (raw == null) return [];

    try {
      final value = jsonDecode(raw);
      if (value is! List) throw const FormatException();
      return value
          .whereType<Map>()
          .map((e) => VpnConfig.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty && e.rawLink.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveConfigs(List<VpnConfig> value) =>
      _write(_configsKey, jsonEncode(value.map((e) => e.toJson()).toList()));

  Future<List<Subscription>> loadSubscriptions() async {
    final raw = await _read(_subscriptionsKey);
    if (raw == null) return [];

    try {
      final value = jsonDecode(raw);
      if (value is! List) throw const FormatException();
      return value
          .whereType<Map>()
          .map((e) => Subscription.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSubscriptions(List<Subscription> value) => _write(
        _subscriptionsKey,
        jsonEncode(value.map((e) => e.toJson()).toList()),
      );

  Future<String?> loadSelectedConfigId() => _read(_selectedConfigKey);

  Future<void> saveSelectedConfigId(String? value) async {
    if (value == null) {
      await _delete(_selectedConfigKey);
      return;
    }
    await _write(_selectedConfigKey, value);
  }
}
