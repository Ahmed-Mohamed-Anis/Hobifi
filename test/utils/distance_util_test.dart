import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:hobby_haven/utils/distance_util.dart';

void main() {
  group('DistanceUtil', () {
    test('returns null when to is null', () {
      expect(DistanceUtil.formatDistance(const LatLng(30.0, 31.0), null), isNull);
    });

    test('returns km < 10 with one decimal', () {
      // Cairo to ~2.3 km away
      final result = DistanceUtil.formatDistance(
        const LatLng(30.0444, 31.2357),
        const LatLng(30.0650, 31.2357),
      );
      expect(result, isNotNull);
      expect(result, contains('km'));
      expect(result!.contains('.'), isTrue);
    });

    test('returns km >= 10 without decimal', () {
      // Cairo to Alexandria ~180 km
      final result = DistanceUtil.formatDistance(
        const LatLng(30.0444, 31.2357),
        const LatLng(31.2001, 29.9187),
      );
      expect(result, isNotNull);
      expect(result!.contains('.'), isFalse);
    });

    test('same point returns 0.0 km', () {
      final result = DistanceUtil.formatDistance(
        const LatLng(30.0, 31.0),
        const LatLng(30.0, 31.0),
      );
      expect(result, '0.0 km');
    });

    test('distanceKm returns raw km between two points', () {
      // Cairo centre to ~2.3 km north
      final dist = DistanceUtil.distanceKm(
        const LatLng(30.0444, 31.2357),
        const LatLng(30.0650, 31.2357),
      );
      expect(dist, greaterThan(2.0));
      expect(dist, lessThan(3.0));
    });

    test('distanceKm returns 0.0 for same point', () {
      final dist = DistanceUtil.distanceKm(
        const LatLng(30.0, 31.0),
        const LatLng(30.0, 31.0),
      );
      expect(dist, closeTo(0.0, 0.001));
    });
  });
}
