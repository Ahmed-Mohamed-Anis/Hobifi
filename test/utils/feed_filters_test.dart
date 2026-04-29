import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/utils/feed_filters.dart';

ActivityModel _a({
  String id = 'a1',
  double rating = 0.0,
  int reviewCount = 0,
  int spotsLeft = 10,
  DateTime? dateTime,
  double? lat,
  double? lng,
  String category = 'Art',
}) {
  return ActivityModel(
    id: id,
    businessId: 'b1',
    title: 'Test $id',
    description: '',
    category: category,
    price: 100,
    location: 'Cairo',
    imageUrl: 'http://example.com/img.jpg',
    imageUrls: [],
    rating: rating,
    reviewCount: reviewCount,
    duration: '2h',
    maxGuests: 10,
    spotsLeft: spotsLeft,
    dateTime: dateTime ?? DateTime(2026, 5, 4), // Monday default
    isInstantBooking: false,
    isPublic: true,
    features: [],
    latitude: lat,
    longitude: lng,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // ── trendingFilterSort ──────────────────────────────────────────────────────

  group('trendingFilterSort', () {
    test('returns top 3 rated descending, excludes zero-review activities', () {
      final activities = [
        _a(id: 'noReview', rating: 5.0, reviewCount: 0),
        _a(id: 'high', rating: 4.8, reviewCount: 10),
        _a(id: 'mid', rating: 4.0, reviewCount: 3),
        _a(id: 'low', rating: 3.0, reviewCount: 5),
        _a(id: 'extra', rating: 2.0, reviewCount: 2),
      ];
      final result = trendingFilterSort(activities, 'All', null);
      expect(result.length, 3);
      expect(result[0].id, 'high');
      expect(result[1].id, 'mid');
      expect(result[2].id, 'low');
    });

    test('pads with spotsLeft-sorted unrated when fewer than 3 have reviews', () {
      final activities = [
        _a(id: 'rated', rating: 4.0, reviewCount: 5),
        _a(id: 'bigSpots', spotsLeft: 8),
        _a(id: 'smallSpots', spotsLeft: 3),
      ];
      final result = trendingFilterSort(activities, 'All', null);
      expect(result.length, 3);
      expect(result[0].id, 'rated');
      expect(result[1].id, 'bigSpots');
      expect(result[2].id, 'smallSpots');
    });

    test('filters by category before sorting', () {
      final activities = [
        _a(id: 'art', rating: 4.8, reviewCount: 10, category: 'Art'),
        _a(id: 'sports', rating: 4.5, reviewCount: 8, category: 'Sports'),
      ];
      final result = trendingFilterSort(activities, 'Art', null);
      expect(result.length, 1);
      expect(result[0].id, 'art');
    });

    test('returns all when fewer than 3 activities exist', () {
      final activities = [_a(id: 'only', rating: 4.0, reviewCount: 1)];
      final result = trendingFilterSort(activities, 'All', null);
      expect(result.length, 1);
    });
  });

  // ── nearbyFilterSort ────────────────────────────────────────────────────────

  group('nearbyFilterSort', () {
    const cairo = LatLng(30.0444, 31.2357);

    test('returns 4 closest activities when location is provided', () {
      final activities = [
        _a(id: 'far', lat: 31.0, lng: 31.0),
        _a(id: 'closest', lat: 30.045, lng: 31.236),
        _a(id: 'medium', lat: 30.2, lng: 31.2),
        _a(id: 'close', lat: 30.05, lng: 31.24),
        _a(id: 'veryFar', lat: 25.0, lng: 30.0),
      ];
      final result = nearbyFilterSort(activities, 'All', cairo);
      expect(result.length, 4);
      expect(result.first.id, 'closest');
      expect(result[1].id, 'close');
    });

    test('activities without coordinates are placed last', () {
      final activities = [
        _a(id: 'noCoord'),
        _a(id: 'withCoord', lat: 30.05, lng: 31.24),
      ];
      final result = nearbyFilterSort(activities, 'All', cairo);
      expect(result[0].id, 'withCoord');
      expect(result[1].id, 'noCoord');
    });

    test('falls back to take(4) when no location provided', () {
      final activities = List.generate(6, (i) => _a(id: 'a$i'));
      final result = nearbyFilterSort(activities, 'All', null);
      expect(result.length, 4);
      expect(result[0].id, 'a0');
    });

    test('filters by category', () {
      final activities = [
        _a(id: 'art', lat: 30.05, lng: 31.24, category: 'Art'),
        _a(id: 'sports', lat: 30.06, lng: 31.24, category: 'Sports'),
      ];
      final result = nearbyFilterSort(activities, 'Art', cairo);
      expect(result.length, 1);
      expect(result[0].id, 'art');
    });
  });

  // ── weekendFilterSort ───────────────────────────────────────────────────────

  group('weekendFilterSort', () {
    // 2026-05-01 = Friday, 2026-05-02 = Saturday, 2026-05-03 = Sunday
    final friday = DateTime(2026, 5, 1);
    final saturday = DateTime(2026, 5, 2);
    final sunday = DateTime(2026, 5, 3);

    test('returns only friday and saturday activities', () {
      final activities = [
        _a(id: 'fri', dateTime: friday),
        _a(id: 'sat', dateTime: saturday),
        _a(id: 'sun', dateTime: sunday),
      ];
      final result = weekendFilterSort(activities, 'All', null);
      expect(result.length, 2);
      expect(result.any((a) => a.id == 'fri'), isTrue);
      expect(result.any((a) => a.id == 'sat'), isTrue);
      expect(result.any((a) => a.id == 'sun'), isFalse);
    });

    test('returns empty list when no weekend activities', () {
      final activities = [_a(id: 'sun', dateTime: sunday)];
      expect(weekendFilterSort(activities, 'All', null), isEmpty);
    });

    test('filters by category', () {
      final activities = [
        _a(id: 'art', dateTime: friday, category: 'Art'),
        _a(id: 'sports', dateTime: friday, category: 'Sports'),
      ];
      final result = weekendFilterSort(activities, 'Art', null);
      expect(result.length, 1);
      expect(result[0].id, 'art');
    });
  });
}
