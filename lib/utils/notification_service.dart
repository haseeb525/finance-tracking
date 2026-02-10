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

    await _notifications.zonedSchedule(
      id: transaction.id!,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelSettlementReminder(int transactionId) async {
    await _notifications.cancel(id: transactionId);
  }
}
