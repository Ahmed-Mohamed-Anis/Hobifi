# Frontend Manager Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the UI/UX changes from the manager review round — auth polish, dark mode palette, nav restructure, ticket check-in without QR, business signup wizard, and recurring activities — in three independently shippable phases.

**Architecture:** Flutter/Dart app with Supabase backend. All Phase A + B changes are client-only (no DB migrations). Phase C adds one column to `users` for business onboarding completion, plus a Dart helper that generates N independent activity rows for recurring activities (no new series concept).

**Tech Stack:** Flutter 3.x, Dart, Provider, GoRouter, Supabase, `cached_network_image`, `google_fonts`. The codebase has no existing Dart test suite; this plan uses unit tests only for pure-Dart utilities (booking code) and smoke-test verification for UI changes.

**Spec:** `docs/superpowers/specs/2026-04-19-frontend-manager-feedback.md`

**Commit style:** Small, frequent commits per task. Use the project's existing `feat:` / `fix:` / `chore:` prefixes (see `git log --oneline -10`).

---

## Phase A — Visual Polish

### Task A1: Auth screen — Sign-In / Sign-Up pill toggle

**Files:**
- Modify: `lib/screens/auth_screen.dart` (logo block area + remove bottom toggle)

**Background:** Currently `_isSignUp` is toggled via a small gray `TextButton` at the bottom of the screen. We want a prominent segmented pill between the logo block and the role toggle, styled like the existing Explorer/Host pill.

- [ ] **Step 1: Add a `_buildModeToggle` method just below `_buildRoleToggle` in `auth_screen.dart`.**

Add this method inside `_AuthScreenState`:

```dart
Widget _buildModeToggle(ColorScheme colorScheme) {
  return Center(
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeTab(
            label: 'Sign In',
            isSelected: !_isSignUp,
            colorScheme: colorScheme,
            onTap: () => setState(() => _isSignUp = false),
          ),
          _buildModeTab(
            label: 'Sign Up',
            isSelected: _isSignUp,
            colorScheme: colorScheme,
            onTap: () => setState(() => _isSignUp = true),
          ),
        ],
      ),
    ),
  );
}

Widget _buildModeTab({
  required String label,
  required bool isSelected,
  required ColorScheme colorScheme,
  required VoidCallback onTap,
}) {
  final accentColor = _isUser ? AppColors.orange : AppColors.lime;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9999),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? accentColor : Colors.transparent,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2: Insert the mode toggle into the build tree directly below the logo block.**

In the main `build` method, between the logo and role toggle:

```dart
// Logo block
_buildLogoBlock(theme, colorScheme),

const SizedBox(height: 16),

// Sign In / Sign Up mode toggle (NEW)
_buildModeToggle(colorScheme),

const SizedBox(height: 12),

// Role toggle
_buildRoleToggle(colorScheme),
```

- [ ] **Step 3: Remove the bottom toggle TextButton (the `Center(child: TextButton(...))` block that toggles `_isSignUp`).**

Delete the entire `Center(child: TextButton(onPressed: () => setState(() => _isSignUp = !_isSignUp), ...))` block currently rendered between the social buttons and the Terms text. Keep the Terms block.

- [ ] **Step 4: Smoke-test the flow.**

Run: `flutter run`
- Auth screen opens → confirm pill toggle visible under the logo with "Sign In" selected by default.
- Tap "Sign Up" → form expands to show Name field, button label changes to "Create Account", logo subtitle switches to "Begin Your Journey".
- Toggle role (Explorer/Host) → the active pill (Sign In or Sign Up) accent color should change between orange and lime.
- Verify there is no bottom "Don't have an account?" text.

- [ ] **Step 5: Commit.**

```bash
git add lib/screens/auth_screen.dart
git commit -m "feat(auth): add prominent Sign In/Sign Up pill toggle"
```

---

### Task A2: Dark mode palette pass

**Files:**
- Modify: `lib/theme.dart` (AppColors dark constants + `ColorScheme.dark` call)

**Background:** Dark mode currently looks flat because only two surface levels are defined (`#0A0A0F`, `#16161F`) and primary `#4A47B8` is muddy. Flutter auto-generates the missing Material 3 surface container tones — the result is inconsistent. This task replaces the palette and passes all surface tones explicitly.

- [ ] **Step 1: Replace the dark constants in `AppColors`.**

In `lib/theme.dart`, find the "Dark mode" constants section and replace with:

```dart
// Dark mode (2026-04 palette pass — warmer base, better hierarchy)
static const Color darkPrimary = Color(0xFF6E6AE8);
static const Color darkOnPrimary = Color(0xFFFFFFFF);
static const Color darkSecondary = Color(0xFFF2A15E);
static const Color darkOnSecondary = Color(0xFF1A0F05);
static const Color darkAccent = Color(0xFFB6D25A);
static const Color darkBackground = Color(0xFF0F0D1A);
static const Color darkSurface = Color(0xFF1A1825);
static const Color darkSurfaceContainerLowest = Color(0xFF151322);
static const Color darkSurfaceContainerLow = Color(0xFF201D2E);
static const Color darkSurfaceContainer = Color(0xFF26223A);
static const Color darkSurfaceContainerHigh = Color(0xFF2D2947);
static const Color darkSurfaceContainerHighest = Color(0xFF353055);
static const Color darkOnSurface = Color(0xFFF0EEFF);
static const Color darkPrimaryText = Color(0xFFF0EEFF);
static const Color darkSecondaryText = Color(0xFFA39DBD);
static const Color darkHint = Color(0xFF6B6690);
static const Color darkError = Color(0xFFFF6B5F);
static const Color darkOnError = Color(0xFFFFFFFF);
static const Color darkSuccess = lime;
static const Color darkDivider = Color(0xFF3A3750);
static const Color darkOutline = Color(0xFF3A3750);
```

- [ ] **Step 2: Update the `darkTheme` `ColorScheme.dark(...)` to pass all surface tones explicitly.**

Replace the existing `ColorScheme.dark(...)` inside `darkTheme` with:

```dart
colorScheme: const ColorScheme.dark(
  primary: AppColors.darkPrimary,
  onPrimary: AppColors.darkOnPrimary,
  secondary: AppColors.darkSecondary,
  onSecondary: AppColors.darkOnSecondary,
  tertiary: AppColors.darkAccent,
  onTertiary: AppColors.darkOnPrimary,
  error: AppColors.darkError,
  onError: AppColors.darkOnError,
  surface: AppColors.darkSurface,
  onSurface: AppColors.darkOnSurface,
  surfaceContainerLowest: AppColors.darkSurfaceContainerLowest,
  surfaceContainerLow: AppColors.darkSurfaceContainerLow,
  surfaceContainer: AppColors.darkSurfaceContainer,
  surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
  surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
  outline: AppColors.darkOutline,
  outlineVariant: AppColors.darkDivider,
),
```

- [ ] **Step 3: Smoke-test dark mode across the key screens.**

Run: `flutter run` → switch device/simulator to dark mode (iOS Simulator: `Features → Toggle Appearance`; Android: quick-settings → dark mode).

Walk through and visually confirm nothing looks broken:
- Feed screen (`/feed`)
- Activity details (tap any activity)
- Bookings / My Hobbies (`/bookings`)
- Profile (`/profile`)
- Auth screen (sign out, confirm)

Expected: backgrounds feel warmer (not cold near-black), cards have clear elevation hierarchy, primary buttons / selected chips are visibly indigo-purple, orange and lime accents are present but not overpowering.

If a specific widget still looks off (e.g., hard-coded color), fix it inline and note the file. The spec allows inline fixes during verification.

- [ ] **Step 4: Commit.**

```bash
git add lib/theme.dart
git commit -m "style(theme): warmer dark palette with explicit surface hierarchy"
```

If you had to fix any hard-coded dark-mode colors in widget files, include those in a second commit:

```bash
git add lib/<paths>
git commit -m "fix: replace hard-coded dark colors with colorScheme tones"
```

---

## Phase B — Navigation & Ticket Restructure

### Task B1: Booking code utility

**Files:**
- Create: `lib/utils/booking_code.dart`
- Create: `test/utils/booking_code_test.dart`

**Background:** Deterministic 6-char booking code derived from `booking.id`. Format: `XXX-XXX` using unambiguous base32 (Crockford alphabet: no I/L/O/U) so providers can read it aloud without confusion. Pure function — unit-testable.

- [ ] **Step 1: Write the failing test first.**

Create `test/utils/booking_code_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_haven/utils/booking_code.dart';

void main() {
  group('bookingCodeFor', () {
    test('returns 7 chars in XXX-XXX format', () {
      final code = bookingCodeFor('b5b8f7e0-1234-4abc-9def-000000000001');
      expect(code.length, 7);
      expect(code[3], '-');
    });

    test('is deterministic for the same id', () {
      const id = 'b5b8f7e0-1234-4abc-9def-000000000001';
      expect(bookingCodeFor(id), bookingCodeFor(id));
    });

    test('differs for different ids', () {
      final a = bookingCodeFor('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      final b = bookingCodeFor('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
      expect(a, isNot(b));
    });

    test('uses only Crockford base32 chars (no I/L/O/U)', () {
      final code = bookingCodeFor('some-random-booking-id-12345');
      final body = code.replaceAll('-', '');
      for (final ch in body.split('')) {
        expect('0123456789ABCDEFGHJKMNPQRSTVWXYZ'.contains(ch), isTrue,
            reason: 'unexpected char: $ch in $code');
      }
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails.**

Run: `flutter test test/utils/booking_code_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:hobby_haven/utils/booking_code.dart'`.

- [ ] **Step 3: Implement the utility.**

Create `lib/utils/booking_code.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

String bookingCodeFor(String bookingId) {
  final digest = sha256.convert(utf8.encode(bookingId)).bytes;
  final buf = StringBuffer();
  for (int i = 0; i < 6; i++) {
    buf.write(_crockford[digest[i] % 32]);
  }
  final raw = buf.toString();
  return '${raw.substring(0, 3)}-${raw.substring(3, 6)}';
}
```

- [ ] **Step 4: Ensure `crypto` is in dependencies.**

Check `pubspec.yaml` under `dependencies:` — if `crypto:` is not listed, add it:

```yaml
  crypto: ^3.0.3
```

Then run: `flutter pub get`

- [ ] **Step 5: Run the tests again.**

Run: `flutter test test/utils/booking_code_test.dart`
Expected: All 4 tests PASS.

- [ ] **Step 6: Commit.**

```bash
git add lib/utils/booking_code.dart test/utils/booking_code_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(utils): add deterministic booking code generator"
```

---

### Task B2: Ticket screen — replace QR with booking code

**Files:**
- Modify: `lib/screens/user/ticket_screen.dart`

**Background:** Remove the QR widget. Show a large `XXX-XXX` code with a "Show this code to the host" hint.

- [ ] **Step 1: Locate and remove the QR widget.**

Open `lib/screens/user/ticket_screen.dart`. Find the QR rendering (likely `QrImageView(...)` from `qr_flutter`). Replace the QR section with a booking code card.

- [ ] **Step 2: Replace with the booking code card.**

Add the import at the top:

```dart
import 'package:hobby_haven/utils/booking_code.dart';
```

Where the QR was, insert:

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
  decoration: BoxDecoration(
    color: colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: colorScheme.outlineVariant),
  ),
  child: Column(
    children: [
      Text(
        'Booking Code',
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        bookingCodeFor(booking.id),
        style: theme.textTheme.displayMedium?.copyWith(
          color: colorScheme.primary,
          letterSpacing: 6,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Show this code to the host',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    ],
  ),
),
```

- [ ] **Step 3: Remove the now-unused `qr_flutter` import from this file.**

Delete the `import 'package:qr_flutter/qr_flutter.dart';` line from `ticket_screen.dart`. Do not touch `pubspec.yaml` — the package may still be in use elsewhere; leave it unless a repo-wide search confirms it's unreferenced.

Run: `flutter analyze lib/screens/user/ticket_screen.dart`
Expected: no errors in this file.

- [ ] **Step 4: Smoke-test.**

Run: `flutter run` → sign in → book an activity (or open existing booking) → tap into the ticket. Confirm the code card shows a 7-char `XXX-XXX` code and no QR. Verify layout on both light and dark mode.

- [ ] **Step 5: Commit.**

```bash
git add lib/screens/user/ticket_screen.dart
git commit -m "feat(tickets): replace QR with 6-digit booking code"
```

---

### Task B3: `BookingService.markAttended` helper

**Files:**
- Modify: `lib/services/booking_service.dart`

**Background:** Add a helper that updates a booking's status to `completed`. Used by the provider mark-attended button (Task B4).

- [ ] **Step 1: Open `lib/services/booking_service.dart` and find the existing cancellation method (`cancelBookingServerSide` or similar).**

This gives you the pattern for how this codebase updates booking status via Supabase.

- [ ] **Step 2: Add the `markAttended` method following the same pattern.**

Add next to the other booking mutation methods:

```dart
/// Mark a booking as attended (status → completed). Provider-side action.
Future<Map<String, dynamic>> markAttended(String bookingId) async {
  try {
    final supabase = Supabase.instance.client;
    await supabase
        .from('bookings')
        .update({'status': 'completed', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', bookingId);

    // Refresh local cache if the service keeps one
    await loadUserBookings(supabase.auth.currentUser?.id ?? '');
    notifyListeners();

    return {'success': true, 'message': 'Booking marked as attended'};
  } catch (e) {
    return {'success': false, 'message': 'Failed to mark attended: $e'};
  }
}
```

Note: if `loadUserBookings` requires a different argument or if the service uses a different refresh pattern, match the pattern used in `cancelBookingServerSide`. Do not invent new loading logic.

- [ ] **Step 3: Confirm it compiles.**

Run: `flutter analyze lib/services/booking_service.dart`
Expected: no errors.

- [ ] **Step 4: Commit.**

```bash
git add lib/services/booking_service.dart
git commit -m "feat(bookings): add markAttended helper for provider check-in"
```

---

### Task B4: Provider mark-attended UI on activity manage screen

**Files:**
- Modify: `lib/screens/business/activity_manage_screen.dart`
- Import: `lib/utils/booking_code.dart`, `lib/services/booking_service.dart`

**Background:** On the business's "manage activity" screen, each booking in the attendee list gets a "Mark attended" button. Shows the `XXX-XXX` code beside the attendee name. After marking, row grays out with a "Checked in" badge.

- [ ] **Step 1: Open `activity_manage_screen.dart` and locate the attendee/booking list section.**

Read the file and find the widget that renders each booking row (likely a `ListTile` or custom Row inside a `ListView.builder`).

- [ ] **Step 2: Modify each row to show the booking code and a mark-attended action.**

For each attendee row, add:

```dart
// Import at top of file:
// import 'package:hobby_haven/utils/booking_code.dart';
// import 'package:hobby_haven/services/booking_service.dart';
// import 'package:provider/provider.dart';

// Inside the row builder, where each booking is rendered:
final isAttended = booking.status == BookingStatus.completed;

return Opacity(
  opacity: isAttended ? 0.5 : 1.0,
  child: ListTile(
    title: Text(booking.userName ?? 'Guest'), // adapt to actual field name in BookingModel
    subtitle: Row(
      children: [
        Text(
          bookingCodeFor(booking.id),
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.primary,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
    trailing: isAttended
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Checked in',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : TextButton(
            onPressed: () => _confirmMarkAttended(context, booking),
            child: const Text('Mark attended'),
          ),
  ),
);
```

If `booking.userName` is not available on `BookingModel`, use what is (`booking.userId` or the already-rendered field). Do not add new fields to the model in this task.

- [ ] **Step 3: Add the confirmation handler to the state class.**

```dart
Future<void> _confirmMarkAttended(BuildContext context, BookingModel booking) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mark as attended?'),
      content: Text('Confirm ${booking.userName ?? 'this guest'} has checked in. This can\'t be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark attended')),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final bookingService = context.read<BookingService>();
  final result = await bookingService.markAttended(booking.id);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result['message'] ?? 'Done')),
  );
}
```

- [ ] **Step 4: Smoke-test end-to-end.**

Run: `flutter run` as a business account → open an activity's manage screen → confirm you see attendee rows with a code and "Mark attended" button. Create a test booking as a user account if needed (separate simulator/device). Tap "Mark attended" → confirm dialog → accept → row grays out with "Checked in" badge. Re-open the screen to confirm persistence.

- [ ] **Step 5: Commit.**

```bash
git add lib/screens/business/activity_manage_screen.dart
git commit -m "feat(business): add mark-attended action with booking code display"
```

---

### Task B5: My Hobbies TabBar (Upcoming / Liked)

**Files:**
- Modify: `lib/screens/user/saved_screen.dart` (extract body as reusable widget)
- Modify: `lib/screens/user/bookings_screen.dart` (add TabBar, remove old chips)

**Background:** My Hobbies gets a `TabBar` with `Upcoming` and `Liked` tabs. The Liked tab renders the current Saved screen's body. Remove the `Upcoming / Completed / Cancelled` chips from bookings_screen entirely — Completed/Cancelled move to Profile in Task B6.

- [ ] **Step 1: Extract SavedScreen body into a reusable widget.**

Open `lib/screens/user/saved_screen.dart`. At the bottom of the file (or in the same file), add a public `SavedContent` widget that renders the list without the `Scaffold` / header. Then make `SavedScreen` render `Scaffold(body: SafeArea(child: SavedContent()))`.

Example structure:

```dart
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SafeArea(child: SavedContent()));
  }
}

class SavedContent extends StatefulWidget {
  const SavedContent({super.key});

  @override
  State<SavedContent> createState() => _SavedContentState();
}

class _SavedContentState extends State<SavedContent> {
  // Move existing SavedScreen state logic here unchanged.
  // ...
}
```

Keep all existing behavior (loading, refresh, list rendering) inside `SavedContent`.

- [ ] **Step 2: In `bookings_screen.dart`, convert the state to a TabController + replace the chips section.**

Change `_BookingsScreenState` to `extends State<BookingsScreen> with SingleTickerProviderStateMixin`, add `late TabController _tabController;` and initialize with `length: 2`.

Delete `_selectedFilter` and the three `HobifiChip` widgets. Delete the filtering switch (`switch (_selectedFilter) { case 'Completed': ... }`). The screen now shows only upcoming bookings in the Upcoming tab.

Replace the chips `SliverToBoxAdapter` with:

```dart
// (after the header sliver)
SliverPersistentHeader(
  pinned: true,
  delegate: _TabBarDelegate(
    TabBar(
      controller: _tabController,
      labelColor: theme.colorScheme.primary,
      unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      indicatorColor: theme.colorScheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Liked')],
    ),
    theme.colorScheme.surface,
  ),
),
```

- [ ] **Step 3: Wrap the body in a `TabBarView` with two children.**

Because the screen uses `CustomScrollView` + slivers, the simplest refactor is to replace the bottom half with a fixed-height region hosting the `TabBarView`. Change the scaffold body to a `Column` containing:
1. A non-scrolling header (the `My Hobbies` title + avatar block).
2. A pinned `TabBar`.
3. `Expanded(child: TabBarView(controller: _tabController, children: [<UpcomingList>, SavedContent()]))`.

Where `<UpcomingList>` is the existing booking-card list, simplified to show only `upcomingBookings` (no filter switch).

If the existing "Explore more" banner should appear in the Upcoming tab, keep it there. Do not show it in the Liked tab.

- [ ] **Step 4: Add the sliver `TabBar` delegate (if you chose to keep CustomScrollView instead).**

If you went with the `Column` layout in Step 3, skip this step. If you kept slivers, add this class at the bottom of `bookings_screen.dart`:

```dart
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, this.background);
  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: background, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
```

Pragmatic recommendation: use the `Column` + `Expanded(TabBarView)` layout. Simpler, works fine for this screen, avoids the sliver TabBar complexity.

- [ ] **Step 5: Smoke-test.**

Run: `flutter run` → navigate to My Hobbies → confirm TabBar with `Upcoming` and `Liked`. Upcoming shows the existing booking list. Liked shows the saved activities. Pull-to-refresh works on both (if the existing screens supported it).

- [ ] **Step 6: Commit.**

```bash
git add lib/screens/user/bookings_screen.dart lib/screens/user/saved_screen.dart
git commit -m "feat(nav): fold Saved into My Hobbies as Liked tab"
```

---

### Task B6: BookingHistoryScreen (Completed / Cancelled)

**Files:**
- Create: `lib/screens/user/booking_history_screen.dart`

**Background:** Dedicated screen pushed from Profile, showing past bookings in two tabs.

- [ ] **Step 1: Create the screen.**

Create `lib/screens/user/booking_history_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/screens/user/bookings_screen.dart' show BookingCard;
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookingService = context.watch<BookingService>();
    final authService = context.watch<AuthService>();
    final all = bookingService.getUserBookings(authService.currentUser?.id ?? '');
    final completed = all.where((b) => b.status == BookingStatus.completed).toList();
    final cancelled = all.where((b) => b.status == BookingStatus.cancelled).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking History'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [Tab(text: 'Completed'), Tab(text: 'Cancelled')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(completed, 'No completed bookings yet'),
          _buildList(cancelled, 'No cancelled bookings'),
        ],
      ),
    );
  }

  Widget _buildList(List<BookingModel> bookings, String emptyLabel) {
    if (bookings.isEmpty) {
      return HobifiEmptyState(
        icon: Icons.history_rounded,
        title: emptyLabel,
        subtitle: 'Your past activity bookings will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: bookings.length,
      itemBuilder: (_, i) => BookingCard(booking: bookings[i]),
    );
  }
}
```

- [ ] **Step 2: Confirm `BookingCard` is public in `bookings_screen.dart`.**

Open `lib/screens/user/bookings_screen.dart`. The existing `BookingCard` class is already public (top-level class). If the export style in this codebase requires it, re-export from a widgets barrel — otherwise the direct import above works.

- [ ] **Step 3: Confirm it compiles.**

Run: `flutter analyze lib/screens/user/booking_history_screen.dart`
Expected: no errors.

- [ ] **Step 4: Commit.**

```bash
git add lib/screens/user/booking_history_screen.dart
git commit -m "feat(profile): add Booking History screen with Completed/Cancelled tabs"
```

---

### Task B7: Profile — Booking History row + route

**Files:**
- Modify: `lib/screens/user/profile_screen.dart`
- Modify: `lib/nav.dart` (add `profileHistory` route)

**Background:** Wire the new screen into nav and surface it on the Profile page.

- [ ] **Step 1: Add the route constant and route definition.**

In `lib/nav.dart`, add to `AppRoutes`:

```dart
static const String profileHistory = '/profile/history';
static const String friends = '/friends';
```

Add the `BookingHistoryScreen` import at the top of `nav.dart`:

```dart
import 'package:hobby_haven/screens/user/booking_history_screen.dart';
```

Add the route as a detail route (outside shell) in the routes list, near the other `_buildSmoothTransition` routes:

```dart
GoRoute(
  path: AppRoutes.profileHistory,
  name: 'profile-history',
  parentNavigatorKey: _rootNavigatorKey,
  pageBuilder: (context, state) => _buildSmoothTransition(
    child: const BookingHistoryScreen(),
    state: state,
  ),
),
```

- [ ] **Step 2: Add a "Booking History" row on Profile.**

Open `lib/screens/user/profile_screen.dart`. Find the profile options/rows section (usually a list of `ListTile`-like rows). Add a new row:

```dart
ListTile(
  leading: Icon(Icons.history_rounded, color: colorScheme.primary),
  title: const Text('Booking History'),
  subtitle: Text('Completed and cancelled activities',
      style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.6))),
  trailing: const Icon(Icons.chevron_right_rounded),
  onTap: () => context.push(AppRoutes.profileHistory),
),
```

Match the exact styling of the other rows in the file (they may use custom containers, not `ListTile`) — follow the pattern that exists.

- [ ] **Step 3: Smoke-test.**

Run: `flutter run` → open Profile → tap "Booking History" → new screen pushes in → tabs show Completed / Cancelled with correct bookings.

- [ ] **Step 4: Commit.**

```bash
git add lib/screens/user/profile_screen.dart lib/nav.dart
git commit -m "feat(profile): link Booking History from profile screen"
```

---

### Task B8: Friends screen (Coming Soon)

**Files:**
- Create: `lib/screens/user/friends_screen.dart`

**Background:** Placeholder screen. Uses existing `HobifiEmptyState`.

- [ ] **Step 1: Create the screen.**

Create `lib/screens/user/friends_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';
import 'package:hobby_haven/theme.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.paddingLg,
              child: Text(
                'Friends',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Expanded(
              child: HobifiEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Friends coming soon',
                subtitle: 'Meet people who share your hobbies — launching in a future update.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Confirm it compiles.**

Run: `flutter analyze lib/screens/user/friends_screen.dart`
Expected: no errors.

- [ ] **Step 3: Commit.**

```bash
git add lib/screens/user/friends_screen.dart
git commit -m "feat(nav): add Friends coming-soon screen"
```

---

### Task B9: Footer restructure — rename labels, swap Saved → Friends

**Files:**
- Modify: `lib/nav.dart` (user shell destinations + routes)

**Background:** The final piece that ties Phase B together. Rename footer labels to match page headers, remove the standalone `/saved` route from the user shell (Saved content now lives inside My Hobbies), add the Friends route as the 3rd tab.

- [ ] **Step 1: Add the Friends import in nav.dart.**

```dart
import 'package:hobby_haven/screens/user/friends_screen.dart';
```

- [ ] **Step 2: Replace the `/saved` route inside the user ShellRoute with `/friends`.**

Find the user `ShellRoute` → the child routes. Remove:

```dart
GoRoute(
  path: AppRoutes.saved,
  name: 'saved',
  pageBuilder: (context, state) => const NoTransitionPage(child: SavedScreen()),
),
```

Add:

```dart
GoRoute(
  path: AppRoutes.friends,
  name: 'friends',
  pageBuilder: (context, state) => const NoTransitionPage(child: FriendsScreen()),
),
```

Also remove the `SavedScreen` import from `nav.dart` if no other route uses it (the saved widget is still imported from `bookings_screen.dart` for Liked tab embedding, but that's a different import site).

- [ ] **Step 3: Update `_UserShellScreen._currentIndex` to recognize `/friends` instead of `/saved`.**

```dart
int _currentIndex(BuildContext context) {
  final location = GoRouterState.of(context).matchedLocation;
  if (location.startsWith(AppRoutes.bookings)) return 1;
  if (location.startsWith(AppRoutes.friends)) return 2;
  if (location.startsWith(AppRoutes.profile)) return 3;
  return 0; // feed
}
```

- [ ] **Step 4: Update the `onDestinationSelected` switch.**

```dart
onDestinationSelected: (i) {
  switch (i) {
    case 0:
      context.go(AppRoutes.feed);
    case 1:
      context.go(AppRoutes.bookings);
    case 2:
      context.go(AppRoutes.friends);
    case 3:
      context.go(AppRoutes.profile);
  }
},
```

- [ ] **Step 5: Update the `NavigationDestination` list with new labels and the friends icon.**

```dart
destinations: [
  NavigationDestination(
    icon: Icon(Icons.explore_outlined, color: idx == 0 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
    selectedIcon: Icon(Icons.explore_rounded, color: colorScheme.primary),
    label: 'Discover',
  ),
  NavigationDestination(
    icon: Icon(Icons.confirmation_number_outlined, color: idx == 1 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
    selectedIcon: Icon(Icons.confirmation_number_rounded, color: colorScheme.primary),
    label: 'My Hobbies',
  ),
  NavigationDestination(
    icon: Icon(Icons.people_outline_rounded, color: idx == 2 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
    selectedIcon: Icon(Icons.people_rounded, color: colorScheme.primary),
    label: 'Friends',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline_rounded, color: idx == 3 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
    selectedIcon: Icon(Icons.person_rounded, color: colorScheme.primary),
    label: 'Profile',
  ),
],
```

- [ ] **Step 6: Remove `AppRoutes.saved` constant and any other references.**

In the `AppRoutes` class at the bottom of `nav.dart`, delete the `saved` constant.

Then, from the repo root, search for stale references:

Run: `grep -rn "AppRoutes.saved\|/saved" lib/ || true`

If anything is still referencing `AppRoutes.saved`, change it to navigate to `/bookings` (My Hobbies) instead. Expected typical offenders: user empty states, profile links. If one of them specifically needs to open the Liked tab, pass it via `GoRouterState.extra` — but for MVP just sending the user to `/bookings` is acceptable.

- [ ] **Step 7: Smoke-test the full nav.**

Run: `flutter run` → login as a user → verify footer reads `Discover | My Hobbies | Friends | Profile`. Each tab loads the correct screen. No `/saved` deep-link still lingers (try to manually navigate if possible — should 404 or redirect cleanly).

- [ ] **Step 8: Commit.**

```bash
git add lib/nav.dart lib/screens/**/*.dart
git commit -m "feat(nav): rename footer labels and replace Saved tab with Friends"
```

---

## Phase C — Features

### Task C1: DB migration + UserModel + AuthService for business onboarding flag

**Files:**
- Create: `lib/supabase/migrations/20260419_add_business_onboarded.sql`
- Modify: `lib/models/user_model.dart`
- Modify: `lib/services/auth_service.dart`

**Background:** A new `business_onboarded` column on `users` lets the router skip the wizard for already-onboarded businesses.

- [ ] **Step 1: Write the migration.**

Create `lib/supabase/migrations/20260419_add_business_onboarded.sql`:

```sql
-- Adds business onboarding completion flag for the business signup wizard.
alter table public.users
  add column if not exists business_onboarded boolean not null default false;

-- Existing business accounts (pre-feature) are treated as already onboarded
-- so they don't get forced through the new wizard retroactively.
update public.users
   set business_onboarded = true
 where role = 'business';
```

- [ ] **Step 2: Apply the migration locally.**

Run: `supabase db push`
(Or the project's migration command — check `CLAUDE.md` or the Supabase CLI memory note if unsure. Fall back to running the SQL directly via the Supabase dashboard SQL editor if the CLI is not wired up.)
Expected: migration applied, no errors.

- [ ] **Step 3: Add the field to `UserModel`.**

Open `lib/models/user_model.dart`. Add a `businessOnboarded` boolean field, update the constructor, `copyWith`, `toJson`, and `fromJson`/`fromMap`:

```dart
// In the class:
final bool businessOnboarded;

// Constructor parameter (near the bottom of required/optional list):
this.businessOnboarded = false,

// fromJson/fromMap:
businessOnboarded: (json['business_onboarded'] as bool?) ?? false,

// toJson:
'business_onboarded': businessOnboarded,

// copyWith (if present):
bool? businessOnboarded,
// ... and pass through: businessOnboarded: businessOnboarded ?? this.businessOnboarded,
```

Adapt field names to match the exact conventions already used in `user_model.dart` (snake_case on the wire, camelCase in Dart).

- [ ] **Step 4: Confirm AuthService picks up the new field.**

Open `lib/services/auth_service.dart`. The mapping from Supabase rows to `UserModel` should automatically read the new field via `UserModel.fromJson`. If there's explicit column picking (`select('id, email, ...')`), add `business_onboarded` to the select list.

- [ ] **Step 5: Confirm it compiles.**

Run: `flutter analyze lib/models/user_model.dart lib/services/auth_service.dart`
Expected: no errors.

- [ ] **Step 6: Commit.**

```bash
git add lib/supabase/migrations/20260419_add_business_onboarded.sql lib/models/user_model.dart lib/services/auth_service.dart
git commit -m "feat(auth): add business_onboarded flag to user model and schema"
```

---

### Task C2: BusinessOnboardingScreen (2-step wizard)

**Files:**
- Create: `lib/screens/business/business_onboarding_screen.dart`

**Background:** Two-step wizard. Step 1 required (name/category/city). Step 2 skippable (description + optional cover photo). On finish, update the business profile + set `business_onboarded = true`.

- [ ] **Step 1: Create the screen scaffold with step state.**

Create `lib/screens/business/business_onboarding_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/theme.dart';

class BusinessOnboardingScreen extends StatefulWidget {
  const BusinessOnboardingScreen({super.key});

  @override
  State<BusinessOnboardingScreen> createState() => _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState extends State<BusinessOnboardingScreen> {
  int _step = 0;
  bool _saving = false;

  // Step 1
  final _nameController = TextEditingController();
  String? _category;
  String? _city;

  // Step 2
  final _descriptionController = TextEditingController();

  static const _categories = ['fitness', 'arts', 'food', 'music', 'outdoor', 'other'];
  static const _cities = ['Cairo', 'Alexandria', 'Giza', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _step1Valid =>
      _nameController.text.trim().isNotEmpty && _category != null && _city != null;

  Future<void> _finish({bool skippedStep2 = false}) async {
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    final result = await auth.completeBusinessOnboarding(
      businessName: _nameController.text.trim(),
      category: _category!,
      city: _city!,
      description: skippedStep2 ? null : _descriptionController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      context.go(AppRoutes.businessDashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Could not save. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress
              Row(
                children: [
                  Expanded(child: _stepIndicator(active: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _stepIndicator(active: _step >= 1)),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _step == 0 ? 'Tell us about your business' : 'Introduce yourself',
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _step == 0
                    ? 'This helps explorers find you.'
                    : 'Optional — skip if you\'re in a rush.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: SingleChildScrollView(child: _step == 0 ? _buildStep1() : _buildStep2())),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepIndicator({required bool active}) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Business name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final c in _categories)
              DropdownMenuItem(value: c, child: Text(c[0].toUpperCase() + c.substring(1))),
          ],
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _city,
          decoration: const InputDecoration(labelText: 'City'),
          items: [for (final c in _cities) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _city = v),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: 240,
          decoration: const InputDecoration(
            labelText: 'Short description',
            hintText: 'What makes your hobby sessions special?',
          ),
        ),
        // Cover photo upload is optional MVP — omit if AuthService doesn't yet expose upload.
        // If the codebase already has a profile-photo uploader, wire it here as a follow-up task.
      ],
    );
  }

  Widget _buildActions() {
    if (_step == 0) {
      return FilledButton(
        onPressed: _step1Valid && !_saving ? () => setState(() => _step = 1) : null,
        child: const Text('Continue'),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _saving ? null : () => _finish(skippedStep2: true),
            child: const Text('Skip for now'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: _saving ? null : () => _finish(),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Finish'),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Add the `completeBusinessOnboarding` method to AuthService.**

In `lib/services/auth_service.dart`, add:

```dart
Future<Map<String, dynamic>> completeBusinessOnboarding({
  required String businessName,
  required String category,
  required String city,
  String? description,
}) async {
  try {
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return {'success': false, 'message': 'Not signed in'};

    final updates = <String, dynamic>{
      'name': businessName,
      'business_onboarded': true,
      'updated_at': DateTime.now().toIso8601String(),
    };
    // If the users table has category/city/description columns, include them.
    // Otherwise add those columns in a follow-up migration and uncomment below:
    // if (description != null && description.isNotEmpty) updates['description'] = description;
    // updates['category'] = category;
    // updates['city'] = city;

    await supabase.from('users').update(updates).eq('id', uid);

    // Refresh the cached user
    await refreshCurrentUser();
    notifyListeners();
    return {'success': true};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}
```

**Important:** only write fields that exist on the `users` table. Based on `lib/supabase/supabase_tables.sql`, the current columns are `id`, `email`, `name`, `avatar_url`, `role`, `created_at`, `updated_at`. Category / city / description are **not** in the schema yet — for MVP, only persist `business_onboarded = true` and update `name`. Log the other fields to a TODO comment if they're not yet in the schema, or add them in a companion migration in the same task if you prefer. The safe default is to only write what exists.

Pragmatic path: for this task, write only `name` and `business_onboarded`. Category/city/description collection happens in the UI but isn't persisted yet — this is still a net improvement, and we avoid a schema expansion that wasn't in the spec.

- [ ] **Step 3: Confirm `refreshCurrentUser` exists on AuthService.**

Open `lib/services/auth_service.dart` and confirm there's a method that re-fetches the current user row after a mutation (it may be called `loadUser`, `refreshUser`, `fetchProfile`, etc.). Match the existing name in Step 2. If no such method exists, implement a minimal one that selects the user row by id and updates the cached `_currentUser`.

- [ ] **Step 4: Compile check.**

Run: `flutter analyze lib/screens/business/business_onboarding_screen.dart lib/services/auth_service.dart`
Expected: no errors.

- [ ] **Step 5: Commit.**

```bash
git add lib/screens/business/business_onboarding_screen.dart lib/services/auth_service.dart
git commit -m "feat(business): add 2-step business onboarding wizard"
```

---

### Task C3: Route + redirect for business onboarding

**Files:**
- Modify: `lib/nav.dart`

**Background:** Wire the screen into routing and redirect business-role users with `businessOnboarded == false` to it.

- [ ] **Step 1: Add route constant and import.**

```dart
import 'package:hobby_haven/screens/business/business_onboarding_screen.dart';

// In AppRoutes:
static const String businessOnboarding = '/business-onboarding';
```

- [ ] **Step 2: Add the route (no shell, full-screen).**

Near the user `OnboardingScreen` route in `nav.dart`:

```dart
GoRoute(
  path: AppRoutes.businessOnboarding,
  name: 'business-onboarding',
  pageBuilder: (context, state) => const NoTransitionPage(child: BusinessOnboardingScreen()),
),
```

- [ ] **Step 3: Update the router redirect to route un-onboarded businesses to the wizard.**

In the existing `redirect:` block (top of the GoRouter constructor), extend the logic:

```dart
redirect: (context, state) {
  final isAuthenticated = authService.isAuthenticated;
  final isAuthRoute = state.matchedLocation == AppRoutes.auth;

  if (!isAuthenticated && !isAuthRoute) return AppRoutes.auth;

  if (isAuthenticated && isAuthRoute) {
    final user = authService.currentUser;
    if (user?.role.name == 'business') {
      return user!.businessOnboarded
          ? AppRoutes.businessDashboard
          : AppRoutes.businessOnboarding;
    }
    if (user != null && user.interests.isEmpty) return AppRoutes.onboarding;
    return AppRoutes.feed;
  }

  if (isAuthenticated) {
    final user = authService.currentUser;
    final loc = state.matchedLocation;

    // Business onboarded check
    if (user != null &&
        user.role.name == 'business' &&
        !user.businessOnboarded &&
        loc != AppRoutes.businessOnboarding) {
      return AppRoutes.businessOnboarding;
    }
    // Already onboarded — don't let them revisit
    if (user != null &&
        user.role.name == 'business' &&
        user.businessOnboarded &&
        loc == AppRoutes.businessOnboarding) {
      return AppRoutes.businessDashboard;
    }

    // Existing user onboarding logic (unchanged)
    final isOnboarding = loc == AppRoutes.onboarding;
    if (user != null && user.role.name == 'user' && user.interests.isEmpty && !isOnboarding) {
      return AppRoutes.onboarding;
    }
    if (isOnboarding && user != null && user.interests.isNotEmpty) {
      return AppRoutes.feed;
    }
  }

  return null;
},
```

- [ ] **Step 4: Smoke-test.**

Run: `flutter run` → sign up as a new Host (business) account → confirm you land on `/business-onboarding` instead of directly on the dashboard. Complete step 1 → continue → skip or finish step 2 → land on the dashboard. Sign out and back in → you should now go straight to the dashboard.

- [ ] **Step 5: Commit.**

```bash
git add lib/nav.dart
git commit -m "feat(nav): redirect un-onboarded business users to wizard"
```

---

### Task C4: Onboarding polish + auth benefit strip

**Files:**
- Modify: `lib/screens/onboarding_screen.dart`
- Modify: `lib/screens/auth_screen.dart`

**Background:** Small polish on the user onboarding screen (warmer copy + step indicator) and a benefit strip shown in Sign Up mode on the auth screen.

- [ ] **Step 1: Polish the user onboarding header copy.**

Open `lib/screens/onboarding_screen.dart`. Find the title/subtitle text at the top of the screen. Change the title to something warmer (current copy may say "Pick your interests" — replace with "Welcome to Hobifi" or keep the existing title and add a subtitle `"Let's find what moves you."`). Add a simple progress indicator row (one filled bar, since it's a single step) matching the style used in BusinessOnboardingScreen for consistency.

Concrete diff: if the existing screen doesn't have a step bar, add:

```dart
Row(
  children: [
    Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  ],
),
const SizedBox(height: 16),
```

Keep the polish light — do not rewrite the screen's logic.

- [ ] **Step 2: Add the benefit strip to the auth screen.**

In `lib/screens/auth_screen.dart`, inside `_buildLogoBlock` (or directly in the build tree, between logo and mode toggle), add a conditional benefit strip visible only when `_isSignUp == true`:

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  child: _isSignUp
      ? Column(
          key: const ValueKey('benefits'),
          children: [
            const SizedBox(height: 8),
            Text(
              _isUser ? 'Discover local hobbies' : 'Host your passion',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _isUser ? 'Book and meet real people' : 'Get paid in EGP',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        )
      : const SizedBox.shrink(key: ValueKey('nobenefits')),
),
```

Place it right below the existing `_buildLogoBlock` subtitle in the main `build` return.

- [ ] **Step 3: Smoke-test.**

Run: `flutter run` → Auth screen → toggle Sign In/Sign Up → confirm benefit strip appears only in Sign Up. Toggle Explorer/Host → copy changes between Discover/Book and Host/Get paid in EGP.

Sign up as user → onboarding shows the progress bar + new copy.

- [ ] **Step 4: Commit.**

```bash
git add lib/screens/onboarding_screen.dart lib/screens/auth_screen.dart
git commit -m "feat(signup): benefit strip on auth + onboarding progress polish"
```

---

### Task C5: Recurring activities — Weekly / Biweekly / Monthly

**Files:**
- Modify: `lib/screens/business/create_activity_screen.dart`
- Optionally modify: `lib/services/activity_service.dart`

**Background:** Add a "Repeats" section on create-activity. On save, generate N independent activity rows via the existing `createActivity` call. Cap at 26 occurrences (6 months weekly).

- [ ] **Step 1: Add repeat-state fields to the create-activity screen state.**

In `_CreateActivityScreenState` (or equivalent), add:

```dart
bool _repeats = false;
String _frequency = 'weekly'; // 'weekly' | 'biweekly' | 'monthly'
DateTime? _repeatUntil;
```

- [ ] **Step 2: Add the "Repeats" UI section below the existing date/time picker.**

```dart
SwitchListTile(
  title: const Text('This activity repeats'),
  value: _repeats,
  onChanged: (v) => setState(() => _repeats = v),
),
if (_repeats) ...[
  const SizedBox(height: 8),
  DropdownButtonFormField<String>(
    value: _frequency,
    decoration: const InputDecoration(labelText: 'Frequency'),
    items: const [
      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
      DropdownMenuItem(value: 'biweekly', child: Text('Every 2 weeks')),
      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
    ],
    onChanged: (v) => setState(() => _frequency = v ?? 'weekly'),
  ),
  const SizedBox(height: 12),
  ListTile(
    leading: const Icon(Icons.event_rounded),
    title: const Text('End date'),
    subtitle: Text(_repeatUntil == null
        ? 'Select'
        : '${_repeatUntil!.toLocal().toString().split(' ').first}'),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 30)),
        firstDate: DateTime.now().add(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked != null) setState(() => _repeatUntil = picked);
    },
  ),
],
```

- [ ] **Step 3: Add an occurrence generator helper inside the state class.**

```dart
List<DateTime> _occurrenceDates(DateTime start, String frequency, DateTime endInclusive) {
  final dates = <DateTime>[];
  var cursor = start;
  while (!cursor.isAfter(endInclusive)) {
    dates.add(cursor);
    switch (frequency) {
      case 'weekly':
        cursor = cursor.add(const Duration(days: 7));
      case 'biweekly':
        cursor = cursor.add(const Duration(days: 14));
      case 'monthly':
        cursor = DateTime(cursor.year, cursor.month + 1, cursor.day, cursor.hour, cursor.minute);
    }
  }
  return dates;
}
```

- [ ] **Step 4: Update the save handler to generate N activities.**

Find the existing save handler (probably something like `_saveActivity` or an `onPressed: () async { ... }` on the Submit button). Wrap the create call:

```dart
Future<void> _submit() async {
  final activityService = context.read<ActivityService>();
  final baseStart = _selectedDateTime!; // the existing date/time field

  List<DateTime> dates;
  if (_repeats) {
    if (_repeatUntil == null) {
      _showError('Please pick an end date for the repeating activity.');
      return;
    }
    dates = _occurrenceDates(baseStart, _frequency, _repeatUntil!);
    if (dates.length > 26) {
      _showError('Please pick an earlier end date — max 26 sessions.');
      return;
    }
    if (dates.isEmpty) {
      _showError('The end date must be on or after the start date.');
      return;
    }
  } else {
    dates = [baseStart];
  }

  setState(() => _saving = true);
  int created = 0;
  for (final dt in dates) {
    final result = await activityService.createActivity(
      // ... existing field arguments, with dateTime: dt ...
    );
    if (result['success'] == true) created++;
  }
  setState(() => _saving = false);

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Created $created session${created == 1 ? '' : 's'}.')),
  );
  context.go(AppRoutes.businessDashboard);
}
```

Adapt field names to match the existing create call signature. Do not introduce new required fields.

- [ ] **Step 5: Smoke-test.**

Run: `flutter run` as a business account → Create an activity → toggle "This activity repeats" → pick Weekly, end date 6 weeks out → save → confirm snackbar "Created 6 sessions." → open the dashboard and confirm 6 activity cards appear with weekly-spaced dates.

Edge cases to try:
- End date before start date → error message
- 26-cap: end date 8 months out on Weekly → error message

- [ ] **Step 6: Commit.**

```bash
git add lib/screens/business/create_activity_screen.dart
git commit -m "feat(business): add weekly/biweekly/monthly recurring activities"
```

---

## Wrap-up

### Final verification

- [ ] **Run full project analyzer.**

```bash
flutter analyze
```
Expected: no new errors introduced. Warnings that already existed before this plan can remain.

- [ ] **Run the test suite.**

```bash
flutter test
```
Expected: `booking_code_test.dart` passes. All other tests (if any) unaffected.

- [ ] **Sanity smoke-test per phase.**

Walk through the verification steps listed at the end of the spec for each phase.

- [ ] **Optional: open a PR per phase** (`phase-a-visual-polish`, `phase-b-nav-restructure`, `phase-c-features`) so the manager can review in chunks. If you prefer, squash into one PR at the end.
