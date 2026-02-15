class TransactionModel {
  final int? id;
  final int userId;
  final String transactionType; // 'GIVEN' or 'TAKEN'
  final String personName;
  final String personContact;
  final double amount;
  final String reason;
  final String transactionDate;
  final String? expectedSettlementDate;
  final bool isSettled;
  final double settledAmount; // Amount already settled (partial)
  final String? nextSettlementDate; // Next expected settlement date
  final String? settlementDetails; // Details for full settlement
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
    this.expectedSettlementDate,
    required this.isSettled,
    this.settledAmount = 0.0,
    this.nextSettlementDate,
    this.settlementDetails,
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
      'expected_settlement_date': expectedSettlementDate,
      'is_settled': isSettled ? 1 : 0,
      'settled_amount': settledAmount,
      'next_settlement_date': nextSettlementDate,
      'settlement_details': settlementDetails,
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
      expectedSettlementDate: map['expected_settlement_date'],
      isSettled: map['is_settled'] == 1,
      settledAmount: (map['settled_amount'] ?? 0.0).toDouble(),
      nextSettlementDate: map['next_settlement_date'],
      settlementDetails: map['settlement_details'],
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
    String? expectedSettlementDate,
    bool? isSettled,
    double? settledAmount,
    String? nextSettlementDate,
    String? settlementDetails,
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
      expectedSettlementDate:
          expectedSettlementDate ?? this.expectedSettlementDate,
      isSettled: isSettled ?? this.isSettled,
      settledAmount: settledAmount ?? this.settledAmount,
      nextSettlementDate: nextSettlementDate ?? this.nextSettlementDate,
      settlementDetails: settlementDetails ?? this.settlementDetails,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
