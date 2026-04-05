# Hobifi Frontend Overhaul — Design Spec

**Date:** 2026-04-05
**Goal:** Overhaul all frontend screens for a clean, social-media-inspired UI ready for launch. Instagram-influenced feed, Airbnb-style activity details, Stripe-polished business dashboard.

---

## 1. Design System & Shared Components

### Palette (unchanged)
- Primary: Indigo `#1E1B7A` (light) / `#4A47B8` (dark)
- Secondary: Orange `#E88B3C`
- Accent: Lime `#9BC53D`
- Background: Cream `#F5EED6` (light) / `#0A0A0F` (dark)
- Surface: White (light) / `#16161F` (dark)

### Typography (unchanged)
- Headings: Poppins (bold/extrabold)
- Body: Urbanist (regular/medium)

### Spacing & Radius (unchanged)
- Horizontal screen padding: 20px consistently
- Card radius: 16px
- Chip radius: full (pill)
- Button radius: 16px

### New Shared Widgets (`lib/widgets/`)

| Widget | Purpose |
|--------|---------|
| `HobifiCard` | Reusable activity card — hero image, overlay price badge, like button, info row |
| `HobifiChip` | Category filter chip — pill shape, filled when selected (indigo + white text), outlined when not |
| `HobifiStatCard` | Dashboard stat card — value, label, optional trend badge, left-edge gradient accent |
| `HobifiSectionHeader` | Section title + optional "See all" action link |
| `HobifiEmptyState` | Icon + message + optional CTA button for empty/error states |
| `HobifiShimmer` | Skeleton loading placeholder — replaces all bare `CircularProgressIndicator` usage |

### Cross-cutting patterns
- All images: `CachedNetworkImage` with shimmer placeholder
- Loading states: shimmer skeletons, never bare spinners
- Empty states: illustration/icon + descriptive message + CTA
- Haptic feedback: on book, like, and pay actions (`HapticFeedback.lightImpact()`)
- Pull-to-refresh: on feed, bookings, dashboard, wallet

---

## 2. Feed Screen (Explorer) — `lib/screens/user/feed_screen.dart`

### Layout: Vertical card feed

**Header:**
- "Explore" title (Poppins headlineMedium) + user avatar circle (tap → profile)
- Clean, minimal — single row

**Search bar:**
- Rounded pill, search icon left, clear button right when active
- 20px horizontal margin

**Category chips:**
- Horizontal scrollable row below search
- Pill-shaped `HobifiChip` widgets
- Selected: filled indigo, white text + icon
- Unselected: surface color, muted text + icon, subtle outline

**Content sections (when not searching):**

1. **"Trending Near You"** — horizontal scroll
   - Large cards, aspect ratio ~3:4
   - Image fills ~70% of card
   - Gradient scrim at bottom of image
   - Title + price + rating overlaid on scrim
   - Heart button top-right with scale animation

2. **"Upcoming This Week"** — vertical list
   - Standard cards, aspect ratio ~16:9
   - Image top half, info below
   - Info row: title (Poppins semibold), host name (Urbanist muted)
   - Metadata row: star rating, category chip, spots-left pill (orange if < 5 spots)

3. **"New Activities"** — same vertical card format

**Activity card anatomy (`HobifiCard`):**
- Hero image via `CachedNetworkImage` + `HobifiShimmer` placeholder
- Heart button: top-right, white circle bg, scale + color animation on tap
- Price badge: bottom-left on image, indigo pill with white text ("EGP 150")
- Below image: title, host name, metadata row (stars | category | spots left)

**Search results:**
- Same card layout as vertical list, flat (no section headers)
- Loading state: `CircularProgressIndicator` (centered) — acceptable here since it's a transient search state

**Infinite scroll:** Keep existing `_onScroll` pagination logic.

---

## 3. Activity Details Screen — `lib/screens/user/activity_details_screen.dart`

### Collapsing header (SliverAppBar + SliverList)

**Expanded state (~40% screen height):**
- Full-bleed hero image
- Back button (top-left, circular white bg with shadow)
- Share + like buttons (top-right)
- Gradient scrim at bottom of image for text readability

**Collapsed state:**
- Standard app bar height
- Activity title in app bar

**Scrollable body:**

1. **Title + rating row**
   - Activity name: Poppins bold, 22px
   - Star rating + review count: inline, right-aligned or below

2. **Quick info pills**
   - Horizontal row of chips: date, time, location, category
   - Icons + text, surface-colored pills

3. **Description**
   - Expandable: 3-line preview with "Read more" tap to expand
   - Urbanist body text

4. **Host card**
   - Avatar + name + "Hosted by" label
   - Tappable (future: host profile)
   - Surface card with subtle border

5. **Reviews section**
   - Star breakdown (5-star bar chart)
   - Individual review cards: avatar, name, stars, text, date

6. **Map preview** (if location data available)
   - Static map card placeholder (future enhancement)

**Sticky bottom bar:**
- Always visible at bottom of screen
- Left: price in bold ("EGP 150")
- Right: "Book Now" filled button (indigo)
- Surface background with top border shadow

---

## 4. Business Dashboard — `lib/screens/business/dashboard_screen.dart`

### Data-forward with energy

**Header:**
- "Dashboard" title + business avatar
- Greeting: "Good morning, {name}" (time-aware)

**Stat cards (horizontal scroll, 3 cards):**
- Total Revenue (EGP) — big number, trend badge ("+12%" in lime if positive, red if negative)
- Total Bookings — same format
- Active Activities — count
- Card style: surface bg, subtle left-edge accent (indigo→purple gradient strip), rounded 16px
- Numbers animate on first load (count-up)

**Revenue chart:**
- Area chart via `fl_chart`
- Gradient fill: indigo → transparent under the line
- Smooth bezier curves
- Period selector: 7d / 30d / 90d chips (keep existing `_selectedDays` logic)
- Y-axis: EGP amounts
- X-axis: date labels

**Per-activity breakdown:**
- Cards per activity: title, bookings count, revenue, fill rate (linear progress bar, lime fill)
- Tappable → navigate to activity manage screen

**Recent earnings:**
- Clean list of transaction rows
- Each row: activity title, amount (EGP), date, status badge (completed=lime, pending=orange, refunded=red)
- "See all" link to wallet screen

---

## 5. Auth Screen — `lib/screens/auth_screen.dart`

**Keep:** Constellation background animation (distinctive brand element).

**Polish:**
- Tighter vertical spacing in the form section
- Form fields: consistent with `InputDecorationTheme` (rounded 20px, filled)
- Role toggle (User/Business): cleaner pill toggle, not raw buttons
- Sign Up / Sign In toggle: subtle text link, not competing with primary CTA
- Primary CTA button: full-width, indigo filled, 16px radius, 52px height
- Google sign-in button: outlined style, Google icon

---

## 6. Onboarding Screen — `lib/screens/onboarding_screen.dart`

**Keep:** Page flow (interests → city).

**Polish:**
- Interest grid: larger tap targets (min 80px height), subtle scale animation on select
- Selected state: filled with category color + white checkmark overlay
- Unselected: surface card with icon + label
- City input: same form field style as auth
- Progress indicator: dot indicators at bottom showing page 1/2
- Skip button: muted text link top-right
- Continue button: full-width indigo filled

---

## 7. Profile Screen — `lib/screens/user/profile_screen.dart`

**Keep:** Card layout with avatar, stats, settings.

**Polish:**
- Tighter card padding
- Stats row: add "Reviews" count alongside Bookings and Liked
- Interest tags: show user's selected interests as small chips below the role badge
- Edit interests: tap chips to open interest editor (reuse onboarding interest widget)
- Settings section: clean list tiles with leading icon containers (gradient bg like dark mode toggle)
- Sign out: keep at bottom, red outlined

---

## 8. Bookings/Tickets Screen — `lib/screens/user/bookings_screen.dart`

**Card-based list:**
- Each booking card: activity image thumbnail (left, 80x80 rounded), info column (title, date/time, host), status badge (right)
- Status badges: confirmed=lime bg, pending=orange bg, cancelled=red bg, completed=muted
- Tap → ticket screen
- Tab bar or filter chips at top: All / Upcoming / Past
- Empty state: `HobifiEmptyState` — "No bookings yet" + "Explore Activities" CTA

---

## 9. Saved Screen — `lib/screens/user/saved_screen.dart`

**Flat list of liked activities:**
- Same `HobifiCard` widget as feed (vertical card format)
- No section headers, just the list
- Pull-to-refresh
- Empty state: "No saved activities" + "Start Exploring" CTA

---

## 10. Business Wallet — `lib/screens/business/wallet_screen.dart`

**Balance card:**
- Top of screen, large card
- Big balance number (Poppins bold 34px)
- Currency: "EGP" (fix from current "$")
- Subtitle: "Available balance"
- Optional: pending amount in smaller text

**Transaction history:**
- Clean list below balance card
- Each row: activity title, +/- amount, date, status icon
- Status: completed (lime checkmark), pending (orange clock), refunded (red arrow)

---

## 11. Business Profile — `lib/screens/business/business_profile_screen.dart`

Same structure as user profile, adapted for business:
- Business name, email, avatar
- Stats: Total Activities, Total Bookings, Average Rating
- Settings section

---

## 12. Booking Confirm Screen — `lib/screens/user/booking_confirm_screen.dart`

**Order summary card:**
- Activity image + title at top
- Date, time, location details
- Price breakdown: activity price, clear "Total" line
- "Proceed to Payment" CTA button (full-width, indigo)

---

## 13. Payment Screen — `lib/screens/user/payment_screen.dart`

**Keep:** Paymob iframe flow + polling.

**Polish:**
- Clean header: "Payment" + activity title
- Loading/polling state: shimmer or branded animation instead of bare spinner
- Success state: checkmark animation → navigate to ticket

---

## 14. Ticket Screen — `lib/screens/user/ticket_screen.dart`

**Ticket card design:**
- Activity image at top
- Dashed divider (ticket tear effect)
- Below: booking details (date, time, location, booking ID)
- QR code or booking reference
- "Add to Calendar" CTA (future enhancement placeholder — not in MVP)

---

## File Impact Summary

| File | Change Type |
|------|------------|
| `lib/widgets/hobifi_card.dart` | NEW |
| `lib/widgets/hobifi_chip.dart` | NEW |
| `lib/widgets/hobifi_stat_card.dart` | NEW |
| `lib/widgets/hobifi_section_header.dart` | NEW |
| `lib/widgets/hobifi_empty_state.dart` | NEW |
| `lib/widgets/hobifi_shimmer.dart` | NEW |
| `lib/screens/user/feed_screen.dart` | REWRITE |
| `lib/screens/user/activity_details_screen.dart` | REWRITE |
| `lib/screens/user/profile_screen.dart` | MODERATE EDIT |
| `lib/screens/user/bookings_screen.dart` | MODERATE EDIT |
| `lib/screens/user/saved_screen.dart` | MODERATE EDIT |
| `lib/screens/user/booking_confirm_screen.dart` | MODERATE EDIT |
| `lib/screens/user/payment_screen.dart` | LIGHT EDIT |
| `lib/screens/user/ticket_screen.dart` | MODERATE EDIT |
| `lib/screens/business/dashboard_screen.dart` | REWRITE |
| `lib/screens/business/wallet_screen.dart` | MODERATE EDIT |
| `lib/screens/business/business_profile_screen.dart` | LIGHT EDIT |
| `lib/screens/auth_screen.dart` | MODERATE EDIT |
| `lib/screens/onboarding_screen.dart` | MODERATE EDIT |
| `lib/nav.dart` | LIGHT EDIT (bottom nav polish) |
| `lib/theme.dart` | NO CHANGE |

---

## Out of Scope

- New backend/Supabase changes (purely frontend)
- Push notifications, crash reporting (Phase 3 features)
- Map integration (placeholder only)
- Business cashout flow
- New packages: only `shimmer` (for skeleton loading) — already using `cached_network_image`, `fl_chart`, `google_fonts`
