import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/app_notification.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

final notificationsStreamProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchNotifications(user.uid);
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(0);
  return ref
      .watch(firestoreServiceProvider)
      .watchUnreadNotificationCount(user.uid);
});

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
});
