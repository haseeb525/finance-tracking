import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import '../utils/app_theme.dart';
import 'dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();

      // Check if user already exists
      final existingUser = await DatabaseHelper.instance.getUserByUsername(
        username,
      );
      if (existingUser != null) {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            'Username already exists',
            isError: true,
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Create new user
      final newUser = UserModel(
        username: username,
        createdAt: Helpers.getCurrentDateTime(),
      );

      final user = await DatabaseHelper.instance.createUser(newUser);

      if (user != null && user.id != null) {
        // Save user session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(AppConstants.keyUserId, user.id!);
        await prefs.setString(AppConstants.keyUsername, user.username);

        if (mounted) {
          Helpers.showSnackBar(context, 'Account created successfully!');
          // Navigate to dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  DashboardScreen(userId: user.id!, username: user.username),
            ),
          );
        }
      } else {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            'Failed to create account',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppTheme.darkBg, AppTheme.darkSurface]
                    : [AppTheme.lightBg, Colors.white],
              ),
            ),
          ),

          // Neon glow effect (dark mode only)
          if (isDark)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.neonBlue.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Animated app icon
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppTheme.neonGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.neonBlue.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          size: 60.sp,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 32.h),

                      // Title with gradient
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: isDark
                              ? [AppTheme.neonBlue, AppTheme.neonPurple]
                              : [AppTheme.primaryLight, AppTheme.accentLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          'Finance Tracker',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),

                      Text(
                        'Enter your name to begin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 56.h),

                      // Username field with neon border
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          gradient: isDark
                              ? LinearGradient(
                                  colors: [
                                    AppTheme.neonBlue.withOpacity(0.1),
                                    AppTheme.neonPurple.withOpacity(0.1),
                                  ],
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.transparent,
                                  ],
                                ),
                          boxShadow: [
                            if (isDark)
                              BoxShadow(
                                color: AppTheme.neonBlue.withOpacity(0.15),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Your Name',
                            hintText: 'Enter your full name',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: isDark ? AppTheme.neonBlue : null,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppTheme.neonBlue.withOpacity(0.3)
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppTheme.neonBlue.withOpacity(0.2)
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppTheme.neonBlue
                                    : AppTheme.primaryLight,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.darkCard.withOpacity(0.5)
                                : Colors.white70,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 18.h,
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(fontSize: 16.sp),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            if (!Helpers.isValidUsername(value)) {
                              return 'Name must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 40.h),

                      // Futuristic Get Started button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          gradient: LinearGradient(
                            colors: isDark
                                ? [AppTheme.neonBlue, AppTheme.neonPurple]
                                : [AppTheme.primaryLight, AppTheme.accentLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? AppTheme.neonBlue.withOpacity(0.4)
                                  : AppTheme.primaryLight.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoading ? null : _signup,
                            borderRadius: BorderRadius.circular(16.r),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              child: Center(
                                child: _isLoading
                                    ? SizedBox(
                                        height: 24.h,
                                        width: 24.w,
                                        child: const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Get Started',
                                        style: TextStyle(
                                          fontSize: 17.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20.h),

                      // Bottom accent line
                      if (isDark)
                        Center(
                          child: Container(
                            height: 2,
                            width: 60.w,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.neonBlue.withOpacity(0.3),
                                  AppTheme.neonBlue.withOpacity(0),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
