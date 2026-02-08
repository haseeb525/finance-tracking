import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'constants.dart';

class Helpers {
  // Hash password
  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Format currency
  static String formatCurrency(double amount) {
    return 'PKR ${amount.toStringAsFixed(2)}';
  }

  // Format date
  static String formatDate(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return DateFormat(AppConstants.displayDateFormat).format(dateTime);
    } catch (e) {
      return date;
    }
  }

  // Format date for report
  static String formatDateForReport(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return DateFormat(AppConstants.reportDateFormat).format(dateTime);
    } catch (e) {
      return date;
    }
  }

  // Get current date string
  static String getCurrentDate() {
    return DateFormat(AppConstants.dateFormat).format(DateTime.now());
  }

  // Get current datetime string
  static String getCurrentDateTime() {
    return DateTime.now().toIso8601String();
  }

  // Validate email/username
  static bool isValidUsername(String username) {
    return username.length >= 3;
  }

  // Validate password
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  // Show snackbar
  static void showSnackBar(context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
