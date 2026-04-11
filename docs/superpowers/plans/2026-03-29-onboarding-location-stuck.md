# Fix Onboarding Location Screen Getting Stuck

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the bug where users get permanently stuck on the location/city page of onboarding with an infinite spinner.

**Architecture:** The root cause is that `_finish()` and `_skip()` in `onboarding_screen.dart` don't handle failures from `updateProfile()`. When `updateProfile()` fails (network error, Supabase timeout), `_saving` stays `true` (spinner forever), and the router redirects back to onboarding because interests were never persisted. The fix adds error handling, resets `_saving` on failure, and shows an error snackbar using the pre-captured `ScaffoldMessenger` pattern (same pattern used in auth_screen.dart).

**Tech Stack:** Flutter, Provider, GoRouter, Supabase

---

### Task 1: Add error handling to `_finish()` in onboarding_screen.dart

**Files:**
- Modify: `lib/screens/onboarding_screen.dart:57-72`

- [ ] **Step 1: Replace `_finish()` with error-handling version**

Replace the existing `_finish()` method (lines 57–72) with:

```dart
Future<void> _finish() async {
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final interests = _selectedInterests.toList();
    final city = _cityController.text.trim();

    final success = await auth.updateProfile(
      interests: interests.isEmpty ? ['All'] : interests,
      city: city.isEmpty ? null : city,
    );

    if (!success) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
      return;
    }

    if (mounted) {
      context.go(AppRoutes.feed);
    }
  }
```

- [ ] **Step 2: Verify the change compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/onboarding_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding_screen.dart
git commit -m "fix: handle updateProfile failure in onboarding _finish()"
```

---

### Task 2: Add error handling to `_skip()` in onboarding_screen.dart

**Files:**
- Modify: `lib/screens/onboarding_screen.dart:50-55`

- [ ] **Step 1: Replace `_skip()` with error-handling version**

Replace the existing `_skip()` method (lines 50–55) with:

```dart
Future<void> _skip() async {
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final success = await auth.updateProfile(interests: ['All']);

    if (!success) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
      return;
    }

    if (mounted) context.go(AppRoutes.feed);
  }
```

- [ ] **Step 2: Verify the change compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/onboarding_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding_screen.dart
git commit -m "fix: handle updateProfile failure in onboarding _skip()"
```

---

### Task 3: Manual smoke test

- [ ] **Step 1: Test happy path**

1. Sign up as a new user
2. Select 3+ interests → tap "Continue"
3. Enter a city name (e.g. "Cairo") → tap "Get Started"
4. Verify: navigates to feed screen, no spinner stuck

- [ ] **Step 2: Test skip path**

1. Sign up as a new user
2. Tap "Skip" on interests page
3. Verify: navigates to feed, no spinner stuck

- [ ] **Step 3: Test failure path (airplane mode)**

1. Sign up as a new user, complete interests page
2. Turn on airplane mode
3. Tap "Get Started" on city page
4. Verify: spinner stops, error snackbar appears, button is tappable again
5. Turn off airplane mode, tap "Get Started" again
6. Verify: navigates to feed
