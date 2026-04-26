import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/payment_model.dart';
import 'package:hobby_haven/models/user_payment_method_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class PaymentService extends ChangeNotifier {
  List<PaymentModel> _payments = [];
  List<UserPaymentMethod> _savedCards = [];
  bool _isLoading = false;
  String? _currentPaymentUrl;
  String? _currentPaymentToken;

  List<PaymentModel> get payments => _payments;
  List<UserPaymentMethod> get savedCards => _savedCards;
  bool get isLoading => _isLoading;
  String? get currentPaymentUrl => _currentPaymentUrl;
  String? get currentPaymentToken => _currentPaymentToken;

  Future<void> loadSavedCards(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('user_payment_methods')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      _savedCards = (data as List).map((j) => UserPaymentMethod.fromJson(j as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load saved cards: $e');
      _savedCards = [];
    }
  }

  /// Initialize payment session with Paymob
  Future<Map<String, dynamic>> initializePayment({
    required String bookingId,
    required String userId,
    required String activityId,
    required double amount,
    required String activityTitle,
    required String userEmail,
    required String userName,
    required String userPhone,
    String paymentMethod = 'card',
    String? walletPhone,
    String? cardToken,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Force-refresh the session to guarantee a valid JWT.
      // On web, the Supabase client can hold a stale token that DB
      // calls auto-refresh but functions.invoke() does not.
      String accessToken;
      try {
        final refreshed = await SupabaseConfig.auth.refreshSession();
        accessToken = refreshed.session?.accessToken
            ?? SupabaseConfig.auth.currentSession?.accessToken
            ?? '';
      } catch (_) {
        accessToken = SupabaseConfig.auth.currentSession?.accessToken ?? '';
      }

      if (accessToken.isEmpty) {
        throw Exception('You must be signed in to make a payment.');
      }

      debugPrint('PAYMENT DEBUG: token length=${accessToken.length}, starts=${accessToken.substring(0, 20.clamp(0, accessToken.length))}...');
      debugPrint('PAYMENT DEBUG: session exists=${SupabaseConfig.auth.currentSession != null}, user=${SupabaseConfig.auth.currentUser?.id}');

      final response = await SupabaseConfig.client.functions.invoke(
        'paymob-init',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {
          'booking_id': bookingId,
          'activity_id': activityId,
          'activity_title': activityTitle,
          'user_email': userEmail,
          'user_name': userName,
          'user_phone': userPhone,
          'payment_method': paymentMethod,
          if (walletPhone != null) 'wallet_phone': walletPhone,
          if (cardToken != null) 'card_token': cardToken,
        },
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        _currentPaymentUrl = data['iframe_url'] as String?;
        _currentPaymentToken = data['payment_token'] as String?;
        _isLoading = false;
        notifyListeners();
        return data;
      } else {
        final body = response.data is Map ? jsonEncode(response.data) : response.data.toString();
        throw Exception('Failed to initialize payment: $body');
      }
    } catch (e) {
      debugPrint('Payment initialization failed: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Load user payments
  Future<void> loadUserPayments(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await SupabaseService.select(
        'payments',
        filters: {'user_id': userId},
        orderBy: 'created_at',
        ascending: false,
      );

      _payments = data.map((json) => PaymentModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load payments: $e');
      _payments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load business earnings (payments for their activities)
  Future<double> getBusinessEarnings(String businessId) async {
    try {
      // Get activities owned by this business
      final activities = await SupabaseService.select(
        'activities',
        select: 'id',
        filters: {'business_id': businessId},
      );

      final activityIds = activities.map((a) => a['id'] as String).toList();
      if (activityIds.isEmpty) return 0.0;

      // Get completed payments for these activities
      final paymentsData = await SupabaseService.from('payments')
          .select('business_earnings')
          .inFilter('activity_id', activityIds)
          .eq('status', 'completed') as List<dynamic>;

      return paymentsData.fold<double>(
        0.0,
        (sum, row) => sum + ((row['business_earnings'] as num?)?.toDouble() ?? 0.0),
      );
    } catch (e) {
      debugPrint('Failed to get business earnings: $e');
      return 0.0;
    }
  }

  /// Create payment record after successful payment
  Future<void> createPayment(PaymentModel payment) async {
    try {
      final data = Map<String, dynamic>.from(payment.toJson());
      data.remove('id');
      data.remove('created_at');
      data.remove('updated_at');
      await SupabaseService.insert('payments', data);
      await loadUserPayments(payment.userId);
    } catch (e) {
      debugPrint('Failed to create payment: $e');
      rethrow;
    }
  }

  /// Update payment status
  Future<void> updatePaymentStatus(String paymentId, PaymentStatus status, {String? transactionId}) async {
    try {
      final updates = <String, dynamic>{'status': status.name};
      if (transactionId != null) {
        updates['transaction_id'] = transactionId;
      }
      await SupabaseService.update(
        'payments',
        updates,
        filters: {'id': paymentId},
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update payment status: $e');
      rethrow;
    }
  }

  /// Get payment by booking ID
  PaymentModel? getPaymentByBookingId(String bookingId) {
    try {
      return _payments.firstWhere((p) => p.bookingId == bookingId);
    } catch (_) {
      return null;
    }
  }

  void clearPaymentSession() {
    _currentPaymentUrl = null;
    _currentPaymentToken = null;
    notifyListeners();
  }
}
