class TransactionModel {
  final int? id;
  final int userId;
  final String transactionType; // 'GIVEN' or 'TAKEN'
  final String personName;
  final String personContact;
  final double amount;
  final String reason;
  final String transactionDate;
  final bool isSettled;
  final String createdAt;

  TransactionModel({
    this.id,
    required this.userId,
    required this.transactionType,
    required this.personName,
    required this.personContact,
    required this.amount,
    required this.reason,
    required this.transactionDate,
    required this.isSettled,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'transaction_type': transactionType,
      'person_name': personName,
      'person_contact': personContact,
      'amount': amount,
      'reason': reason,
      'transaction_date': transactionDate,
      'is_settled': isSettled ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      userId: map['user_id'],
      transactionType: map['transaction_type'],
      personName: map['person_name'],
      personContact: map['person_contact'],
      amount: map['amount'],
      reason: map['reason'],
      transactionDate: map['transaction_date'],
      isSettled: map['is_settled'] == 1,
      createdAt: map['created_at'],
    );
  }

  TransactionModel copyWith({
    int? id,
    int? userId,
    String? transactionType,
    String? personName,
    String? personContact,
    double? amount,
    String? reason,
    String? transactionDate,
    bool? isSettled,
    String? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      transactionType: transactionType ?? this.transactionType,
      personName: personName ?? this.personName,
      personContact: personContact ?? this.personContact,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      transactionDate: transactionDate ?? this.transactionDate,
      isSettled: isSettled ?? this.isSettled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
