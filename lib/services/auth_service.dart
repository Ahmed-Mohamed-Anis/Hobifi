import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/user_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';
import 'package:hobby_haven/auth/google_auth.dart';
import 'package:hobby_haven/auth/apple_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _disposed = false;
  bool _suppressAuthListener = false;
  StreamSubscription<AuthState>? _authSub;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    // Guard against double initialization
    if (_authSub != null) return;

    _isLoading = true;
    _safeNotify();

    try {
      _authSub = SupabaseConfig.auth.onAuthStateChange.listen((data) {
        if (_suppressAuthListener) return;
        final session = data.session;
        if (session != null) {
          _loadCurrentUser();
        } else {
          _currentUser = null;
          _safeNotify();
        }
      });

      final session = SupabaseConfig.auth.currentSession;
      if (session != null) {
        await _loadCurrentUser();
      }
    } catch (e) {
      debugPrint('Failed to initialize auth: $e');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;

      final userData = await SupabaseService.selectSingle(
        'users',
        filters: {'id': userId},
      );

      if (userData != null) {
        final enriched = Map<String, dynamic>.from(userData);
        enriched['email'] ??= SupabaseConfig.auth.currentUser?.email;
        _currentUser = UserModel.fromJson(enriched);
        _safeNotify();
        return;
      }

      // Backfill a minimal profile if missing (e.g. social sign-in first time).
      // This is a best-effort recovery — if it fails, the user can still retry.
      debugPrint('No profile row found for $userId. Creating a default profile...');
      final authUser = SupabaseConfig.auth.currentUser;
      final email = authUser?.email ?? '';
      final displayName = authUser?.userMetadata?['full_name'] as String?
          ?? authUser?.userMetadata?['name'] as String?
          ?? 'Explorer';
      try {
        await SupabaseService.insert('users', {
          'id': userId,
          'email': email,
          'name': displayName,
          'role': UserRole.user.name,
        });
      } catch (e) {
        debugPrint('Failed to create default profile: $e');
      }

      final created = await SupabaseService.selectSingle(
        'users',
        filters: {'id': userId},
      );
      if (created != null) {
        final enriched = Map<String, dynamic>.from(created);
        enriched['email'] ??= email;
        _currentUser = UserModel.fromJson(enriched);
        _safeNotify();
      }
    } catch (e) {
      debugPrint('Failed to load user: $e');
    }
  }

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
      _safeNotify();
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

  Future<Map<String, dynamic>> signUp(String email, String password, String name, UserRole role) async {
    _isLoading = true;
    _safeNotify();
    _suppressAuthListener = true;

    try {
      final response = await SupabaseConfig.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null,
      );

      if (response.user == null) {
        _isLoading = false;
        _suppressAuthListener = false;
        _safeNotify();
        return {'success': false, 'message': 'Sign up failed. Please try again.'};
      }

      try {
        await SupabaseService.insert('users', {
          'id': response.user!.id,
          'email': email,
          'name': name,
          'role': role.name,
        });
      } catch (profileError) {
        // Profile insert failed but auth user exists.
        // The backfill logic in _loadCurrentUser will recover this on next sign-in.
        // Don't treat as a sign-up failure — the user can still sign in.
        debugPrint('Profile insert failed (will be recovered on sign-in): $profileError');
      }

      _isLoading = false;
      _suppressAuthListener = false;
      _safeNotify();

      final session = response.session;
      if (session == null) {
        return {
          'success': true,
          'requiresConfirmation': true,
          'message': 'Please check your email ($email) and click the confirmation link to activate your account.',
        };
      }

      return {'success': true, 'requiresConfirmation': false};
    } on AuthException catch (e) {
      debugPrint('Sign up failed: ${e.message}');
      _isLoading = false;
      _suppressAuthListener = false;
      _safeNotify();
      return {'success': false, 'message': e.message};
    } on PostgrestException catch (e) {
      debugPrint('Sign up postgrest error: ${e.message}');
      _isLoading = false;
      _suppressAuthListener = false;
      _safeNotify();
      return {'success': false, 'message': 'Could not create your profile. Please try again.'};
    } catch (e) {
      debugPrint('Sign up failed: $e');
      _isLoading = false;
      _suppressAuthListener = false;
      _safeNotify();
      return {'success': false, 'message': 'An error occurred. Please try again.'};
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _safeNotify();

    try {
      await SupabaseConfig.auth.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Sign out failed: $e');
      // Force sign out even if Supabase fails
      _currentUser = null;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    _isLoading = true;
    _safeNotify();

    try {
      final user = await googleSignInFunc();
      
      if (user == null) {
        _isLoading = false;
        _safeNotify();
        return {'success': false, 'message': 'Google sign-in was cancelled'};
      }

      // User profile will be loaded via auth state listener
      _isLoading = false;
      _safeNotify();
      return {'success': true};
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      _isLoading = false;
      _safeNotify();
      return {'success': false, 'message': 'Google sign-in failed. Please try again.'};
    }
  }

  /// Sign in with Apple
  Future<Map<String, dynamic>> signInWithApple() async {
    _isLoading = true;
    _safeNotify();

    try {
      final user = await appleSignInFunc();
      
      if (user == null) {
        _isLoading = false;
        _safeNotify();
        return {'success': false, 'message': 'Apple sign-in was cancelled'};
      }

      // User profile will be loaded via auth state listener
      _isLoading = false;
      _safeNotify();
      return {'success': true};
    } catch (e) {
      debugPrint('Apple sign-in failed: $e');
      _isLoading = false;
      _safeNotify();
      return {'success': false, 'message': 'Apple sign-in failed. Please try again.'};
    }
  }

  Future<bool> updateProfile({String? name, String? avatarUrl, String? bio, List<String>? interests, String? city}) async {
    if (_currentUser == null) return false;

    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (bio != null) updates['bio'] = bio;
      if (interests != null) updates['interests'] = interests;
      if (city != null) updates['city'] = city;

      if (updates.isEmpty) return false;

      await SupabaseService.update(
        'users',
        updates,
        filters: {'id': _currentUser!.id},
      );

      await _loadCurrentUser();
      return true;
    } catch (e) {
      debugPrint('Failed to update profile: $e');
      return false;
    }
  }

  Future<String?> uploadAvatarBytes(Uint8List bytes, {String? fileExt}) async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id ?? _currentUser?.id;
      if (userId == null) return null;

      final ext = (fileExt ?? 'jpg').toLowerCase();
      final contentType = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'application/octet-stream',
      };
      final filePath = 'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      // Reuse existing bucket used for activities. Store avatars in a subfolder.
      const targetBucket = 'activity-images';
      await SupabaseConfig.client.storage.from(targetBucket).uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: contentType, cacheControl: '3600', upsert: true),
      );

      final publicUrl = SupabaseConfig.client.storage.from(targetBucket).getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      final msg = e.toString();
      debugPrint('uploadAvatarBytes failed: $msg');
      // Provide clearer guidance
      if (msg.contains('Bucket not found') || msg.contains('storage.buckets')) {
        throw Exception('Storage bucket "activity-images" is missing. Please create it in Supabase Storage and make it public.');
      }
      return null;
    }
  }

  Future<bool> changeAvatar(Uint8List bytes, {String? fileExt}) async {
    try {
      final url = await uploadAvatarBytes(bytes, fileExt: fileExt);
      if (url == null) return false;
      return await updateProfile(avatarUrl: url);
    } catch (e) {
      debugPrint('changeAvatar failed: $e');
      return false;
    }
  }

  /// Send password reset email with OTP code
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _safeNotify();

    try {
      await SupabaseConfig.auth.resetPasswordForEmail(email);
      _isLoading = false;
      _safeNotify();
      return {
        'success': true,
        'message': 'A verification code has been sent to $email',
      };
    } on AuthException catch (e) {
      debugPrint('Password reset request failed: ${e.message}');
      _isLoading = false;
      _safeNotify();
      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint('Password reset request failed: $e');
      _isLoading = false;
      _safeNotify();
      return {'success': false, 'message': 'Failed to send reset email. Please try again.'};
    }
  }

  /// Verify OTP code from password reset email
  Future<Map<String, dynamic>> verifyPasswordResetOTP(String email, String token) async {
    _isLoading = true;
    _safeNotify();

    try {
      final response = await SupabaseConfig.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );

      if (response.session == null) {
        _isLoading = false;
        _safeNotify();
        return {'success': false, 'message': 'Invalid or expired verification code.'};
      }

      _isLoading = false;
      _safeNotify();
      return {'success': true};
    } on AuthException catch (e) {
      debugPrint('OTP verification failed: ${e.message}');
      _isLoading = false;
      _safeNotify();
      String message = 'Invalid verification code.';
      if (e.message.contains('expired')) {
        message = 'Verification code has expired. Please request a new one.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      debugPrint('OTP verification failed: $e');
      _isLoading = false;
      _safeNotify();
      return {'success': false, 'message': 'Verification failed. Please try again.'};
    }
  }

  /// Update password after OTP verification
  Future<Map<String, dynamic>> updatePassword(String newPassword) async {
    _isLoading = true;
    _safeNotify();

    try {
      await SupabaseConfig.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      _isLoading = false;
      _safeNotify();
      return {
        'success': true,
        'message': 'Password updated successfully! You can now sign in with your new password.',
      };
    } on AuthException catch (e) {
      debugPrint('Password update failed: ${e.message}');
      _isLoading = false;
      _safeNotify();
      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint('Password update failed: $e');
      _isLoading = false;
      _safeNotify();
      return {'success': false, 'message': 'Failed to update password. Please try again.'};
    }
  }
}
