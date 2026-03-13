import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/providers/statistics_provider.dart';

class AchievementsTab extends ConsumerWidget {
  const AchievementsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    final theme = Theme.of(context);
    final unlocked = achievements.where((a) => a.unlocked).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.emoji_events,
                    size: 40, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$unlocked / ${achievements.length} Unlocked',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Keep going to unlock more!',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Achievement grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            return _AchievementCard(
              achievement: achievements[index],
              theme: theme,
            );
          },
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final ThemeData theme;

  const _AchievementCard({
    required this.achievement,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final progress = achievement.progress.clamp(0, achievement.target);
    final fraction = achievement.target > 0 ? progress / achievement.target : 0.0;

    return Card(
      color: achievement.unlocked
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              achievement.icon,
              style: TextStyle(
                fontSize: 32,
                color: achievement.unlocked ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: achievement.unlocked
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              achievement.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: achievement.unlocked
                    ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                    : theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (!achievement.unlocked) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$progress / ${achievement.target}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline, fontSize: 10),
              ),
            ] else
              Icon(Icons.check_circle,
                  color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
