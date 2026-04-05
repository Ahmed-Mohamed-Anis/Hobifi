# Login Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the heavy animated login screen with a clean, minimal design using the app's existing design system.

**Architecture:** Single-file rewrite of `lib/screens/auth_screen.dart`. Remove all animation infrastructure and custom painters. Rebuild the `build()` method with a simple vertical layout on the scaffold's cream background. All business logic methods stay untouched.

**Tech Stack:** Flutter/Dart, Provider, GoRouter, Supabase Auth

**Spec:** `docs/superpowers/specs/2026-04-05-login-screen-redesign.md`

---

### Task 1: Strip animation infrastructure

**Files:**
- Modify: `lib/screens/auth_screen.dart:1-107` (imports, state fields, initState, animation methods)

- [ ] **Step 1: Remove dart:math import and animation fields**

Replace the top of the file (lines 1–36) with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/models/user_model.dart';
import 'package:hobby_haven/theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isUser = true;
  bool _isSignUp = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }
```

Key changes: removed `dart:math`, removed `TickerProviderStateMixin`, removed all `AnimationController`/`Animation` fields, removed `_nodes`/`_edges` lists, removed `_initAnimations()` and `_initConstellationData()` calls from `initState`.

- [ ] **Step 2: Remove animation methods and simplify dispose**

Delete `_initConstellationData()` (lines 38–83) and `_initAnimations()` (lines 85–107) entirely.

Replace `dispose()` with:

```dart
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
```

- [ ] **Step 3: Delete constellation classes at end of file**

Delete these three classes entirely (lines 786–897):
- `_ConstellationNode`
- `_ConstellationEdge`
- `_ConstellationPainter`

- [ ] **Step 4: Verify the app compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/auth_screen.dart`
Expected: No errors related to removed animation code. (The `build()` method will still reference removed variables — that's fixed in Task 2.)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/auth_screen.dart
git commit -m "refactor: strip animation infrastructure from login screen"
```

---

### Task 2: Rewrite the build method

**Files:**
- Modify: `lib/screens/auth_screen.dart` — replace the entire `build()` method (lines 272–687)

- [ ] **Step 1: Replace the build method**

Replace the entire `build()` method with:

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authService = context.watch<AuthService>();
    final size = MediaQuery.of(context).size;
    final accentColor = _isUser ? AppColors.orange : AppColors.lime;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: size.height * 0.12),

                // Logo block
                _buildLogoBlock(theme, colorScheme),

                const SizedBox(height: 24),

                // Role toggle
                _buildRoleToggle(colorScheme),

                const SizedBox(height: 24),

                // Form card
                _buildFormCard(theme, colorScheme, authService, accentColor),

                const SizedBox(height: 20),

                // Social divider
                _buildDivider(colorScheme),

                const SizedBox(height: 12),

                // Social buttons
                _buildSocialButtons(colorScheme),

                const SizedBox(height: 24),

                // Toggle sign up/in
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign In'
                          : "Don't have an account? Sign Up",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),

                // Terms
                Center(
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 2: Verify the app compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/auth_screen.dart`
Expected: Errors about missing `_buildLogoBlock`, `_buildRoleToggle`, `_buildFormCard`, `_buildDivider`, `_buildSocialButtons` methods. These are added in the next tasks.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/auth_screen.dart
git commit -m "refactor: rewrite login build method with clean layout"
```

---

### Task 3: Add logo block and role toggle widgets

**Files:**
- Modify: `lib/screens/auth_screen.dart` — add methods before `_buildInputField`

- [ ] **Step 1: Add _buildLogoBlock method**

Add this method after the `build()` method:

```dart
  Widget _buildLogoBlock(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // Logo icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.explore_rounded, size: 24, color: Colors.white),
        ),
        const SizedBox(height: 16),

        // Brand name
        Text(
          'HOBIFI',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),

        // Tagline
        Text(
          _isSignUp ? 'Begin Your Journey' : 'Discover What Moves You',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 2: Add _buildRoleToggle method**

Add this method after `_buildLogoBlock`:

```dart
  Widget _buildRoleToggle(ColorScheme colorScheme) {
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
            _buildToggleTab(
              label: 'Explorer',
              isSelected: _isUser,
              colorScheme: colorScheme,
              onTap: () => setState(() => _isUser = true),
            ),
            _buildToggleTab(
              label: 'Host',
              isSelected: !_isUser,
              colorScheme: colorScheme,
              onTap: () => setState(() => _isUser = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTab({
    required String label,
    required bool isSelected,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Verify compilation**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/auth_screen.dart`
Expected: Still errors for missing `_buildFormCard`, `_buildDivider`, `_buildSocialButtons`. Logo and toggle are resolved.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/auth_screen.dart
git commit -m "feat: add clean logo block and role toggle to login"
```

---

### Task 4: Add form card, divider, and social buttons

**Files:**
- Modify: `lib/screens/auth_screen.dart` — add remaining builder methods, update `_buildSocialButton`

- [ ] **Step 1: Add _buildFormCard method**

Add after `_buildToggleTab`:

```dart
  Widget _buildFormCard(
    ThemeData theme,
    ColorScheme colorScheme,
    AuthService authService,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name field (sign up only)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isSignUp
                ? Column(
                    children: [
                      _buildInputField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'How should we call you?',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Email field
          _buildInputField(
            controller: _emailController,
            label: 'Email',
            hint: 'your@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          // Password field
          _buildInputField(
            controller: _passwordController,
            label: 'Password',
            hint: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
            icon: Icons.lock_outline_rounded,
            obscure: true,
          ),

          if (!_isSignUp) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: Text(
                  'Forgot Password?',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Primary action button
          if (authService.isLoading)
            Center(
              child: SizedBox(
                height: 52,
                child: Center(
                  child: CircularProgressIndicator(
                    color: accentColor,
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _handleAuth,
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isSignUp ? 'Create Account' : 'Sign In',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
```

- [ ] **Step 2: Add _buildDivider method**

```dart
  Widget _buildDivider(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: colorScheme.outlineVariant)),
      ],
    );
  }
```

- [ ] **Step 3: Add _buildSocialButtons method and update _buildSocialButton**

Replace the existing `_buildSocialButton` method (lines 750–781) and add the new `_buildSocialButtons` wrapper:

```dart
  Widget _buildSocialButtons(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            icon: Icons.g_mobiledata,
            label: 'Google',
            colorScheme: colorScheme,
            onTap: _handleGoogleSignIn,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSocialButton(
            icon: Icons.apple_rounded,
            label: 'Apple',
            colorScheme: colorScheme,
            onTap: _handleAppleSignIn,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: icon == Icons.g_mobiledata ? 28 : 22,
              color: colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Update _buildInputField to use colorScheme**

Replace the existing `_buildInputField` method (lines 689–748) with:

```dart
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = _isUser ? AppColors.orange : AppColors.lime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.35),
              fontSize: 15,
            ),
            prefixIcon: Icon(icon, color: colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
            suffixIcon: obscure
                ? Icon(Icons.visibility_off_rounded, color: colorScheme.onSurface.withValues(alpha: 0.4), size: 20)
                : null,
            filled: true,
            fillColor: colorScheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 5: Verify the app compiles cleanly**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/auth_screen.dart`
Expected: No errors. All builder methods now exist and reference valid fields.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/auth_screen.dart
git commit -m "feat: add clean form card, social buttons, and themed inputs"
```

---

### Task 5: Final verification and cleanup

**Files:**
- Modify: `lib/screens/auth_screen.dart` (if cleanup needed)

- [ ] **Step 1: Run full project analysis**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze`
Expected: No new errors or warnings in `auth_screen.dart`.

- [ ] **Step 2: Verify ForgotPasswordDialog still works**

Confirm that `ForgotPasswordDialog` class (unchanged, at the bottom of the file) has no broken references. It uses `AppColors` directly which is fine — it's a dialog that appears on top of the screen.

- [ ] **Step 3: Hot restart and visual check**

Run: `flutter run` (or hot restart if already running)
Verify:
- Cream background (light mode) / dark background (dark mode)
- Logo + HOBIFI text centered at top
- Explorer/Host toggle works and switches accent color
- Form card with border, inputs styled correctly
- Sign in / Sign up toggle works, name field animates in/out
- Google & Apple buttons outlined below divider
- Forgot password dialog still opens
- Scrolls on small screens

- [ ] **Step 4: Commit any cleanup**

```bash
git add lib/screens/auth_screen.dart
git commit -m "chore: final cleanup on login screen redesign"
```
