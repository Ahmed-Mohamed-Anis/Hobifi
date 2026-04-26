class UserPaymentMethod {
  final String id;
  final String userId;
  final String cardToken;
  final String? maskedPan;
  final String? cardType;
  final bool isDefault;

  const UserPaymentMethod({
    required this.id,
    required this.userId,
    required this.cardToken,
    this.maskedPan,
    this.cardType,
    this.isDefault = false,
  });

  factory UserPaymentMethod.fromJson(Map<String, dynamic> json) {
    return UserPaymentMethod(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      cardToken: json['card_token'] as String,
      maskedPan: json['masked_pan'] as String?,
      cardType: json['card_type'] as String?,
      isDefault: (json['is_default'] as bool?) ?? false,
    );
  }

  String get displayLabel {
    if (maskedPan != null && maskedPan!.isNotEmpty) {
      final last4 = maskedPan!.replaceAll(RegExp(r'X'), '').trim();
      final type = cardType ?? 'Card';
      return '$type •••• ${last4.length >= 4 ? last4.substring(last4.length - 4) : last4}';
    }
    return cardType ?? 'Saved Card';
  }
}
