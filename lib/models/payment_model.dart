class PaymentModel {
  final String id;
  final String bookingId;
  final String userId;
  final String activityId;
  final double amount;
  final double platformFee; // 10% fee
  final double businessEarnings; // 90% of amount
  final String transactionId;
  final PaymentStatus status;
  final PaymentMethod paymentMethod;
  final RefundStatus refundStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.activityId,
    required this.amount,
    required this.platformFee,
    required this.businessEarnings,
    required this.transactionId,
    required this.status,
    required this.paymentMethod,
    this.refundStatus = RefundStatus.none,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
    id: json['id'] as String,
    bookingId: json['booking_id'] as String,
    userId: json['user_id'] as String,
    activityId: json['activity_id'] as String,
    amount: (json['amount'] as num).toDouble(),
    platformFee: (json['platform_fee'] as num).toDouble(),
    businessEarnings: (json['business_earnings'] as num).toDouble(),
    transactionId: json['transaction_id'] as String? ?? '',
    status: PaymentStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => PaymentStatus.pending,
    ),
    paymentMethod: PaymentMethod.values.firstWhere(
      (e) => e.name == json['payment_method'],
      orElse: () => PaymentMethod.card,
    ),
    refundStatus: RefundStatus.values.firstWhere(
      (e) => e.name == (json['refund_status'] as String? ?? 'none'),
      orElse: () => RefundStatus.none,
    ),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'booking_id': bookingId,
    'user_id': userId,
    'activity_id': activityId,
    'amount': amount,
    'platform_fee': platformFee,
    'business_earnings': businessEarnings,
    'transaction_id': transactionId,
    'status': status.name,
    'payment_method': paymentMethod.name,
    'refund_status': refundStatus.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  PaymentModel copyWith({
    String? id,
    String? bookingId,
    String? userId,
    String? activityId,
    double? amount,
    double? platformFee,
    double? businessEarnings,
    String? transactionId,
    PaymentStatus? status,
    PaymentMethod? paymentMethod,
    RefundStatus? refundStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PaymentModel(
    id: id ?? this.id,
    bookingId: bookingId ?? this.bookingId,
    userId: userId ?? this.userId,
    activityId: activityId ?? this.activityId,
    amount: amount ?? this.amount,
    platformFee: platformFee ?? this.platformFee,
    businessEarnings: businessEarnings ?? this.businessEarnings,
    transactionId: transactionId ?? this.transactionId,
    status: status ?? this.status,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    refundStatus: refundStatus ?? this.refundStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Calculate earnings from amount (90%)
  static double calculateBusinessEarnings(double amount) => amount * 0.9;
  
  /// Calculate platform fee from amount (10%)
  static double calculatePlatformFee(double amount) => amount * 0.1;
}

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  refunded
}

enum PaymentMethod {
  card,
  wallet,
  applePay
}

enum RefundStatus {
  none,
  requested,
  processed
}
