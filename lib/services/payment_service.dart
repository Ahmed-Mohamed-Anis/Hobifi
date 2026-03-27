import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/payment_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';
import 'package:http/http.dart' as http;

class PaymentService extends ChangeNotifier {
  List<PaymentModel> _payments = [];
  bool _isLoading = false;
  String? _currentPaymentUrl;
  String? _currentPaymentToken;

  List<PaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get currentPaymentUrl => _currentPaymentUrl;
  String? get currentPaymentToken => _currentPaymentToken;

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
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/paymob-init'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
        body: jsonEncode({
          'booking_id': bookingId,
          'user_id': userId,
          'activity_id': activityId,
          'amount': amount,
          'activity_title': activityTitle,
          'user_email': userEmail,
          'user_name': userName,
          'user_phone': userPhone,
          'payment_method': paymentMethod,
          if (walletPhone != null) 'wallet_phone': walletPhone,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentPaymentUrl = data['iframe_url'];
        _currentPaymentToken = data['payment_token'];
        _isLoading = false;
        notifyListeners();
        return data;
      } else {
        throw Exception('Failed to initialize payment: ${response.body}');
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
