import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/providers/statistics_provider.dart';

class TaskStatsTab extends ConsumerWidget {
  const TaskStatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(taskStatsProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        _SummaryRow(stats: stats, theme: theme),
        const SizedBox(height: 24),

        // Weekly completion chart
        Text('Completion Trend (Last 7 Days)',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _WeeklyBarChart(data: stats.completedByDay, theme: theme),
        ),
        const SizedBox(height: 24),

        // Priority breakdown
        if (stats.byPriority.isNotEmpty) ...[
          Text('By Priority', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _PriorityPieChart(data: stats.byPriority, theme: theme),
          ),
          const SizedBox(height: 24),
        ],

        // By list breakdown
        if (stats.byList.isNotEmpty) ...[
          Text('By List', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...stats.byList.entries.map((e) => _BreakdownRow(
                label: e.key,
                count: e.value,
                total: stats.completedAllTime,
                theme: theme,
              )),
          const SizedBox(height: 24),
        ],

        // By tag breakdown
        if (stats.byTag.isNotEmpty) ...[
          Text('By Tag', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...stats.byTag.entries.map((e) => _BreakdownRow(
                label: e.key,
                count: e.value,
                total: stats.completedAllTime,
                theme: theme,
              )),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final TaskStats stats;
  final ThemeData theme;

  const _SummaryRow({required this.stats, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Today',
                value: '${stats.completedToday}',
                icon: Icons.today,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'This Week',
                value: '${stats.completedThisWeek}',
                icon: Icons.date_range,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'This Month',
                value: '${stats.completedThisMonth}',
                icon: Icons.calendar_month,
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'All Time',
                value: '${stats.completedAllTime}',
                icon: Icons.emoji_events,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        if (stats.overdueCount > 0) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Text(
                    '${stats.overdueCount} overdue task${stats.overdueCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final Map<String, int> data;
  final ThemeData theme;

  const _WeeklyBarChart({required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text('No data yet',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline)),
      );
    }

    final entries = data.entries.toList();
    final maxY = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxY + 2).toDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} tasks',
                TextStyle(color: theme.colorScheme.onInverseSurface),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(entries[idx].key,
                      style: theme.textTheme.bodySmall),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == value.roundToDouble()) {
                  return Text('${value.toInt()}',
                      style: theme.textTheme.bodySmall);
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: List.generate(entries.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value.toDouble(),
                color: theme.colorScheme.primary,
                width: 20,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _PriorityPieChart extends StatelessWidget {
  final Map<String, int> data;
  final ThemeData theme;

  const _PriorityPieChart({required this.data, required this.theme});

  static const _priorityColors = {
    'None': Color(0xFF9E9E9E),
    'Low': Color(0xFF4CAF50),
    'Medium': Color(0xFFFF9800),
    'High': Color(0xFFF44336),
  };

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<int>(0, (s, v) => s + v);
    if (total == 0) return const SizedBox();

    final entries = data.entries.toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: entries.map((e) {
                final pct = (e.value / total * 100).round();
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  title: '$pct%',
                  color: _priorityColors[e.key] ?? theme.colorScheme.outline,
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _priorityColors[e.key] ??
                          theme.colorScheme.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.key} (${e.value})',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final ThemeData theme;

  const _BreakdownRow({
    required this.label,
    required this.count,
    required this.total,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text('$count', style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
