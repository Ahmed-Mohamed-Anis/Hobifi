import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signs in with Google using Supabase Auth
/// 
/// On web, uses OAuth redirect flow.
/// On native platforms, uses Google Sign-In package.
Future<User?> googleSignInFunc() async {
  // For both web and native, use Supabase OAuth
  // This is the simplest approach that works across all platforms
  final success = await Supabase.instance.client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: kIsWeb ? null : 'io.supabase.hobifiapo://login-callback/',
  );
  
  return success ? Supabase.instance.client.auth.currentUser : null;
}
