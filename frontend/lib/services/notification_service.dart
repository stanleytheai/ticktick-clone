import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ticktick_clone/services/firestore_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Listen for foreground FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap (when app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  /// Request notification permissions and return FCM token
  Future<String?> requestPermissionAndGetToken() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      return await _messaging.getToken();
    }
    return null;
  }

  /// Register FCM token with backend
  Future<void> registerToken(String userId) async {
    final token = await requestPermissionAndGetToken();
    if (token == null) return;

    final platform = Platform.isIOS ? 'ios' : 'android';
    await FirestoreService().registerFcmToken(userId, token, platform);

    // Listen for token refreshes
    _messaging.onTokenRefresh.listen((newToken) {
      FirestoreService().registerFcmToken(userId, newToken, platform);
    });
  }

  /// Show a local notification (for foreground reminder display)
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'reminders',
      'Task Reminders',
      channelDescription: 'Notifications for task reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Schedule a local notification for a future time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    // Only schedule if in the future
    if (scheduledTime.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'reminders',
      'Task Reminders',
      channelDescription: 'Notifications for task reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use schedule for future notifications
    // Note: For production, use timezone-aware scheduling with TZDateTime
    // For now, use show() with a delayed Future as a simple approach
    final delay = scheduledTime.difference(DateTime.now());
    if (delay.isNegative) return;
    Future.delayed(delay, () {
      _localNotifications.show(id, title, body, details, payload: payload);
    });
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show local notification when app is in foreground
    showLocalNotification(
      id: message.hashCode,
      title: message.notification?.title ?? 'TickTick Clone',
      body: message.notification?.body ?? '',
      payload: message.data['taskId'],
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    // Navigation to task detail would be handled by the app's routing
    // The payload/data can be used to navigate to the right screen
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    // Handle local notification tap - payload contains taskId
    // Navigation would be handled by the app's global key navigator
  }
}
