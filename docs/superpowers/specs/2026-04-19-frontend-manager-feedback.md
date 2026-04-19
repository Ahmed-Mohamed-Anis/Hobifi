# Frontend Manager Feedback — Design Spec

**Date:** 2026-04-19
**Scope:** UI/UX changes from non-technical manager review
**Approach:** Phased (A → B → C), each shippable independently

---

## Source Feedback

Manager's bullet points, verbatim:

- We need to highlight the sign up more
- The footer buttons don't match the page names on top
- In My Hobbies let's put also add Liked (saved) — it shouldn't be its own button
- Completed and Cancelled should be in the Profile page
- For the tickets, if we put a QR code that means we need the system so the service providers can scan it
- The third button should be Friends (inside the page write "coming soon")
- The dark mode color changes aren't nice
- The service providers need a repeat button for activities that repeat
- Will not be able to add stories?
- We should put a little more experience in the sign up page for both users and providers

## Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| Tickets QR | **Drop QR.** Show 6-digit booking code; provider manually taps "Mark attended" on their booking list. No scanner system built. |
| Stories | **Defer.** Out of scope. Noted in Future Work. |
| Sign-up "more experience" | **Both** visual polish on auth screen **and** wizard onboarding for each role. |
| Business repeat activities | **Simple generation** — toggle on create form generates N independent activity rows. No series concept. |
| Dark mode | **Targeted palette pass.** No architectural redesign. |

## Out of Scope

- Instagram-style stories (capture, upload, TTL, feed placement)
- QR scanner for providers
- True recurring-activity series concept (parent/child edit-all-or-one)
- Full dark-mode redesign (just palette tuning)

---

## Phase A — Visual Polish

Low-risk, shippable on its own. No data-model changes.

### A1. Auth screen — Sign Up prominence

**Problem:** Sign Up is currently a tiny gray `TextButton` at the bottom of `lib/screens/auth_screen.dart`. New users miss it.

**Change:**
- Add a pill-style segmented control `Sign In | Sign Up` directly under the logo block, styled like the existing Explorer/Host role toggle.
- Tapping drives the existing `_isSignUp` state — no behavior change in the form.
- Remove the bottom "Don't have an account? Sign Up" text link.
- Keep `Forgot Password?` inline in the form (already there) when in Sign In mode.

**File:** `lib/screens/auth_screen.dart`

### A2. Dark mode — palette pass

**Problem:** `lib/theme.dart` defines only two surface levels (`#0A0A0F` / `#16161F`) and a muddy primary `#4A47B8`. Flutter auto-fills missing Material 3 surface containers, producing flat, inconsistent cards and chips.

**Change:** Expand `AppColors` dark constants and pass them explicitly into `ColorScheme.dark(...)`. No widget changes — all widgets already read `colorScheme.xxx`.

| Role | Current | New |
|---|---|---|
| Background | `#0A0A0F` | `#0F0D1A` |
| Surface | `#16161F` | `#1A1825` |
| surfaceContainerLow | auto | `#201D2E` |
| surfaceContainer | auto | `#26223A` |
| surfaceContainerHigh | auto | `#2D2947` |
| surfaceContainerHighest | auto | `#353055` |
| Primary | `#4A47B8` | `#6E6AE8` |
| Secondary (orange) | `#E88B3C` | `#F2A15E` |
| Tertiary (lime) | `#9BC53D` | `#B6D25A` |
| onSurface | `#FFFFFF` | `#F0EEFF` |
| Divider/outline | `#25252E` | `#3A3750` |
| Secondary text | `#A0A0B8` | `#A39DBD` |

**Light theme:** unchanged.

**Verification:** smoke-test feed, activity details, bookings, profile, auth in dark mode. Fix any screen inline if it still looks off.

**File:** `lib/theme.dart`

---

## Phase B — Navigation & Ticket Restructure

The largest UX change. All under-user-shell + ticket screen + business dashboard check-in.

### B1. Footer ↔ page-header alignment

Rename footer to match canonical page-header copy.

| Position | Current footer label | New footer label | Page-header copy |
|---|---|---|---|
| 1 | Browse | **Discover** | Discover |
| 2 | Tickets | **My Hobbies** | My Hobbies |
| 3 | Saved | **Friends** (new) | Friends |
| 4 | Profile | Profile | Profile |

Icon for position 3: `Icons.people_outline_rounded` / `Icons.people_rounded`.

**File:** `lib/nav.dart` (labels + icons in `_UserShellScreen`).

### B2. Saved folded into My Hobbies

My Hobbies screen (`lib/screens/user/bookings_screen.dart`) gets two top-level tabs (Material `TabBar` under the header, not chips):

- **Upcoming** — existing upcoming/confirmed bookings list
- **Liked** — contents of the current `SavedScreen`, rendered inside this screen

`SavedScreen` widget is kept but its content is embedded as the second tab. The `/saved` route is removed from the user shell. Any `context.go(AppRoutes.saved)` or `context.push(AppRoutes.saved)` call sites are updated to navigate to `/bookings` (optionally with an initial-tab argument via `GoRouterState.extra`).

### B3. Completed / Cancelled moved to Profile

Remove the Upcoming / Completed / Cancelled filter chips from My Hobbies (now replaced by the two tabs above).

On the Profile screen, add a "Booking History" list row that pushes to a new sub-screen `BookingHistoryScreen`:

- Route: `/profile/history` (outside user shell, stacked push)
- Two sub-tabs on that screen: **Completed** | **Cancelled**
- Each tab renders the same `BookingCard` widget filtered by status

**Files:**
- `lib/screens/user/bookings_screen.dart` (remove chips, add tabs)
- `lib/screens/user/saved_screen.dart` (export body as a sub-widget so it can be embedded)
- `lib/screens/user/profile_screen.dart` (new "Booking History" row)
- `lib/screens/user/booking_history_screen.dart` (new)
- `lib/nav.dart` (add route, remove saved route)

### B4. Friends tab (Coming Soon)

- New screen `lib/screens/user/friends_screen.dart`
- Renders `HobifiEmptyState`: `Icons.people_outline_rounded`, title "Friends coming soon", subtitle "Meet people who share your hobbies — launching in a future update." No CTA.
- New route `AppRoutes.friends = '/friends'` added as a child of the user `ShellRoute`.

### B5. Tickets — QR → booking code + provider check-in

**Ticket screen (`lib/screens/user/ticket_screen.dart`):**
- Remove the QR code widget.
- Show a large, centered 6-digit booking code (format: `XXX-XXX`, e.g. `A3F-91K`).
- Code is derived deterministically from `booking.id` — first 6 chars of a base32-encoded hash. No DB migration.
- Caption under the code: "Show this code to the host."

**Provider side:**
- On the business dashboard's attendee/booking list for each activity, each upcoming booking gets a "Mark attended" button next to the attendee name.
- Tapping shows a confirmation dialog ("Mark <name> as attended?") → on confirm, updates the booking status to `completed` via existing `BookingService` logic.
- The same 6-digit code is shown beside each attendee name so the provider can verbally cross-check at the door.
- After marking attended, the row grays out in place with a "Checked in" badge and can't be toggled back (idempotent).

**Files:**
- `lib/screens/user/ticket_screen.dart` (remove QR, show code)
- `lib/screens/business/activity_manage_screen.dart` (mark-attended button)
- `lib/services/booking_service.dart` (add `markAttended(bookingId)` helper that sets status = completed)
- Utility: `lib/utils/booking_code.dart` (deterministic `bookingCodeFor(String bookingId)` function)

---

## Phase C — Features

Signup experience + recurring activities. Ships after B.

### C1. Signup wizard — both roles

**User side (mostly built):**
- Existing `OnboardingScreen` (interests) already triggers for new user-role accounts with empty interests. No logic change.
- Polish: warmer welcome copy on first frame ("Welcome to Hobifi — let's find what moves you"), optional progress pill "Step 1 of 1" for consistency with business wizard.

**Business side (new):**
- After business signup, router redirects to new `BusinessOnboardingScreen` instead of directly to dashboard.
- Redirect trigger: `user.role == business && business_onboarded == false`.
- Two steps:
  - **Step 1 — Business basics** (required): business name, category dropdown (fitness / arts / food / music / outdoor / other), city (Cairo / Alexandria / Giza / other).
  - **Step 2 — Tell people about you** (skippable): short description (max 240 chars), optional cover photo upload to existing Supabase storage bucket.
- Finish → set `business_onboarded = true` on user row → navigate to dashboard.

**Schema:**
- New column `business_onboarded boolean default false not null` on the users/profiles table.
- Migration in `lib/supabase/migrations/`.

**Auth-screen polish (tied to signup):**
- When `_isSignUp == true`, show a small 2-line benefit strip under the logo block. Copy switches with role toggle:
  - Explorer: "Discover local hobbies" / "Book and meet real people"
  - Host: "Host your passion" / "Get paid in EGP"
- Sign-In mode: no benefit strip (keeps that flow tight).

**Files:**
- `lib/screens/business/business_onboarding_screen.dart` (new, 2 steps)
- `lib/screens/onboarding_screen.dart` (copy polish + progress)
- `lib/screens/auth_screen.dart` (benefit strip in sign-up mode)
- `lib/nav.dart` (new business-onboarding route + redirect rule in top-level `redirect`)
- `lib/models/user_model.dart` (`businessOnboarded` field)
- `lib/services/auth_service.dart` (load/expose the flag)
- `lib/supabase/migrations/<timestamp>_add_business_onboarded.sql`

### C2. Recurring activities — generate N rows

**Create Activity screen (`lib/screens/business/create_activity_screen.dart`):**

Add a "Repeats" section below the date/time picker:

- Checkbox: "This activity repeats"
- When checked:
  - Frequency dropdown: Weekly / Every 2 weeks / Monthly
  - End date picker (required; validation error if > 6 months from start)

**On save:**
- Compute occurrence dates from start-date through end-date at the chosen frequency.
- Cap at 26 occurrences. Validation error if exceeded ("Please pick an earlier end date — max 26 sessions.").
- Insert N activity rows by calling existing `ActivityService.createActivity` in a loop (or a new batch helper that wraps it). Each row is a plain activity with its own date/time; all other fields identical.
- Success snackbar: "Created N sessions of '<title>'." Navigate to business dashboard.

**Constraints (intentional, per Approach A):**
- No `series_id` column. Each generated activity is fully independent.
- Editing one does not edit others.
- Cancelling one does not cancel others.
- Bookings attach to each specific instance, as they do today.

**Files:**
- `lib/screens/business/create_activity_screen.dart` (repeat section + generation)
- `lib/services/activity_service.dart` (optional `createRecurringActivities(...)` batch helper — or just loop `createActivity`)

---

## File Change Summary

**Phase A:**
- `lib/screens/auth_screen.dart`
- `lib/theme.dart`

**Phase B:**
- `lib/nav.dart`
- `lib/screens/user/bookings_screen.dart`
- `lib/screens/user/saved_screen.dart`
- `lib/screens/user/profile_screen.dart`
- `lib/screens/user/booking_history_screen.dart` (new)
- `lib/screens/user/friends_screen.dart` (new)
- `lib/screens/user/ticket_screen.dart`
- `lib/screens/business/activity_manage_screen.dart`
- `lib/services/booking_service.dart`
- `lib/utils/booking_code.dart` (new)

**Phase C:**
- `lib/screens/business/business_onboarding_screen.dart` (new)
- `lib/screens/onboarding_screen.dart`
- `lib/screens/auth_screen.dart`
- `lib/screens/business/create_activity_screen.dart`
- `lib/services/activity_service.dart`
- `lib/nav.dart`
- `lib/models/user_model.dart`
- `lib/services/auth_service.dart`
- `lib/supabase/migrations/<timestamp>_add_business_onboarded.sql`

---

## Verification per phase

- **Phase A:** Smoke-test auth screen (both modes, both roles) and the five main screens in dark mode.
- **Phase B:** Smoke-test nav (all 4 tabs), My Hobbies (both sub-tabs, refresh behavior), Profile → Booking History, Friends screen, ticket screen (code visible, no QR), provider mark-attended flow end-to-end on a test booking.
- **Phase C:** Smoke-test business signup → onboarding → dashboard, user signup → interests → feed, auth benefit strip copy per role, create a weekly recurring activity and verify N rows appear on the dashboard.

---

## Future Work (deferred)

- Instagram-style stories (capture, upload, 24h TTL, feed strip)
- Provider QR scanner (upgrade from manual mark-attended)
- True recurring-activity series concept (`series_id` + edit-all vs edit-one semantics)
- Full dark-mode redesign if the palette pass isn't enough
