import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/transaction_change_notifier.dart';
import '../utils/notification_service.dart';
import '../utils/drive_backup_service.dart';
import '../widgets/currency_icon.dart';

class AddTransactionScreen extends StatefulWidget {
  final int userId;
  final TransactionModel? transaction; // For editing

  const AddTransactionScreen({
    super.key,
    required this.userId,
    this.transaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personNameController = TextEditingController();
  final _personContactController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  String _selectedType = AppConstants.transactionTypeGiven;
  DateTime _selectedDate = DateTime.now();
  DateTime? _expectedSettlementDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _personNameController.text = widget.transaction!.personName;
      _personContactController.text = widget.transaction!.personContact;
      _amountController.text = widget.transaction!.amount.toString();
      _reasonController.text = widget.transaction!.reason;
      _selectedType = widget.transaction!.transactionType;
      _selectedDate = DateTime.parse(widget.transaction!.transactionDate);
      if (widget.transaction!.expectedSettlementDate != null) {
        _expectedSettlementDate = DateTime.parse(
          widget.transaction!.expectedSettlementDate!,
        );
      }
    }
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _personContactController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(colorScheme: theme.colorScheme),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectExpectedSettlementDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expectedSettlementDate ?? _selectedDate,
      firstDate: _selectedDate,
      lastDate: DateTime(2100),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(colorScheme: theme.colorScheme),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _expectedSettlementDate = picked);
    }
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    Widget? icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final inputTheme = Theme.of(context).inputDecorationTheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: icon,
      filled: true,
      fillColor: inputTheme.fillColor ?? colorScheme.surface,
      labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
      floatingLabelStyle: TextStyle(color: colorScheme.primary),
      prefixIconColor: colorScheme.primary,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final transaction = TransactionModel(
        id: widget.transaction?.id,
        userId: widget.userId,
        transactionType: _selectedType,
        personName: _personNameController.text.trim(),
        personContact: _personContactController.text.trim(),
        amount: double.parse(_amountController.text),
        reason: _reasonController.text.trim(),
        transactionDate: DateFormat(
          AppConstants.dateFormat,
        ).format(_selectedDate),
        expectedSettlementDate: _expectedSettlementDate != null
            ? DateFormat(
                AppConstants.dateFormat,
              ).format(_expectedSettlementDate!)
            : null,
        isSettled: widget.transaction?.isSettled ?? false,
        createdAt:
            widget.transaction?.createdAt ?? Helpers.getCurrentDateTime(),
      );

      if (widget.transaction == null) {
        final created = await DatabaseHelper.instance.createTransaction(
          transaction,
        );
        if (mounted) {
          Helpers.showSnackBar(context, 'Transaction added successfully!');
          // Notify dashboard of new transaction
          context.read<TransactionChangeNotifier>().notifyTransactionAdded();
          // Trigger auto-backup
          DriveBackupService.instance.autoBackupNow();
          if (!created.isSettled && created.expectedSettlementDate != null) {
            await NotificationService.instance.scheduleSettlementReminder(
              created,
            );
          }
        }
      } else {
        await DatabaseHelper.instance.updateTransaction(transaction);
        if (mounted) {
          Helpers.showSnackBar(context, 'Transaction updated successfully!');
          // Notify dashboard of transaction update
          context.read<TransactionChangeNotifier>().notifyTransactionUpdated();
          // Trigger auto-backup
          DriveBackupService.instance.autoBackupNow();
          if (transaction.id != null) {
            await NotificationService.instance.cancelSettlementReminder(
              transaction.id!,
            );
            if (!transaction.isSettled &&
                transaction.expectedSettlementDate != null) {
              await NotificationService.instance.scheduleSettlementReminder(
                transaction,
              );
            }
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
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
    final isEditing = widget.transaction != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Transaction' : 'Add Transaction',
          style: TextStyle(fontSize: 20.sp),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Transaction Type Toggle
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? colorScheme.primary.withOpacity(0.25)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                          () =>
                              _selectedType = AppConstants.transactionTypeGiven,
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          decoration: BoxDecoration(
                            color:
                                _selectedType ==
                                    AppConstants.transactionTypeGiven
                                ? AppConstants.givenColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Money Given',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color:
                                  _selectedType ==
                                      AppConstants.transactionTypeGiven
                                  ? Colors.white
                                  : colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                          () =>
                              _selectedType = AppConstants.transactionTypeTaken,
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          decoration: BoxDecoration(
                            color:
                                _selectedType ==
                                    AppConstants.transactionTypeTaken
                                ? AppConstants.takenColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Money Taken',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color:
                                  _selectedType ==
                                      AppConstants.transactionTypeTaken
                                  ? Colors.white
                                  : colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Person Name
              TextFormField(
                controller: _personNameController,
                decoration: _inputDecoration(
                  context,
                  label: 'Person Name',
                  icon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter person name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Person Contact
              TextFormField(
                controller: _personContactController,
                decoration: _inputDecoration(
                  context,
                  label: 'Person Contact',
                  icon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter person contact';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: _inputDecoration(
                  context,
                  label: 'Amount (PKR)',
                  icon: const CurrencyIcon(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: _inputDecoration(
                  context,
                  label: 'Reason',
                  icon: const Icon(Icons.note),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter reason';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Date Picker
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 16.h,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark
                          ? colorScheme.primary.withOpacity(0.3)
                          : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: isDark
                            ? colorScheme.primary
                            : Colors.grey.shade700,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'Date: ${DateFormat(AppConstants.displayDateFormat).format(_selectedDate)}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Expected Settlement Date
              Text(
                'Expected Settlement Date (Optional)',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8.h),
              InkWell(
                onTap: _selectExpectedSettlementDate,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 16.h,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark
                          ? colorScheme.primary.withOpacity(0.3)
                          : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        color: isDark
                            ? colorScheme.primary
                            : Colors.grey.shade700,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          _expectedSettlementDate != null
                              ? DateFormat(
                                  AppConstants.displayDateFormat,
                                ).format(_expectedSettlementDate!)
                              : 'Select expected settlement date',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: _expectedSettlementDate != null
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_expectedSettlementDate != null)
                        IconButton(
                          onPressed: () =>
                              setState(() => _expectedSettlementDate = null),
                          icon: Icon(
                            Icons.close,
                            size: 18.sp,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          tooltip: 'Clear date',
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20.h,
                        width: 20.w,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEditing ? 'Update Transaction' : 'Add Transaction',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
