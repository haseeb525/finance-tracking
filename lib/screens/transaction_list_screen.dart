import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../widgets/transaction_card.dart';
import 'person_detail_screen.dart';

class TransactionListScreen extends StatefulWidget {
  final int userId;

  const TransactionListScreen({super.key, required this.userId});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  bool _isLoading = true;
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  String _selectedFilter = 'ALL'; // ALL, GIVEN, TAKEN, UNSETTLED

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
        _allTransactions = transactions;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      switch (_selectedFilter) {
        case 'GIVEN':
          _filteredTransactions = _allTransactions
              .where(
                (t) => t.transactionType == AppConstants.transactionTypeGiven,
              )
              .toList();
          break;
        case 'TAKEN':
          _filteredTransactions = _allTransactions
              .where(
                (t) => t.transactionType == AppConstants.transactionTypeTaken,
              )
              .toList();
          break;
        case 'UNSETTLED':
          _filteredTransactions = _allTransactions
              .where((t) => !t.isSettled)
              .toList();
          break;
        default:
          _filteredTransactions = _allTransactions;
      }
    });
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filter Transactions',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.h),
              _buildFilterOption('ALL', 'All Transactions', Icons.list),
              _buildFilterOption('GIVEN', 'Money Given', Icons.arrow_upward),
              _buildFilterOption('TAKEN', 'Money Taken', Icons.arrow_downward),
              _buildFilterOption('UNSETTLED', 'Unsettled', Icons.pending),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: colorScheme.primary)
          : null,
      onTap: () {
        setState(() => _selectedFilter = value);
        _applyFilter();
        Navigator.pop(context);
      },
    );
  }

  Future<void> _showPersonList() async {
    final personNames = await DatabaseHelper.instance.getAllPersonNames(
      widget.userId,
    );

    if (!mounted) return;

    if (personNames.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No persons found')));
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Person',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.h),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: personNames.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(personNames[index]),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PersonDetailScreen(
                              userId: widget.userId,
                              personName: personNames[index],
                            ),
                          ),
                        ).then((_) => _loadTransactions());
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'All Transactions',
          style: TextStyle(fontSize: 20.sp),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: _showPersonList,
            tooltip: 'View by Person',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterMenu,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredTransactions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 64.sp,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'No transactions found',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: _filteredTransactions.length,
                itemBuilder: (context, index) {
                  return TransactionCard(
                    transaction: _filteredTransactions[index],
                    onTap: () {
                      _loadTransactions();
                    },
                  );
                },
              ),
      ),
    );
  }
}
