import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.sortedByDelay;

    return Scaffold(
      appBar: AppBar(
        title: Text('سرورها (${list.length})'),
        actions: [
          IconButton(
            onPressed:
                app.isTestingAll ? null : context.read<AppState>().testAll,
            icon: const Icon(Icons.speed),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final server = list[index];
          final delay = server.lastDelayMs;

          final color = delay == null
              ? AppColors.textSecondary
              : delay < 0
                  ? AppColors.danger
                  : delay < 150
                      ? AppColors.success
                      : delay < 400
                          ? AppColors.warning
                          : AppColors.danger;

          return ListTile(
            leading: Icon(
              server.id == app.selectedConfigId
                  ? Icons.check_circle
                  : Icons.dns_outlined,
              color: server.id == app.selectedConfigId
                  ? AppColors.success
                  : null,
            ),
            title: Text(
              server.remark,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(server.protocol.toUpperCase()),
            trailing: Text(
              delay == null
                  ? '—'
                  : delay < 0
                      ? 'خطا'
                      : '${delay}ms',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: app.isBusy
                ? null
                : () async {
                    final ok =
                        await context.read<AppState>().connectTo(server);
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context);
                    } else {
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
          );
        },
      ),
    );
  }
}
