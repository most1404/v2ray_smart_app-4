import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class PowerButton extends StatelessWidget {
  const PowerButton({
    super.key,
    required this.state,
    this.onTap,
  });

  final VpnConnectionState state;
  final VoidCallback? onTap;

  bool get _busy =>
      state == VpnConnectionState.connecting ||
      state == VpnConnectionState.switching;

  Color get _color => switch (state) {
        VpnConnectionState.connected => AppColors.success,
        VpnConnectionState.connecting ||
        VpnConnectionState.switching =>
          AppColors.accent,
        VpnConnectionState.error => AppColors.danger,
        _ => AppColors.textSecondary,
      };

  String get _label => switch (state) {
        VpnConnectionState.connected => 'متصل',
        VpnConnectionState.connecting => 'در حال اتصال...',
        VpnConnectionState.switching => 'در حال جابجایی...',
        VpnConnectionState.error => 'خطا در اتصال',
        _ => 'اتصال قطع است',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _busy ? null : onTap,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _color.withValues(alpha: .25),
                  _color.withValues(alpha: .02),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: _color, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _color.withValues(alpha: .35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Icon(
                        Icons.power_settings_new_rounded,
                        size: 56,
                        color: _color,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      ],
    );
  }
}
