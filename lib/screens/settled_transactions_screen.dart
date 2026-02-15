import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../utils/app_theme.dart';
import '../widgets/transaction_card.dart';
import 'transaction_detail_screen.dart';

class SettledTransactionsScreen extends StatefulWidget {
  final int userId;

  const SettledTransactionsScreen({super.key, required this.userId});

  @override
  State<SettledTransactionsScreen> createState() =>
      _SettledTransactionsScreenState();
}

class _SettledTransactionsScreenState extends State<SettledTransactionsScreen> {
  bool _isLoading = true;
  List<TransactionModel> _settledTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadSettledTransactions();
  }

  Future<void> _loadSettledTransactions() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await DatabaseHelper.instance.getTransactions(
        widget.userId,
      );
      setState(() {
        _settledTransactions = transactions.where((t) => t.isSettled).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settled Transactions',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: isDark ? AppTheme.neonBlue : AppTheme.primaryLight,
        onRefresh: _loadSettledTransactions,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: isDark ? AppTheme.neonBlue : AppTheme.primaryLight,
                ),
              )
            : _settledTransactions.isEmpty
            ? _buildEmptyState(isDark)
            : ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: _settledTransactions.length,
                itemBuilder: (context, index) {
                  final transaction = _settledTransactions[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: TransactionCard(
                      transaction: transaction,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionDetailScreen(
                              transaction: transaction,
                            ),
                          ),
                        );
                        if (result == true) {
                          _loadSettledTransactions();
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80.sp,
            color: isDark
                ? AppTheme.neonBlue.withOpacity(0.5)
                : AppTheme.primaryLight.withOpacity(0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'No Settled Transactions',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Settled transactions will appear here',
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
