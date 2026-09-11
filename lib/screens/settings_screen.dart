import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vpn_config.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = context.read<AppState>().settings;
  }

  Future<void> _save() async {
    await context.read<AppState>().updateSettings(_settings);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        actions: [
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'بروزرسانی ساب: هر ${_settings.subscriptionRefreshHours} ساعت',
          ),
          Slider(
            value: _settings.subscriptionRefreshHours.toDouble(),
            min: 1,
            max: 24,
            divisions: 23,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(
                subscriptionRefreshHours: v.round(),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('سوییچ خودکار'),
            subtitle: const Text(
              'در صورت بهتر بودن محسوس یک سرور دیگر، جابه‌جا می‌شود.',
            ),
            value: _settings.autoSwitchEnabled,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(
                autoSwitchEnabled: v,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('تأیید اینترنت'),
            value: _settings.verifyInternet,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(
                verifyInternet: v,
              ),
            ),
          ),
          Text(
            'فاصله تست زنده: ${_settings.pingIntervalSeconds} ثانیه',
          ),
          Slider(
            value: _settings.pingIntervalSeconds.toDouble(),
            min: 15,
            max: 300,
            divisions: 19,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(
                pingIntervalSeconds: v.round(),
              ),
            ),
          ),
          Text(
            'حداقل بهبود برای سوییچ: ${_settings.switchImprovementMs}ms',
          ),
          Slider(
            value: _settings.switchImprovementMs.toDouble(),
            min: 20,
            max: 500,
            divisions: 48,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(
                switchImprovementMs: v.round(),
              ),
            ),
          ),
          Text(
            'تعداد تست شکست قبل از failover: '
            '${_settings.requiredFailuresForFailover}',
          ),
          Slider(
            value: _settings.requiredFailuresForFailover.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(
                requiredFailuresForFailover: v.round(),
              ),
            ),
          ),
          Text(
            'Cooldown سوییچ: ${_settings.switchCooldownSeconds} ثانیه',
          ),
          Slider(
            value: _settings.switchCooldownSeconds.toDouble(),
            min: 30,
            max: 900,
            divisions: 29,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(
                switchCooldownSeconds: v.round(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}
