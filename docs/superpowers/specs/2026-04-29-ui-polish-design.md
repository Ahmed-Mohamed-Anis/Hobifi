# UI Polish — Design Spec
**Date:** 2026-04-29

## Overview

Eight targeted UI improvements across the nav bar, feed, and My Hobbies tab. All changes are client-side only — no schema or API changes required.

---

## 1. Footer: Icons Only

**File:** `lib/nav.dart` — `_UserShellScreen` and `_BusinessShellScreen`

Change `NavigationBar.labelBehavior` from `alwaysShow` to `alwaysHide` on both shells. Reduce `height` from `68` to `56`. Flutter hides the label text automatically; no label strings need to be removed from `NavigationDestination`.

---

## 2. Logo — Bigger & Closer to "Discover"

**File:** `lib/screens/user/feed_screen.dart` — `_MinimalHeader`

- Increase logo `height` from `70` to `90`
- Set `fit: BoxFit.fitHeight`
- Remove the `SizedBox(height: 4)` between logo and "Discover" text

The larger render height combined with zero gap pushes the wordmark visually flush against the section title.

---

## 3. Liked Tab — Compact Horizontal Cards

**File:** `lib/screens/user/saved_screen.dart`

The Liked tab (`SavedContent`) currently uses `HobifiCard` (tall vertical card). Replace with a new private widget `_ActivityCompactCard` defined in the same file.

`_ActivityCompactCard` layout mirrors `BookingCard` from `bookings_screen.dart`:
- 80×80 `CachedNetworkImage` thumbnail, `borderRadius: 12`, left-aligned
- Right column: title (`titleSmall`, bold, 1 line), date (`bodySmall`, muted), location with pin icon (`bodySmall`, muted)
- Full-width tap → `context.push('${AppRoutes.activity}/${activity.id}')`
- Like button (heart icon) in top-right corner using `LikeService.toggleLike`

---

## 4. Remove Completed Bookings from Upcoming

**File:** `lib/screens/user/bookings_screen.dart` — `_BookingsScreenState.build`

Change the `upcomingBookings` filter (lines 55–58) to include only `BookingStatus.confirmed`. Remove `BookingStatus.completed` from the predicate. The subtitle count updates automatically.

`pending` was not in the original filter and is not added — the Upcoming tab shows only confirmed bookings.

---

## 5. Trending Experiences — Highest Rated

**File:** `lib/screens/user/feed_screen.dart` — `_buildDiscoveryFeed`

Replace `activities.take(3)` with:
1. Filter: `reviewCount > 0`
2. Sort: `rating` descending
3. Take top 3
4. Fallback: if fewer than 3 results, pad with activities sorted by `spotsLeft` descending (availability signal)

---

## 6. Popular Near You — Closest to User

**File:** `lib/screens/user/feed_screen.dart` — `_buildDiscoveryFeed`

Replace `activities.skip(1).take(4)` with:
- When `userLocation != null`: sort by distance ascending using `DistanceUtil`, take top 4
- When `userLocation == null`: keep current fallback (`skip(1).take(4)`)

Both `LocationService` and `DistanceUtil` are already imported and in scope.

---

## 7. Weekend Adventures → Friday & Saturday

**File:** `lib/screens/user/feed_screen.dart` — `_buildDiscoveryFeed`

Replace `a.spotsLeft > 5` filter with:
```dart
a.dateTime.weekday == DateTime.friday || a.dateTime.weekday == DateTime.saturday
```

Update section header title to `'Friday & Saturday'` and subtitle to `'Activities this weekend'`. Section is already hidden when list is empty — no change needed there.

---

## 8. "Explore More" — Section Explore Screen

### Section headers

Each `HobifiSectionHeader` in `_buildDiscoveryFeed` gets:
```dart
actionLabel: 'Explore more',
onAction: () => context.push(
  AppRoutes.sectionExplore,
  extra: {'title': '...', 'subtitle': '...', 'filterSort': _filterFnForSection},
),
```

### New route

**File:** `lib/nav.dart` — add to root navigator routes (outside shell, no bottom nav):
```dart
GoRoute(
  path: AppRoutes.sectionExplore,
  name: 'section-explore',
  parentNavigatorKey: _rootNavigatorKey,
  pageBuilder: (context, state) {
    final extra = state.extra as Map<String, dynamic>;
    return _buildSmoothTransition(
      child: SectionExploreScreen(
        title: extra['title'],
        subtitle: extra['subtitle'],
        filterSort: extra['filterSort'],
      ),
      state: state,
    );
  },
)
```

Add `static const String sectionExplore = '/section-explore';` to `AppRoutes`.

### `SectionExploreScreen`

**File:** `lib/screens/user/section_explore_screen.dart` (new file)

**Constructor:**
```dart
SectionExploreScreen({
  required String title,
  required String subtitle,
  required List<ActivityModel> Function(List<ActivityModel> all, String category, LatLng? userLocation) filterSort,
})
```

**Layout:**
- `Scaffold` with `SafeArea`
- Header row: back button (`context.pop()`) + title text
- `HobifiSearchBar` (extracted from `feed_screen.dart` — see "Making `_MinimalSearchBar` reusable" below)
- Category chips row (same 7 categories: All, Art, Sports, Music, Cooking, Tech, Outdoor)
- `Expanded` `ListView` of `HobifiCard` items — result of `filterSort(allActivities, selectedCategory, userLocation)` filtered further by search query client-side

**State:**
- `_selectedCategory` (default `'All'`)
- `_searchQuery` with debounce (same pattern as `FeedScreen`)
- Watches `ActivityService`, `LikeService`, `LocationService`, `AuthService`

**Empty state:** `HobifiEmptyState` with icon `Icons.search_off_rounded`.

### Making `_MinimalSearchBar` reusable

Move `_MinimalSearchBar` from `feed_screen.dart` to `lib/widgets/hobifi_search_bar.dart` as a public `HobifiSearchBar` widget. Update `feed_screen.dart` to import and use `HobifiSearchBar`.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/nav.dart` | Icons-only footer, new `sectionExplore` route + `AppRoutes` constant |
| `lib/screens/user/feed_screen.dart` | Logo fix, trending/nearby/weekend logic, "Explore more" actions, use `HobifiSearchBar` |
| `lib/screens/user/bookings_screen.dart` | Remove `completed` from Upcoming filter |
| `lib/screens/user/saved_screen.dart` | Replace `HobifiCard` with `_ActivityCompactCard` in Liked tab |
| `lib/screens/user/section_explore_screen.dart` | New file — section explore screen |
| `lib/widgets/hobifi_search_bar.dart` | New file — extracted `HobifiSearchBar` widget |
