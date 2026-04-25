# Auth Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the auth screen to an Instagram-style flow — sign-up greets the user, sign-in is a secondary action at the bottom, with in-place animation between modes.

**Architecture:** All changes are confined to `lib/screens/auth_screen.dart`. The screen stays a single `StatefulWidget` with `_isSignUp` (default `true`) and `_isUser` (default `true`) driving all conditional rendering. No new files, no new services, no new routes.

**Tech Stack:** Flutter, Dart, existing `AppColors` / `theme.textTheme` design tokens.

**Spec:** `docs/superpowers/specs/2026-04-25-auth-screen-redesign.md`

---

### Task 1: Fix default state to sign-up

**Files:**
- Modify: `lib/screens/auth_screen.dart:17`

- [ ] **Step 1: Change `_isSignUp` default to `true`**

In `_AuthScreenState`, change:
```dart
bool _isSignUp = false;
```
to:
```dart
bool _isSignUp = true;
```

- [ ] **Step 2: Analyze**
```bash
flutter analyze lib/screens/auth_screen.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**
```bash
git add lib/screens/auth_screen.dart
git commit -m "fix(auth): default to sign-up mode on launch"
```

---

### Task 2: Remove the Sign In / Sign Up mode toggle pill

**Files:**
- Modify: `lib/screens/auth_screen.dart`

- [ ] **Step 1: Delete `_buildModeToggle()` and `_buildModeTab()` methods**

Remove the entire `_buildModeToggle` method and `_buildModeTab` method (the two methods starting with `Widget _buildModeToggle` and `Widget _buildModeTab`).

- [ ] **Step 2: Remove the mode toggle call and its surrounding spacing from `build()`**

In `build()`, delete these lines:
```dart
              // Sign In / Sign Up mode toggle (NEW)
              _buildModeToggle(colorScheme),

              const SizedBox(height: 12),
```

- [ ] **Step 3: Analyze**
```bash
flutter analyze lib/screens/auth_screen.dart
```
Expected: No issues.

- [ ] **Step 4: Commit**
```bash
git add lib/screens/auth_screen.dart
git commit -m "refactor(auth): remove mode toggle pill — switching driven by bottom link"
```

---

### Task 3: Fix password show/hide toggle

**Files:**
- Modify: `lib/screens/auth_screen.dart`

- [ ] **Step 1: Add `_obscurePassword` state variable**

In `_AuthScreenState`, next to the other boolean fields:
```dart
bool _obscurePassword = true;
```

- [ ] **Step 2: Add `onToggleObscure` parameter to `_buildInputField`**

Change the method signature from:
```dart
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
```
to:
```dart
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    VoidCallback? onToggleObscure,
  }) {
```

- [ ] **Step 3: Replace the static suffix icon with a functional `IconButton`**

Inside `_buildInputField`, replace:
```dart
            suffixIcon: obscure
                ? Icon(Icons.visibility_off_rounded, color: colorScheme.onSurface.withValues(alpha: 0.4), size: 20)
                : null,
```
with:
```dart
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
```

Note: the condition uses `onToggleObscure != null` (not `obscure`) so the icon stays visible even when the user reveals the password.

- [ ] **Step 4: Update the password field call in `_buildFormCard`**

Change:
```dart
          _buildInputField(
            controller: _passwordController,
            label: 'Password',
            hint: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
            icon: Icons.lock_outline_rounded,
            obscure: true,
          ),
```
to:
```dart
          _buildInputField(
            controller: _passwordController,
            label: 'Password',
            hint: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
```

- [ ] **Step 5: Analyze**
```bash
flutter analyze lib/screens/auth_screen.dart
```
Expected: No issues.

- [ ] **Step 6: Commit**
```bash
git add lib/screens/auth_screen.dart
git commit -m "fix(auth): make password show/hide toggle functional"
```

---

### Task 4: Improve hero section with animated headline and subtext

**Files:**
- Modify: `lib/screens/auth_screen.dart`

- [ ] **Step 1: Rewrite `_buildLogoBlock` with animated copy**

Replace the entire `_buildLogoBlock` method with:
```dart
  Widget _buildLogoBlock(ThemeData theme, ColorScheme colorScheme) {
    final String headline;
    final String subtext;
    if (_isSignUp) {
      headline = _isUser ? 'Discover local hobbies' : 'Host your passion';
      subtext = _isUser ? 'Book and meet real people' : 'Get paid in EGP';
    } else {
      headline = 'Welcome back';
      subtext = 'Sign in to continue';
    }

    return Column(
      children: [
        Image.asset(
          'assets/images/hobifi_logo.png',
          height: 150,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            headline,
            key: ValueKey(headline),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            subtext,
            key: ValueKey(subtext),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 2: Remove the old benefit strip `AnimatedSwitcher` from `build()`**

Delete the entire benefit strip block and its trailing spacing from `build()`:
```dart
              // Benefit strip (sign up only)
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

              const SizedBox(height: 16),
```

- [ ] **Step 3: Analyze**
```bash
flutter analyze lib/screens/auth_screen.dart
```
Expected: No issues.

- [ ] **Step 4: Commit**
```bash
git add lib/screens/auth_screen.dart
git commit -m "feat(auth): animated hero headline and subtext by mode and role"
```

---

### Task 5: Move role toggle to sign-in only + add Host/Explorer switch link

**Files:**
- Modify: `lib/screens/auth_screen.dart`

- [ ] **Step 1: Wrap the role toggle in `AnimatedSize` to show only in sign-in mode**

In `build()`, replace:
```dart
              // Role toggle
              _buildRoleToggle(colorScheme),

              const SizedBox(height: 12),
```
with:
```dart
              // Role toggle — sign-in only
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: !_isSignUp
                    ? Column(
                        children: [
                          _buildRoleToggle(colorScheme),
                          const SizedBox(height: 12),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
```

- [ ] **Step 2: Add Host/Explorer switch link below the form card**

In `build()`, directly after the `Expanded` block (the form card), add:
```dart
              // Host / Explorer switch link — sign-up only
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isSignUp
                    ? Padding(
                        key: const ValueKey('role-link'),
                        padding: const EdgeInsets.only(top: 4),
                        child: Center(
                          child: TextButton(
                            onPressed: () => setState(() => _isUser = !_isUser),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            child: Text(
                              _isUser ? 'Sign up as a Host →' : 'Sign up as an Explorer →',
                              style: TextStyle(
                                color: _isUser ? AppColors.lime : AppColors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('no-role-link')),
              ),
```

- [ ] **Step 3: Analyze**
```bash
flutter analyze lib/screens/auth_screen.dart
```
Expected: No issues.

- [ ] **Step 4: Commit**
```bash
git add lib/screens/auth_screen.dart
git commit -m "feat(auth): role toggle sign-in only, Host/Explorer link in sign-up mode"
```

---

### Task 6: Add bottom mode-switch link

**Files:**
- Modify: `lib/screens/auth_screen.dart`

- [ ] **Step 1: Add the mode-switch link above the Terms text**

In `build()`, directly before the Terms `Padding` widget at the very bottom:
```dart
              // Mode switch link
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp ? 'Sign in' : 'Sign up',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
```

- [ ] **Step 2: Analyze**
```bash
flutter analyze lib/screens/auth_screen.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**
```bash
git add lib/screens/auth_screen.dart
git commit -m "feat(auth): add bottom sign-in/sign-up mode switch link"
```

---

### Task 7: Code review

- [ ] **Step 1: Dispatch code review sub-agent**

Invoke the `superpowers:requesting-code-review` skill to review `lib/screens/auth_screen.dart` for code quality, dead code, and adherence to the Hobifi design system (colors via `colorScheme`, spacing, opacity via `withValues`).

- [ ] **Step 2: Apply any feedback from the review**

Address issues identified by the reviewer before considering implementation complete.
