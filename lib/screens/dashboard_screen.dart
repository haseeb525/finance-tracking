import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/app_theme.dart';
import '../utils/transaction_change_notifier.dart';
import '../utils/drive_backup_service.dart';
import '../widgets/transaction_card.dart';
import '../widgets/theme_toggle.dart';
import 'add_transaction_screen.dart';
import 'backup_restore_screen.dart';
import 'google_signin_screen.dart';
import 'transaction_list_screen.dart';
import 'report_generation_screen.dart';
import 'settled_transactions_screen.dart';
import 'typed_transactions_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int userId;
  final String username;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  double _totalGiven = 0.0;
  double _totalTaken = 0.0;
  List<TransactionModel> _recentTransactions = [];
  List<TransactionModel> _upcomingSettlements = [];

  @override
  void initState() {
    super.initState();
    _loadData();

    // Listen for transaction changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = context.read<TransactionChangeNotifier>();
      notifier.addListener(_onTransactionChange);
    });
  }

  @override
  void dispose() {
    // Remove listener
    try {
      context.read<TransactionChangeNotifier>().removeListener(
        _onTransactionChange,
      );
    } catch (e) {
      // Handle dispose error gracefully
    }
    super.dispose();
  }

  void _onTransactionChange() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final summary = await DatabaseHelper.instance.getSummary(widget.userId);
      final transactions = await DatabaseHelper.instance.getTransactions(
        widget.userId,
      );
      final upcoming = await DatabaseHelper.instance.getUpcomingSettlements(
        widget.userId,
        Helpers.getCurrentDate(),
      );

      setState(() {
        _totalGiven = summary['given'] ?? 0.0;
        _totalTaken = summary['taken'] ?? 0.0;
        _recentTransactions = transactions.take(10).toList();
        _upcomingSettlements = upcoming.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Error loading data: ${e.toString()}',
          isError: true,
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _navigateToAddTransaction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(userId: widget.userId),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _navigateToAllTransactions() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionListScreen(userId: widget.userId),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportGenerationScreen(userId: widget.userId),
      ),
    );
  }

  void _navigateToBackupRestore() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BackupRestoreScreen()),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DriveBackupService.instance.signOut();
        // Clear local session
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(AppConstants.keyUserId);
        await prefs.remove(AppConstants.keyUsername);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const GoogleSignInScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            'Sign out failed: ${e.toString()}',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final netBalance = _totalTaken - _totalGiven;
    final isPositive = netBalance >= 0;

    // Extract username before @ symbol
    final displayName = widget.username.contains('@')
        ? widget.username.split('@').first
        : widget.username;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isDesktop ? 56.h : 95.h),
        child: AppBar(
          elevation: 0,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: isDesktop ? 2.h : 4.h,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Welcome, $displayName',
                      style: TextStyle(
                        fontSize: isDesktop ? 18.sp : 20.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.assessment_rounded,
                            color: isDark
                                ? AppTheme.neonBlue
                                : AppTheme.primaryLight,
                            size: isDesktop ? 20.sp : 24.sp,
                          ),
                          iconSize: isDesktop ? 20.sp : 24.sp,
                          padding: EdgeInsets.all(isDesktop ? 4.w : 8.w),
                          onPressed: _navigateToReports,
                          tooltip: 'Generate Reports',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.cloud_sync,
                            color: isDark
                                ? AppTheme.neonBlue
                                : AppTheme.primaryLight,
                            size: isDesktop ? 20.sp : 24.sp,
                          ),
                          iconSize: isDesktop ? 20.sp : 24.sp,
                          padding: EdgeInsets.all(isDesktop ? 4.w : 8.w),
                          onPressed: _navigateToBackupRestore,
                          tooltip: 'Google Drive',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.check_circle_outline,
                            color: isDark
                                ? AppTheme.neonBlue
                                : AppTheme.primaryLight,
                            size: isDesktop ? 20.sp : 24.sp,
                          ),
                          iconSize: isDesktop ? 20.sp : 24.sp,
                          padding: EdgeInsets.all(isDesktop ? 4.w : 8.w),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettledTransactionsScreen(
                                  userId: widget.userId,
                                ),
                              ),
                            );
                          },
                          tooltip: 'Settled Transactions',
                        ),
                        const ThemeToggle(),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'signout') {
                              _signOut();
                            }
                          },
                          itemBuilder: (context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'signout',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.logout,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sign Out',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          icon: Icon(
                            Icons.more_vert,
                            color: isDark
                                ? AppTheme.neonBlue
                                : AppTheme.primaryLight,
                            size: isDesktop ? 20.sp : 24.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: isDark ? AppTheme.neonBlue : AppTheme.primaryLight,
        onRefresh: _loadData,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: isDark ? AppTheme.neonBlue : AppTheme.primaryLight,
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards Row
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TypedTransactionsScreen(
                                          userId: widget.userId,
                                          transactionType:
                                              AppConstants.transactionTypeGiven,
                                        ),
                                  ),
                                );
                              },
                              child: _buildSummaryCard(
                                title: 'Money Given',
                                amount: _totalGiven,
                                icon: Icons.arrow_upward_rounded,
                                color: const Color(0xFFFF6B6B),
                                isDark: isDark,
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TypedTransactionsScreen(
                                          userId: widget.userId,
                                          transactionType:
                                              AppConstants.transactionTypeTaken,
                                        ),
                                  ),
                                );
                              },
                              child: _buildSummaryCard(
                                title: 'Money Taken',
                                amount: _totalTaken,
                                icon: Icons.arrow_downward_rounded,
                                color: const Color(0xFF4ECDC4),
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // In-App Notifications
                      Text(
                        'In-App Notifications',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      if (_upcomingSettlements.isEmpty)
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            'No upcoming settlements',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        Column(
                          children: _upcomingSettlements.map((transaction) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 10.h),
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.notifications_active,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${transaction.personName} - ${Helpers.formatCurrency(transaction.amount)}',
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          'Due on ${Helpers.formatDate(transaction.expectedSettlementDate!)}',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      SizedBox(height: 24.h),

                      // Net Balance Card - Futuristic
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [AppTheme.neonBlue, AppTheme.neonPurple]
                                : [AppTheme.primaryLight, AppTheme.accentLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? AppTheme.neonBlue.withOpacity(0.3)
                                  : AppTheme.primaryLight.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Net Balance',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 6.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    isPositive ? 'To Pay' : 'To Receive',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [Colors.white, Colors.white70],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Text(
                                Helpers.formatCurrency(netBalance.abs()),
                                style: TextStyle(
                                  fontSize: 36.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32.h),

                      // Recent Transactions Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recent Activity',
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Container(
                                height: 3,
                                width: 40.w,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [
                                            AppTheme.neonBlue,
                                            AppTheme.neonPurple,
                                          ]
                                        : [
                                            AppTheme.primaryLight,
                                            AppTheme.accentLight,
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(1.5.r),
                                ),
                              ),
                            ],
                          ),
                          if (_recentTransactions.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkCard
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.neonBlue.withOpacity(0.2)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: GestureDetector(
                                onTap: _navigateToAllTransactions,
                                child: Text(
                                  'View All',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppTheme.neonBlue
                                        : AppTheme.primaryLight,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Recent Transactions List
                      _recentTransactions.isEmpty
                          ? Container(
                              padding: EdgeInsets.symmetric(vertical: 60.h),
                              child: Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(16.w),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? AppTheme.darkCard
                                            : Colors.grey.shade100,
                                      ),
                                      child: Icon(
                                        Icons.receipt_long_rounded,
                                        size: 48.sp,
                                        color: isDark
                                            ? AppTheme.neonBlue.withOpacity(0.5)
                                            : AppTheme.primaryLight.withOpacity(
                                                0.5,
                                              ),
                                      ),
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      'No transactions yet',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'Add your first transaction to get started',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.4)
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recentTransactions.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: TransactionCard(
                                    transaction: _recentTransactions[index],
                                    onTap: () async {
                                      _loadData();
                                    },
                                  ),
                                );
                              },
                            ),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddTransaction,
        backgroundColor: isDark ? AppTheme.neonBlue : AppTheme.primaryLight,
        elevation: 8,
        tooltip: 'Add Transaction',
        label: Text(
          'Add Transaction',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.grey.shade700,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            Helpers.formatCurrency(amount),
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
