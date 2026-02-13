import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/helpers.dart';
import '../utils/drive_backup_service.dart';
import '../utils/transaction_change_notifier.dart';
import '../utils/notification_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isBusy = false;
  String? _email;
  Map<String, dynamic>? _backupInfo;

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
      if (ok) {
        Helpers.showSnackBar(context, 'Backup uploaded to Drive');
        // Automatically check backup status after successful backup
        await _checkBackupStatus();
      } else {
        Helpers.showSnackBar(context, 'Backup failed', isError: true);
      }
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

  Future<void> _checkBackupStatus() async {
    if (_email == null) {
      Helpers.showSnackBar(context, 'Please sign in first', isError: true);
      return;
    }
    setState(() => _isBusy = true);
    try {
      final info = await DriveBackupService.instance.getBackupInfo();
      if (!mounted) return;
      setState(() => _backupInfo = info);
      if (info == null) {
        Helpers.showSnackBar(
          context,
          'No backup found in Google Drive',
          isError: true,
        );
      } else {
        Helpers.showSnackBar(context, 'Backup found! Check details below.');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to check backup: ${e.toString()}',
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
      body: SingleChildScrollView(
        child: Padding(
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
                      icon: const Icon(
                        Icons.cloud_download,
                        color: Colors.white,
                      ),
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
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isBusy ? null : _checkBackupStatus,
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                      label: Text(
                        'Check Backup Status',
                        style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_backupInfo != null) ...[
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark
                          ? Colors.green.withOpacity(0.3)
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Backup Found',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildInfoRow(
                        'File Name',
                        _backupInfo!['name'] ?? 'N/A',
                        isDark,
                      ),
                      SizedBox(height: 8.h),
                      _buildInfoRow(
                        'Size',
                        _formatFileSize(_backupInfo!['size'] ?? 0),
                        isDark,
                      ),
                      if (_backupInfo!['modifiedTime'] != null) ...[
                        SizedBox(height: 8.h),
                        _buildInfoRow(
                          'Last Modified',
                          _formatDateTime(_backupInfo!['modifiedTime']),
                          isDark,
                        ),
                      ],
                      if (_backupInfo!['createdTime'] != null) ...[
                        SizedBox(height: 8.h),
                        _buildInfoRow(
                          'Created',
                          _formatDateTime(_backupInfo!['createdTime']),
                          isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              SizedBox(height: 24.h),
              Divider(color: Colors.grey.shade600),
              SizedBox(height: 16.h),
              Text(
                'Test Notifications',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isBusy
                          ? null
                          : () async {
                              await NotificationService.instance
                                  .showTestNotification();
                              if (mounted) {
                                Helpers.showSnackBar(
                                  context,
                                  'Test notification sent! Check your notification panel.',
                                );
                              }
                            },
                      icon: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Test Notification',
                        style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
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
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime.toLocal());
  }
}
