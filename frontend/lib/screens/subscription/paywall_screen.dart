import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/providers/subscription_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subscription = ref.watch(subscriptionProvider);
    final isPremium = subscription.value?.isPremium ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Icon(
              Icons.workspace_premium,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              isPremium ? 'You\'re Premium!' : 'Unlock Everything',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isPremium
                  ? 'Enjoy unlimited access to all features.'
                  : 'Get the most out of your productivity.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Feature comparison
            _FeatureComparisonCard(theme: theme),
            const SizedBox(height: 24),

            // Price and CTA
            if (!isPremium) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Premium',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$2.99/month',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'or \$29.99/year (save 17%)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _handleUpgrade(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Start Free Trial'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '7-day free trial, cancel anytime',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Already premium - show manage button
              _PremiumStatusCard(theme: theme, subscription: subscription),
            ],

            const SizedBox(height: 16),
            Text(
              'Subscriptions are managed through your app store account.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _handleUpgrade(BuildContext context) {
    // In production, this would trigger RevenueCat/Stripe checkout.
    // For now, show a placeholder.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment processing will be configured with Stripe.'),
      ),
    );
  }
}

class _FeatureComparisonCard extends StatelessWidget {
  final ThemeData theme;
  const _FeatureComparisonCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compare Plans',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _comparisonRow('Lists', 'Up to 9', 'Unlimited'),
            _comparisonRow('Tasks per list', 'Up to 19', 'Unlimited'),
            _comparisonRow('Habits', 'Up to 5', 'Unlimited'),
            _comparisonRow('Reminders per task', 'Up to 2', 'Up to 5'),
            _comparisonRow('Calendar views', 'Basic', 'All layouts'),
            _comparisonRow('Themes', 'Basic', 'All themes'),
            _comparisonRow('Collaboration', '1 member', 'Up to 29'),
            _comparisonRow('Statistics', 'Basic', 'Advanced'),
          ],
        ),
      ),
    );
  }

  Widget _comparisonRow(String feature, String free, String premium) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(feature, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: Text(
              free,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              premium,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumStatusCard extends StatelessWidget {
  final ThemeData theme;
  final AsyncValue<dynamic> subscription;

  const _PremiumStatusCard({
    required this.theme,
    required this.subscription,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Premium Active',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Manage subscription through your app store account.'),
                  ),
                );
              },
              child: const Text('Manage Subscription'),
            ),
          ],
        ),
      ),
    );
  }
}
