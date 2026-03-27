import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generates a random nonce string for Apple Sign-In security
String _generateNonce([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}

/// Creates SHA256 hash of the nonce
String _sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Signs in with Apple using Supabase Auth
/// 
/// On web, uses OAuth redirect flow.
/// On native platforms, uses native Apple Sign-In.
Future<User?> appleSignInFunc() async {
  if (kIsWeb) {
    // Web: Use OAuth redirect
    final success = await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.apple,
    );
    return success ? Supabase.instance.client.auth.currentUser : null;
  }

  // Native: Use Sign in with Apple package
  final rawNonce = _generateNonce();
  final hashedNonce = _sha256ofString(rawNonce);

  try {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw 'No ID Token received from Apple';
    }

    final authResponse = await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    return authResponse.user;
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) {
      debugPrint('Apple Sign-In was cancelled by user');
      return null;
    }
    debugPrint('Apple Sign-In error: ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('Apple Sign-In failed: $e');
    rethrow;
  }
}
