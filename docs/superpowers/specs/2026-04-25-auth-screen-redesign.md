# Auth Screen Redesign

**Date:** 2026-04-25
**Status:** Approved
**File:** `lib/screens/auth_screen.dart`

## Goal

Redesign the auth screen to match an Instagram/Facebook-style flow: users are greeted with sign-up as the primary experience, and sign-in is a secondary action anchored at the bottom. The screen stays single-screen — sign-up and sign-in are two in-place animated states of the same widget.

## State Model

Two boolean state variables drive the entire screen:

- `_isSignUp` (default: `true`) — sign-up vs sign-in mode
- `_isUser` (default: `true`) — Explorer vs Host role

Sign-up mode defaults to Explorer. The user can switch to Host via a "Sign up as a Host →" text link. The role toggle pill is only rendered in sign-in mode (returning users need to pick their role to land on the correct shell).

## Layout (top to bottom)

```
[ Logo image — 150px, centered ]
[ Headline ]           ← animated per mode/role
[ Subtext ]            ← animated per mode/role

[ Role pill — sign-in mode only, AnimatedSize ]

[ Form card ]
  ├── Name field        ← AnimatedSize, sign-up only
  ├── Email field
  ├── Password field    ← show/hide toggle (obscureText)
  └── Forgot Password?  ← sign-in only, right-aligned

[ "Sign up as a Host →" link — sign-up only ]

[ "Create Account" / "Sign In" primary button — 52px, filled, accent color ]

[ ── or continue with ── divider ]
[ Google ]  [ Apple ]

[ Bottom mode-switch link ]
  sign-up mode: "Already have an account? Sign in"
  sign-in mode: "Don't have an account? Sign up"
```

## Animations

All transitions are in-place when `_isSignUp` toggles:

| Element | Animation | Duration |
|---|---|---|
| Headline + subtext | `AnimatedSwitcher` crossfade | 200ms |
| Name field | `AnimatedSize` collapse/expand | 250ms, easeInOut |
| Forgot Password link | `AnimatedSize` appear/disappear | 200ms |
| Role pill | `AnimatedSize` appear/disappear | 200ms |
| Host link | `AnimatedSwitcher` fade | 200ms |
| Bottom link text | `AnimatedSwitcher` crossfade | 200ms |
| CTA button label | Text swap inline | — |

## Headline Copy

| Mode | Role | Headline | Subtext |
|---|---|---|---|
| Sign Up | Explorer | "Discover local hobbies" | "Book and meet real people" |
| Sign Up | Host | "Host your passion" | "Get paid in EGP" |
| Sign In | Any | "Welcome back" | "Sign in to continue" |

## Component Details

### Hero Section
- Logo: `Image.asset('assets/images/hobifi_logo.png')`, height 150, centered
- Headline: `theme.textTheme.titleLarge`, `fontWeight: w800`
- Subtext: `theme.textTheme.bodySmall`, `alpha: 0.55`

### "Sign up as a Host →" Link
- Visible in sign-up mode only (`AnimatedSwitcher`)
- Color: `AppColors.lime`, `bodySmall`, `fontWeight: w600`, centered
- Tapping sets `_isUser = false`, headline/subtext update instantly

### Role Pill (sign-in only)
- Reuses existing `_buildRoleToggle()` — no visual change
- Wrapped in `AnimatedSize`, appears above the form card in sign-in mode

### Password Field Fix
- Adds `_obscurePassword` bool (default: `true`)
- `suffixIcon` is an `IconButton` that toggles between `visibility_off_rounded` and `visibility_rounded`
- Fixes the current static non-functional eye icon

### Bottom Mode-Switch Link
- `RichText` with two `TextSpan`s: muted label + bold tappable action word
- Tappable span uses `TapGestureRecognizer` to call `setState(() => _isSignUp = !_isSignUp)`
- Pinned near bottom via `Spacer()` in the column

### Removed
- `_buildModeToggle()` method and its Sign In / Sign Up pill tabs — deleted entirely
- `_buildRoleToggle()` call at the top-level layout — moved inside `AnimatedSize` conditional

## Error Handling
No changes. Existing `SnackBar` pattern and email confirmation dialog are preserved.

## Code Review
After implementation, dispatch a sub-agent using `superpowers:requesting-code-review` to review the changed file for code quality, dead code, and adherence to the Hobifi design system.
