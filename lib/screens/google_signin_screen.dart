import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/drive_backup_service.dart';
import 'dashboard_screen.dart';

class GoogleSignInScreen extends StatefulWidget {
  const GoogleSignInScreen({super.key});

  @override
  State<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    // Try silent sign-in
    final email = await DriveBackupService.instance.signInEmail(silently: true);
    if (!mounted) return;

    if (email != null) {
      await _handleSignInSuccess(email);
    }
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final email = await DriveBackupService.instance.signInEmail();
      if (email == null) {
        if (mounted) {
          Helpers.showSnackBar(context, 'Sign-in failed', isError: true);
        }
        return;
      }

      await _handleSignInSuccess(email);
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Sign-in failed: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignInSuccess(String email) async {
    try {
      // Try to restore from Drive
      await DriveBackupService.instance.restoreFromDrive();
    } catch (e) {
      // No backup found or restoration failed, proceed with new user
      debugPrint('Restore attempted: ${e.toString()}');
    }

    if (!mounted) return;

    // Check if user exists
    final existingUser = await DatabaseHelper.instance.getUserByUsername(email);

    int userId;
    if (existingUser != null && existingUser.id != null) {
      userId = existingUser.id!;
    } else {
      // Create new user
      final newUser = UserModel(
        username: email,
        createdAt: Helpers.getCurrentDateTime(),
      );
      final user = await DatabaseHelper.instance.createUser(newUser);
      if (user == null || user.id == null) {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            'Failed to create user account',
            isError: true,
          );
        }
        return;
      }
      userId = user.id!;
    }

    if (mounted) {
      // Save user session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyUserId, userId);
      await prefs.setString(AppConstants.keyUsername, email);

      // Check and perform daily backup if needed (silently in background)
      DriveBackupService.instance.autoBackupIfNeeded();

      if (mounted) {
        Helpers.showSnackBar(context, 'Signed in successfully!');
        // Navigate to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                DashboardScreen(userId: userId, username: email),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isDesktop) SizedBox(height: 40.h),
                Icon(
                  Icons.account_balance_wallet,
                  size: isDesktop ? 60.sp : 80.sp,
                  color: isDark ? Colors.blue.shade300 : Colors.blue,
                ),
                SizedBox(height: isDesktop ? 20.h : 32.h),
                Text(
                  'Finance Tracker',
                  style: TextStyle(
                    fontSize: isDesktop ? 28.sp : 32.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Track your finances and settlements',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isDesktop ? 30.h : 48.h),
                if (_isLoading)
                  Column(
                    children: [
                      CircularProgressIndicator(
                        color: isDark ? Colors.blue.shade300 : Colors.blue,
                      ),
                      SizedBox(height: 16.h),
                      Text('Signing in...', style: TextStyle(fontSize: 14.sp)),
                    ],
                  )
                else
                  SizedBox(
                    width: isDesktop ? 350.w : double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _signIn,
                      icon: Container(
                        width: 36.w,
                        height: 36.h,
                        padding: EdgeInsets.all(5.w),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.w),
                        ),
                        child: Image.asset(
                          'assets/google_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      label: Text(
                        'Sign in with Google',
                        style: TextStyle(fontSize: 16.sp, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(
                          vertical: 14.h,
                          horizontal: 20.w,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: isDesktop ? 20.h : 32.h),
                Text(
                  'Your data is automatically synced to Google Drive',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isDesktop) SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
