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
  bool _isSignUp = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final authService = context.read<AuthService>();
    final role = _isUser ? UserRole.user : UserRole.business;
    // Capture ScaffoldMessenger before async gap — the widget may rebuild
    // during signIn (GoRouter refreshListenable fires on notifyListeners),
    // which can unmount this State and make context invalid.
    final messenger = ScaffoldMessenger.of(context);

    Map<String, dynamic> result;
    if (_isSignUp) {
      result = await authService.signUp(
        _emailController.text,
        _passwordController.text,
        _nameController.text.isEmpty ? (_isUser ? 'Explorer' : 'Business Owner') : _nameController.text,
        role,
      );
    } else {
      result = await authService.signIn(_emailController.text, _passwordController.text, role);
    }

    if (result['success'] == true) {
      if (!mounted) return;
      if (result['requiresConfirmation'] == true) {
        // Auto sign-in after sign-up so the user doesn't have to re-enter credentials
        final signInResult = await authService.signIn(
          _emailController.text,
          _passwordController.text,
          role,
        );
        if (!mounted) return;
        if (signInResult['success'] == true) {
          context.go('/');
        } else if (signInResult['message']?.toString().contains('not confirmed') == true) {
          _showEmailConfirmationDialog(result['message'] ?? 'Please check your email for a confirmation link.');
        } else {
          // Sign-in failed for another reason — show the confirmation dialog as fallback
          _showEmailConfirmationDialog(result['message'] ?? 'Please check your email for a confirmation link.');
        }
      } else {
        // Let the router redirect handle navigation based on role + onboarding state
        context.go('/');
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'An error occurred. Please try again.'),
          backgroundColor: AppColors.lightError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authService = context.read<AuthService>();
    final result = await authService.signInWithGoogle();

    if (!mounted) return;

    if (result['success'] == true) {
      // Wait for user profile to be loaded by the auth state listener
      await _waitForProfile(authService);
      if (!mounted) return;
      // Let the router redirect handle navigation based on role + onboarding state
      context.go('/');
    } else if (result['message'] != null && !result['message'].toString().contains('cancelled')) {
      _showErrorSnackBar(result['message']);
    }
  }

  Future<void> _handleAppleSignIn() async {
    final authService = context.read<AuthService>();
    final result = await authService.signInWithApple();

    if (!mounted) return;

    if (result['success'] == true) {
      // Wait for user profile to be loaded by the auth state listener
      await _waitForProfile(authService);
      if (!mounted) return;
      // Let the router redirect handle navigation based on role + onboarding state
      context.go('/');
    } else if (result['message'] != null && !result['message'].toString().contains('cancelled')) {
      _showErrorSnackBar(result['message']);
    }
  }

  /// Wait for the auth service to finish loading the user profile,
  /// polling with short delays instead of a fixed wait.
  Future<void> _waitForProfile(AuthService authService) async {
    for (int i = 0; i < 20; i++) {
      if (authService.currentUser != null) return;
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.lightError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showEmailConfirmationDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.orange.withValues(alpha: 0.2), AppColors.lime.withValues(alpha: 0.2)],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded, color: AppColors.orange, size: 32),
        ),
        title: const Text('Verify Your Email', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text('After confirming, you can sign in with your credentials.', 
              textAlign: TextAlign.center, 
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.lightSecondaryText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isSignUp = false;
                _emailController.clear();
                _passwordController.clear();
                _nameController.clear();
              });
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ForgotPasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authService = context.watch<AuthService>();
    final accentColor = _isUser ? AppColors.orange : AppColors.lime;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Logo block
              _buildLogoBlock(theme, colorScheme),

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

              // Sign In / Sign Up mode toggle (NEW)
              _buildModeToggle(colorScheme),

              const SizedBox(height: 12),

              // Role toggle
              _buildRoleToggle(colorScheme),

              const SizedBox(height: 12),

              // Form card (only this part scrolls on very small screens)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildFormCard(theme, colorScheme, authService, accentColor),
                ),
              ),

              const SizedBox(height: 12),

              // Social divider
              _buildDivider(colorScheme),

              const SizedBox(height: 10),

              // Social buttons
              _buildSocialButtons(colorScheme),

              const SizedBox(height: 8),

              // Terms
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 2),
                child: Center(
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLogoBlock(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Image.asset(
          'assets/images/hobifi_logo.png',
          height: 150,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 12),
        Text(
          _isSignUp ? 'Begin Your Journey' : 'Discover What Moves You',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
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
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(ColorScheme colorScheme) {
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
            _buildModeTab(
              label: 'Sign In',
              isSelected: !_isSignUp,
              colorScheme: colorScheme,
              onTap: () => setState(() => _isSignUp = false),
            ),
            _buildModeTab(
              label: 'Sign Up',
              isSelected: _isSignUp,
              colorScheme: colorScheme,
              onTap: () => setState(() => _isSignUp = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool isSelected,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    final accentColor = _isUser ? AppColors.orange : AppColors.lime;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.55),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
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

}

// Forgot Password Dialog with multi-step flow
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  // Steps: 0 = email, 1 = OTP, 2 = new password, 3 = success
  int _step = 0;
  bool _isLoading = false;
  String? _errorMessage;
  
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final result = await authService.sendPasswordResetEmail(email);

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _step = 1;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'];
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit verification code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final result = await authService.verifyPasswordResetOTP(
      _emailController.text.trim(),
      otp,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _step = 2;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'];
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || newPassword.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final result = await authService.updatePassword(newPassword);

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _step = 3;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.orange.withValues(alpha: 0.2),
                      AppColors.lime.withValues(alpha: 0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _step == 0 ? Icons.lock_reset_rounded :
                  _step == 1 ? Icons.pin_rounded :
                  _step == 2 ? Icons.password_rounded :
                  Icons.check_circle_rounded,
                  color: _step == 3 ? AppColors.lime : AppColors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                _step == 0 ? 'Reset Password' :
                _step == 1 ? 'Enter Verification Code' :
                _step == 2 ? 'Create New Password' :
                'Password Updated!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigo,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                _step == 0 ? 'Enter your email address and we\'ll send you a verification code.' :
                _step == 1 ? 'We\'ve sent a 6-digit code to ${_emailController.text}' :
                _step == 2 ? 'Create a strong password for your account.' :
                'You can now sign in with your new password.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.lightSecondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Step content
              if (_step == 0) _buildEmailStep(),
              if (_step == 1) _buildOTPStep(),
              if (_step == 2) _buildPasswordStep(),
              
              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.lightError, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.lightError),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Action buttons
              if (_step < 3)
                Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: TextButton(
                          onPressed: _isLoading ? null : () {
                            setState(() {
                              if (_step == 1) {
                                _step = 0;
                                _otpController.clear();
                              } else if (_step == 2) {
                                _step = 1;
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();
                              }
                              _errorMessage = null;
                            });
                          },
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () {
                          if (_step == 0) {
                            _sendResetEmail();
                          } else if (_step == 1) {
                            _verifyOTP();
                          } else if (_step == 2) {
                            _updatePassword();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _step == 0 ? 'Send Code' :
                                _step == 1 ? 'Verify' : 'Update Password',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sign In Now',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              
              // Cancel button (only on first step)
              if (_step == 0) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.lightSecondaryText),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
        color: AppColors.indigo,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'your@email.com',
        hintStyle: TextStyle(
          color: AppColors.indigo.withValues(alpha: 0.35),
          fontSize: 15,
        ),
        prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.indigo.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppColors.cream.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.indigo.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.indigo.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildOTPStep() {
    return Column(
      children: [
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            color: AppColors.indigo,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: AppColors.indigo.withValues(alpha: 0.2),
            ),
            counterText: '',
            filled: true,
            fillColor: AppColors.cream.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.indigo.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.indigo.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : _sendResetEmail,
          child: const Text(
            'Resend Code',
            style: TextStyle(
              color: AppColors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      children: [
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          style: const TextStyle(
            color: AppColors.indigo,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'New password',
            hintStyle: TextStyle(
              color: AppColors.indigo.withValues(alpha: 0.35),
              fontSize: 15,
            ),
            prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.indigo.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppColors.cream.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.indigo.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.indigo.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          style: const TextStyle(
            color: AppColors.indigo,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Confirm password',
            hintStyle: TextStyle(
              color: AppColors.indigo.withValues(alpha: 0.35),
              fontSize: 15,
            ),
            prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.indigo.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppColors.cream.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.indigo.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.indigo.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
