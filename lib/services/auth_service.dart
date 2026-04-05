import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// E-Mail + Passwort Registrierung
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  /// E-Mail + Passwort Login
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Magic Link (passwordless)
  static Future<void> signInWithMagicLink(String email) async {
    await client.auth.signInWithOtp(email: email);
  }

  /// Google Login via Supabase OAuth
  static Future<bool> signInWithGoogle() async {
    final result = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.waidblick://login-callback/',
    );
    return result;
  }

  /// Apple Login via Supabase OAuth
  static Future<bool> signInWithApple() async {
    final result = await client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.waidblick://login-callback/',
    );
    return result;
  }

  /// Passwort-Reset E-Mail senden
  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.waidblick://reset-callback/',
    );
  }

  /// Logout
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Profil laden
  static Future<Map<String, dynamic>?> getProfile() async {
    if (currentUser == null) return null;
    final res = await client
        .from('profiles')
        .select()
        .eq('id', currentUser!.id)
        .single();
    return res;
  }

  /// Profil updaten
  static Future<void> updateProfile({
    String? username,
    String? fullName,
    String? revier,
    String? region,
  }) async {
    if (currentUser == null) return;
    await client.from('profiles').update({
      if (username != null) 'username': username,
      if (fullName != null) 'full_name': fullName,
      if (revier != null) 'revier': revier,
      if (region != null) 'region': region,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', currentUser!.id);
  }
}
