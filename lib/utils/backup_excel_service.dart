import 'package:excel/excel.dart' as excel_lib;
import '../database/database_helper.dart';
import '../models/partial_settlement_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

class BackupExcelService {
  static final BackupExcelService instance = BackupExcelService._();

  BackupExcelService._();

  Future<List<int>> generateBackupExcelBytes() async {
    final users = await DatabaseHelper.instance.getAllUsers();
    final transactions = await DatabaseHelper.instance.getAllTransactions();
    final partialSettlements = await DatabaseHelper.instance
        .getAllPartialSettlements();

    final excel = excel_lib.Excel.createExcel();

    _buildUsersSheet(excel, users);
    _buildTransactionsSheet(excel, transactions);
    _buildPartialSettlementsSheet(excel, partialSettlements);

    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Failed to generate backup file');
    }
    return fileBytes;
  }

  Future<void> restoreFromBackupBytes(List<int> bytes) async {
    final excel = excel_lib.Excel.decodeBytes(bytes);

    final usersSheet = excel['Users'];
    final transactionsSheet = excel['Transactions'];
    final settlementsSheet = excel['Partial Settlements'];

    if (usersSheet.maxRows == 0 || transactionsSheet.maxRows == 0) {
      throw Exception('Invalid backup file');
    }

    final users = _readUsers(usersSheet);
    final transactions = _readTransactions(transactionsSheet);
    final partialSettlements = _readPartialSettlements(settlementsSheet);

    await DatabaseHelper.instance.replaceAllData(
      users: users,
      transactions: transactions,
      partialSettlements: partialSettlements,
    );
  }

  void _buildUsersSheet(excel_lib.Excel excel, List<UserModel> users) {
    final sheet = excel['Users'];
    final headers = ['id', 'username', 'created_at'];

    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          )
          .value = excel_lib.TextCellValue(
        headers[i],
      );
    }

    for (var i = 0; i < users.length; i++) {
      final rowIndex = i + 1;
      final user = users[i];

      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.IntCellValue(
        user.id ?? 0,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        user.username,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        user.createdAt,
      );
    }
  }

  void _buildTransactionsSheet(
    excel_lib.Excel excel,
    List<TransactionModel> transactions,
  ) {
    final sheet = excel['Transactions'];
    final headers = [
      'id',
      'user_id',
      'transaction_type',
      'person_name',
      'person_contact',
      'amount',
      'reason',
      'transaction_date',
      'expected_settlement_date',
      'is_settled',
      'settled_amount',
      'next_settlement_date',
      'created_at',
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          )
          .value = excel_lib.TextCellValue(
        headers[i],
      );
    }

    for (var i = 0; i < transactions.length; i++) {
      final rowIndex = i + 1;
      final transaction = transactions[i];

      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.IntCellValue(
        transaction.id ?? 0,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.IntCellValue(
        transaction.userId,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        transaction.transactionType,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 3,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        transaction.personName,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 4,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        transaction.personContact,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 5,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.DoubleCellValue(
        transaction.amount,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 6,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        transaction.reason,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 7,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        transaction.transactionDate,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 8,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        transaction.expectedSettlementDate ?? '',
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 9,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.IntCellValue(
        transaction.isSettled ? 1 : 0,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 10,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.DoubleCellValue(
        transaction.settledAmount,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 11,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        transaction.nextSettlementDate ?? '',
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 12,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        transaction.createdAt,
      );
    }
  }

  void _buildPartialSettlementsSheet(
    excel_lib.Excel excel,
    List<PartialSettlementModel> partialSettlements,
  ) {
    final sheet = excel['Partial Settlements'];
    final headers = [
      'id',
      'transaction_id',
      'settled_amount',
      'settlement_date',
      'next_settlement_date',
      'created_at',
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          )
          .value = excel_lib.TextCellValue(
        headers[i],
      );
    }

    for (var i = 0; i < partialSettlements.length; i++) {
      final rowIndex = i + 1;
      final settlement = partialSettlements[i];

      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.IntCellValue(
        settlement.id ?? 0,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.IntCellValue(
        settlement.transactionId,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.DoubleCellValue(
        settlement.settledAmount,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 3,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        settlement.settlementDate,
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 4,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        settlement.nextSettlementDate ?? '',
      );
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 5,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_lib.TextCellValue(
        settlement.createdAt,
      );
    }
  }

  List<UserModel> _readUsers(excel_lib.Sheet sheet) {
    final users = <UserModel>[];
    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.row(rowIndex);
      final id = _readInt(row, 0);
      final username = _readString(row, 1) ?? '';
      final createdAt = _readString(row, 2) ?? '';

      if (username.isEmpty || createdAt.isEmpty) {
        continue;
      }

      users.add(UserModel(id: id, username: username, createdAt: createdAt));
    }
    return users;
  }

  List<TransactionModel> _readTransactions(excel_lib.Sheet sheet) {
    final transactions = <TransactionModel>[];
    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.row(rowIndex);
      final id = _readInt(row, 0);
      final userId = _readInt(row, 1) ?? 0;
      final transactionType = _readString(row, 2) ?? '';
      final personName = _readString(row, 3) ?? '';
      final personContact = _readString(row, 4) ?? '';
      final amount = _readDouble(row, 5);
      final reason = _readString(row, 6) ?? '';
      final transactionDate = _readString(row, 7) ?? '';
      final expectedSettlementDate = _readString(row, 8);
      final isSettled = _readBool(row, 9);
      final settledAmount = _readDouble(row, 10);
      final nextSettlementDate = _readString(row, 11);
      final createdAt = _readString(row, 12) ?? '';

      if (userId == 0 || transactionType.isEmpty || createdAt.isEmpty) {
        continue;
      }

      transactions.add(
        TransactionModel(
          id: id,
          userId: userId,
          transactionType: transactionType,
          personName: personName,
          personContact: personContact,
          amount: amount,
          reason: reason,
          transactionDate: transactionDate,
          expectedSettlementDate: _normalizeOptional(expectedSettlementDate),
          isSettled: isSettled,
          settledAmount: settledAmount,
          nextSettlementDate: _normalizeOptional(nextSettlementDate),
          createdAt: createdAt,
        ),
      );
    }
    return transactions;
  }

  List<PartialSettlementModel> _readPartialSettlements(excel_lib.Sheet sheet) {
    final settlements = <PartialSettlementModel>[];
    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.row(rowIndex);
      final id = _readInt(row, 0);
      final transactionId = _readInt(row, 1) ?? 0;
      final settledAmount = _readDouble(row, 2);
      final settlementDate = _readString(row, 3) ?? '';
      final nextSettlementDate = _readString(row, 4);
      final createdAt = _readString(row, 5) ?? '';

      if (transactionId == 0 || settlementDate.isEmpty || createdAt.isEmpty) {
        continue;
      }

      settlements.add(
        PartialSettlementModel(
          id: id,
          transactionId: transactionId,
          settledAmount: settledAmount,
          settlementDate: settlementDate,
          nextSettlementDate: _normalizeOptional(nextSettlementDate),
          createdAt: createdAt,
        ),
      );
    }
    return settlements;
  }

  String? _readString(List<excel_lib.Data?> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    final value = cell?.value;
    if (value == null) return null;
    if (value is excel_lib.TextCellValue) return value.value.toString();
    if (value is excel_lib.IntCellValue) return value.value.toString();
    if (value is excel_lib.DoubleCellValue) return value.value.toString();
    if (value is excel_lib.BoolCellValue) return value.value.toString();
    return value.toString();
  }

  int? _readInt(List<excel_lib.Data?> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    final value = cell?.value;
    if (value == null) return null;
    if (value is excel_lib.IntCellValue) return value.value;
    if (value is excel_lib.DoubleCellValue) return value.value.toInt();
    if (value is excel_lib.TextCellValue) {
      return int.tryParse(value.value.toString());
    }
    return int.tryParse(value.toString());
  }

  double _readDouble(List<excel_lib.Data?> row, int index) {
    if (index >= row.length) return 0.0;
    final cell = row[index];
    final value = cell?.value;
    if (value == null) return 0.0;
    if (value is excel_lib.DoubleCellValue) return value.value;
    if (value is excel_lib.IntCellValue) return value.value.toDouble();
    if (value is excel_lib.TextCellValue) {
      return double.tryParse(value.value.toString()) ?? 0.0;
    }
    return double.tryParse(value.toString()) ?? 0.0;
  }

  bool _readBool(List<excel_lib.Data?> row, int index) {
    if (index >= row.length) return false;
    final cell = row[index];
    final value = cell?.value;
    if (value == null) return false;
    if (value is excel_lib.IntCellValue) return value.value == 1;
    if (value is excel_lib.BoolCellValue) return value.value;
    if (value is excel_lib.TextCellValue) {
      final text = value.value.toString().toLowerCase();
      return text == '1' ||
          text == 'true' ||
          text == 'settled' ||
          text == 'yes';
    }
    return value.toString() == '1' || value.toString().toLowerCase() == 'true';
  }

  String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
