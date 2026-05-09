import 'package:latlong2/latlong.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/utils/distance_util.dart';

typedef SectionFilterSort = List<ActivityModel> Function(
  List<ActivityModel> all,
  String category,
  LatLng? userLocation,
);

List<ActivityModel> _byCat(List<ActivityModel> list, String category) {
  if (category == 'All') return List.of(list);
  return list.where((a) => a.category == category).toList();
}

List<ActivityModel> trendingFilterSort(
  List<ActivityModel> all,
  String category,
  LatLng? userLocation,
) {
  final filtered = _byCat(all, category);
  final rated = filtered.where((a) => a.reviewCount > 0).toList()
    ..sort((a, b) => b.rating.compareTo(a.rating));

  if (rated.length >= 5) return rated.take(5).toList();

  final ratedIds = rated.map((a) => a.id).toSet();
  final newest = filtered.where((a) => !ratedIds.contains(a.id)).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return [...rated, ...newest].take(5).toList();
}

List<ActivityModel> nearbyFilterSort(
  List<ActivityModel> all,
  String category,
  LatLng? userLocation,
) {
  final filtered = _byCat(all, category);

  if (userLocation == null) return [];

  final withCoords = filtered.where((a) => a.latitude != null && a.longitude != null).toList()
    ..sort((a, b) {
      final dA = DistanceUtil.distanceKm(
        userLocation,
        LatLng(a.latitude!, a.longitude!),
      );
      final dB = DistanceUtil.distanceKm(
        userLocation,
        LatLng(b.latitude!, b.longitude!),
      );
      return dA.compareTo(dB);
    });

  final withoutCoords = filtered.where((a) => a.latitude == null || a.longitude == null).toList();
  return [...withCoords, ...withoutCoords].take(4).toList();
}

List<ActivityModel> weekendFilterSort(
  List<ActivityModel> all,
  String category,
  LatLng? userLocation,
) {
  return _byCat(all, category)
      .where(
        (a) =>
            a.dateTime.weekday == DateTime.friday ||
            a.dateTime.weekday == DateTime.saturday,
      )
      .toList();
}
