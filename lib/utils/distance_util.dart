import 'dart:math';
import 'package:latlong2/latlong.dart';

class DistanceUtil {
  DistanceUtil._();

  static String? formatDistance(LatLng from, LatLng? to) {
    if (to == null) return null;
    final km = _haversineKm(from.latitude, from.longitude, to.latitude, to.longitude);
    if (km >= 10) return '${km.round()} km';
    return '${km.toStringAsFixed(1)} km';
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;
}
