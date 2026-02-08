import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/transaction_change_notifier.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late TransactionModel _transaction;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
  }

  Future<void> _toggleSettle() async {
    try {
      final updated = _transaction.copyWith(isSettled: !_transaction.isSettled);
      await DatabaseHelper.instance.updateTransaction(updated);

      setState(() => _transaction = updated);

      if (mounted) {
        Helpers.showSnackBar(
          context,
          _transaction.isSettled ? 'Marked as settled' : 'Marked as unsettled',
        );
        // Notify dashboard of change
        context.read<TransactionChangeNotifier>().notifyTransactionUpdated();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _deleteTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Transaction',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this transaction?',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteTransaction(_transaction.id!);
        if (mounted) {
          Helpers.showSnackBar(context, 'Transaction deleted');
          // Notify dashboard of deletion
          context.read<TransactionChangeNotifier>().notifyTransactionDeleted();
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            'Error: ${e.toString()}',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _editTransaction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          userId: _transaction.userId,
          transaction: _transaction,
        ),
      ),
    );

    if (result == true && mounted) {
      // Reload transaction details
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGiven =
        _transaction.transactionType == AppConstants.transactionTypeGiven;
    final color = isGiven ? AppConstants.givenColor : AppConstants.takenColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Transaction Details',
          style: TextStyle(fontSize: 20.sp),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editTransaction,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteTransaction,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    isGiven ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 48.sp,
                    color: Colors.white,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    isGiven ? 'Money Given' : 'Money Taken',
                    style: TextStyle(fontSize: 16.sp, color: Colors.white70),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    Helpers.formatCurrency(_transaction.amount),
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Details
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  _buildDetailCard(
                    icon: Icons.person,
                    title: 'Person Name',
                    value: _transaction.personName,
                  ),
                  SizedBox(height: 12.h),
                  _buildDetailCard(
                    icon: Icons.phone,
                    title: 'Contact',
                    value: _transaction.personContact,
                  ),
                  SizedBox(height: 12.h),
                  _buildDetailCard(
                    icon: Icons.note,
                    title: 'Reason',
                    value: _transaction.reason,
                  ),
                  SizedBox(height: 12.h),
                  _buildDetailCard(
                    icon: Icons.calendar_today,
                    title: 'Transaction Date',
                    value: Helpers.formatDate(_transaction.transactionDate),
                  ),
                  SizedBox(height: 12.h),
                  _buildDetailCard(
                    icon: Icons.access_time,
                    title: 'Created At',
                    value: Helpers.formatDate(
                      _transaction.createdAt.split('T')[0],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildDetailCard(
                    icon: _transaction.isSettled
                        ? Icons.check_circle
                        : Icons.pending,
                    title: 'Status',
                    value: _transaction.isSettled ? 'Settled' : 'Unsettled',
                    valueColor: _transaction.isSettled
                        ? Colors.green
                        : Colors.orange,
                  ),
                  SizedBox(height: 24.h),

                  // Settle Button
                  ElevatedButton.icon(
                    onPressed: _toggleSettle,
                    icon: Icon(
                      _transaction.isSettled ? Icons.replay : Icons.check,
                      color: Colors.white,
                    ),
                    label: Text(
                      _transaction.isSettled
                          ? 'Mark as Unsettled'
                          : 'Mark as Settled',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _transaction.isSettled
                          ? Colors.orange
                          : Colors.green,
                      padding: EdgeInsets.symmetric(
                        vertical: 16.h,
                        horizontal: 24.w,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 24.sp),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
