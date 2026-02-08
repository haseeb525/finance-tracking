import 'package:flutter/material.dart';

class AppConstants {
  // Transaction types
  static const String transactionTypeGiven = 'GIVEN';
  static const String transactionTypeTaken = 'TAKEN';

  // Colors
  static const Color primaryColor = Color(0xFF6200EA);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color givenColor = Color(0xFFE53935);
  static const Color takenColor = Color(0xFF43A047);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);

  // Shared Preferences keys
  static const String keyUserId = 'user_id';
  static const String keyUsername = 'username';

  // Date format
  static const String dateFormat = 'yyyy-MM-dd';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String reportDateFormat = 'dd-MM-yyyy';
}
