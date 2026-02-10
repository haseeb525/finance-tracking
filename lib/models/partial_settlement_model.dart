class PartialSettlementModel {
  final int? id;
  final int transactionId;
  final double settledAmount;
  final String settlementDate;
  final String? nextSettlementDate;
  final String createdAt;

  PartialSettlementModel({
    this.id,
    required this.transactionId,
    required this.settledAmount,
    required this.settlementDate,
    this.nextSettlementDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'settled_amount': settledAmount,
      'settlement_date': settlementDate,
      'next_settlement_date': nextSettlementDate,
      'created_at': createdAt,
    };
  }

  factory PartialSettlementModel.fromMap(Map<String, dynamic> map) {
    return PartialSettlementModel(
      id: map['id'],
      transactionId: map['transaction_id'],
      settledAmount: map['settled_amount'],
      settlementDate: map['settlement_date'],
      nextSettlementDate: map['next_settlement_date'],
      createdAt: map['created_at'],
    );
  }

  PartialSettlementModel copyWith({
    int? id,
    int? transactionId,
    double? settledAmount,
    String? settlementDate,
    String? nextSettlementDate,
    String? createdAt,
  }) {
    return PartialSettlementModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      settledAmount: settledAmount ?? this.settledAmount,
      settlementDate: settlementDate ?? this.settlementDate,
      nextSettlementDate: nextSettlementDate ?? this.nextSettlementDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
