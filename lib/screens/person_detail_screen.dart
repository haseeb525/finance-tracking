import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/transaction_card.dart';

class PersonDetailScreen extends StatefulWidget {
  final int userId;
  final String personName;

  const PersonDetailScreen({
    super.key,
    required this.userId,
    required this.personName,
  });

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  bool _isLoading = true;
  List<TransactionModel> _transactions = [];
  double _totalGiven = 0.0;
  double _totalTaken = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await DatabaseHelper.instance
          .getTransactionsByPerson(widget.userId, widget.personName);

      double given = 0.0;
      double taken = 0.0;

      for (var transaction in transactions) {
        if (!transaction.isSettled) {
          if (transaction.transactionType ==
              AppConstants.transactionTypeGiven) {
            given += transaction.amount;
          } else {
            taken += transaction.amount;
          }
        }
      }

      setState(() {
        _transactions = transactions;
        _totalGiven = given;
        _totalTaken = taken;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final netBalance = _totalTaken - _totalGiven;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.personName,
          style: TextStyle(fontSize: 20.sp),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Card
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppConstants.primaryColor,
                              AppConstants.primaryColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppConstants.primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Given',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      Helpers.formatCurrency(_totalGiven),
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Taken',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      Helpers.formatCurrency(_totalTaken),
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            Divider(color: Colors.white30, thickness: 1),
                            SizedBox(height: 16.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Net Balance',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  Helpers.formatCurrency(netBalance),
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              netBalance > 0
                                  ? 'They owe you'
                                  : netBalance < 0
                                  ? 'You owe them'
                                  : 'All settled',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Transactions Header
                      Text(
                        'Transactions (${_transactions.length})',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Transactions List
                      _transactions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 48.h),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 64.sp,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      'No transactions',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _transactions.length,
                              itemBuilder: (context, index) {
                                return TransactionCard(
                                  transaction: _transactions[index],
                                  onTap: () {
                                    _loadTransactions();
                                  },
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
