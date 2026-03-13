import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/screens/statistics/task_stats_tab.dart';
import 'package:ticktick_clone/screens/statistics/focus_stats_tab.dart';
import 'package:ticktick_clone/screens/statistics/habit_stats_tab.dart';
import 'package:ticktick_clone/screens/statistics/achievements_tab.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistics'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.task_alt), text: 'Tasks'),
              Tab(icon: Icon(Icons.timer), text: 'Focus'),
              Tab(icon: Icon(Icons.repeat), text: 'Habits'),
              Tab(icon: Icon(Icons.emoji_events), text: 'Achievements'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TaskStatsTab(),
            FocusStatsTab(),
            HabitStatsTab(),
            AchievementsTab(),
          ],
        ),
      ),
    );
  }
}
