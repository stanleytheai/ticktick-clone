import 'package:flutter/material.dart';
import 'package:ticktick_clone/screens/subscription/paywall_screen.dart';

class UpgradePromptDialog extends StatelessWidget {
  final String feature;
  final int currentCount;
  final int limit;

  const UpgradePromptDialog({
    super.key,
    required this.feature,
    required this.currentCount,
    required this.limit,
  });

  static Future<void> show(
    BuildContext context, {
    required String feature,
    required int currentCount,
    required int limit,
  }) {
    return showDialog(
      context: context,
      builder: (_) => UpgradePromptDialog(
        feature: feature,
        currentCount: currentCount,
        limit: limit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.workspace_premium,
          size: 48, color: theme.colorScheme.primary),
      title: const Text('Upgrade to Premium'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You\'ve reached the free tier limit of $limit $feature.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Upgrade to Premium for unlimited $feature and more!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Maybe Later'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            );
          },
          child: const Text('Upgrade'),
        ),
      ],
    );
  }
}
