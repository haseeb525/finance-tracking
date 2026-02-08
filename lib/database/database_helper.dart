import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';

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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
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
        is_settled $intType,
        created_at $textType,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
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

    final givenResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE user_id = ? AND transaction_type = ? AND is_settled = 0',
      [userId, 'GIVEN'],
    );

    final takenResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE user_id = ? AND transaction_type = ? AND is_settled = 0',
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
