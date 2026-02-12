import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../models/partial_settlement_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/transaction_change_notifier.dart';
import '../utils/notification_service.dart';
import '../utils/drive_backup_service.dart';
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
  List<PartialSettlementModel> _partialSettlements = [];

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _loadPartialSettlements();
  }

  Future<void> _loadPartialSettlements() async {
    if (_transaction.id != null) {
      final settlements = await DatabaseHelper.instance.getPartialSettlements(
        _transaction.id!,
      );
      setState(() => _partialSettlements = settlements);
    }
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
        if (_transaction.id != null) {
          if (_transaction.isSettled) {
            await NotificationService.instance.cancelSettlementReminder(
              _transaction.id!,
            );
          } else if (_transaction.expectedSettlementDate != null) {
            await NotificationService.instance.scheduleSettlementReminder(
              _transaction,
            );
          }
        }
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
          if (_transaction.id != null) {
            await NotificationService.instance.cancelSettlementReminder(
              _transaction.id!,
            );
          }
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

  Future<void> _showPartialSettlementDialog() async {
    final amountController = TextEditingController();
    DateTime? nextSettlementDate;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Add Partial Settlement',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Amount: ${Helpers.formatCurrency(_transaction.amount)}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_transaction.settledAmount > 0) ...[
                  SizedBox(height: 8.h),
                  Text(
                    'Already Settled: ${Helpers.formatCurrency(_transaction.settledAmount)}',
                    style: TextStyle(fontSize: 14.sp, color: Colors.green),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Remaining: ${Helpers.formatCurrency(_transaction.amount - _transaction.settledAmount)}',
                    style: TextStyle(fontSize: 14.sp, color: Colors.orange),
                  ),
                ],
                SizedBox(height: 16.h),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Settlement Amount',
                    hintText: 'Enter amount to settle',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    prefixIcon: const Icon(Icons.currency_rupee),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                SizedBox(height: 16.h),
                ListTile(
                  title: Text('Next Settlement Date'),
                  subtitle: Text(
                    nextSettlementDate == null
                        ? 'Select Date'
                        : Helpers.formatDate(
                            nextSettlementDate.toString().split(' ')[0],
                          ),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          nextSettlementDate ??
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => nextSettlementDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                amountController.dispose();
                Navigator.pop(context);
              },
              child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
            ),
            ElevatedButton(
              onPressed: () async {
                final settledAmount =
                    double.tryParse(amountController.text) ?? 0.0;

                if (settledAmount <= 0) {
                  if (mounted) {
                    Helpers.showSnackBar(
                      context,
                      'Please enter a valid amount',
                      isError: true,
                    );
                  }
                  return;
                }

                if (nextSettlementDate == null) {
                  if (mounted) {
                    Helpers.showSnackBar(
                      context,
                      'Please select next settlement date',
                      isError: true,
                    );
                  }
                  return;
                }

                final totalSettledAmount =
                    _transaction.settledAmount + settledAmount;
                if (totalSettledAmount > _transaction.amount) {
                  if (mounted) {
                    Helpers.showSnackBar(
                      context,
                      'Total settlement cannot exceed transaction amount',
                      isError: true,
                    );
                  }
                  return;
                }

                try {
                  // Create partial settlement record
                  final now = DateTime.now();
                  final settlementDateStr = now.toString().split(' ')[0];
                  final nextDateStr = nextSettlementDate?.toString().split(
                    ' ',
                  )[0];

                  final settlement = PartialSettlementModel(
                    transactionId: _transaction.id!,
                    settledAmount: settledAmount,
                    settlementDate: settlementDateStr,
                    nextSettlementDate: nextDateStr,
                    createdAt: now.toIso8601String(),
                  );

                  await DatabaseHelper.instance.createPartialSettlement(
                    settlement,
                  );

                  // Update transaction with new settled amount
                  final isFullySettled =
                      totalSettledAmount >= _transaction.amount;
                  final updated = _transaction.copyWith(
                    settledAmount: totalSettledAmount,
                    isSettled: isFullySettled,
                    nextSettlementDate: nextDateStr,
                  );

                  await DatabaseHelper.instance.updateTransaction(updated);

                  if (mounted) {
                    setState(() {
                      _transaction = updated;
                    });
                    _loadPartialSettlements();

                    Navigator.pop(context);
                    Helpers.showSnackBar(
                      context,
                      isFullySettled
                          ? 'Transaction settled completely!'
                          : 'Partial settlement recorded',
                    );

                    // Schedule reminder for next settlement
                    if (nextSettlementDate != null && _transaction.id != null) {
                      final updatedWithNextDate = updated.copyWith(
                        expectedSettlementDate: nextDateStr,
                      );
                      await NotificationService.instance
                          .scheduleSettlementReminder(updatedWithNextDate);
                    }

                    // Notify dashboard of change
                    if (mounted && context.mounted) {
                      context
                          .read<TransactionChangeNotifier>()
                          .notifyTransactionUpdated();
                      // Trigger auto-backup
                      DriveBackupService.instance.autoBackupNow();
                    }
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
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(
                'Save',
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
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
                  if (_transaction.expectedSettlementDate != null) ...[
                    SizedBox(height: 12.h),
                    _buildDetailCard(
                      icon: Icons.event,
                      title: 'Expected Settlement',
                      value: Helpers.formatDate(
                        _transaction.expectedSettlementDate!,
                      ),
                    ),
                  ],
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
                  if (_transaction.settledAmount > 0) ...[
                    SizedBox(height: 12.h),
                    _buildDetailCard(
                      icon: Icons.payments,
                      title: 'Settled Amount',
                      value: Helpers.formatCurrency(_transaction.settledAmount),
                      valueColor: Colors.green,
                    ),
                    SizedBox(height: 12.h),
                    _buildDetailCard(
                      icon: Icons.pending_actions,
                      title: 'Remaining Amount',
                      value: Helpers.formatCurrency(
                        _transaction.amount - _transaction.settledAmount,
                      ),
                      valueColor: Colors.orange,
                    ),
                  ],
                  if (_transaction.nextSettlementDate != null) ...[
                    SizedBox(height: 12.h),
                    _buildDetailCard(
                      icon: Icons.event_available,
                      title: 'Next Settlement Date',
                      value: Helpers.formatDate(
                        _transaction.nextSettlementDate!,
                      ),
                    ),
                  ],
                  SizedBox(height: 24.h),

                  // Settlement Buttons
                  if (!_transaction.isSettled) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showPartialSettlementDialog,
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Partial Settlement',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 2,
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
                            onPressed: _toggleSettle,
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: Text(
                              'Mark as Settled',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: _toggleSettle,
                      icon: const Icon(Icons.replay, color: Colors.white),
                      label: Text(
                        'Mark as Unsettled',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
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
                  // Partial Settlement History
                  if (_partialSettlements.isNotEmpty) ...[
                    SizedBox(height: 24.h),
                    Text(
                      'Settlement History',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _partialSettlements.length,
                      itemBuilder: (context, index) {
                        final settlement = _partialSettlements[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 10.h),
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Settlement ${index + 1}',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    Helpers.formatCurrency(
                                      settlement.settledAmount,
                                    ),
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Date:',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    Helpers.formatDate(
                                      settlement.settlementDate,
                                    ),
                                    style: TextStyle(fontSize: 12.sp),
                                  ),
                                ],
                              ),
                              if (settlement.nextSettlementDate != null) ...[
                                SizedBox(height: 6.h),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Next Due:',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      Helpers.formatDate(
                                        settlement.nextSettlementDate!,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
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
