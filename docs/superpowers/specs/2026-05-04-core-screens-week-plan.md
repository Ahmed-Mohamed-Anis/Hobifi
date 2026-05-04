# Core Screens Week Plan — Design Spec
**Date:** 2026-05-04  
**Scope:** Auth, Feed, Dashboard — missing features and refinements  
**Stretch goal:** Google + Apple Sign-In setup (guided alongside main work)

---

## 1. Auth Screen

### 1.1 Email OTP Verification
Merge the existing WIP OTP flow (already built in `lib/screens/auth_screen.dart`).

Behaviour:
- After sign-up, show the 6-digit code screen instead of the old confirmation dialog
- Auto-submit when the 6th digit is entered (no need to tap Verify button)
- Show a loading indicator during verification
- Clear error message on any new input
- Resend button with 30-second cooldown (already built)

Files: `lib/screens/auth_screen.dart`, `lib/services/auth_service.dart`

### 1.2 Silent Re-auth on Cold Launch
Goal: returning users with a valid session never see the auth screen.

Root cause: `AuthService.initialize()` is async. While it's loading, `isAuthenticated` is false, so GoRouter briefly redirects to `/auth` before the session loads — causing a flash.

Fix:
- Add `isInitializing` bool to `AuthService` (true during `initialize()`, false after)
- In GoRouter redirect: if `authService.isInitializing`, return `null` (stay put, don't redirect yet)
- Once `isInitializing` becomes false, `notifyListeners()` triggers a redirect re-evaluation — user lands on feed/dashboard directly
- The splash screen absorbs the wait visually (already shown during init)

Files: `lib/services/auth_service.dart`, `lib/nav.dart` (redirect guard)

### 1.3 Stretch Goal — Social Sign-In Setup
Google and Apple Sign-In code already exists. What's missing is external configuration.

**Google:**
1. Create OAuth 2.0 credentials in Google Cloud Console (iOS client ID + Web client ID)
2. Add `GOOGLE_WEB_CLIENT_ID` to Supabase Auth settings
3. Add iOS client ID to `Info.plist` / `google-services.json`

**Apple:**
1. Enable Sign In with Apple capability in Apple Developer portal
2. Register Service ID in Apple Developer portal
3. Add Apple credentials to Supabase Auth settings

These will be done interactively with user guidance — not automated.

---

## 2. Feed Screen

### 2.1 Trending Experiences Fix
Current: shows random activities  
Fixed:
- Filter: `activity.reviewCount > 0`
- Sort: `rating` descending
- Padding: if fewer than 5 results, append newest activities (sorted by `createdAt` desc) until 5 items, no duplicates

Files: `lib/utils/feed_filters.dart`, `lib/screens/user/feed_screen.dart`

### 2.2 Popular Near You Fix
Current: no distance sorting  
Fixed:
- Sort by distance ascending using `LocationService.currentPosition`
- If location permission is off or position is null: show `HobifiEmptyState` with icon `Icons.location_off_rounded`, message "Enable location to see activities near you", CTA button "Enable Location" → opens `openAppSettings()` (from `geolocator` package)

Files: `lib/utils/feed_filters.dart`, `lib/screens/user/feed_screen.dart`

### 2.3 Friday & Saturday Fix
Current: filters by `spotsLeft > 5`  
Fixed: filter by `activity.dateTime.weekday == DateTime.friday || activity.dateTime.weekday == DateTime.saturday`

Files: `lib/utils/feed_filters.dart`

### 2.4 Search History
- Store last 5 unique search terms in `SharedPreferences` key `search_history`
- When search bar is focused AND query is empty: show a horizontal chip row labelled "Recent" with each stored term
- Tapping a chip: fills the search bar and triggers search
- Each chip has an `×` button that removes that term from history
- New search term is prepended to history on submit; list trimmed to 5

Files: `lib/screens/user/feed_screen.dart`

### 2.5 Suggested Searches
- When search bar is focused AND query is empty AND history is empty: show a chip row labelled "Popular" with 4 hardcoded suggestions: `Pottery`, `Yoga`, `Cooking class`, `Photography`
- Tapping fills the search bar and triggers search
- No persistence — always the same 4

Files: `lib/screens/user/feed_screen.dart`

---

## 3. Dashboard Screen

### 3.1 Booking Management
A full bookings list accessible from the dashboard.

Entry point: "All Bookings" button/link below the Today's Schedule section (or a new section header with "See all").

UI:
- Full-screen pushed route (not a tab)
- Status filter tabs at top: All / Confirmed / Pending / Completed / Cancelled
- Each row: activity thumbnail, activity name, user name, date, amount (EGP), status badge
- Pull-to-refresh
- Empty state per filter tab
- Tapping a row: shows a bottom sheet with booking detail (activity, user, amount, booking code, status, cancellation option if confirmed)

Data: query `bookings` joined with `activities` filtered by `activities.business_id = currentUser.id`, ordered by `created_at` desc.

Files: new `lib/screens/business/business_bookings_screen.dart`, `lib/nav.dart` (new route), `lib/services/booking_service.dart` (new `loadBusinessBookingsAll()` method)

### 3.2 Activity Performance
Replace current "Your Activities" top-3 section with a full scrollable list.

Changes:
- Remove the 3-item cap
- Add sort control row: Revenue / Bookings / Fill Rate (pill tabs, defaults to Revenue)
- Each activity card: name, thumbnail, bookings count, revenue (EGP), fill rate progress bar, star rating
- Tapping opens the existing `ActivityManageScreen`

Files: `lib/screens/business/dashboard_screen.dart`

### 3.3 Analytics Charts
Add two new chart types alongside the existing Revenue chart.

Chart selector: 3-tab pill row replacing the current period selector position — **Revenue · Bookings · Fill Rate**
- The existing 7 / 30 / 90 day period selector stays below the chart type tabs

**Bookings chart:** daily booking count for selected period, same line chart style as revenue  
**Fill rate chart:** average fill rate (spotsLeft / maxGuests) per day for selected period, shown as a percentage line chart (0–100%)

Data queries:
- Bookings chart: aggregate `bookings` by `created_at` date, count per day
- Fill rate: average `(maxGuests - spotsLeft) / maxGuests * 100` per day from `activities` joined with date range

Files: `lib/screens/business/dashboard_screen.dart`

### 3.4 In-App Notification Inbox
A notification bell in the dashboard header.

UI:
- Bell icon (`Icons.notifications_outlined`) in top-right of dashboard header
- Unread badge: red dot with count if unread > 0
- Tapping: opens a modal bottom sheet "Notifications"
- Each row: title (bold), body, relative time (Today / Yesterday / N days ago)
- Unread rows have a subtle left border accent
- All marked as read when the sheet is opened
- Empty state: "No notifications yet"

Data: new `notifications` table in Supabase (id, user_id, title, body, read, created_at). Edge functions already write to `device_tokens` — they will also insert a row into `notifications` alongside FCM dispatch.

Scope note: inbox UI is dashboard (business) only this week. User-role notification inbox is out of scope — users receive push notifications via FCM but have no in-app inbox yet.

New migration: `20260504_notifications_inbox.sql`  
New service: `lib/services/notification_service.dart`  
Files: `lib/screens/business/dashboard_screen.dart`

---

## Execution Order (User Impact First)

| Day | Work |
|-----|------|
| 1 | Auth: OTP merge + silent re-auth |
| 2 | Feed: trending + popular + weekend filters + empty state |
| 3 | Feed: search history + suggested searches |
| 4 | Dashboard: booking management screen |
| 5 | Dashboard: activity performance list |
| 6 | Dashboard: analytics charts (bookings + fill rate) |
| 7 | Dashboard: notification inbox + stretch social login setup |

---

## Out of Scope This Week
- Friends/social features
- Content moderation UI (reports are stored, no admin UI)
- Offline-first caching beyond what's already built
- Push notification delivery testing (requires Firebase config)
