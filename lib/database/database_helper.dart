import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/partial_settlement_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance_tracking.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const nullableTextType = 'TEXT';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE users (
        id $idType,
        username $textType UNIQUE,
        created_at $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id $idType,
        user_id $intType,
        transaction_type $textType,
        person_name $textType,
        person_contact $textType,
        amount $realType,
        reason $textType,
        transaction_date $textType,
        expected_settlement_date $nullableTextType,
        is_settled $intType,
        settled_amount $realType DEFAULT 0.0,
        next_settlement_date $nullableTextType,
        settlement_details $nullableTextType,
        created_at $textType,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE partial_settlements (
        id $idType,
        transaction_id $intType,
        settled_amount $realType,
        settlement_date $textType,
        next_settlement_date $nullableTextType,
        settlement_details $nullableTextType,
        created_at $textType,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN expected_settlement_date TEXT',
      );
    }
    if (oldVersion < 3) {
      // Add partial settlement columns
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN settled_amount REAL DEFAULT 0.0',
      );
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN next_settlement_date TEXT',
      );
      // Create partial_settlements table
      await db.execute('''
        CREATE TABLE partial_settlements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL,
          settled_amount REAL NOT NULL,
          settlement_date TEXT NOT NULL,
          next_settlement_date TEXT,
          settlement_details TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (transaction_id) REFERENCES transactions (id)
        )
      ''');
    }
    if (oldVersion < 4) {
      // Add settlement_details column to existing partial_settlements table
      await db.execute(
        'ALTER TABLE partial_settlements ADD COLUMN settlement_details TEXT',
      );
    }
    if (oldVersion < 5) {
      // Add settlement_details column to transactions table for full settlements
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN settlement_details TEXT',
      );
    }
  }

  // User operations
  Future<UserModel?> createUser(UserModel user) async {
    final db = await database;
    try {
      final id = await db.insert('users', user.toMap());
      return user.copyWith(id: id);
    } catch (e) {
      return null; // Username already exists
    }
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  // Transaction operations
  Future<TransactionModel> createTransaction(
    TransactionModel transaction,
  ) async {
    final db = await database;
    final id = await db.insert('transactions', transaction.toMap());
    return transaction.copyWith(id: id);
  }

  Future<List<TransactionModel>> getTransactions(int userId) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'transaction_date DESC',
    );

    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByDateRange(
    int userId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'user_id = ? AND transaction_date >= ? AND transaction_date <= ?',
      whereArgs: [userId, startDate, endDate],
      orderBy: 'transaction_date DESC',
    );

    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByType(
    int userId,
    String type,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'user_id = ? AND transaction_type = ?',
      whereArgs: [userId, type],
      orderBy: 'transaction_date DESC',
    );

    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByPerson(
    int userId,
    String personName,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'user_id = ? AND person_name = ?',
      whereArgs: [userId, personName],
      orderBy: 'transaction_date DESC',
    );

    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getUpcomingSettlements(
    int userId,
    String fromDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where:
          'user_id = ? AND is_settled = 0 AND expected_settlement_date IS NOT NULL AND expected_settlement_date >= ?',
      whereArgs: [userId, fromDate],
      orderBy: 'expected_settlement_date ASC',
    );

    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    return db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getSummary(int userId) async {
    final db = await database;

    // Calculate remaining balance (amount - settled_amount) for unsettled transactions
    final givenResult = await db.rawQuery(
      'SELECT SUM(amount - settled_amount) as total FROM transactions WHERE user_id = ? AND transaction_type = ? AND is_settled = 0',
      [userId, 'GIVEN'],
    );

    final takenResult = await db.rawQuery(
      'SELECT SUM(amount - settled_amount) as total FROM transactions WHERE user_id = ? AND transaction_type = ? AND is_settled = 0',
      [userId, 'TAKEN'],
    );

    final givenTotal = givenResult.first['total'] as double? ?? 0.0;
    final takenTotal = takenResult.first['total'] as double? ?? 0.0;

    return {'given': givenTotal, 'taken': takenTotal};
  }

  Future<List<String>> getAllPersonNames(int userId) async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT person_name FROM transactions WHERE user_id = ? ORDER BY person_name',
      [userId],
    );

    return maps.map((map) => map['person_name'] as String).toList();
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final maps = await db.query('users', orderBy: 'id ASC');
    return maps.map((map) => UserModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'id ASC');
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<PartialSettlementModel>> getAllPartialSettlements() async {
    final db = await database;
    final maps = await db.query('partial_settlements', orderBy: 'id ASC');
    return maps.map((map) => PartialSettlementModel.fromMap(map)).toList();
  }

  Future<List<PartialSettlementModel>> getPartialSettlementsByDateRange(
    int userId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT ps.*
      FROM partial_settlements ps
      INNER JOIN transactions t ON t.id = ps.transaction_id
      WHERE t.user_id = ?
        AND ps.settlement_date >= ?
        AND ps.settlement_date <= ?
      ORDER BY ps.settlement_date DESC
      ''',
      [userId, startDate, endDate],
    );

    return maps.map((map) => PartialSettlementModel.fromMap(map)).toList();
  }

  // Partial Settlement operations
  Future<int> createPartialSettlement(dynamic partialSettlement) async {
    final db = await database;
    return await db.insert('partial_settlements', partialSettlement.toMap());
  }

  Future<List<PartialSettlementModel>> getPartialSettlements(
    int transactionId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'partial_settlements',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'settlement_date DESC',
    );

    return maps.map((map) => PartialSettlementModel.fromMap(map)).toList();
  }

  Future<void> replaceAllData({
    required List<UserModel> users,
    required List<TransactionModel> transactions,
    required List<PartialSettlementModel> partialSettlements,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('partial_settlements');
      await txn.delete('transactions');
      await txn.delete('users');

      for (final user in users) {
        await txn.insert(
          'users',
          user.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final transaction in transactions) {
        await txn.insert(
          'transactions',
          transaction.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final settlement in partialSettlements) {
        await txn.insert(
          'partial_settlements',
          settlement.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}

extension UserModelCopyWith on UserModel {
  UserModel copyWith({int? id, String? username, String? createdAt}) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
