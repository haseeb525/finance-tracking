import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/transaction_card.dart';
import 'transaction_detail_screen.dart';

class TypedTransactionsScreen extends StatefulWidget {
  final int userId;
  final String transactionType; // 'GIVEN' or 'TAKEN'

  const TypedTransactionsScreen({
    super.key,
    required this.userId,
    required this.transactionType,
  });

  @override
  State<TypedTransactionsScreen> createState() =>
      _TypedTransactionsScreenState();
}

class _TypedTransactionsScreenState extends State<TypedTransactionsScreen> {
  bool _isLoading = true;
  List<TransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await DatabaseHelper.instance.getTransactions(
        widget.userId,
      );
      setState(() {
        _transactions =
            transactions
                .where((t) => t.transactionType == widget.transactionType)
                .toList()
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
    final isGiven = widget.transactionType == AppConstants.transactionTypeGiven;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isGiven ? 'Money Given' : 'Money Taken',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: isDark ? AppTheme.neonBlue : AppTheme.primaryLight,
        onRefresh: _loadTransactions,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: isDark ? AppTheme.neonBlue : AppTheme.primaryLight,
                ),
              )
            : _transactions.isEmpty
            ? _buildEmptyState(isDark, isGiven)
            : ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
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
                          _loadTransactions();
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool isGiven) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isGiven ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 80.sp,
            color: isDark
                ? AppTheme.neonBlue.withOpacity(0.5)
                : AppTheme.primaryLight.withOpacity(0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            isGiven ? 'No Money Given' : 'No Money Taken',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            isGiven
                ? 'Transactions you lend will appear here'
                : 'Transactions you borrow will appear here',
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
