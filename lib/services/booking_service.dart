import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class BookingService extends ChangeNotifier {
  List<BookingModel> _bookings = [];
  bool _isLoading = false;
  String? _loadedForUserId;

  List<BookingModel> get bookings => _bookings;
  bool get isLoading => _isLoading;

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
    } catch (e) {
      debugPrint('Failed to load bookings: $e');
      _bookings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
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
        _bookings = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get bookings for these activities
      final data = await SupabaseService.from('bookings')
          .select()
          .inFilter('activity_id', activityIds)
          .order('created_at', ascending: false) as List<dynamic>;
      _bookings = data
          .map((row) => BookingModel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Failed to load business bookings: $e');
      _bookings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<BookingModel> getUserBookings(String userId) =>
      _bookings.where((b) => b.userId == userId).toList();

  List<BookingModel> getBookingsByStatus(BookingStatus status) =>
      _bookings.where((b) => b.status == status).toList();

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
