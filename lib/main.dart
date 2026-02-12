import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'screens/google_signin_screen.dart';
import 'screens/dashboard_screen.dart';
import 'utils/constants.dart';
import 'utils/app_theme.dart';
import 'utils/theme_provider.dart';
import 'utils/transaction_change_notifier.dart';
import 'utils/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TransactionChangeNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp(
              title: 'Finance Tracker',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    await Future.delayed(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(AppConstants.keyUserId);
    final username = prefs.getString(AppConstants.keyUsername);

    if (mounted) {
      if (userId != null && username != null) {
        // User already signed in, go to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                DashboardScreen(userId: userId, username: username),
          ),
        );
      } else {
        // No user session, go to Google Sign-In
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const GoogleSignInScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 100.sp,
              color: Colors.white,
            ),
            SizedBox(height: 24.h),
            Text(
              'Finance Tracker',
              style: TextStyle(
                fontSize: 32.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16.h),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
