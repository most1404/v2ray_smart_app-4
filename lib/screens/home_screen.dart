import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/power_button.dart';
import 'logs_screen.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';
import 'subscriptions_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (!app.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sinereh VPN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LogsScreen(engine: app.engine),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.link_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SubscriptionsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: app.refreshAllSubscriptions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 16),
            PowerButton(
              state: app.connectionState,
              onTap: () => context.read<AppState>().toggleConnection(),
            ),
            if (app.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                app.lastError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 20),
            _CurrentServerCard(app: app),
            const SizedBox(height: 12),
            _SubscriptionBar(app: app),
            const SizedBox(height: 12),
            _ServerPreview(app: app),
          ],
        ),
      ),
    );
  }
}

class _CurrentServerCard extends StatelessWidget {
  const _CurrentServerCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final current = app.selectedConfig;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: current == null
            ? const Text(
                'هنوز سروری انتخاب نشده است.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            : Row(
                children: [
                  const Icon(Icons.dns_rounded, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      current.remark,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (current.lastDelayMs != null)
                    Text(
                      current.lastDelayMs! >= 0
                          ? '${current.lastDelayMs}ms'
                          : 'خطا',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SubscriptionBar extends StatelessWidget {
  const _SubscriptionBar({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${app.activeConfigs.length} سرور',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        OutlinedButton.icon(
          onPressed: app.isRefreshingSubs
              ? null
              : () => context.read<AppState>().refreshAllSubscriptions(),
          icon: const Icon(Icons.sync, size: 18),
          label: const Text('بروزرسانی'),
        ),
      ],
    );
  }
}

class _ServerPreview extends StatelessWidget {
  const _ServerPreview({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final servers = app.sortedByDelay.take(6).toList();

    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('سرورها'),
            trailing: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ServersScreen(),
                ),
              ),
              child: const Text('همه'),
            ),
          ),
          for (final server in servers)
            ListTile(
              leading: Icon(
                server.id == app.selectedConfigId
                    ? Icons.check_circle
                    : Icons.dns_outlined,
              ),
              title: Text(
                server.remark,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(server.protocol.toUpperCase()),
              trailing: Text(
                server.lastDelayMs == null
                    ? '—'
                    : server.lastDelayMs! < 0
                        ? 'خطا'
                        : '${server.lastDelayMs}ms',
              ),
              onTap: app.isBusy
                  ? null
                  : () async {
                      final ok =
                          await context.read<AppState>().connectTo(server);
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.read<AppState>().lastError ??
                                  'اتصال ناموفق بود.',
                            ),
                          ),
                        );
                      }
                    },
            ),
        ],
      ),
    );
  }
}
