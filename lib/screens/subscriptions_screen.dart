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
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
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
    if (error != null && error.isNotEmpty) {
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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

  Widget _buildSubscriptionCard(BuildContext context, AppState app, SubscriptionViewData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            RadioListTile<String>(
              value: data.id,
              groupValue: app.settings.activeSubscriptionId,
              onChanged: (_) =>
                  context.read<AppState>().setActiveSubscription(data.id),
              title: Text(data.name),
              subtitle: Text('${data.serverCount} سرور'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _maskUrl(data.url),
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
                      await Clipboard.setData(ClipboardData(text: data.url));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('لینک کپی شد.')),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    onPressed: () => _remove(context, data.id, data.name),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
            if (data.lastError != null && data.lastError!.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    data.lastError!,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final subscriptionCards = app.subscriptions
        .map(
          (sub) => SubscriptionViewData(
            id: sub.id,
            name: sub.name,
            url: sub.url,
            serverCount: sub.serverCount,
            lastError: sub.lastError,
          ),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ساب‌اسکریپشن‌ها'),
        actions: [
          IconButton(
            tooltip: 'بروزرسانی همه',
            onPressed: app.subscriptions.isEmpty || app.isRefreshingSubs
                ? null
                : context.read<AppState>().refreshAllSubscriptions,
            icon: const Icon(Icons.sync_rounded),
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                Card(
                  child: RadioListTile<String?>(
                    value: null,
                    groupValue: app.settings.activeSubscriptionId,
                    onChanged: (_) => context
                        .read<AppState>()
                        .setActiveSubscription(null),
                    title: const Text('همه ساب‌ها'),
                    subtitle: Text('${app.configs.length} سرور'),
                  ),
                ),
                const SizedBox(height: 10),
                ...subscriptionCards.map(
                  (data) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildSubscriptionCard(context, app, data),
                  ),
                ),
              ],
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

class SubscriptionViewData {
  const SubscriptionViewData({
    required this.id,
    required this.name,
    required this.url,
    required this.serverCount,
    required this.lastError,
  });

  final String id;
  final String name;
  final String url;
  final int serverCount;
  final String? lastError;
}
