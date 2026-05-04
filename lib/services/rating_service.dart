import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/rating_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';
import 'package:hobby_haven/utils/input_sanitizer.dart';

class RatingService extends ChangeNotifier {
  List<RatingModel> _ratings = [];
  bool _isLoading = false;

  /// Cache of reviews per activity (activityId -> list of reviews)
  final Map<String, List<RatingModel>> _activityReviews = {};

  List<RatingModel> get ratings => _ratings;
  bool get isLoading => _isLoading;

  Future<void> loadUserRatings(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await SupabaseService.select(
        'ratings',
        filters: {'user_id': userId},
        orderBy: 'created_at',
        ascending: false,
      );

      _ratings = data.map((json) => RatingModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load ratings: $e');
      _ratings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  RatingModel? getUserRatingForActivity(String userId, String activityId) {
    try {
      return _ratings.firstWhere(
        (r) => r.userId == userId && r.activityId == activityId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Load all reviews for an activity (with user names)
  Future<List<RatingModel>> loadActivityReviews(String activityId, {bool force = false}) async {
    if (!force && _activityReviews.containsKey(activityId)) {
      return _activityReviews[activityId]!;
    }

    try {
      final data = await SupabaseService.select(
        'ratings',
        filters: {'activity_id': activityId},
        orderBy: 'created_at',
        ascending: false,
        limit: 50,
      );

      final reviews = data.map((json) => RatingModel.fromJson(json)).toList();
      _activityReviews[activityId] = reviews;
      notifyListeners();
      return reviews;
    } catch (e) {
      debugPrint('Failed to load activity reviews: $e');
      return [];
    }
  }

  /// Get cached reviews for an activity
  List<RatingModel> getCachedActivityReviews(String activityId) {
    return _activityReviews[activityId] ?? [];
  }

  Future<void> addOrUpdateRating(String userId, String activityId, int rating, {String? comment}) async {
    try {
      final existing = getUserRatingForActivity(userId, activityId);

      final sanitizedComment = (comment != null && comment.isNotEmpty)
          ? InputSanitizer.sanitize(comment, maxLength: 500)
          : comment;

      if (existing != null) {
        // Update existing rating — always include comment to allow clearing
        await SupabaseService.update(
          'ratings',
          {'rating': rating, 'comment': sanitizedComment ?? ''},
          filters: {'id': existing.id},
        );
      } else {
        // Create new rating
        final payload = <String, dynamic>{
          'user_id': userId,
          'activity_id': activityId,
          'rating': rating,
        };
        if (sanitizedComment != null && sanitizedComment.isNotEmpty) {
          payload['comment'] = sanitizedComment;
        }
        await SupabaseService.insert('ratings', payload);
      }

      // Reload both user ratings and activity reviews
      await loadUserRatings(userId);
      // Invalidate activity review cache
      _activityReviews.remove(activityId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add/update rating: $e');
      rethrow;
    }
  }

  Future<Map<String, double>> getAverageRatingsForActivities(List<String> activityIds) async {
    if (activityIds.isEmpty) return {};

    try {
      final data = await SupabaseService.from('ratings')
          .select('activity_id, rating')
          .inFilter('activity_id', activityIds);

      final Map<String, List<int>> grouped = {};
      for (final row in data) {
        final activityId = row['activity_id'] as String;
        final rating = row['rating'] as int;
        grouped.putIfAbsent(activityId, () => []).add(rating);
      }

      return grouped.map((activityId, ratings) {
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        return MapEntry(activityId, avg);
      });
    } catch (e) {
      debugPrint('Failed to get average ratings: $e');
      return {};
    }
  }

  Future<double> getAverageRatingForActivity(String activityId) async {
    try {
      final data = await SupabaseService.select(
        'ratings',
        select: 'rating',
        filters: {'activity_id': activityId},
      );

      if (data.isEmpty) return 0.0;

      final ratings = data.map((r) => r['rating'] as int).toList();
      return ratings.reduce((a, b) => a + b) / ratings.length;
    } catch (e) {
      debugPrint('Failed to get average rating: $e');
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> reportReview(String reviewId, String reason) async {
    try {
      if (reason.trim().isEmpty) {
        return {'success': false, 'error': 'Reason cannot be empty'};
      }

      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return {'success': false, 'error': 'Not authenticated'};
      await SupabaseService.insert('review_reports', {
        'review_id': reviewId,
        'reporter_id': userId,
        'reason': reason,
      });
      return {'success': true};
    } catch (e) {
      debugPrint('reportReview error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
