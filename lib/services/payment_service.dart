import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/user_payment_method_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class PaymentService extends ChangeNotifier {
  List<UserPaymentMethod> _savedCards = [];
  bool _isLoading = false;

  List<UserPaymentMethod> get savedCards => _savedCards;
  bool get isLoading => _isLoading;

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

  Future<void> deleteSavedCard(String cardId, String userId) async {
    try {
      await SupabaseConfig.client
          .from('user_payment_methods')
          .delete()
          .eq('id', cardId)
          .eq('user_id', userId);
      _savedCards.removeWhere((c) => c.id == cardId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete saved card: $e');
      rethrow;
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
    bool saveCard = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Force-refresh the session to guarantee a valid JWT.
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
          'save_card': saveCard,
        },
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
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
}
