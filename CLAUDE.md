# Hobifi — Flutter App

Activity booking app for Egypt. Users browse/book hobby activities, businesses host them.

## Tech Stack
- **Frontend:** Flutter/Dart, Provider state management, GoRouter navigation
- **Backend:** Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **Payments:** Paymob (EGP currency)
- **Package name:** `hobby_haven` (in imports: `package:hobby_haven/...`)
- **Bundle ID:** `com.hobifi.app` (iOS + Android)
- **Deep link scheme:** `io.supabase.hobifi` (OAuth callback: `io.supabase.hobifi://login-callback/`)
- **Logo asset:** `assets/images/hobifi_logo.png` (orange wordmark, used in splash, feed header, auth screen)

## Design System

### Colors (defined in `lib/theme.dart`)
- Primary: Indigo `#1E1B7A` (light) / `#4A47B8` (dark)
- Secondary: Orange `#E88B3C`
- Accent/Tertiary: Lime `#9BC53D`
- Background: Cream `#F5EED6` (light) / `#0A0A0F` (dark)
- Surface: White (light) / `#16161F` (dark)
- Error/Like: Red `#E53935`

### Typography
- Headings: **Poppins** (bold/extrabold)
- Body: **Urbanist** (regular/medium)
- Use `theme.textTheme.xxx` — never hardcode font families

### Spacing & Radius
- Horizontal screen padding: **20px** consistently
- Card border radius: **16px**
- Chip/pill radius: **9999** (full pill)
- Button radius: **16px**
- Standard button height: **52px**

### Opacity
- Always use `.withValues(alpha: 0.X)` — NEVER `.withOpacity()`

### Currency
- Always display **"EGP"** — never "$" or "USD"

## Shared Widget Library (`lib/widgets/`)

Use these instead of building inline equivalents:

| Widget | File | Usage |
|--------|------|-------|
| `HobifiCard` | `hobifi_card.dart` | Activity cards — `.featured()` for horizontal scroll, default for vertical lists |
| `HobifiChip` | `hobifi_chip.dart` | Filter chips — pill shape, animated selected/unselected states |
| `HobifiStatCard` | `hobifi_stat_card.dart` | Dashboard stat cards with trend badge |
| `HobifiSectionHeader` | `hobifi_section_header.dart` | Section titles with optional "See all" action |
| `HobifiEmptyState` | `hobifi_empty_state.dart` | Empty/error states — icon + message + optional CTA |
| `HobifiShimmer` | `hobifi_shimmer.dart` | Skeleton loading — `.card()`, `.listTile()`, `.box()` |

## UI Patterns

- **Loading states:** Always use `HobifiShimmer` — never bare `CircularProgressIndicator`
- **Empty states:** Always use `HobifiEmptyState` — never inline empty widgets
- **Images:** Always `CachedNetworkImage` with `HobifiShimmer.box()` placeholder
- **Like button:** Use haptic feedback (`HapticFeedback.lightImpact()`)
- **Pull-to-refresh:** On feed, bookings, dashboard, wallet, saved
- **Dark mode:** Always use `colorScheme.xxx` — never hardcode `AppColors.lightXxx`

## Navigation

- Two shells: User (Browse/Tickets/Saved/Profile) and Business (Dashboard/Create/Wallet/Profile)
- Tab navigation: `context.go(AppRoutes.xxx)` (replaces)
- Detail screens: `context.push(...)` (adds to stack)
- Back: `context.pop()`
- **NEVER use `context.pop()` to return to a shell tab route** — it pops out of the ShellRoute entirely. Always use `context.go(AppRoutes.xxx)` to navigate back to a tab.
- Routes defined in `lib/nav.dart` → `AppRoutes` class

## Auth

- Email/password sign-up with auto sign-in (calls `signIn()` after `signUp()` since Supabase returns null session before email confirmation)
- Google Sign-In: native via `google_sign_in` package → Supabase `signInWithIdToken`
- Apple Sign-In: native via `sign_in_with_apple` → Supabase `signInWithIdToken`
- OAuth deep link callback: `io.supabase.hobifi://login-callback/`
- **Dashboard config needed:** Google OAuth (Supabase + Google Cloud Console), Apple Sign-In (Apple Developer + Supabase)
- Auth screen: `lib/screens/auth_screen.dart` — clean layout with logo, role toggle, form card, social buttons
- Google auth helper: `lib/auth/google_auth.dart`

## Ratings

- Activities show star rating only when `reviewCount > 0`
- When `reviewCount == 0`, show "New" badge instead of misleading rating
- DB default rating is 0.0 (fixed from incorrect 5.0 default)

## Project Structure

```
lib/
  models/          — Data models (ActivityModel, BookingModel, UserModel, etc.)
  services/        — Business logic (ActivityService, AuthService, BookingService, etc.)
  screens/
    user/          — Explorer screens (feed, details, bookings, saved, profile, etc.)
    business/      — Host screens (dashboard, create, manage, wallet, profile)
  widgets/         — Shared widget library (HobifiCard, HobifiChip, etc.)
  supabase/        — Edge functions and migrations
  theme.dart       — Design system (colors, typography, spacing)
  nav.dart         — GoRouter config, routes, bottom nav shells
```

## Docs

- **Design spec:** `docs/superpowers/specs/2026-04-05-frontend-overhaul-design.md`
- **Implementation plan:** `docs/superpowers/plans/2026-04-05-frontend-overhaul.md`
- **Login redesign spec:** `docs/superpowers/specs/2026-04-05-login-screen-redesign.md`
- **Login redesign plan:** `docs/superpowers/plans/2026-04-05-login-screen-redesign.md`
- **MVP gap analysis:** `docs/superpowers/specs/2026-03-29-hobifi-mvp-gap-analysis.md`
