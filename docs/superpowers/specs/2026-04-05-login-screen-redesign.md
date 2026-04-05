# Login Screen Redesign

**Date:** 2026-04-05
**Status:** Approved
**File:** `lib/screens/auth_screen.dart`

## Goal

Replace the current heavy, animation-laden login screen with a clean, minimal design that uses the app's existing design system. The current screen has a constellation animation, gradient backgrounds, radial glows, and 3 animation controllers — all of which make it feel "too much."

## Layout (top to bottom, centered)

1. **Top spacer** — ~15% of screen height
2. **Logo block** — orange icon + "HOBIFI" + tagline
3. 24px gap
4. **Explorer/Host toggle** — compact segmented pill
5. 24px gap
6. **Form card** — email, password, forgot password link, name field (sign-up), primary button
7. 20px gap
8. **"or continue with" divider**
9. 12px gap
10. **Google & Apple buttons** — side by side, outlined
11. **Sign up/in toggle text**
12. **Terms text**

Wrapped in `SingleChildScrollView` for small screens.

## Visual Styling

### Background
- Solid `colorScheme.surface` (cream light / dark surface dark)
- No gradients, no animations, no custom painters

### Logo Block
- Orange rounded-square container: 48px, radius 14, `Icons.explore_rounded` 24px white
- "HOBIFI": `headlineMedium`, Poppins bold, `colorScheme.onSurface`, letter-spacing 3
- Tagline: `bodyMedium`, `colorScheme.onSurface` at alpha 0.5
  - Sign-in: "Discover What Moves You"
  - Sign-up: "Begin Your Journey"

### Role Toggle
- Container: `colorScheme.surfaceContainerHighest` background, full pill radius (9999)
- Selected: `colorScheme.primary` (indigo) fill, white text, bold
- Unselected: transparent, `colorScheme.onSurface` at alpha 0.5
- Compact sizing: horizontal padding 16, vertical 8

### Form Card
- `colorScheme.surfaceContainer` background (slightly elevated from page), `colorScheme.outlineVariant` border (1px), 16px radius
- Padding: 24px all around
- Input fields: filled `colorScheme.surfaceContainerLowest`, 14px radius, subtle border
- Focus border: orange (Explorer mode) / lime (Host mode)
- Primary button: 52px height, 16px radius, filled orange/lime, bold white text

### Social Buttons
- Outside the card, on the background surface
- Outlined: `colorScheme.outline` border, `colorScheme.onSurface` text
- 52px height, 14px radius

### Dark Mode
- All colors via `colorScheme.xxx` — adapts automatically
- Orange and lime accent colors stay hardcoded as brand colors

## What Gets Removed

- `_ConstellationNode`, `_ConstellationEdge`, `_ConstellationPainter` — entire classes deleted
- 3 `AnimationController`s: `_constellationController`, `_pulseController`, `_heroController`
- `_initConstellationData()`, `_initAnimations()` methods
- `TickerProviderStateMixin` (no longer needed)
- Gradient background (`LinearGradient` with dark indigo colors)
- Radial glow `Positioned` containers
- `ShaderMask` on brand name
- `dart:math` import

## What Stays Unchanged

- All business logic: `_handleAuth()`, `_handleGoogleSignIn()`, `_handleAppleSignIn()`, `_waitForProfile()`
- `ForgotPasswordDialog` (multi-step OTP flow) — untouched
- `_showEmailConfirmationDialog()`, `_showErrorSnackBar()`
- `AnimatedSize` on the name field expand/collapse
