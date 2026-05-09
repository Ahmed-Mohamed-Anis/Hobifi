# Location Feature Design

**Date:** 2026-04-26
**Status:** Approved

## Goal

Add full location awareness to Hobifi: users grant GPS permission during onboarding and see distance-to-activity on feed cards; activity detail screens show an interactive map with a "Get Directions" button; businesses pin their exact location on a map when creating an activity.

---

## Packages

| Package | Version | Purpose |
|---|---|---|
| `geolocator` | ^13.x | Device GPS + permission requests |
| `flutter_map` | ^7.x | OSM map tile rendering |
| `latlong2` | ^0.9.x | `LatLng` type used by flutter_map |
| `url_launcher` | latest | Open Google/Apple Maps deep links |

Address search and reverse geocoding use **Nominatim** (OSM's free REST API) via the existing `http` package — no API key, no billing, restricted to Egypt via `countrycodes=eg`.

---

## Architecture

### New Files

| File | Responsibility |
|---|---|
| `lib/services/location_service.dart` | Permission requests, GPS reads, SharedPreferences persistence |
| `lib/utils/distance_util.dart` | Haversine distance calculation + formatting |
| `lib/widgets/location_picker.dart` | Reusable full-screen map picker (search + drag pin) |

### Modified Files

| File | Change |
|---|---|
| `lib/models/activity_model.dart` | Add nullable `latitude: double?`, `longitude: double?` |
| `lib/screens/onboarding_screen.dart` | Step 2: add "Use my location" button + confirmation chip |
| `lib/screens/user/activity_details_screen.dart` | Add map section + "Get Directions" button |
| `lib/screens/business/create_activity_screen.dart` | Replace text location field with location picker row |
| `lib/widgets/hobifi_card.dart` | Add optional `distanceLabel: String?` parameter |
| `lib/screens/user/feed_screen.dart` | Compute + pass distance labels to cards |
| `pubspec.yaml` | Add 3 new packages |
| `android/app/src/main/AndroidManifest.xml` | Add location permissions |
| `ios/Runner/Info.plist` | Add `NSLocationWhenInUseUsageDescription` |

### New Migration

`supabase/migrations/20260426000000_add_activity_coordinates.sql`:
```sql
ALTER TABLE activities
  ADD COLUMN latitude  DOUBLE PRECISION,
  ADD COLUMN longitude DOUBLE PRECISION;
```

---

## Data Model

### ActivityModel

```dart
final double? latitude;
final double? longitude;
```

Both nullable. `fromJson` reads them as `(json['latitude'] as num?)?.toDouble()`. Activities without coordinates degrade gracefully — no map shown, no distance badge.

### User Location Storage

Stored in `SharedPreferences` under keys `user_lat` and `user_lng` as doubles. Not stored in Supabase. Refreshed on each successful GPS read.

---

## LocationService

```dart
class LocationService extends ChangeNotifier {
  LatLng? savedLocation;

  Future<bool> requestPermission();
  Future<LatLng?> getCurrentLocation(); // requests, saves, notifies
  void loadSavedLocation();             // reads from SharedPreferences on init
}
```

Registered as a `ChangeNotifierProvider` alongside other services. `loadSavedLocation()` called at app start so `savedLocation` is available immediately.

---

## DistanceUtil

```dart
// lib/utils/distance_util.dart
String? formatDistance(LatLng from, LatLng? to);
// Returns "2.3 km" (< 10 km) or "12 km" (≥ 10 km). Returns null if `to` is null.
```

Uses the Haversine formula. Pure function — no dependencies, easily tested.

---

## Feature 1: Onboarding Location Permission

**Location:** `lib/screens/onboarding_screen.dart` — Step 2 (city/location step)

**UI (top to bottom in step 2):**
1. "Use my location →" `TextButton` (lime accent, centered)
2. `OR` divider
3. Existing city text input

**Flow:**
- Tap "Use my location →" → call `LocationService.requestPermission()`
  - Denied → show snackbar "Location access denied — enter your city manually"
  - Granted → call `getCurrentLocation()` → replace both button and text field with a confirmation chip: `📍 Location detected` (lime, with "Change" link to revert)
- Skip entirely → no coordinates saved → distance omitted from feed

**Native permission strings:**

`AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

`Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Hobifi uses your location to show activities near you.</string>
```

---

## Feature 2: Activity Detail Map

**Location:** `lib/screens/user/activity_details_screen.dart`

**Rendered only when `activity.latitude != null`.**

**Layout (inserted below info pills row):**
```
[ flutter_map — height 200, borderRadius 16 ]
[ "Get Directions" button — full width, outlined, 48px ]
```

Map properties:
- Center: `LatLng(activity.latitude!, activity.longitude!)`
- Zoom: 15
- `interactionOptions: InteractionOptions(flags: InteractiveFlag.none)` — non-interactive preview
- Single `Marker` pin at activity coordinates

**"Get Directions" URL:**
```
https://www.google.com/maps/search/?api=1&query=LAT,LON
```
Opens Google Maps on Android; on iOS opens Google Maps if installed, otherwise Apple Maps. Launched via `url_launcher`.

**Graceful degradation:**
- No lat/lng → map section hidden entirely, existing location text pill unchanged
- Tile load failure → grey container with centered location text

---

## Feature 3: Business Location Picker

**Entry point:** `lib/screens/business/create_activity_screen.dart`

The text location field is replaced by a tappable row:
```
[ 📍 icon ]  [ "Tap to set location" or displayAddress ]  [ › ]
```
Tapping pushes `LocationPickerWidget` as a full-screen route.

### LocationPickerWidget (`lib/widgets/location_picker.dart`)

**Layout:**
```
[ AppBar: "Set Location" + Confirm button ]
[ Search bar: "Search address..." ]
[ Dropdown results (shown while searching) ]
[ flutter_map fills remaining height ]
[ Fixed crosshair pin at map center ]
```

**Interaction:**
1. Type address → 500ms debounce → `GET https://nominatim.openstreetmap.org/search?q=QUERY&format=json&limit=5&countrycodes=eg`
2. Tap result → map pans to coordinates, dropdown closes
3. Drag map to fine-tune — pin stays fixed at center (crosshair pattern)
4. Tap "Confirm" → reverse geocode map center via `GET https://nominatim.openstreetmap.org/reverse?lat=LAT&lon=LON&format=json` → pop with result

**Return value:**
```dart
record (double latitude, double longitude, String displayAddress)
```

`create_activity_screen.dart` stores `latitude` and `longitude` as separate state variables submitted with the form. The visible location row shows `displayAddress`.

---

## Feature 4: Distance on Feed Cards

**`HobifiCard` change:**
```dart
final String? distanceLabel; // e.g. "2.3 km" — optional, shows badge if non-null
```

Distance badge: small pill at bottom-left of card image. Style matches existing chips (indigo background, white text, pill radius).

**Feed screen computation:**
```dart
final userLoc = context.read<LocationService>().savedLocation;
// Per activity:
final distLabel = DistanceUtil.formatDistance(
  userLoc,
  activity.latitude != null ? LatLng(activity.latitude!, activity.longitude!) : null,
);
// Pass distLabel to HobifiCard
```

Cards for activities without coordinates receive `null` → badge absent. No sorting by distance in this version — informational only.

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| Location permission denied | Snackbar + fall back to city text field |
| GPS timeout / unavailable | `getCurrentLocation()` returns null, no coordinates saved |
| Nominatim search fails | Show "No results found" in dropdown |
| Nominatim reverse geocode fails | Use `"LAT, LON"` as fallback display address |
| Map tiles fail to load | Grey container fallback |
| Activity has no coordinates | All location UI hidden gracefully |
