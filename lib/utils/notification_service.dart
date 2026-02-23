import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/transaction_model.dart';
import 'helpers.dart';

class NotificationService {
  NotificationService._init();

  static final NotificationService instance = NotificationService._init();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Skip initialization on desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      tz.initializeTimeZones();
      return;
    }

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings: initSettings);

    // Request notification permissions for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleSettlementReminder(TransactionModel transaction) async {
    if (transaction.id == null || transaction.expectedSettlementDate == null) {
      return;
    }

    final expectedDate = DateTime.tryParse(transaction.expectedSettlementDate!);
    if (expectedDate == null) return;

    final scheduledDate = tz.TZDateTime.local(
      expectedDate.year,
      expectedDate.month,
      expectedDate.day,
      9,
      0,
    );

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    final title = 'Settlement due today';
    final body =
        '${transaction.personName} - ${Helpers.formatCurrency(transaction.amount)} is due on ${Helpers.formatDate(transaction.expectedSettlementDate!)}.';

    const androidDetails = AndroidNotificationDetails(
      'settlement_reminders',
      'Settlement Reminders',
      channelDescription: 'Reminders for expected settlement dates',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.zonedSchedule(
        id: transaction.id!,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // Silently fail if exact alarm permission is not granted
      // The transaction will still be saved, just without notification
      print('Failed to schedule notification: $e');
    }
  }

  Future<void> cancelSettlementReminder(int transactionId) async {
    try {
      await _notifications.cancel(id: transactionId);
    } catch (e) {
      // Silently fail if notification cancellation fails
      print('Failed to cancel notification: $e');
    }
  }

  /// Test method to show an immediate notification
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notifications for debugging',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.show(
        id: 999,
        title: 'Test Notification',
        body: 'If you see this, notifications are working! 🎉',
        notificationDetails: details,
      );
    } catch (e) {
      print('Failed to show test notification: $e');
    }
  }
}
