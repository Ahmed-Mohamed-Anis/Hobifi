# Location Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full location awareness — GPS permission in onboarding, distance badges on feed cards, map view on activity detail screen, and a map-based location picker for businesses.

**Architecture:** A new `LocationService` (ChangeNotifier) handles GPS permission, position reads, and SharedPreferences persistence. `ActivityModel` gains nullable `latitude`/`longitude`. Three UI features (onboarding, detail screen, business picker) are built on this shared infrastructure. Distance is computed client-side with Haversine.

**Tech Stack:** Flutter, `geolocator` (GPS), `flutter_map` + `latlong2` (OSM maps), Nominatim REST API (address search/reverse-geocode, no key needed), `shared_preferences` + `url_launcher` (already in pubspec).

**Spec:** `docs/superpowers/specs/2026-04-26-location-feature-design.md`

---

## File Map

| Action | File |
|---|---|
| Create | `lib/services/location_service.dart` |
| Create | `lib/utils/distance_util.dart` |
| Create | `lib/widgets/location_picker.dart` |
| Create | `supabase/migrations/20260426000000_add_activity_coordinates.sql` |
| Modify | `pubspec.yaml` |
| Modify | `android/app/src/main/AndroidManifest.xml` |
| Modify | `ios/Runner/Info.plist` |
| Modify | `lib/models/activity_model.dart` |
| Modify | `lib/main.dart` |
| Modify | `lib/screens/onboarding_screen.dart` |
| Modify | `lib/screens/user/activity_details_screen.dart` |
| Modify | `lib/screens/business/create_activity_screen.dart` |
| Modify | `lib/widgets/hobifi_card.dart` |
| Modify | `lib/screens/user/feed_screen.dart` |

---

### Task 1: Add packages to pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

Note: `url_launcher`, `http`, and `shared_preferences` are **already** in pubspec — do not re-add them.

- [ ] **Step 1: Add the three new dependencies**

In `pubspec.yaml`, under `dependencies:`, add after `shimmer: ^3.0.0`:
```yaml
  geolocator: ^13.0.0
  flutter_map: ^7.0.0
  latlong2: ^0.9.0
```

- [ ] **Step 2: Install packages**

```bash
flutter pub get
```
Expected: resolves without errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add geolocator, flutter_map, latlong2 packages"
```

---

### Task 2: Add native location permissions

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Add Android permissions**

In `android/app/src/main/AndroidManifest.xml`, add these two lines directly before the `<application` tag:
```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

- [ ] **Step 2: Add iOS usage description**

In `ios/Runner/Info.plist`, add inside the root `<dict>` (alongside existing keys):
```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Hobifi uses your location to show activities near you.</string>
```

- [ ] **Step 3: Analyze**

```bash
flutter analyze
```
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "chore: add location permissions for Android and iOS"
```

---

### Task 3: Supabase migration — add lat/lng to activities

**Files:**
- Create: `supabase/migrations/20260426000000_add_activity_coordinates.sql`

- [ ] **Step 1: Create migration file**

Create `supabase/migrations/20260426000000_add_activity_coordinates.sql` with:
```sql
ALTER TABLE activities
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/20260426000000_add_activity_coordinates.sql
git commit -m "chore(db): add latitude/longitude columns to activities"
```

---

### Task 4: Update ActivityModel with nullable coordinates

**Files:**
- Modify: `lib/models/activity_model.dart`

- [ ] **Step 1: Add fields to the class**

After `final List<String> features;` add:
```dart
  final double? latitude;
  final double? longitude;
```

- [ ] **Step 2: Add to constructor**

In `ActivityModel({...})`, after `required this.features,`:
```dart
    this.latitude,
    this.longitude,
```

- [ ] **Step 3: Add to `fromJson`**

In `factory ActivityModel.fromJson(...)`, after `features: List<String>.from(json['features'] as List),`:
```dart
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
```

- [ ] **Step 4: Add to `toJson`**

In `Map<String, dynamic> toJson()`, after `'features': features,`:
```dart
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
```

- [ ] **Step 5: Add to `copyWith`**

In `ActivityModel copyWith({...})` signature, after `List<String>? features,`:
```dart
    double? latitude,
    double? longitude,
```

In the `copyWith` return body, after `features: features ?? this.features,`:
```dart
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
```

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/models/activity_model.dart
```
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/models/activity_model.dart
git commit -m "feat(model): add nullable latitude/longitude to ActivityModel"
```

---

### Task 5: Create DistanceUtil + unit test

**Files:**
- Create: `lib/utils/distance_util.dart`
- Modify: `test/utils/distance_util_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/utils/distance_util_test.dart`:
```dart
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
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/utils/distance_util_test.dart
```
Expected: FAIL — `distance_util.dart` not found.

- [ ] **Step 3: Implement DistanceUtil**

Create `lib/utils/distance_util.dart`:
```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/utils/distance_util_test.dart
```
Expected: 4/4 PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/distance_util.dart test/utils/distance_util_test.dart
git commit -m "feat: add DistanceUtil with Haversine formula"
```

---

### Task 6: Create LocationService

**Files:**
- Create: `lib/services/location_service.dart`

- [ ] **Step 1: Create the service**

Create `lib/services/location_service.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService extends ChangeNotifier {
  static const _keyLat = 'user_lat';
  static const _keyLng = 'user_lng';

  LatLng? savedLocation;

  void loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLat);
    final lng = prefs.getDouble(_keyLng);
    if (lat != null && lng != null) {
      savedLocation = LatLng(lat, lng);
      notifyListeners();
    }
  }

  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<LatLng?> getCurrentLocation() async {
    final granted = await requestPermission();
    if (!granted) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyLat, latLng.latitude);
      await prefs.setDouble(_keyLng, latLng.longitude);
      savedLocation = latLng;
      notifyListeners();
      return latLng;
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/services/location_service.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/services/location_service.dart
git commit -m "feat: add LocationService with GPS permission and SharedPreferences persistence"
```

---

### Task 7: Register LocationService in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add import**

At the top of `lib/main.dart`, add:
```dart
import 'package:hobby_haven/services/location_service.dart';
```

- [ ] **Step 2: Register provider**

In the `MultiProvider` list, add after `ChangeNotifierProvider(create: (_) => ActivityService()..initialize()),`:
```dart
        ChangeNotifierProvider(create: (_) => LocationService()..loadSavedLocation()),
```

- [ ] **Step 3: Analyze**

```bash
flutter analyze lib/main.dart
```
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: register LocationService provider in main.dart"
```

---

### Task 8: Update onboarding with "Use my location" button

**Files:**
- Modify: `lib/screens/onboarding_screen.dart`

- [ ] **Step 1: Add LocationService import**

At the top of `lib/screens/onboarding_screen.dart`, add:
```dart
import 'package:hobby_haven/services/location_service.dart';
```

- [ ] **Step 2: Convert `_CityPage` to StatefulWidget**

Replace the entire `_CityPage` class (the `StatelessWidget` and its `build` method) with a `StatefulWidget`:

```dart
class _CityPage extends StatefulWidget {
  final TextEditingController controller;
  const _CityPage({required this.controller});

  @override
  State<_CityPage> createState() => _CityPageState();
}

class _CityPageState extends State<_CityPage> {
  bool _locationDetected = false;
  bool _detecting = false;

  Future<void> _useMyLocation() async {
    setState(() => _detecting = true);
    final locationService = context.read<LocationService>();
    final result = await locationService.getCurrentLocation();
    if (!mounted) return;
    if (result == null) {
      setState(() => _detecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location access denied — enter your city manually'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _locationDetected = true;
      _detecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: AppSpacing.horizontalLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Where are you?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll show activities near you first.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 40),

          if (_locationDetected)
            // Confirmation chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: colorScheme.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location detected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _locationDetected = false),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Change',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // "Use my location" button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _detecting ? null : _useMyLocation,
                icon: _detecting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(Icons.my_location_rounded, color: colorScheme.primary),
                label: Text(
                  _detecting ? 'Detecting...' : 'Use my location',
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Divider(color: colorScheme.outline.withValues(alpha: 0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colorScheme.outline.withValues(alpha: 0.3))),
              ],
            ),
            const SizedBox(height: 12),
            // City text field
            TextField(
              controller: widget.controller,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Cairo, Alexandria, London...',
                prefixIcon: Icon(Icons.location_on_rounded, color: colorScheme.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),
          ],

          const SizedBox(height: 16),
          Center(
            child: Text(
              'This is optional — you can always change it later.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze**

```bash
flutter analyze lib/screens/onboarding_screen.dart
```
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/onboarding_screen.dart
git commit -m "feat(onboarding): add 'Use my location' GPS button with confirmation chip"
```

---

### Task 9: Create LocationPickerWidget

**Files:**
- Create: `lib/widgets/location_picker.dart`

- [ ] **Step 1: Create the widget**

Create `lib/widgets/location_picker.dart`:
```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:hobby_haven/theme.dart';

typedef LocationResult = ({double latitude, double longitude, String displayAddress});

class LocationPickerWidget extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerWidget({super.key, this.initialLocation});

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  late final MapController _mapController;
  late LatLng _center;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<_NominatimResult> _searchResults = [];
  bool _isSearching = false;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _center = widget.initialLocation ?? const LatLng(30.0444, 31.2357); // Cairo default
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=eg',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'com.hobifi.app'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _searchResults = data.map((e) => _NominatimResult.fromJson(e as Map<String, dynamic>)).toList();
          _isSearching = false;
        });
      } else {
        setState(() => _isSearching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectResult(_NominatimResult result) {
    final latLng = LatLng(result.lat, result.lng);
    _mapController.move(latLng, 15);
    setState(() {
      _center = latLng;
      _searchResults = [];
      _searchController.text = result.displayName;
    });
  }

  Future<void> _confirm() async {
    setState(() => _isConfirming = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${_center.latitude}&lon=${_center.longitude}&format=json',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'com.hobifi.app'});
      String address;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        address = data['display_name'] as String? ?? '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}';
      } else {
        address = '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}';
      }
      if (!mounted) return;
      Navigator.of(context).pop<LocationResult>((
        latitude: _center.latitude,
        longitude: _center.longitude,
        displayAddress: address,
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get address. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Location'),
        actions: [
          TextButton(
            onPressed: _isConfirming ? null : _confirm,
            child: _isConfirming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search address...',
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Search results dropdown
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final result = _searchResults[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.location_on_rounded, color: colorScheme.primary, size: 18),
                    title: Text(result.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _selectResult(result),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Map with crosshair pin
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 14,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        setState(() => _center = camera.center);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.hobifi.app',
                    ),
                  ],
                ),
                // Fixed crosshair pin
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_pin, color: AppColors.orange, size: 48),
                      const SizedBox(height: 24), // offset so pin tip is at center
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NominatimResult {
  final double lat;
  final double lng;
  final String displayName;

  const _NominatimResult({required this.lat, required this.lng, required this.displayName});

  factory _NominatimResult.fromJson(Map<String, dynamic> json) => _NominatimResult(
    lat: double.parse(json['lat'] as String),
    lng: double.parse(json['lon'] as String),
    displayName: json['display_name'] as String,
  );
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/widgets/location_picker.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/location_picker.dart
git commit -m "feat: add LocationPickerWidget with OSM map, address search, and crosshair pin"
```

---

### Task 10: Update create_activity_screen with location picker

**Files:**
- Modify: `lib/screens/business/create_activity_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/screens/business/create_activity_screen.dart`, add:
```dart
import 'package:latlong2/latlong.dart';
import 'package:hobby_haven/widgets/location_picker.dart';
```

- [ ] **Step 2: Add lat/lng state variables**

In `_CreateActivityScreenState`, after `final _locationController = TextEditingController();`:
```dart
  double? _activityLat;
  double? _activityLng;
```

- [ ] **Step 3: Add location picker method**

Add a new method to `_CreateActivityScreenState`:
```dart
  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerWidget(
          initialLocation: _activityLat != null
              ? LatLng(_activityLat!, _activityLng!)
              : null,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _locationController.text = result.displayAddress;
        _activityLat = result.latitude;
        _activityLng = result.longitude;
      });
    }
  }
```

- [ ] **Step 4: Replace the location TextField with a tappable row**

Find this block in the build method:
```dart
                    FormLabel(label: 'Location'),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'Enter street address or venue name',
                        prefixIcon: Icon(Icons.location_on_rounded),
                      ),
                    ),
```

Replace with:
```dart
                    FormLabel(label: 'Location'),
                    GestureDetector(
                      onTap: _pickLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(14),
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _locationController,
                                builder: (_, value, __) => Text(
                                  value.text.isEmpty ? 'Tap to set location on map' : value.text,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: value.text.isEmpty
                                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                          ],
                        ),
                      ),
                    ),
```

- [ ] **Step 5: Include lat/lng in the create and update calls**

Find all places where an activity map is built for Supabase (the `create` and `update` calls). They include `location: _locationController.text.trim()`. After each such `location:` line in the data map, add:
```dart
          if (_activityLat != null) 'latitude': _activityLat,
          if (_activityLng != null) 'longitude': _activityLng,
```

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/screens/business/create_activity_screen.dart
```
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/business/create_activity_screen.dart
git commit -m "feat(business): replace location text field with map picker in create activity"
```

---

### Task 11: Add map section to activity detail screen

**Files:**
- Modify: `lib/screens/user/activity_details_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/screens/user/activity_details_screen.dart`, add:
```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
```

- [ ] **Step 2: Add `_openDirections` method to the screen state or build helper**

Add this method inside `_ActivityDetailsScreenState` (or the widget class if it's stateless — check the file):
```dart
  Future<void> _openDirections(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
```

- [ ] **Step 3: Insert map section after info pills**

Find the comment `// 3. Description` in the scrollable body. Directly before it (after the closing `),` of the Wrap info pills), insert:

```dart
                    // 3. Map (only when coordinates available)
                    if (activity.latitude != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 200,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(activity.latitude!, activity.longitude!),
                              initialZoom: 15,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.hobifi.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(activity.latitude!, activity.longitude!),
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _openDirections(
                            activity.latitude!,
                            activity.longitude!,
                          ),
                          icon: const Icon(Icons.directions_rounded),
                          label: const Text('Get Directions'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
```

Note: Renumber the original `// 3. Description` comment to `// 4. Description` for clarity.

- [ ] **Step 4: Analyze**

```bash
flutter analyze lib/screens/user/activity_details_screen.dart
```
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/user/activity_details_screen.dart
git commit -m "feat(activity): add OSM map and Get Directions button to activity detail screen"
```

---

### Task 12: Add distanceLabel to HobifiCard

**Files:**
- Modify: `lib/widgets/hobifi_card.dart`

- [ ] **Step 1: Add `distanceLabel` parameter**

In the `HobifiCard` class fields, after `final bool featured;`:
```dart
  final String? distanceLabel;
```

In the `const HobifiCard({...})` constructor, after `this.featured = false,`:
```dart
    this.distanceLabel,
```

In the `const HobifiCard.featured({...})` constructor, after `required this.onLikeTap,`:
```dart
    this.distanceLabel,
```
And change `: featured = true;` to `: featured = true, distanceLabel = distanceLabel;` — wait, named constructors need explicit field init. Replace the featured constructor with:
```dart
  const HobifiCard.featured({
    super.key,
    required this.activity,
    required this.isLiked,
    required this.onTap,
    required this.onLikeTap,
    this.distanceLabel,
  }) : featured = true;
```

- [ ] **Step 2: Add distance badge to standard card image stack**

In `_buildStandardCard`, inside the image `Stack`, after the `_LikeButton` positioned widget and after the price badge `Positioned`, add:
```dart
                  // Distance badge — bottom-right of image
                  if (distanceLabel != null)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              distanceLabel!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
```

- [ ] **Step 3: Add distance badge to featured card stack**

In `_buildFeaturedCard`, inside the `Stack`, after the price badge `Positioned`:
```dart
            // Distance badge — bottom-right
            if (distanceLabel != null)
              Positioned(
                bottom: 70,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        distanceLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
```

- [ ] **Step 4: Analyze**

```bash
flutter analyze lib/widgets/hobifi_card.dart
```
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/hobifi_card.dart
git commit -m "feat(card): add optional distance badge to HobifiCard"
```

---

### Task 13: Wire distance into feed screen

**Files:**
- Modify: `lib/screens/user/feed_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/screens/user/feed_screen.dart`, add:
```dart
import 'package:latlong2/latlong.dart';
import 'package:hobby_haven/services/location_service.dart';
import 'package:hobby_haven/utils/distance_util.dart';
```

- [ ] **Step 2: Read user location in `build`**

In `build()`, after `final auth = context.watch<AuthService>();`, add:
```dart
    final userLocation = context.watch<LocationService>().savedLocation;
```

- [ ] **Step 3: Add distance helper method to `_FeedScreenState`**

Add this method to `_FeedScreenState`:
```dart
  String? _distanceLabel(ActivityModel activity, LatLng? userLocation) {
    if (userLocation == null || activity.latitude == null) return null;
    return DistanceUtil.formatDistance(
      userLocation,
      LatLng(activity.latitude!, activity.longitude!),
    );
  }
```

- [ ] **Step 4: Pass distanceLabel to every HobifiCard in the feed**

Search for every `HobifiCard(` and `HobifiCard.featured(` call in `feed_screen.dart`. For each one, add the `distanceLabel` parameter:
```dart
distanceLabel: _distanceLabel(activity, userLocation),
```

- [ ] **Step 5: Run all tests**

```bash
flutter test
```
Expected: All tests pass.

- [ ] **Step 6: Analyze entire project**

```bash
flutter analyze
```
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/user/feed_screen.dart
git commit -m "feat(feed): show distance badge on activity cards using GPS location"
```
