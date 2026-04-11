# Role-Gated Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent business users from signing in on the Explorer tab and vice versa — each tab only accepts accounts matching that role.

**Architecture:** The current approach of checking the role AFTER `signInWithPassword` fails because Supabase's `onAuthStateChange` listener fires immediately on sign-in, which triggers `notifyListeners()`, which triggers GoRouter's `refreshListenable` redirect — all before our role check runs. The fix requires two changes: (1) suppress the auth state listener during sign-in so the router doesn't redirect prematurely, and (2) validate the role before allowing `_currentUser` to be set and notified.

**Tech Stack:** Flutter, Supabase Auth, GoRouter, Provider

---

## Root Cause Analysis

```
Current broken flow:
1. User taps Sign In on Explorer tab
2. signInWithPassword() succeeds
3. onAuthStateChange fires immediately
4. Listener calls _loadCurrentUser() → sets _currentUser → calls _safeNotify()
5. GoRouter refreshListenable fires → sees isAuthenticated → redirects to /business-dashboard
6. signIn() role check runs — but user is already on the dashboard
```

The fix:
```
Fixed flow:
1. User taps Sign In on Explorer tab
2. signIn() sets _suppressAuthListener = true
3. signInWithPassword() succeeds
4. onAuthStateChange fires — listener sees _suppressAuthListener, does nothing
5. signIn() manually calls _loadCurrentUser()
6. signIn() checks role — MISMATCH → signs out, returns error
7. signIn() sets _suppressAuthListener = false
8. No redirect ever happened — user sees error on auth screen
```

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/services/auth_service.dart` | Modify | Add `_suppressAuthListener` flag, use it in listener + signIn/signUp |
| `lib/screens/auth_screen.dart` | No change needed | Already passes role correctly, already shows error snackbar |
| `lib/nav.dart` | No change needed | Router redirect logic is correct — it just shouldn't fire prematurely |

---

### Task 1: Add suppression flag to AuthService and gate the listener

**Files:**
- Modify: `lib/services/auth_service.dart:10-50` (fields + initialize + listener)

- [ ] **Step 1: Add the `_suppressAuthListener` field**

In `auth_service.dart`, add a new boolean field alongside the other private fields:

```dart
class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _disposed = false;
  bool _suppressAuthListener = false;  // ADD THIS
  StreamSubscription<AuthState>? _authSub;
  Future<void>? _loadingProfile;
```

- [ ] **Step 2: Gate the onAuthStateChange listener**

In the `initialize()` method, modify the listener to check the suppression flag:

```dart
_authSub = SupabaseConfig.auth.onAuthStateChange.listen((data) {
  if (_suppressAuthListener) return;  // ADD THIS CHECK
  final session = data.session;
  if (session != null) {
    _loadingProfile = _loadCurrentUser();
  } else {
    _currentUser = null;
    _safeNotify();
  }
});
```

- [ ] **Step 3: Verify no compile errors**

Run: `flutter analyze lib/services/auth_service.dart`
Expected: No errors (warnings about unused field are fine)

- [ ] **Step 4: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "feat(auth): add listener suppression flag for role-gated login"
```

---

### Task 2: Use suppression flag in signIn to prevent premature redirect

**Files:**
- Modify: `lib/services/auth_service.dart:116-169` (signIn method)

- [ ] **Step 1: Wrap signIn with suppression flag**

Replace the entire `signIn` method with:

```dart
Future<Map<String, dynamic>> signIn(String email, String password, UserRole role) async {
  _isLoading = true;
  _safeNotify();

  // Suppress the auth state listener so GoRouter doesn't redirect
  // before we've checked the user's role.
  _suppressAuthListener = true;

  try {
    final response = await SupabaseConfig.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      _isLoading = false;
      _suppressAuthListener = false;
      _safeNotify();
      return {'success': false, 'message': 'Sign in failed. Please check your credentials.'};
    }

    // Manually load the profile (listener is suppressed)
    await _loadCurrentUser();

    // Check role BEFORE allowing the router to see the authenticated state
    if (_currentUser != null && _currentUser!.role != role) {
      final actualTab = _currentUser!.role == UserRole.user ? 'Explorer' : 'Host';
      await SupabaseConfig.auth.signOut();
      _currentUser = null;
      _isLoading = false;
      _suppressAuthListener = false;
      _safeNotify();
      return {
        'success': false,
        'message': 'This account is registered as a $actualTab. Please switch to the $actualTab tab to sign in.',
      };
    }

    // Role matches — allow the router to see the authenticated user
    _isLoading = false;
    _suppressAuthListener = false;
    _safeNotify();  // THIS is when GoRouter finally fires and redirects
    return {'success': true};
  } on AuthException catch (e) {
    debugPrint('Sign in failed: ${e.message}');
    _isLoading = false;
    _suppressAuthListener = false;
    _safeNotify();
    String message = 'Sign in failed. Please check your credentials.';
    if (e.message.contains('Email not confirmed')) {
      message = 'Please verify your email address before signing in.';
    } else if (e.message.contains('Invalid')) {
      message = 'Invalid email or password.';
    }
    return {'success': false, 'message': message};
  } catch (e) {
    debugPrint('Sign in failed: $e');
    _isLoading = false;
    _suppressAuthListener = false;
    _safeNotify();
    return {'success': false, 'message': 'An error occurred. Please try again.'};
  }
}
```

- [ ] **Step 2: Verify no compile errors**

Run: `flutter analyze lib/services/auth_service.dart`
Expected: No errors

- [ ] **Step 3: Manual test — business user on Explorer tab**

1. Open app in Chrome
2. Stay on "Explorer" tab
3. Enter a business account's email/password
4. Tap Sign In
5. Expected: Red snackbar says "This account is registered as a Host. Please switch to the Host tab to sign in."
6. Expected: User stays on the auth screen, NOT redirected to dashboard

- [ ] **Step 4: Manual test — business user on Host tab**

1. Switch to "Host" tab
2. Enter same business email/password
3. Tap Sign In
4. Expected: Redirected to business dashboard

- [ ] **Step 5: Manual test — explorer user on Host tab**

1. Switch to "Host" tab
2. Enter an explorer account's email/password
3. Tap Sign In
4. Expected: Red snackbar says "This account is registered as a Explorer. Please switch to the Explorer tab to sign in."

- [ ] **Step 6: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "fix(auth): role-gated login prevents cross-tab sign-in"
```

---

### Task 3: Apply suppression flag to signUp as well

**Files:**
- Modify: `lib/services/auth_service.dart:171+` (signUp method)

- [ ] **Step 1: Add suppression to signUp**

SignUp doesn't have the same problem (the role is set at creation time), but we should still suppress the listener to prevent a race between the profile INSERT and the router redirect. Wrap the signUp method:

```dart
Future<Map<String, dynamic>> signUp(String email, String password, String name, UserRole role) async {
  _isLoading = true;
  _safeNotify();

  _suppressAuthListener = true;  // ADD: suppress during signup too

  try {
    final response = await SupabaseConfig.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: null,
    );

    // ... rest of method stays the same until the return statements ...
```

Add `_suppressAuthListener = false;` before every return statement and in every catch block, same pattern as signIn.

- [ ] **Step 2: Verify no compile errors**

Run: `flutter analyze lib/services/auth_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "fix(auth): suppress listener during signup to prevent race condition"
```
