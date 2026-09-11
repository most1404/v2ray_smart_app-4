import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final controller = TextEditingController();

    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن ساب'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('افزودن'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (url == null || url.isEmpty || !context.mounted) return;

    await context.read<AppState>().addSubscription(url);

    if (!context.mounted) return;

    final error = context.read<AppState>().lastError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  Future<void> _remove(
    BuildContext context,
    String id,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف ساب'),
        content: Text('ساب «$name» و سرورهایش حذف شوند؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await context.read<AppState>().removeSubscription(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ساب‌اسکریپشن‌ها'),
        actions: [
          IconButton(
            onPressed: app.isRefreshingSubs
                ? null
                : context.read<AppState>().refreshAllSubscriptions,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('افزودن ساب'),
      ),
      body: app.subscriptions.isEmpty
          ? const Center(child: Text('هنوز سابی اضافه نشده است.'))
          : RadioGroup<String?>(
              groupValue: app.settings.activeSubscriptionId,
              onChanged: (value) => context
                  .read<AppState>()
                  .setActiveSubscription(value),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                Card(
                  child: RadioListTile<String?>(
                    value: null,
                    title: const Text('همه ساب‌ها'),
                    subtitle: Text('${app.configs.length} سرور'),
                  ),
                ),
                const SizedBox(height: 10),
                for (final sub in app.subscriptions) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          RadioListTile<String?>(
                            value: sub.id,
                            title: Text(sub.name),
                            subtitle: Text(
                              '${sub.serverCount} سرور',
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _maskUrl(sub.url),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'کپی لینک',
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: sub.url),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text('لینک کپی شد.'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_outlined),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _remove(context, sub.id, sub.name),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (sub.lastError != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  sub.lastError!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ],
          ),
        ),
    );
  }

  static String _maskUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '***';
    final host = uri.host.isEmpty ? 'subscription' : uri.host;
    return '${uri.scheme}://$host/••••';
  }
}
