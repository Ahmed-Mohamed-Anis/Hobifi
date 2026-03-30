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
      return BookingStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => BookingStatus.pending,
      );
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
      _bookings = [];
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
      _businessBookings = [];
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

  Future<void> createBooking(BookingModel booking) async {
    try {
      final data = Map<String, dynamic>.from(booking.toJson());
      // Keep the ID if provided, let Supabase generate timestamps
      data.remove('created_at');
      data.remove('updated_at');
      await SupabaseService.insert('bookings', data);
      await loadUserBookings(booking.userId, force: true);
    } catch (e) {
      debugPrint('Failed to create booking: $e');
      rethrow;
    }
  }

  Future<void> updateBookingStatus(String bookingId, BookingStatus status) async {
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
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/process-cancellation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.auth.currentSession?.accessToken ?? SupabaseConfig.anonKey}',
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
