import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/filter_provider.dart';
import 'package:ticktick_clone/screens/calendar/calendar_screen.dart';
import 'package:ticktick_clone/screens/eisenhower/eisenhower_screen.dart';
import 'package:ticktick_clone/screens/filters/filter_builder_screen.dart';
import 'package:ticktick_clone/screens/filters/smart_list_screen.dart';
import 'package:ticktick_clone/screens/pomodoro/pomodoro_screen.dart';
import 'package:ticktick_clone/screens/tasks/task_list_screen.dart';
import 'package:ticktick_clone/screens/lists/lists_screen.dart';
import 'package:ticktick_clone/screens/habits/habits_screen.dart';
import 'package:ticktick_clone/screens/settings/settings_screen.dart';
import 'package:ticktick_clone/widgets/quick_add_dialog.dart';
import 'package:ticktick_clone/providers/task_provider.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);

    // Ensure default list exists
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      ref.read(firestoreServiceProvider).createDefaultList(user.uid);
    }

    final screens = [
      const _TodayTab(),
      const CalendarScreen(),
      const PomodoroScreen(),
      const EisenhowerScreen(),
      const TaskListScreen(listId: 'inbox', title: 'Inbox'),
      const ListsScreen(),
      const HabitsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      drawer: const _SmartListDrawer(),
      body: IndexedStack(index: selectedTab, children: screens),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const QuickAddDialog(),
        ),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (i) =>
            ref.read(selectedTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar'),
          NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer),
              label: 'Focus'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Matrix'),
          NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox),
              label: 'Inbox'),
          NavigationDestination(
              icon: Icon(Icons.list_outlined),
              selectedIcon: Icon(Icons.list),
              label: 'Lists'),
          NavigationDestination(
              icon: Icon(Icons.repeat_outlined),
              selectedIcon: Icon(Icons.repeat),
              label: 'Habits'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}

class _SmartListDrawer extends ConsumerWidget {
  const _SmartListDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pinnedFilters = ref.watch(pinnedFiltersProvider);
    final allFilters = ref.watch(filtersStreamProvider).value ?? [];

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Smart Lists',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const Divider(),

            // Built-in smart lists
            _DrawerSmartListTile(
              icon: Icons.today,
              title: 'Today',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BuiltInSmartListScreen(
                        smartList: BuiltInSmartList.today),
                  ),
                );
              },
            ),
            _DrawerSmartListTile(
              icon: Icons.next_plan,
              title: 'Tomorrow',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BuiltInSmartListScreen(
                        smartList: BuiltInSmartList.tomorrow),
                  ),
                );
              },
            ),
            _DrawerSmartListTile(
              icon: Icons.date_range,
              title: 'Next 7 Days',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BuiltInSmartListScreen(
                        smartList: BuiltInSmartList.next7Days),
                  ),
                );
              },
            ),
            _DrawerSmartListTile(
              icon: Icons.all_inclusive,
              title: 'All',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BuiltInSmartListScreen(
                        smartList: BuiltInSmartList.all),
                  ),
                );
              },
            ),
            _DrawerSmartListTile(
              icon: Icons.task_alt,
              title: 'Completed',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BuiltInSmartListScreen(
                        smartList: BuiltInSmartList.completed),
                  ),
                );
              },
            ),
            _DrawerSmartListTile(
              icon: Icons.delete_outline,
              title: 'Trash',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BuiltInSmartListScreen(
                        smartList: BuiltInSmartList.trash),
                  ),
                );
              },
            ),

            // Pinned custom filters
            if (pinnedFilters.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Pinned Filters',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              ...pinnedFilters.map((filter) => _DrawerSmartListTile(
                    icon: Icons.filter_list,
                    title: filter.name,
                    color: filter.colorValue != null
                        ? Color(filter.colorValue!)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SmartListScreen(filter: filter),
                        ),
                      );
                    },
                  )),
            ],

            // All custom filters section
            if (allFilters.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Custom Filters',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              ...allFilters
                  .where((f) => !f.pinned)
                  .map((filter) => _DrawerSmartListTile(
                        icon: Icons.filter_list,
                        title: filter.name,
                        color: filter.colorValue != null
                            ? Color(filter.colorValue!)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SmartListScreen(filter: filter),
                            ),
                          );
                        },
                      )),
            ],

            // Create new filter button
            const Divider(),
            _DrawerSmartListTile(
              icon: Icons.add,
              title: 'New Smart List',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FilterBuilderScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSmartListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerSmartListTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      onTap: onTap,
      dense: true,
    );
  }
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayTasks = ref.watch(todayTasksProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Today',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: todayTasks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wb_sunny_outlined,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No tasks due today',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: todayTasks.length,
              itemBuilder: (context, index) {
                final task = todayTasks[index];
                return _TaskTile(task: task);
              },
            ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        color: Colors.green,
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (user == null) return false;
        if (direction == DismissDirection.startToEnd) {
          await ref.read(firestoreServiceProvider).updateTask(
                user.uid,
                task.copyWith(isCompleted: true, updatedAt: DateTime.now()),
              );
        } else {
          await ref.read(firestoreServiceProvider).deleteTask(user.uid, task.id);
        }
        return false;
      },
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (v) {
            if (user == null) return;
            ref.read(firestoreServiceProvider).updateTask(
                  user.uid,
                  task.copyWith(isCompleted: v ?? false, updatedAt: DateTime.now()),
                );
          },
        ),
        title: Text(task.title,
            style: task.isCompleted
                ? TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: theme.colorScheme.outline)
                : null),
        trailing: task.priority.value > 0
            ? Icon(Icons.flag, color: Color(task.priority.colorValue), size: 20)
            : null,
      ),
    );
  }
}
