import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/helpers.dart';
import '../utils/drive_backup_service.dart';
import '../utils/transaction_change_notifier.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isBusy = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _trySilentSignIn();
  }

  Future<void> _trySilentSignIn() async {
    final user = await DriveBackupService.instance.signIn(silently: true);
    if (!mounted) return;
    setState(() => _email = user?.email);
  }

  Future<void> _signIn() async {
    setState(() => _isBusy = true);
    try {
      final user = await DriveBackupService.instance.signIn();
      if (mounted) {
        setState(() => _email = user?.email);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Sign-in failed: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isBusy = true);
    try {
      await DriveBackupService.instance.signOut();
      if (mounted) {
        setState(() => _email = null);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Sign-out failed: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _backup() async {
    if (_email == null) {
      Helpers.showSnackBar(context, 'Please sign in first', isError: true);
      return;
    }
    setState(() => _isBusy = true);
    try {
      final ok = await DriveBackupService.instance.backupToDrive();
      if (!mounted) return;
      Helpers.showSnackBar(
        context,
        ok ? 'Backup uploaded to Drive' : 'Backup failed',
        isError: !ok,
      );
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Backup failed: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restore() async {
    if (_email == null) {
      Helpers.showSnackBar(context, 'Please sign in first', isError: true);
      return;
    }
    setState(() => _isBusy = true);
    try {
      final ok = await DriveBackupService.instance.restoreFromDrive();
      if (!mounted) return;
      if (ok) {
        Helpers.showSnackBar(context, 'Restore completed successfully');
        context.read<TransactionChangeNotifier>().notifyTransactionUpdated();
      } else {
        Helpers.showSnackBar(context, 'No backup file found', isError: true);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Restore failed: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Backup & Restore',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isDark
                      ? AppTheme.neonBlue.withOpacity(0.2)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_circle,
                    size: 36.sp,
                    color: isDark ? AppTheme.neonBlue : AppTheme.primaryLight,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      _email ?? 'Not signed in',
                      style: TextStyle(fontSize: 14.sp),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBusy
                        ? null
                        : (_email == null ? _signIn : _signOut),
                    icon: Icon(
                      _email == null ? Icons.login : Icons.logout,
                      color: Colors.white,
                    ),
                    label: Text(
                      _email == null ? 'Sign In' : 'Sign Out',
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppTheme.neonBlue
                          : AppTheme.primaryLight,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _backup,
                    icon: const Icon(Icons.cloud_upload, color: Colors.white),
                    label: Text(
                      'Backup Now',
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _restore,
                    icon: const Icon(Icons.cloud_download, color: Colors.white),
                    label: Text(
                      'Restore Now',
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Backups are stored as a single file in your Google Drive app data.',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
