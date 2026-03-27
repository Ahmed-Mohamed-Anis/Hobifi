import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class ActivityService extends ChangeNotifier {
  List<ActivityModel> _activities = [];
  bool _isLoading = false;
  bool _hasMore = true;
  static const int _pageSize = 20;

  List<ActivityModel> get activities => _activities;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> initialize() async {
    await loadActivities();
  }

  Future<void> loadActivities() async {
    _isLoading = true;
    _hasMore = true;
    notifyListeners();

    try {
      final data = await SupabaseService.select(
        'activities',
        orderBy: 'created_at',
        ascending: false,
        limit: _pageSize,
      );

      _activities = data.map((json) => ActivityModel.fromJson(json)).toList();
      _hasMore = data.length >= _pageSize;
    } catch (e) {
      debugPrint('Failed to load activities: $e');
      _activities = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load next page of activities (for infinite scroll)
  Future<void> loadMoreActivities() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await SupabaseService.select(
        'activities',
        orderBy: 'created_at',
        ascending: false,
        limit: _pageSize,
        offset: _activities.length,
      );

      final newActivities = data.map((json) => ActivityModel.fromJson(json)).toList();
      _activities.addAll(newActivities);
      _hasMore = newActivities.length >= _pageSize;
    } catch (e) {
      debugPrint('Failed to load more activities: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh: reload from scratch
  Future<void> refreshActivities() async {
    _hasMore = true;
    await loadActivities();
  }

  List<ActivityModel> getActivitiesByCategory(String category) {
    if (category == 'All') return _activities;
    return _activities.where((a) => a.category == category).toList();
  }

  ActivityModel? getActivityById(String id) {
    try {
      return _activities.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  List<ActivityModel> getActivitiesByBusinessId(String businessId) =>
      _activities.where((a) => a.businessId == businessId).toList();

  Future<void> createActivity(ActivityModel activity) async {
    try {
      try {
        // Let DB generate id and timestamps
        final payload = Map<String, dynamic>.from(activity.toJson());
        payload.remove('id');
        payload.remove('created_at');
        payload.remove('updated_at');
        await SupabaseService.insert('activities', payload);
      } catch (e) {
        final err = e.toString();
        debugPrint('Create activity failed (first try): $err');
        // Retry without gallery_images/start_at/end_at if the column is missing
        if (err.contains('gallery_images') || err.contains('start_at') || err.contains('end_at') || err.contains('column') || err.contains('No column')) {
          final legacy = Map<String, dynamic>.from(activity.toJson());
          legacy.remove('id');
          legacy.remove('created_at');
          legacy.remove('updated_at');
          legacy.remove('gallery_images');
          legacy.remove('start_at');
          legacy.remove('end_at');
          await SupabaseService.insert('activities', legacy);
        } else {
          rethrow;
        }
      }
      await loadActivities();
    } catch (e) {
      debugPrint('Failed to create activity: $e');
      rethrow;
    }
  }

  Future<void> updateActivity(ActivityModel activity) async {
    try {
      try {
        final payload = Map<String, dynamic>.from(activity.toJson());
        // Don't send id or timestamps in update payload
        payload.remove('id');
        payload.remove('created_at');
        payload.remove('updated_at');
        await SupabaseService.update(
          'activities',
          payload,
          filters: {'id': activity.id},
        );
      } catch (e) {
        final err = e.toString();
        debugPrint('Update activity failed (first try): $err');
        if (err.contains('gallery_images') || err.contains('start_at') || err.contains('end_at') || err.contains('column') || err.contains('No column')) {
          final legacy = Map<String, dynamic>.from(activity.toJson());
          legacy.remove('id');
          legacy.remove('created_at');
          legacy.remove('updated_at');
          legacy.remove('gallery_images');
          legacy.remove('start_at');
          legacy.remove('end_at');
          await SupabaseService.update(
            'activities',
            legacy,
            filters: {'id': activity.id},
          );
        } else {
          rethrow;
        }
      }
      await loadActivities();
    } catch (e) {
      debugPrint('Failed to update activity: $e');
      rethrow;
    }
  }

  Future<void> deleteActivity(String id) async {
    try {
      await SupabaseService.delete(
        'activities',
        filters: {'id': id},
      );
      await loadActivities();
    } catch (e) {
      debugPrint('Failed to delete activity: $e');
      rethrow;
    }
  }
}
