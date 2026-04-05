import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class LikeService extends ChangeNotifier {
  final Set<String> _likedActivityIds = <String>{};
  List<ActivityModel> _likedActivities = [];
  bool _isLoading = false;
  String? _loadedForUserId;

  bool get isLoading => _isLoading;
  Set<String> get likedActivityIds => _likedActivityIds;
  List<ActivityModel> get likedActivities => _likedActivities;

  Future<void> loadLikes(String userId) async {
    if (_loadedForUserId == userId && _likedActivityIds.isNotEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      final data = await SupabaseService.select(
        'likes',
        select: 'activity_id',
        filters: {'user_id': userId},
        orderBy: 'created_at',
        ascending: false,
      );
      _likedActivityIds
        ..clear()
        ..addAll(data.map((e) => (e['activity_id'] as String)).whereType<String>());
      _loadedForUserId = userId;
    } catch (e) {
      debugPrint('Failed to load likes: $e');
      _likedActivityIds.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch full activity objects for all liked IDs
  Future<void> loadLikedActivities() async {
    if (_likedActivityIds.isEmpty) {
      _likedActivities = [];
      notifyListeners();
      return;
    }
    try {
      final data = await SupabaseConfig.client
          .from('activities')
          .select()
          .inFilter('id', _likedActivityIds.toList())
          .order('created_at', ascending: false) as List<dynamic>;
      _likedActivities = data
          .map((row) => ActivityModel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Failed to load liked activities: $e');
      _likedActivities = [];
    }
    notifyListeners();
  }

  bool isLiked(String activityId) => _likedActivityIds.contains(activityId);

  Future<void> toggleLike(String userId, String activityId) async {
    final like = !isLiked(activityId);
    await setLike(userId, activityId, like);
  }

  Future<void> setLike(String userId, String activityId, bool like) async {
    // Optimistic update
    final wasLiked = _likedActivityIds.contains(activityId);
    if (like) {
      _likedActivityIds.add(activityId);
    } else {
      _likedActivityIds.remove(activityId);
      _likedActivities.removeWhere((a) => a.id == activityId);
    }
    notifyListeners();

    try {
      if (like) {
        // Insert if not exists
        try {
          await SupabaseService.insert('likes', {
            'user_id': userId,
            'activity_id': activityId,
          });
        } catch (e) {
          // Unique violation or missing table/column
          final err = e.toString();
          if (!(err.contains('duplicate') || err.contains('Unique'))) {
            rethrow;
          }
        }
      } else {
        await SupabaseService.delete('likes', filters: {
          'user_id': userId,
          'activity_id': activityId,
        });
      }
    } catch (e) {
      debugPrint('setLike failed: $e');
      // Revert on failure
      if (wasLiked) {
        _likedActivityIds.add(activityId);
      } else {
        _likedActivityIds.remove(activityId);
      }
      notifyListeners();
    }
  }

  // New: Count total likes across a list of activities (for business dashboard)
  Future<int> countLikesForActivities(List<String> activityIds) async {
    if (activityIds.isEmpty) return 0;
    try {
      final data = await SupabaseService.from('likes')
          .select('activity_id')
          .inFilter('activity_id', activityIds);
      return (data as List).length;
    } catch (e) {
      debugPrint('Failed to count likes for activities: $e');
      return 0;
    }
  }
}
