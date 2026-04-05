import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signs in with Google using Supabase Auth
///
/// On web, uses OAuth redirect flow.
/// On native platforms, uses OAuth redirect with deep link callback.
///
/// Returns the authenticated User once the OAuth flow completes,
/// or null if the user cancelled / the flow failed.
Future<User?> googleSignInFunc() async {
  final supabase = Supabase.instance.client;

  if (kIsWeb) {
    // Web: OAuth redirect — page will reload, so we can't wait for a result.
    // The auth state listener in AuthService will pick up the session on reload.
    await supabase.auth.signInWithOAuth(OAuthProvider.google);
    return null;
  }

  // Native: signInWithOAuth opens an external browser. The result comes back
  // via the deep link, which Supabase processes and fires onAuthStateChange.
  // We listen for that event with a timeout.
  final completer = Completer<User?>();

  StreamSubscription<AuthState>? sub;
  sub = supabase.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn && data.session?.user != null) {
      if (!completer.isCompleted) {
        completer.complete(data.session!.user);
      }
      sub?.cancel();
    }
  });

  final launched = await supabase.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: 'io.supabase.hobifiapo://login-callback/',
  );

  if (!launched) {
    sub.cancel();
    return null;
  }

  // Wait up to 120 seconds for the OAuth callback
  try {
    return await completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        sub?.cancel();
        return null;
      },
    );
  } catch (e) {
    debugPrint('Google OAuth wait failed: $e');
    sub.cancel();
    return null;
  }
}
