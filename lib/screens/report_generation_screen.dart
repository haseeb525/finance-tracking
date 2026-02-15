import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../models/partial_settlement_model.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class _ReportItem {
  final String filePath;
  final String dateRange;
  final DateTime generatedDate;
  final int transactionCount;

  _ReportItem({
    required this.filePath,
    required this.dateRange,
    required this.generatedDate,
    required this.transactionCount,
  });
}

class ReportGenerationScreen extends StatefulWidget {
  final int userId;

  const ReportGenerationScreen({super.key, required this.userId});

  @override
  State<ReportGenerationScreen> createState() => _ReportGenerationScreenState();
}

class _ReportGenerationScreenState extends State<ReportGenerationScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isGenerating = false;
  String? _lastGeneratedFile;
  List<_ReportItem> _reportHistory = [];

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
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

    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(colorScheme: theme.colorScheme),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _generateReport() async {
    if (_startDate == null || _endDate == null) {
      Helpers.showSnackBar(
        context,
        'Please select both start and end dates',
        isError: true,
      );
      return;
    }

    if (_startDate!.isAfter(_endDate!)) {
      Helpers.showSnackBar(
        context,
        'Start date must be before end date',
        isError: true,
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final startDateStr = DateFormat(
        AppConstants.dateFormat,
      ).format(_startDate!);
      final endDateStr = DateFormat(AppConstants.dateFormat).format(_endDate!);

      // Fetch transactions
      final transactions = await DatabaseHelper.instance
          .getTransactionsByDateRange(widget.userId, startDateStr, endDateStr);

      if (transactions.isEmpty) {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            'No transactions found for selected date range',
            isError: true,
          );
        }
        setState(() => _isGenerating = false);
        return;
      }

      final List<PartialSettlementModel> partialSettlements =
          await DatabaseHelper.instance.getPartialSettlementsByDateRange(
            widget.userId,
            startDateStr,
            endDateStr,
          );

      // Create Excel
      final excel = excel_lib.Excel.createExcel();
      final excel_lib.Sheet sheet = excel['Transactions'];

      // Add headers
      final headers = [
        'Date',
        'Type',
        'Person Name',
        'Contact',
        'Amount (PKR)',
        'Reason',
        'Status',
        'Settled Amount',
        'Remaining Amount',
        'Next Settlement Date',
      ];

      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = excel_lib.TextCellValue(headers[i]);
        cell.cellStyle = excel_lib.CellStyle(
          bold: true,
          backgroundColorHex: excel_lib.ExcelColor.blue,
          fontColorHex: excel_lib.ExcelColor.white,
        );
      }

      // Add data
      double totalGiven = 0.0;
      double totalTaken = 0.0;

      for (var i = 0; i < transactions.length; i++) {
        final transaction = transactions[i];
        final rowIndex = i + 1;

        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.TextCellValue(
          Helpers.formatDateForReport(transaction.transactionDate),
        );

        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 1,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.TextCellValue(
          transaction.transactionType,
        );

        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 2,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.TextCellValue(
          transaction.personName,
        );

        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 3,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.TextCellValue(
          transaction.personContact,
        );

        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 4,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.DoubleCellValue(
          transaction.amount,
        );

        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 5,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.TextCellValue(
          transaction.reason,
        );

        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 6,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.TextCellValue(
          transaction.isSettled ? 'Settled' : 'Unsettled',
        );

        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 7,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.DoubleCellValue(
          transaction.settledAmount,
        );

        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 8,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.DoubleCellValue(
          transaction.amount - transaction.settledAmount,
        );

        final nextDate =
            transaction.nextSettlementDate ??
            transaction.expectedSettlementDate;
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 9,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.TextCellValue(
          nextDate ?? '',
        );

        if (transaction.transactionType == AppConstants.transactionTypeGiven) {
          totalGiven += transaction.amount;
        } else {
          totalTaken += transaction.amount;
        }
      }

      // Add summary
      final summaryRow = transactions.length + 2;
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: summaryRow,
            ),
          )
          .value = excel_lib.TextCellValue(
        'SUMMARY',
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: summaryRow,
            ),
          )
          .cellStyle = excel_lib.CellStyle(
        bold: true,
      );

      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: summaryRow + 1,
            ),
          )
          .value = excel_lib.TextCellValue(
        'Total Given:',
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: summaryRow + 1,
            ),
          )
          .value = excel_lib.DoubleCellValue(
        totalGiven,
      );

      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: summaryRow + 2,
            ),
          )
          .value = excel_lib.TextCellValue(
        'Total Taken:',
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: summaryRow + 2,
            ),
          )
          .value = excel_lib.DoubleCellValue(
        totalTaken,
      );

      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: summaryRow + 3,
            ),
          )
          .value = excel_lib.TextCellValue(
        'Net Balance:',
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: summaryRow + 3,
            ),
          )
          .value = excel_lib.DoubleCellValue(
        totalTaken - totalGiven,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: summaryRow + 3,
            ),
          )
          .cellStyle = excel_lib.CellStyle(
        bold: true,
      );

      if (partialSettlements.isNotEmpty) {
        final excel_lib.Sheet settlementSheet = excel['Partial Settlements'];

        final settlementHeaders = [
          'Settlement Date',
          'Transaction ID',
          'Person Name',
          'Contact',
          'Settled Amount',
          'Next Settlement Date',
          'Created At',
        ];

        for (var i = 0; i < settlementHeaders.length; i++) {
          final cell = settlementSheet.cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          );
          cell.value = excel_lib.TextCellValue(settlementHeaders[i]);
          cell.cellStyle = excel_lib.CellStyle(
            bold: true,
            backgroundColorHex: excel_lib.ExcelColor.blue,
            fontColorHex: excel_lib.ExcelColor.white,
          );
        }

        final transactionMap = {
          for (final transaction in transactions)
            if (transaction.id != null) transaction.id!: transaction,
        };

        for (var i = 0; i < partialSettlements.length; i++) {
          final settlement = partialSettlements[i];
          final rowIndex = i + 1;
          final transaction = transactionMap[settlement.transactionId];

          settlementSheet
              .cell(
                excel_lib.CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel_lib.TextCellValue(
            Helpers.formatDateForReport(settlement.settlementDate),
          );

          settlementSheet
              .cell(
                excel_lib.CellIndex.indexByColumnRow(
                  columnIndex: 1,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel_lib.IntCellValue(
            settlement.transactionId,
          );

          settlementSheet
              .cell(
                excel_lib.CellIndex.indexByColumnRow(
                  columnIndex: 2,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel_lib.TextCellValue(
            transaction?.personName ?? 'Unknown',
          );

          settlementSheet
              .cell(
                excel_lib.CellIndex.indexByColumnRow(
                  columnIndex: 3,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel_lib.TextCellValue(
            transaction?.personContact ?? '',
          );

          settlementSheet
              .cell(
                excel_lib.CellIndex.indexByColumnRow(
                  columnIndex: 4,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel_lib.DoubleCellValue(
            settlement.settledAmount,
          );

          settlementSheet
              .cell(
                excel_lib.CellIndex.indexByColumnRow(
                  columnIndex: 5,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel_lib.TextCellValue(
            settlement.nextSettlementDate ?? '',
          );

          settlementSheet
              .cell(
                excel_lib.CellIndex.indexByColumnRow(
                  columnIndex: 6,
                  rowIndex: rowIndex,
                ),
              )
              .value = excel_lib.TextCellValue(
            settlement.createdAt,
          );
        }
      }

      // Save file
      final directory = await getExternalStorageDirectory();

      // Generate filename based on date range
      final String dateFormat = 'yyyy-MM-dd';
      final startStr = DateFormat(dateFormat).format(_startDate!);
      final endStr = DateFormat(dateFormat).format(_endDate!);

      final fileName =
          _startDate!.isAtSameMomentAs(_endDate!) ||
              (_startDate!.year == _endDate!.year &&
                  _startDate!.month == _endDate!.month &&
                  _startDate!.day == _endDate!.day)
          ? 'finance_tracking_report_$startStr.xlsx'
          : 'finance_tracking_report_${startStr}_to_$endStr.xlsx';

      final filePath = '${directory!.path}/$fileName';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // Create date range string for display
        final displayStartStr = DateFormat(
          AppConstants.displayDateFormat,
        ).format(_startDate!);
        final displayEndStr = DateFormat(
          AppConstants.displayDateFormat,
        ).format(_endDate!);
        final dateRangeStr =
            _startDate!.isAtSameMomentAs(_endDate!) ||
                (_startDate!.year == _endDate!.year &&
                    _startDate!.month == _endDate!.month &&
                    _startDate!.day == _endDate!.day)
            ? displayStartStr
            : '$displayStartStr - $displayEndStr';

        setState(() {
          _lastGeneratedFile = filePath;
          _reportHistory.insert(
            0,
            _ReportItem(
              filePath: filePath,
              dateRange: dateRangeStr,
              generatedDate: DateTime.now(),
              transactionCount: transactions.length,
            ),
          );
          _isGenerating = false;
        });

        if (mounted) {
          Helpers.showSnackBar(
            context,
            'Report generated successfully!\nSaved to: $filePath',
          );
          _showSuccessDialog(filePath, transactions.length);
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Error generating report: ${e.toString()}',
          isError: true,
        );
      }
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _openReportFolder() async {
    if (_lastGeneratedFile == null) return;

    try {
      final result = await OpenFile.open(_lastGeneratedFile!);
      if (result.type == ResultType.error && mounted) {
        Helpers.showSnackBar(
          context,
          'Unable to open file: ${result.message}',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Error opening file: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _openReportFromHistory(_ReportItem report) async {
    try {
      final result = await OpenFile.open(report.filePath);
      if (result.type == ResultType.error && mounted) {
        Helpers.showSnackBar(
          context,
          'Unable to open file: ${result.message}',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Error opening file: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _showSuccessDialog(String filePath, int transactionCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Report Generated',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Successfully generated report with $transactionCount transactions.',
                style: TextStyle(fontSize: 14.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                'File Location:',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  filePath,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Generate Report',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppTheme.darkSurface, AppTheme.darkCard]
                      : [Colors.blue.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isDark
                      ? AppTheme.neonBlue.withOpacity(0.35)
                      : Colors.blue.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? AppTheme.neonBlue.withOpacity(0.15)
                        : Colors.blue.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDark ? AppTheme.neonBlue : Colors.blue.shade700,
                    size: 24.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Select date range to generate Excel report of your transactions',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isDark
                            ? colorScheme.onSurface
                            : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),

            // Start Date
            Text(
              'Start Date',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            InkWell(
              onTap: _selectStartDate,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.neonBlue.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? AppTheme.neonBlue.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: colorScheme.primary),
                        SizedBox(width: 12.w),
                        Text(
                          _startDate != null
                              ? DateFormat(
                                  AppConstants.displayDateFormat,
                                ).format(_startDate!)
                              : 'Select start date',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: _startDate != null
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // End Date
            Text(
              'End Date',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            InkWell(
              onTap: _selectEndDate,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.neonPurple.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? AppTheme.neonPurple.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: colorScheme.primary),
                        SizedBox(width: 12.w),
                        Text(
                          _endDate != null
                              ? DateFormat(
                                  AppConstants.displayDateFormat,
                                ).format(_endDate!)
                              : 'Select end date',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: _endDate != null
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Tip for single day report
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.shade900.withOpacity(0.2)
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: isDark
                      ? Colors.amber.shade700.withOpacity(0.3)
                      : Colors.amber.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: isDark
                        ? Colors.amber.shade400
                        : Colors.amber.shade700,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Tip: To generate report for a single day, set the same date for both start and end date',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.amber.shade200
                            : Colors.amber.shade900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Generate Button
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateReport,
              icon: _isGenerating
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.file_download, color: Colors.white),
              label: Text(
                _isGenerating ? 'Generating...' : 'Generate Excel Report',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.neonBlue
                    : AppTheme.primaryLight,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 2,
              ),
            ),

            if (_lastGeneratedFile != null) ...[
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.neonGreen.withOpacity(0.4)
                        : Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: isDark
                              ? AppTheme.neonGreen
                              : Colors.green.shade700,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Last Generated Report',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? colorScheme.onSurface
                                : Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      _lastGeneratedFile!,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDark
                            ? colorScheme.onSurfaceVariant
                            : Colors.green.shade800,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openReportFolder,
                        icon: Icon(
                          Icons.file_open,
                          color: isDark
                              ? AppTheme.neonBlue
                              : AppTheme.primaryLight,
                        ),
                        label: Text(
                          'Open Report',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.neonBlue
                                : AppTheme.primaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark
                                ? AppTheme.neonBlue.withOpacity(0.6)
                                : AppTheme.primaryLight.withOpacity(0.6),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_reportHistory.isNotEmpty) ...[
              SizedBox(height: 32.h),
              // Reports History Section
              Text(
                'Reports History',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark
                        ? colorScheme.primary.withOpacity(0.2)
                        : Colors.grey.shade300,
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _reportHistory.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark
                        ? colorScheme.primary.withOpacity(0.1)
                        : Colors.grey.shade300,
                  ),
                  itemBuilder: (context, index) {
                    final report = _reportHistory[index];
                    return InkWell(
                      onTap: () => _openReportFromHistory(report),
                      child: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: Row(
                          children: [
                            Icon(
                              Icons.description,
                              color: colorScheme.primary,
                              size: 24.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report.dateRange,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    '${report.transactionCount} transactions • ${DateFormat('MMM dd, yyyy HH:mm').format(report.generatedDate)}',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16.sp,
                              color: colorScheme.primary.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
