import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/providers/statistics_provider.dart';

class FocusStatsTab extends ConsumerWidget {
  const FocusStatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(focusStatsProvider);
    final theme = Theme.of(context);

    if (stats.totalSessions == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No focus sessions yet',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Start a Pomodoro timer to track your focus time',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        Row(
          children: [
            Expanded(
              child: _FocusCard(
                label: 'Total Sessions',
                value: '${stats.totalSessions}',
                icon: Icons.play_circle_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FocusCard(
                label: 'Total Time',
                value: _formatMinutes(stats.totalMinutes),
                icon: Icons.timer,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FocusCard(
                label: 'Today',
                value: _formatMinutes(stats.todayMinutes),
                icon: Icons.today,
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FocusCard(
                label: 'This Week',
                value: _formatMinutes(stats.thisWeekMinutes),
                icon: Icons.date_range,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Weekly focus chart
        Text('Focus Time (Last 7 Days)',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _FocusLineChart(data: stats.minutesByDay, theme: theme),
        ),
        const SizedBox(height: 24),

        // By list breakdown
        if (stats.minutesByList.isNotEmpty) ...[
          Text('Focus Time by List', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...stats.minutesByList.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: theme.textTheme.bodyMedium),
                    Text(_formatMinutes(e.value),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}

class _FocusCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _FocusCard({
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

class _FocusLineChart extends StatelessWidget {
  final Map<String, int> data;
  final ThemeData theme;

  const _FocusLineChart({required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    final entries = data.entries.toList();
    final maxY = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    return LineChart(
      LineChartData(
        maxY: (maxY + 10).toDouble(),
        minY: 0,
        titlesData: FlTitlesData(
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
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (value == value.roundToDouble()) {
                  return Text('${value.toInt()}m',
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
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 10,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(entries.length,
                (i) => FlSpot(i.toDouble(), entries[i].value.toDouble())),
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: theme.colorScheme.primary,
                strokeWidth: 2,
                strokeColor: theme.colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
