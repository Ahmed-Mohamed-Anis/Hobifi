import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class BookingService extends ChangeNotifier {
  List<BookingModel> _bookings = [];
  List<BookingModel> _businessBookings = [];
  bool _isLoading = false;
  String? _loadedForUserId;

  List<BookingModel> get bookings => _bookings;
  List<BookingModel> get businessBookings => _businessBookings;
  bool get isLoading => _isLoading;

  /// Atomically reserves a spot and creates a booking in one transaction.
  /// Returns the result map with 'ok', 'booking_id', 'expires_at' on success,
  /// or 'ok' = false with 'reason' on failure.
  Future<Map<String, dynamic>> createBookingAtomic({
    required String userId,
    required String activityId,
    required String activityTitle,
    required String activityImage,
    required String location,
    required double price,
    required DateTime dateTime,
  }) async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'create_booking_with_reservation',
        params: {
          'p_user_id': userId,
          'p_activity_id': activityId,
          'p_activity_title': activityTitle,
          'p_activity_image': activityImage,
          'p_location': location,
          'p_price': price,
          'p_date_time': dateTime.toIso8601String(),
        },
      );
      final map = Map<String, dynamic>.from(result as Map);
      if (map['ok'] == true) {
        await loadUserBookings(userId, force: true);
      }
      return map;
    } catch (e) {
      debugPrint('Failed to create atomic booking: $e');
      return {'ok': false, 'reason': 'exception', 'message': e.toString()};
    }
  }

  /// Fetch a single booking's current status from the database.
  /// Used for polling payment status without reloading all bookings.
  Future<BookingStatus?> fetchBookingStatus(String bookingId) async {
    try {
      final data = await SupabaseService.selectSingle(
        'bookings',
        select: 'status',
        filters: {'id': bookingId},
      );
      if (data == null) return null;
      try {
        return BookingStatus.values.firstWhere((e) => e.name == data['status']);
      } on StateError {
        return null;
      }
    } catch (e) {
      debugPrint('Failed to fetch booking status: $e');
      return null;
    }
  }

  Future<void> loadUserBookings(String userId, {bool force = false}) async {
    // Guard against duplicate loads (same pattern as LikeService)
    if (!force && _loadedForUserId == userId && _bookings.isNotEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await SupabaseService.select(
        'bookings',
        filters: {'user_id': userId},
        orderBy: 'created_at',
        ascending: false,
      );

      _bookings = data.map((json) => BookingModel.fromJson(json)).toList();
      _loadedForUserId = userId;

      // Auto-complete expired bookings
      await _autoCompleteExpiredBookings();
    } catch (e) {
      debugPrint('Failed to load bookings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Transitions confirmed bookings to completed if the activity date
  /// has passed by more than 2 hours.
  Future<void> _autoCompleteExpiredBookings() async {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 2));
    final toComplete = _bookings.where((b) =>
      b.status == BookingStatus.confirmed &&
      b.dateTime.isBefore(cutoff),
    ).toList();

    for (final booking in toComplete) {
      try {
        await SupabaseService.update(
          'bookings',
          {'status': 'completed'},
          filters: {'id': booking.id},
        );
        // Update local cache
        final idx = _bookings.indexWhere((b) => b.id == booking.id);
        if (idx >= 0) {
          _bookings[idx] = BookingModel(
            id: booking.id,
            userId: booking.userId,
            activityId: booking.activityId,
            activityTitle: booking.activityTitle,
            activityImage: booking.activityImage,
            location: booking.location,
            price: booking.price,
            dateTime: booking.dateTime,
            status: BookingStatus.completed,
            createdAt: booking.createdAt,
            updatedAt: DateTime.now(),
          );
        }
      } catch (e) {
        debugPrint('Failed to auto-complete booking ${booking.id}: $e');
      }
    }
  }

  /// Force-refresh all business bookings. Called by the booking management screen.
  Future<void> loadBusinessBookingsAll(String businessId) async {
    await loadBusinessBookings(businessId);
  }

  Future<void> loadBusinessBookings(String businessId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get all bookings for activities owned by this business
      final activities = await SupabaseService.select(
        'activities',
        select: 'id',
        filters: {'business_id': businessId},
      );

      final activityIds = activities.map((a) => a['id'] as String).toList();

      if (activityIds.isEmpty) {
        _businessBookings = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get bookings for these activities
      final data = await SupabaseService.from('bookings')
          .select()
          .inFilter('activity_id', activityIds)
          .order('created_at', ascending: false) as List<dynamic>;
      _businessBookings = data
          .map((row) => BookingModel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Failed to load business bookings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<BookingModel> getUserBookings(String userId) =>
      _bookings.where((b) => b.userId == userId).toList();

  List<BookingModel> getBookingsByStatus(BookingStatus status) =>
      _bookings.where((b) => b.status == status).toList();

  /// Check if user has a confirmed or completed booking for this activity
  bool hasBookedActivity(String userId, String activityId) =>
      _bookings.any((b) =>
          b.userId == userId &&
          b.activityId == activityId &&
          (b.status == BookingStatus.confirmed || b.status == BookingStatus.completed));

  Future<void> updateBookingStatus(String bookingId, BookingStatus status) async {
    if (status == BookingStatus.confirmed) {
      throw Exception('Booking confirmation is handled by the payment system.');
    }
    try {
      await SupabaseService.update(
        'bookings',
        {'status': status.name},
        filters: {'id': bookingId},
      );

      // Reload bookings
      final booking = _bookings.firstWhere((b) => b.id == bookingId);
      await loadUserBookings(booking.userId, force: true);
    } catch (e) {
      debugPrint('Failed to update booking status: $e');
      rethrow;
    }
  }

  /// Cancel a booking via the server-side edge function.
  /// Enforces 24-hour cancellation policy and handles refunds.
  Future<Map<String, dynamic>> cancelBookingServerSide(String bookingId) async {
    final token = SupabaseConfig.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      return {'success': false, 'error': 'Session expired. Please sign in again.'};
    }
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/process-cancellation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({'booking_id': bookingId}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Reload bookings to reflect the change
        final userId = SupabaseConfig.auth.currentUser?.id;
        if (userId != null) {
          await loadUserBookings(userId, force: true);
        }
        return data;
      } else {
        return {'success': false, 'error': data['error'] ?? 'Cancellation failed'};
      }
    } catch (e) {
      debugPrint('Failed to cancel booking: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Business cancels a confirmed booking from their side.
  Future<Map<String, dynamic>> cancelBookingBusiness(String bookingId) async {
    final token = SupabaseConfig.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      return {'success': false, 'error': 'Session expired. Please sign in again.'};
    }
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/process-cancellation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({'booking_id': bookingId, 'cancelled_by': 'business'}),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final businessId = SupabaseConfig.auth.currentUser?.id;
        if (businessId != null) await loadBusinessBookings(businessId);
        return {'success': true};
      }
      return {'success': false, 'error': data['error'] ?? 'Cancellation failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark a booking as attended (status -> completed). Provider-side action.
  /// Used when a business checks in a customer at the activity.
  Future<Map<String, dynamic>> markAttended(String bookingId) async {
    try {
      await SupabaseService.update(
        'bookings',
        {
          'status': BookingStatus.completed.name,
          'updated_at': DateTime.now().toIso8601String(),
        },
        filters: {'id': bookingId},
      );

      // Update local business bookings cache if the booking is present.
      final idx = _businessBookings.indexWhere((b) => b.id == bookingId);
      if (idx >= 0) {
        final b = _businessBookings[idx];
        _businessBookings[idx] = BookingModel(
          id: b.id,
          userId: b.userId,
          activityId: b.activityId,
          activityTitle: b.activityTitle,
          activityImage: b.activityImage,
          location: b.location,
          price: b.price,
          dateTime: b.dateTime,
          status: BookingStatus.completed,
          createdAt: b.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      notifyListeners();

      return {'success': true, 'message': 'Booking marked as attended'};
    } catch (e) {
      debugPrint('Failed to mark booking as attended: $e');
      return {'success': false, 'message': 'Failed to mark attended: $e'};
    }
  }

  Future<void> deleteBooking(String id) async {
    try {
      await SupabaseService.delete(
        'bookings',
        filters: {'id': id},
      );

      _bookings.removeWhere((b) => b.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete booking: $e');
      rethrow;
    }
  }
}
