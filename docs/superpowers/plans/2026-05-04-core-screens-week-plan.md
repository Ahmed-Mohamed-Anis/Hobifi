# Core Screens Week Plan — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all 7 features from the 2026-05-04 core screens spec: auth OTP polish + silent re-auth, feed filter improvements + search history, dashboard booking management + activity performance sort + analytics chart tabs + notification inbox.

**Architecture:** Tasks 1–3 (auth + feed) are independent and can be done in any order. Dashboard tasks 4–7 all modify `dashboard_screen.dart` — do them in sequence. Task 7 (notification inbox) requires a SQL migration and edge function update in addition to Dart.

**Tech Stack:** Flutter/Dart, Provider, GoRouter, Supabase client, SharedPreferences, fl_chart 0.68.0, geolocator 13.x, cached_network_image

---

### Task 1: Auth — OTP Error Clear + Silent Re-auth

**Files:**
- Modify: `lib/screens/auth_screen.dart` (line 436–438)
- Modify: `lib/services/auth_service.dart` (lines 11–49)
- Modify: `lib/nav.dart` (line 76)

- [ ] **Step 1: Clear SnackBars on OTP input change**

In `lib/screens/auth_screen.dart`, find the OTP TextField `onChanged` at line 436:

```dart
// before
onChanged: (val) {
  if (val.length == 6) _handleVerifyEmail();
},

// after
onChanged: (val) {
  ScaffoldMessenger.of(context).clearSnackBars();
  if (val.length == 6) _handleVerifyEmail();
},
```

- [ ] **Step 2: Add `_isInitializing` field + getter to `AuthService`**

In `lib/services/auth_service.dart`, after line 13 (`bool _suppressAuthListener = false;`), add:

```dart
bool _isInitializing = false;
```

After line 18 (`bool get isAuthenticated => _currentUser != null;`), add:

```dart
bool get isInitializing => _isInitializing;
```

- [ ] **Step 3: Set `_isInitializing` in `initialize()`**

In `lib/services/auth_service.dart`, inside `initialize()`. Change the block starting at line 24:

```dart
// before
_isLoading = true;
_safeNotify();

// after
_isInitializing = true;
_isLoading = true;
_safeNotify();
```

In the `finally` block (around line 46), change:

```dart
// before
_isLoading = false;
_safeNotify();

// after
_isLoading = false;
_isInitializing = false;
_safeNotify();
```

- [ ] **Step 4: Guard redirect in `nav.dart`**

In `lib/nav.dart`, inside the `redirect` callback (line 76). Insert one line at the very top of the callback body:

```dart
redirect: (context, state) {
  if (authService.isInitializing) return null;   // ← add this line
  final isAuthenticated = authService.isAuthenticated;
  // ... rest unchanged
```

- [ ] **Step 5: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: 0 new errors.

- [ ] **Step 6: Manual test — OTP error clearing**

1. Sign up with a fresh email → OTP screen appears
2. Tap Verify without entering a code → error SnackBar appears
3. Type any digit → SnackBar disappears immediately

- [ ] **Step 7: Manual test — silent re-auth**

1. Sign in and background the app fully (swipe away from app switcher)
2. Relaunch → should land directly on feed/dashboard without flashing the auth screen

- [ ] **Step 8: Commit**

```bash
git add lib/screens/auth_screen.dart lib/services/auth_service.dart lib/nav.dart
git commit -m "feat(auth): clear OTP errors on input, fix cold-launch auth flash via isInitializing"
```

---

### Task 2: Feed — Filter Fixes

**Files:**
- Modify: `lib/utils/feed_filters.dart` (lines 16–31 and 41)
- Modify: `lib/screens/user/feed_screen.dart` (Popular section, lines 432–449)

- [ ] **Step 1: Update `trendingFilterSort` — 5 items, pad by `createdAt` desc**

In `lib/utils/feed_filters.dart`, replace lines 16–32 entirely:

```dart
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
```

- [ ] **Step 2: Update `nearbyFilterSort` — return empty list when location is null**

In `lib/utils/feed_filters.dart`, line 41. Replace:

```dart
// before
if (userLocation == null) return filtered.take(4).toList();

// after
if (userLocation == null) return [];
```

- [ ] **Step 3: Add `geolocator` import to `feed_screen.dart`**

In `lib/screens/user/feed_screen.dart`, add import after line 15 (`import 'package:hobby_haven/services/location_service.dart';`):

```dart
import 'package:geolocator/geolocator.dart';
```

- [ ] **Step 4: Replace Popular section content with conditional empty state**

In `lib/screens/user/feed_screen.dart`, inside `_buildDiscoveryFeed()`, replace lines 432–449 (the `Padding` with `Column` of `popularActivities.map`). The HobifiSectionHeader stays; replace only the content below it:

```dart
// after the HobifiSectionHeader for 'Popular Near You', replace
// the Padding(child: Column(children: popularActivities.map...))
// with:

if (userLocation == null)
  Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: HobifiEmptyState(
      icon: Icons.location_off_rounded,
      title: 'Enable location to see activities near you',
      actionLabel: 'Enable Location',
      onAction: () => Geolocator.openAppSettings(),
    ),
  )
else
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: popularActivities.map((activity) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: HobifiCard(
          activity: activity,
          isLiked: likeService.isLiked(activity.id),
          onTap: () => context.push('${AppRoutes.activity}/${activity.id}'),
          onLikeTap: () {
            final userId = auth.currentUser?.id;
            if (userId != null) likeService.toggleLike(userId, activity.id);
          },
          distanceLabel: _distanceLabel(activity, userLocation),
        ),
      )).toList(),
    ),
  ),
```

- [ ] **Step 5: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 6: Manual test**

1. Revoke location permission in device Settings → open app → Popular Near You shows empty state with "Enable Location" button
2. Tap "Enable Location" → device Settings open
3. Grant location → restart → popular activities appear sorted nearest first
4. Trending section shows up to 5 cards

- [ ] **Step 7: Commit**

```bash
git add lib/utils/feed_filters.dart lib/screens/user/feed_screen.dart
git commit -m "feat(feed): expand trending to 5 items, show location empty state in popular"
```

---

### Task 3: Feed — Search History + Suggested Searches

**Files:**
- Modify: `lib/widgets/hobifi_search_bar.dart` (add `onFocusChange` + `onSubmitted`)
- Modify: `lib/screens/user/feed_screen.dart` (history state + chip UI)

- [ ] **Step 1: Add callbacks to `HobifiSearchBar`**

In `lib/widgets/hobifi_search_bar.dart`, update the widget class fields (add two optional callbacks):

```dart
class HobifiSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<String>? onSubmitted;

  const HobifiSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.onFocusChange,
    this.onSubmitted,
  });

  @override
  State<HobifiSearchBar> createState() => _HobifiSearchBarState();
}
```

In `_HobifiSearchBarState.initState()`, update the focus listener:

```dart
_focusNode.addListener(() {
  setState(() => _isFocused = _focusNode.hasFocus);
  widget.onFocusChange?.call(_focusNode.hasFocus);
});
```

In `build()`, add `onSubmitted` to the `TextField` (after `onChanged: widget.onChanged,`):

```dart
onSubmitted: widget.onSubmitted,
```

- [ ] **Step 2: Add state fields to `_FeedScreenState`**

In `lib/screens/user/feed_screen.dart`, after `final ScrollController _scrollController = ScrollController();` add:

```dart
List<String> _searchHistory = [];
bool _searchFocused = false;

static const _historyKey = 'search_history';
static const _suggestions = ['Pottery', 'Yoga', 'Cooking class', 'Photography'];
```

Add `shared_preferences` import:

```dart
import 'package:shared_preferences/shared_preferences.dart';
```

- [ ] **Step 3: Add history load/save/remove methods**

Add these three methods to `_FeedScreenState`:

```dart
Future<void> _loadSearchHistory() async {
  final prefs = await SharedPreferences.getInstance();
  if (mounted) setState(() => _searchHistory = prefs.getStringList(_historyKey) ?? []);
}

Future<void> _saveSearchTerm(String term) async {
  final trimmed = term.trim();
  if (trimmed.isEmpty) return;
  final updated = [trimmed, ..._searchHistory.where((t) => t != trimmed)].take(5).toList();
  setState(() => _searchHistory = updated);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_historyKey, updated);
}

Future<void> _removeSearchTerm(String term) async {
  final updated = _searchHistory.where((t) => t != term).toList();
  setState(() => _searchHistory = updated);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_historyKey, updated);
}
```

- [ ] **Step 4: Load history in `initState` + wire search bar callbacks**

In `initState()`, after `_scrollController.addListener(_onScroll);`, add:

```dart
_loadSearchHistory();
```

In `build()`, update the `HobifiSearchBar` usage:

```dart
child: HobifiSearchBar(
  controller: _searchController,
  onChanged: _onSearchChanged,
  onClear: () {
    _searchController.clear();
    _onSearchChanged('');
  },
  onFocusChange: (focused) => setState(() => _searchFocused = focused),
  onSubmitted: (term) {
    if (term.trim().isNotEmpty) _saveSearchTerm(term.trim());
  },
),
```

- [ ] **Step 5: Insert chips sliver between search bar and category chips**

In `build()` inside the `CustomScrollView.slivers` list, add a new entry between the search bar `SliverToBoxAdapter` (item 2) and the category chips `SliverToBoxAdapter` (item 3):

```dart
// Search history / suggested chips — shown when search bar is focused and query is empty
if (_searchFocused && _searchQuery.isEmpty)
  SliverToBoxAdapter(child: _buildSearchChips()),
```

- [ ] **Step 6: Add `_buildSearchChips()` method**

Add this method to `_FeedScreenState`:

```dart
Widget _buildSearchChips() {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final chips = _searchHistory.isNotEmpty ? _searchHistory : _suggestions;
  final label = _searchHistory.isNotEmpty ? 'Recent' : 'Popular';

  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((term) {
            return InputChip(
              label: Text(term),
              onPressed: () {
                _searchController.text = term;
                _onSearchChanged(term);
                _saveSearchTerm(term);
              },
              onDeleted: _searchHistory.isNotEmpty ? () => _removeSearchTerm(term) : null,
              deleteIcon: _searchHistory.isNotEmpty
                  ? Icon(Icons.close_rounded,
                      size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5))
                  : null,
              backgroundColor: colorScheme.surface,
              side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
              labelStyle: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
            );
          }).toList(),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 7: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 8: Manual test**

1. Tap search bar with no history → "Popular" chips appear: Pottery, Yoga, Cooking class, Photography
2. Tap a chip → search bar fills and search fires
3. Submit a search manually → tap away → tap search bar → that term appears under "Recent"
4. Tap `×` on a Recent chip → chip disappears
5. Search 6 different terms → confirm only 5 most recent are shown

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/hobifi_search_bar.dart lib/screens/user/feed_screen.dart
git commit -m "feat(feed): add search history and suggested search chips"
```

---

### Task 4: Dashboard — Booking Management Screen

**Files:**
- Create: `lib/screens/business/business_bookings_screen.dart`
- Modify: `lib/nav.dart` (new route + AppRoutes constant)
- Modify: `lib/services/booking_service.dart` (alias method)
- Modify: `lib/screens/business/dashboard_screen.dart` (add CTA)

- [ ] **Step 1: Add `loadBusinessBookingsAll()` alias to `BookingService`**

In `lib/services/booking_service.dart`, after the closing `}` of `loadBusinessBookings()` (around line 176), add:

```dart
/// Force-refresh all business bookings. Called by the booking management screen.
Future<void> loadBusinessBookingsAll(String businessId) async {
  await loadBusinessBookings(businessId);
}
```

- [ ] **Step 2: Add route constant to `AppRoutes` in `nav.dart`**

In `lib/nav.dart` inside `class AppRoutes`, after `sectionExplore`:

```dart
static const String businessBookings = '/business-bookings';
```

- [ ] **Step 3: Add import + GoRoute in `nav.dart`**

Add import at the top of `lib/nav.dart` (with the other business screen imports):

```dart
import 'package:hobby_haven/screens/business/business_bookings_screen.dart';
```

Add the route in the GoRouter `routes` list (after the existing `sectionExplore` GoRoute):

```dart
GoRoute(
  path: AppRoutes.businessBookings,
  name: 'business-bookings',
  parentNavigatorKey: _rootNavigatorKey,
  pageBuilder: (context, state) => _buildSmoothTransition(
    child: const BusinessBookingsScreen(),
    state: state,
  ),
),
```

- [ ] **Step 4: Add "All Bookings" CTA in dashboard**

In `lib/screens/business/dashboard_screen.dart`, in the `build()` method's Column children, after the Today's Schedule section (after the closing `],` of `if (userId != null && todayBookings.isNotEmpty) ...[`), add:

```dart
// ── All Bookings CTA ────────────────────────────────
if (userId != null)
  Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: OutlinedButton.icon(
      onPressed: () => context.push(AppRoutes.businessBookings),
      icon: const Icon(Icons.calendar_month_rounded, size: 18),
      label: const Text('All Bookings'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  ),
```

- [ ] **Step 5: Create `lib/screens/business/business_bookings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';

class BusinessBookingsScreen extends StatefulWidget {
  const BusinessBookingsScreen({super.key});

  @override
  State<BusinessBookingsScreen> createState() => _BusinessBookingsScreenState();
}

class _BusinessBookingsScreenState extends State<BusinessBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabLabels = ['All', 'Confirmed', 'Pending', 'Completed', 'Cancelled'];
  static const _statusFilters = [
    null,
    BookingStatus.confirmed,
    BookingStatus.pending,
    BookingStatus.completed,
    BookingStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthService>().currentUser?.id;
      if (userId != null) {
        context.read<BookingService>().loadBusinessBookingsAll(userId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BookingModel> _filtered(List<BookingModel> all, BookingStatus? status) =>
      status == null ? all : all.where((b) => b.status == status).toList();

  void _showDetail(BuildContext context, BookingModel booking) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Booking Detail',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _DetailRow(label: 'Activity', value: booking.activityTitle),
              _DetailRow(
                label: 'Date & Time',
                value: DateFormat('EEE, MMM d y · h:mm a').format(booking.dateTime),
              ),
              _DetailRow(label: 'Amount', value: 'EGP ${booking.price.toStringAsFixed(2)}'),
              _DetailRow(
                label: 'Booking Code',
                value: '#${booking.id.substring(0, 8).toUpperCase()}',
              ),
              _DetailRow(label: 'Status', value: booking.status.name.toUpperCase()),
              _DetailRow(
                label: 'Booked on',
                value: DateFormat('MMM d, y').format(booking.createdAt),
              ),
              if (booking.status == BookingStatus.confirmed) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await context.read<BookingService>().cancelBookingBusiness(booking.id);
                      final userId = context.read<AuthService>().currentUser?.id;
                      if (userId != null && context.mounted) {
                        context.read<BookingService>().loadBusinessBookingsAll(userId);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel Booking'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookingService = context.watch<BookingService>();
    final allBookings = bookingService.businessBookings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bookings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
        ),
      ),
      body: bookingService.isLoading && allBookings.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: List.generate(5, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HobifiShimmer.listTile(),
                )),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: List.generate(_statusFilters.length, (i) {
                final items = _filtered(allBookings, _statusFilters[i]);
                if (items.isEmpty) {
                  return HobifiEmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No ${_statusFilters[i]?.name ?? ''} bookings',
                    subtitle: _statusFilters[i] == null
                        ? 'Bookings appear here after guests book your activities.'
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    final userId = context.read<AuthService>().currentUser?.id;
                    if (userId != null) {
                      await context.read<BookingService>().loadBusinessBookingsAll(userId);
                    }
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final b = items[idx];
                      return _BookingRow(booking: b, onTap: () => _showDetail(context, b));
                    },
                  ),
                );
              }),
            ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onTap;

  const _BookingRow({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = switch (booking.status) {
      BookingStatus.confirmed => colorScheme.primary,
      BookingStatus.completed => const Color(0xFF9BC53D),
      BookingStatus.cancelled => colorScheme.error,
      BookingStatus.pending => const Color(0xFFE88B3C),
    };

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: booking.activityImage,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => HobifiShimmer.box(56, 56),
                  errorWidget: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.image_rounded, color: colorScheme.outline),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.activityTitle,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d · h:mm a').format(booking.dateTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'EGP ${booking.price.toStringAsFixed(0)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      booking.status.name,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 7: Manual test**

1. Open dashboard → "All Bookings" button appears below Today's Schedule section
2. Tap it → BookingsManagement screen opens with 5 filter tabs
3. Tabs filter correctly (Confirmed shows only confirmed bookings, etc.)
4. Tap a booking row → bottom sheet opens with booking details
5. Pull-to-refresh works on each tab
6. Empty state shows when a tab has no bookings

- [ ] **Step 8: Commit**

```bash
git add lib/screens/business/business_bookings_screen.dart lib/nav.dart \
    lib/services/booking_service.dart lib/screens/business/dashboard_screen.dart
git commit -m "feat(dashboard): add booking management screen with status filter tabs"
```

---

### Task 5: Dashboard — Activity Performance Sort Controls

**Files:**
- Modify: `lib/screens/business/dashboard_screen.dart` (state, data class, card widget)

- [ ] **Step 1: Add sort state to `_DashboardScreenState`**

In `lib/screens/business/dashboard_screen.dart`, in `_DashboardScreenState` fields after `int _selectedDays = 7;`, add:

```dart
String _activitySortBy = 'revenue'; // 'revenue' | 'bookings' | 'fillRate'
```

- [ ] **Step 2: Add sort helper method to `_DashboardScreenState`**

Add this method to `_DashboardScreenState`:

```dart
List<dynamic> _sortedActivities(
  List activities,
  Map<String, _PerActivityStats> agg,
) {
  final sorted = List.from(activities);
  switch (_activitySortBy) {
    case 'revenue':
      sorted.sort((a, b) =>
          (agg[b.id]?.revenue ?? 0).compareTo(agg[a.id]?.revenue ?? 0));
    case 'bookings':
      sorted.sort((a, b) =>
          (agg[b.id]?.bookings ?? 0).compareTo(agg[a.id]?.bookings ?? 0));
    case 'fillRate':
      double rate(a) =>
          a.maxGuests > 0 ? (a.maxGuests - a.spotsLeft) / a.maxGuests : 0.0;
      sorted.sort((a, b) => rate(b).compareTo(rate(a)));
  }
  return sorted;
}
```

- [ ] **Step 3: Update `_ActivityBreakdownCard` to accept `imageUrl` and `avgRating`**

In `lib/screens/business/dashboard_screen.dart`, update the `_ActivityBreakdownCard` class (around line 1400):

```dart
class _ActivityBreakdownCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final int bookings;
  final double revenue;
  final double fillRate;
  final double avgRating;
  final VoidCallback? onTap;

  const _ActivityBreakdownCard({
    required this.title,
    this.imageUrl,
    required this.bookings,
    required this.revenue,
    required this.fillRate,
    required this.avgRating,
    this.onTap,
  });
```

In the `build()` of `_ActivityBreakdownCard`, update the Row in the card to show thumbnail and rating. Replace the existing `Column` content:

```dart
child: Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    // Thumbnail
    if (imageUrl != null)
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: 52, height: 52, fit: BoxFit.cover,
          placeholder: (_, __) => HobifiShimmer.box(52, 52),
          errorWidget: (_, __, ___) => Container(
            width: 52, height: 52,
            color: colorScheme.surfaceContainerHighest,
            child: Icon(Icons.image_rounded, color: colorScheme.outline, size: 20),
          ),
        ),
      ),
    if (imageUrl != null) const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('EGP ${revenue.toStringAsFixed(0)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.confirmation_number_outlined, size: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 3),
              Text('$bookings bookings',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5))),
              const Spacer(),
              if (avgRating > 0) ...[
                Icon(Icons.star_rounded, size: 13, color: colorScheme.tertiary),
                const SizedBox(width: 2),
                Text(avgRating.toStringAsFixed(1),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
              ] else ...[
                Text('${(fillRate * 100).toStringAsFixed(0)}% full',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: fillRate,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: colorScheme.outline.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9BC53D)),
            minHeight: 6,
          ),
        ],
      ),
    ),
  ],
),
```

Add `cached_network_image` import at the top of `dashboard_screen.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
```

- [ ] **Step 4: Add sort control tabs above the activities list + remove 3-item cap**

In `build()`, in the Per-Activity Breakdown section (around line 958), replace `HobifiSectionHeader` with the section header + sort tabs, and update the `FutureBuilder` to use `_sortedActivities` instead of `businessActivities.take(3)`.

Replace the section from `HobifiSectionHeader(title: 'Your Activities',...)` through the `FutureBuilder`:

```dart
// ── Per-Activity Breakdown ───────────────────────────
if (userId != null) ...[
  HobifiSectionHeader(
    title: 'Your Activities',
    onSeeAll: businessActivities.isEmpty
        ? null
        : () => context.push(AppRoutes.businessCreateActivity),
  ),
  // Sort control tabs
  if (businessActivities.isNotEmpty)
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          for (final entry in {
            'revenue': 'Revenue',
            'bookings': 'Bookings',
            'fillRate': 'Fill Rate',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: HobifiChip(
                label: entry.value,
                isSelected: _activitySortBy == entry.key,
                onTap: () => setState(() => _activitySortBy = entry.key),
              ),
            ),
        ],
      ),
    ),
  if (businessActivities.isEmpty)
    _buildEmptyActivitiesCTA(context)
  else
    FutureBuilder<Map<String, _PerActivityStats>>(
      future: _perActivityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HobifiShimmer(
                      width: double.infinity, height: 100, borderRadius: 16),
                ),
              ),
            ),
          );
        }
        final agg = snapshot.data ?? const <String, _PerActivityStats>{};
        final activitiesToShow = _sortedActivities(businessActivities, agg);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: activitiesToShow.map((activity) {
              final stats = agg[activity.id];
              final fillRate = activity.maxGuests > 0
                  ? ((activity.maxGuests - activity.spotsLeft) /
                          activity.maxGuests)
                      .clamp(0.0, 1.0)
                  : 0.0;
              return _ActivityBreakdownCard(
                title: activity.title,
                imageUrl: activity.imageUrl,
                bookings: stats?.bookings ?? 0,
                revenue: stats?.revenue ?? 0.0,
                fillRate: fillRate,
                avgRating: stats?.avgRating ?? 0.0,
                onTap: () {
                  final loc = context.namedLocation(
                    'business-activity',
                    pathParameters: {'id': activity.id},
                  );
                  context.push(loc);
                },
              );
            }).toList(),
          ),
        );
      },
    ),
],
```

- [ ] **Step 5: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 6: Manual test**

1. Open dashboard → Your Activities section shows all activities (no 3-item cap)
2. Sort tabs appear: Revenue / Bookings / Fill Rate
3. Tapping "Bookings" re-orders by booking count
4. Each card shows thumbnail + fill rate progress bar + star rating (or fill %)
5. Tapping a card still navigates to ActivityManageScreen

- [ ] **Step 7: Commit**

```bash
git add lib/screens/business/dashboard_screen.dart
git commit -m "feat(dashboard): activity performance sort tabs, thumbnail, rating, remove cap"
```

---

### Task 6: Dashboard — Analytics Chart Tabs

**Files:**
- Modify: `lib/screens/business/dashboard_screen.dart`

- [ ] **Step 1: Add chart type state + new futures to `_DashboardScreenState`**

In `_DashboardScreenState` fields, after `int _selectedDays = 7;`, add:

```dart
String _chartType = 'revenue'; // 'revenue' | 'bookings' | 'fillRate'
Future<List<_DailyRevenue>>? _bookingsFuture;
Future<List<_DailyRevenue>>? _fillRateFuture;
```

Update `_initDashboard()` to also init the new futures:

```dart
void _initDashboard(String businessId) {
  _statsFuture = _fetchStats(businessId);
  _revenueFuture = _fetchRevenueChart(businessId);
  _bookingsFuture = _fetchBookingsChart(businessId);
  _fillRateFuture = _fetchFillRateChart(businessId);
  _perActivityFuture = _fetchPerActivityStats(businessId);
  _earningsFuture = _fetchEarningsHistory(businessId);
}
```

- [ ] **Step 2: Add `_fetchBookingsChart()` method**

Add after `_generateEmptyDays()`:

```dart
Future<List<_DailyRevenue>> _fetchBookingsChart(String businessId) async {
  try {
    final acts = await SupabaseService.select('activities',
        select: 'id', filters: {'business_id': businessId});
    final activityIds =
        acts.map((e) => e['id'] as String).whereType<String>().toList();
    if (activityIds.isEmpty) return _generateEmptyDays();

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _selectedDays - 1));

    final rows = await SupabaseService.from('bookings')
        .select('created_at')
        .inFilter('activity_id', activityIds)
        .inFilter('status', ['confirmed', 'completed'])
        .gte('created_at', startDate.toIso8601String()) as List<dynamic>;

    final Map<String, double> dailyCounts = {};
    for (int i = 0; i < _selectedDays; i++) {
      final day = DateTime(startDate.year, startDate.month, startDate.day)
          .add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      dailyCounts[key] = 0.0;
    }

    for (final row in rows) {
      final d = DateTime.parse(row['created_at'] as String);
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (dailyCounts.containsKey(key)) dailyCounts[key] = dailyCounts[key]! + 1;
    }

    final sortedKeys = dailyCounts.keys.toList()..sort();
    return sortedKeys.asMap().entries.map((entry) {
      final date = DateTime.parse(entry.value);
      return _DailyRevenue(
          dayIndex: entry.key,
          amount: dailyCounts[entry.value] ?? 0.0,
          date: date);
    }).toList();
  } catch (e) {
    debugPrint('_fetchBookingsChart failed: $e');
    return _generateEmptyDays();
  }
}
```

- [ ] **Step 3: Add `_fetchFillRateChart()` method**

Add after `_fetchBookingsChart()`:

```dart
Future<List<_DailyRevenue>> _fetchFillRateChart(String businessId) async {
  try {
    final acts = await SupabaseService.select('activities',
        select: 'id,max_guests', filters: {'business_id': businessId});
    final activityIds =
        acts.map((e) => e['id'] as String).whereType<String>().toList();
    if (activityIds.isEmpty) return _generateEmptyDays();

    final maxGuestsByActivity = <String, int>{
      for (final a in acts)
        a['id'] as String: (a['max_guests'] as num?)?.toInt() ?? 0,
    };

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _selectedDays - 1));

    final rows = await SupabaseService.from('bookings')
        .select('created_at,activity_id')
        .inFilter('activity_id', activityIds)
        .inFilter('status', ['confirmed', 'completed'])
        .gte('created_at', startDate.toIso8601String()) as List<dynamic>;

    // For each day: collect booking counts per activity, compute average fill rate
    final Map<String, Map<String, int>> dailyActivityBookings = {};
    for (int i = 0; i < _selectedDays; i++) {
      final day = DateTime(startDate.year, startDate.month, startDate.day)
          .add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      dailyActivityBookings[key] = {};
    }

    for (final row in rows) {
      final d = DateTime.parse(row['created_at'] as String);
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final actId = row['activity_id'] as String;
      if (dailyActivityBookings.containsKey(key)) {
        dailyActivityBookings[key]![actId] =
            (dailyActivityBookings[key]![actId] ?? 0) + 1;
      }
    }

    final sortedKeys = dailyActivityBookings.keys.toList()..sort();
    return sortedKeys.asMap().entries.map((entry) {
      final dayKey = entry.value;
      final date = DateTime.parse(dayKey);
      final bookingsByActivity = dailyActivityBookings[dayKey]!;

      double fillRate = 0.0;
      if (bookingsByActivity.isNotEmpty) {
        double totalFillRate = 0.0;
        int counted = 0;
        for (final actId in bookingsByActivity.keys) {
          final max = maxGuestsByActivity[actId] ?? 0;
          if (max > 0) {
            totalFillRate +=
                (bookingsByActivity[actId]! / max * 100).clamp(0.0, 100.0);
            counted++;
          }
        }
        if (counted > 0) fillRate = totalFillRate / counted;
      }

      return _DailyRevenue(dayIndex: entry.key, amount: fillRate, date: date);
    }).toList();
  } catch (e) {
    debugPrint('_fetchFillRateChart failed: $e');
    return _generateEmptyDays();
  }
}
```

- [ ] **Step 4: Replace revenue chart section with chart type tabs + conditional chart**

In `build()`, the Revenue Chart section (starting around line 769). Replace the period-selector row and the `FutureBuilder<List<_DailyRevenue>>` block:

```dart
// ── Analytics Charts ────────────────────────────────
if (userId != null) ...[
  // Chart type selector
  Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(
      children: [
        for (final entry in {
          'revenue': 'Revenue',
          'bookings': 'Bookings',
          'fillRate': 'Fill Rate',
        }.entries)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: HobifiChip(
              label: entry.value,
              isSelected: _chartType == entry.key,
              onTap: () => setState(() => _chartType = entry.key),
            ),
          ),
      ],
    ),
  ),
  // Period selector
  Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: Row(
      children: [
        for (final days in [7, 30, 90])
          HobifiChip(
            label: '${days}d',
            isSelected: _selectedDays == days,
            onTap: () {
              setState(() => _selectedDays = days);
              _refreshDashboard(userId);
            },
          ),
      ],
    ),
  ),
  // Chart area
  FutureBuilder<List<_DailyRevenue>>(
    future: _chartType == 'revenue'
        ? _revenueFuture
        : _chartType == 'bookings'
            ? _bookingsFuture
            : _fillRateFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          snapshot.data == null) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: HobifiShimmer(
              width: double.infinity, height: 220, borderRadius: 20),
        );
      }
      final chartData = snapshot.data ?? _generateEmptyDays();
      final maxY = chartData
          .map((e) => e.amount)
          .fold<double>(0.0, (a, b) => a > b ? a : b);
      final spots = chartData
          .map((e) => FlSpot(e.dayIndex.toDouble(), e.amount))
          .toList();

      final chartTitle = switch (_chartType) {
        'revenue' => 'Revenue Trend (EGP)',
        'bookings' => 'Daily Bookings',
        _ => 'Fill Rate (%)',
      };

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 8),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chartTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: _chartType == 'fillRate'
                        ? 100
                        : (maxY > 0 ? maxY * 1.2 : 10),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _chartType == 'fillRate'
                          ? 25
                          : (maxY > 0 ? maxY / 4 : 25),
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value != value.roundToDouble()) {
                              return const SizedBox.shrink();
                            }
                            final idx = value.toInt();
                            if (idx < 0 || idx >= chartData.length) {
                              return const SizedBox.shrink();
                            }
                            final step = _selectedDays <= 7
                                ? 1
                                : _selectedDays <= 30
                                    ? 5
                                    : 15;
                            if (idx % step != 0) return const SizedBox.shrink();
                            final day = chartData[idx].date;
                            final months = [
                              'Jan','Feb','Mar','Apr','May','Jun',
                              'Jul','Aug','Sep','Oct','Nov','Dec'
                            ];
                            final lbl = _selectedDays == 7
                                ? ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
                                    [day.weekday - 1]
                                : '${day.day} ${months[day.month - 1]}';
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(lbl,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      colorScheme.onSurface.withValues(alpha: 0.4),
                                )),
                            );
                          },
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.min || value == meta.max) {
                              return const SizedBox.shrink();
                            }
                            final lbl = _chartType == 'fillRate'
                                ? '${value.toInt()}%'
                                : value >= 1000
                                    ? '${(value / 1000).toStringAsFixed(1)}k'
                                    : value.toInt().toString();
                            return Text(lbl,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    colorScheme.onSurface.withValues(alpha: 0.4),
                              ));
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: colorScheme.primary,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: _selectedDays == 7,
                          getDotPainter: (spot, _, __, ___) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: colorScheme.surface,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.15),
                              colorScheme.primary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
],
```

- [ ] **Step 5: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 6: Manual test**

1. Open dashboard → chart area shows "Revenue / Bookings / Fill Rate" tabs above "7d / 30d / 90d"
2. Tap "Bookings" → chart updates to show daily booking counts
3. Tap "Fill Rate" → chart shows 0–100% axis with fill rate trend
4. Change period → chart refreshes for the active chart type

- [ ] **Step 7: Commit**

```bash
git add lib/screens/business/dashboard_screen.dart
git commit -m "feat(dashboard): add bookings and fill rate chart tabs"
```

---

### Task 7: Dashboard — Notification Inbox

**Files:**
- Create: `lib/supabase/migrations/20260504_notifications_inbox.sql`
- Create: `lib/services/notification_service.dart`
- Modify: `lib/supabase/functions/send-notification/index.ts` (also write to notifications table)
- Modify: `lib/main.dart` (register NotificationService)
- Modify: `lib/screens/business/dashboard_screen.dart` (bell icon + bottom sheet)

- [ ] **Step 1: Create the SQL migration**

Create `lib/supabase/migrations/20260504_notifications_inbox.sql`:

```sql
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  title text not null,
  body text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on notifications(user_id, created_at desc);

create index if not exists notifications_user_unread_idx
  on notifications(user_id) where not read;

alter table notifications enable row level security;

create policy "Users can view own notifications"
  on notifications for select
  using (auth.uid() = user_id);

create policy "Users can mark own notifications read"
  on notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Service role can insert notifications"
  on notifications for insert
  with check (true);
```

Apply it in the Supabase dashboard (SQL editor) or via Supabase CLI:

```bash
supabase db push
```

- [ ] **Step 2: Create `lib/services/notification_service.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class NotificationService extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _disposed = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.read).length;

  Future<void> loadNotifications(String userId) async {
    _isLoading = true;
    _safeNotify();

    try {
      final rows = await SupabaseService.from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50) as List<dynamic>;

      _notifications = rows
          .map((r) => NotificationModel.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> markAllRead(String userId) async {
    final unread = _notifications.where((n) => !n.read).map((n) => n.id).toList();
    if (unread.isEmpty) return;

    try {
      await SupabaseService.from('notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);

      _notifications = _notifications
          .map((n) => n.read
              ? n
              : NotificationModel(
                  id: n.id,
                  userId: n.userId,
                  title: n.title,
                  body: n.body,
                  read: true,
                  createdAt: n.createdAt,
                ))
          .toList();
      _safeNotify();
    } catch (e) {
      debugPrint('Failed to mark notifications read: $e');
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
```

- [ ] **Step 3: Register `NotificationService` in `main.dart`**

In `lib/main.dart`, add the import:

```dart
import 'package:hobby_haven/services/notification_service.dart';
```

In `MultiProvider`, add after the `WalletService` provider:

```dart
ChangeNotifierProxyProvider<AuthService, NotificationService>(
  create: (_) => NotificationService(),
  update: (context, auth, notifService) {
    final svc = notifService ?? NotificationService();
    final user = auth.currentUser;
    if (user != null && user.role.name == 'business') {
      svc.loadNotifications(user.id);
    }
    return svc;
  },
),
```

- [ ] **Step 4: Update `send-notification/index.ts` to also write to notifications table**

In `lib/supabase/functions/send-notification/index.ts`, after the stale token cleanup (after `if (staleTokenIds.length) {...}`), and before the return statement, add:

```typescript
// Write to in-app notifications inbox (fire-and-forget; errors are non-fatal)
if (title && body) {
  supabase
    .from('notifications')
    .insert(resolvedUserIds.map((uid: string) => ({ user_id: uid, title, body })))
    .then(({ error }) => {
      if (error) console.error('Failed to insert notifications:', error)
    })
}
```

Full context (replace the return statement area):

```typescript
    if (staleTokenIds.length) {
      await supabase.from('device_tokens').delete().in('id', staleTokenIds)
    }

    // Write to in-app notifications inbox (fire-and-forget; errors are non-fatal)
    if (title && body && resolvedUserIds.length) {
      supabase
        .from('notifications')
        .insert(resolvedUserIds.map((uid: string) => ({ user_id: uid, title, body })))
        .then(({ error }: { error: any }) => {
          if (error) console.error('Failed to insert notifications:', error)
        })
    }

    return new Response(JSON.stringify({ success: true, sent: tokens.length - staleTokenIds.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
```

- [ ] **Step 5: Add bell icon to dashboard header**

In `lib/screens/business/dashboard_screen.dart`, add `NotificationService` watch in `build()`:

After `final authService = context.watch<AuthService>();`, add:

```dart
final notifService = context.watch<NotificationService>();
```

Add import at the top:

```dart
import 'package:hobby_haven/services/notification_service.dart';
```

In the header Row (around line 490, before the wallet IconButton), add a bell icon button:

```dart
// Bell icon with badge
Stack(
  clipBehavior: Clip.none,
  children: [
    IconButton(
      onPressed: () => _showNotificationsSheet(context, notifService, userId!),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
      ),
      icon: Icon(Icons.notifications_outlined, color: colorScheme.primary),
    ),
    if (notifService.unreadCount > 0)
      Positioned(
        top: 4,
        right: 4,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: colorScheme.error,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              notifService.unreadCount > 9 ? '9+' : '${notifService.unreadCount}',
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
  ],
),
const SizedBox(width: 8),
// existing wallet IconButton follows
```

- [ ] **Step 6: Add `_showNotificationsSheet()` method to `_DashboardScreenState`**

```dart
void _showNotificationsSheet(
  BuildContext context,
  NotificationService notifService,
  String userId,
) {
  notifService.markAllRead(userId);
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.35,
      expand: false,
      builder: (ctx, sc) {
        final notifications = notifService.notifications;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Row(
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text('Notifications',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No notifications yet',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: notifications.length,
                      itemBuilder: (_, i) {
                        final n = notifications[i];
                        final isUnread = !n.read;
                        final now = DateTime.now();
                        final diff = now.difference(n.createdAt);
                        final timeLabel = diff.inDays == 0
                            ? 'Today'
                            : diff.inDays == 1
                                ? 'Yesterday'
                                : '${diff.inDays} days ago';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: isUnread
                                    ? colorScheme.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(n.title,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold)),
                                    ),
                                    Text(timeLabel,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.4))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(n.body,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}
```

- [ ] **Step 7: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 8: Deploy the edge function**

```bash
supabase functions deploy send-notification
```

- [ ] **Step 9: Manual test**

1. Trigger a booking confirmation payment (test mode) → check Supabase `notifications` table has a new row
2. Open dashboard → bell icon shows red badge with count
3. Tap bell → Notifications sheet opens with the notification row
4. Badge disappears after opening (all marked read)
5. With no notifications: sheet shows "No notifications yet" empty state

- [ ] **Step 10: Commit**

```bash
git add lib/supabase/migrations/20260504_notifications_inbox.sql \
    lib/services/notification_service.dart \
    lib/supabase/functions/send-notification/index.ts \
    lib/main.dart \
    lib/screens/business/dashboard_screen.dart
git commit -m "feat(dashboard): notification inbox with bell icon, badge, and bottom sheet"
```

---

## Stretch Goal: Social Sign-In Configuration

This is a guided setup, not automated code. Work through each step interactively in the browser.

**Google Sign-In:**
1. Go to Google Cloud Console → select/create your project → APIs & Services → Credentials
2. Create OAuth 2.0 Client ID → iOS app → use bundle ID `com.hobifi.app`
3. Create a second Client ID → Web application → note the Web Client ID
4. In Supabase Dashboard → Authentication → Providers → Google → paste the Web Client ID
5. In `ios/Runner/Info.plist`, add the iOS Client ID as a URL scheme:
   ```xml
   <key>CFBundleURLSchemes</key>
   <array>
     <string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string>
   </array>
   ```
6. In `android/app/google-services.json`, add the OAuth client entry

**Apple Sign-In:**
1. Apple Developer portal → Certificates, Identifiers & Profiles → Identifiers → select `com.hobifi.app` → enable Sign In with Apple
2. Create a Service ID: `com.hobifi.app.signin` → enable Sign In with Apple → configure with your domain and return URLs
3. Supabase Dashboard → Authentication → Providers → Apple → paste the Service ID, Team ID, Key ID, and private key
4. The `sign_in_with_apple` package handles the native flow automatically — no code changes needed

Test both flows on device (simulator does not support Apple Sign-In).
