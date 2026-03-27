import 'package:flutter/foundation.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class WalletService extends ChangeNotifier {
  double _balance = 0.0;
  double _totalEarned = 0.0;
  double _totalWithdrawn = 0.0;
  List<WalletTransaction> _transactions = [];
  List<PayoutRequest> _payoutRequests = [];
  bool _isLoading = false;
  String? _loadedForBusinessId;

  double get balance => _balance;
  double get totalEarned => _totalEarned;
  double get totalWithdrawn => _totalWithdrawn;
  List<WalletTransaction> get transactions => _transactions;
  List<PayoutRequest> get payoutRequests => _payoutRequests;
  bool get isLoading => _isLoading;
  double get pendingPayouts => _payoutRequests
      .where((r) => r.status == 'pending' || r.status == 'approved')
      .fold(0.0, (sum, r) => sum + r.amount);

  Future<void> loadWallet(String businessId, {bool force = false}) async {
    if (!force && _loadedForBusinessId == businessId && _balance >= 0) return;
    _isLoading = true;
    notifyListeners();

    try {
      // Load wallet balance
      final walletData = await SupabaseService.selectSingle(
        'business_wallets',
        filters: {'business_id': businessId},
      );

      if (walletData != null) {
        _balance = (walletData['balance'] as num?)?.toDouble() ?? 0.0;
        _totalEarned = (walletData['total_earned'] as num?)?.toDouble() ?? 0.0;
        _totalWithdrawn = (walletData['total_withdrawn'] as num?)?.toDouble() ?? 0.0;
      } else {
        _balance = 0.0;
        _totalEarned = 0.0;
        _totalWithdrawn = 0.0;
      }

      // Load recent transactions
      final txData = await SupabaseService.select(
        'wallet_transactions',
        filters: {'business_id': businessId},
        orderBy: 'created_at',
        ascending: false,
        limit: 50,
      );
      _transactions = txData.map((json) => WalletTransaction.fromJson(json)).toList();

      // Load payout requests
      final payoutData = await SupabaseService.select(
        'payout_requests',
        filters: {'business_id': businessId},
        orderBy: 'created_at',
        ascending: false,
        limit: 20,
      );
      _payoutRequests = payoutData.map((json) => PayoutRequest.fromJson(json)).toList();

      _loadedForBusinessId = businessId;
    } catch (e) {
      debugPrint('Failed to load wallet: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestPayout({
    required String businessId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
  }) async {
    if (amount <= 0 || amount > _balance) return false;

    try {
      await SupabaseService.insert('payout_requests', {
        'business_id': businessId,
        'amount': amount,
        'status': 'pending',
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_holder_name': accountHolderName,
      });

      // Reload wallet data
      await loadWallet(businessId, force: true);
      return true;
    } catch (e) {
      debugPrint('Failed to request payout: $e');
      return false;
    }
  }
}

// Simple data classes for wallet

class WalletTransaction {
  final String id;
  final String businessId;
  final String type; // 'earning', 'payout', 'refund_deduction'
  final double amount;
  final String? referenceId;
  final String description;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.businessId,
    required this.type,
    required this.amount,
    this.referenceId,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    type: json['type'] as String,
    amount: (json['amount'] as num).toDouble(),
    referenceId: json['reference_id'] as String?,
    description: json['description'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class PayoutRequest {
  final String id;
  final String businessId;
  final double amount;
  final String status;
  final String bankName;
  final String accountNumber;
  final String accountHolderName;
  final String? adminNote;
  final DateTime requestedAt;
  final DateTime? processedAt;

  PayoutRequest({
    required this.id,
    required this.businessId,
    required this.amount,
    required this.status,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolderName,
    this.adminNote,
    required this.requestedAt,
    this.processedAt,
  });

  factory PayoutRequest.fromJson(Map<String, dynamic> json) => PayoutRequest(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    amount: (json['amount'] as num).toDouble(),
    status: json['status'] as String,
    bankName: json['bank_name'] as String? ?? '',
    accountNumber: json['account_number'] as String? ?? '',
    accountHolderName: json['account_holder_name'] as String? ?? '',
    adminNote: json['admin_note'] as String?,
    requestedAt: DateTime.parse(json['requested_at'] as String),
    processedAt: json['processed_at'] != null ? DateTime.tryParse(json['processed_at'] as String) : null,
  );
}
