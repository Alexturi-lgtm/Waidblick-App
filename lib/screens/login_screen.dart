import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaidblickColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              // Logo
              Text(
                'WAIDBLICK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: WaidblickColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Das Auge des erfahrenen Jägers',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: WaidblickColors.textPrimary.withOpacity(0.6),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 64),

              // Toggle Login/Register
              Container(
                decoration: BoxDecoration(
                  color: WaidblickColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _tabButton('Anmelden', _isLogin, () => setState(() { _isLogin = true; _error = null; })),
                    _tabButton('Registrieren', !_isLogin, () => setState(() { _isLogin = false; _error = null; })),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Name (nur bei Registrierung)
              if (!_isLogin) ...[
                _inputField(_nameController, 'Vollständiger Name', Icons.person_outline),
                const SizedBox(height: 16),
              ],

              _inputField(_emailController, 'E-Mail', Icons.mail_outline, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _inputField(_passwordController, 'Passwort', Icons.lock_outline, obscure: true),
              const SizedBox(height: 8),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),

              const SizedBox(height: 24),

              // ── Social Login Buttons ──────────────────────────────
              _buildSocialLoginButtons(),
              const SizedBox(height: 20),

              // ── Trennlinie "— oder —" ────────────────────────────
              Row(
                children: [
                  Expanded(child: Divider(color: WaidblickColors.textPrimary.withOpacity(0.2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '— oder —',
                      style: TextStyle(
                        color: WaidblickColors.textPrimary.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: WaidblickColors.textPrimary.withOpacity(0.2))),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WaidblickColors.primary,
                  foregroundColor: WaidblickColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        _isLogin ? 'ANMELDEN' : 'REGISTRIEREN',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 15),
                      ),
              ),

              const SizedBox(height: 16),

              // Ohne Login weitermachen
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                child: Text(
                  'Ohne Account fortfahren',
                  style: TextStyle(color: WaidblickColors.textPrimary.withOpacity(0.5), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? WaidblickColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? WaidblickColors.background : WaidblickColors.textPrimary.withOpacity(0.5),
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: WaidblickColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: WaidblickColors.textPrimary.withOpacity(0.4)),
        prefixIcon: Icon(icon, color: WaidblickColors.primary.withOpacity(0.7)),
        filled: true,
        fillColor: WaidblickColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WaidblickColors.primary, width: 1),
        ),
      ),
    );
  }

  Widget _buildSocialLoginButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Google-Button
        OutlinedButton(
          onPressed: _loading ? null : _signInWithGoogle,
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFF8F8F8),
            foregroundColor: const Color(0xFF333333),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google G Logo
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4285F4),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Mit Google anmelden',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Apple-Button: nur auf iOS anzeigen
        if (Platform.isIOS) ...[  
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _signInWithApple,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Apple-Logo ( = Apple-Symbol in Apple-Font, Fallback: Icon)
                Icon(Icons.apple, size: 22, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Mit Apple anmelden',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.signInWithGoogle();
      // OAuth-Flow öffnet Browser/WebView; Redirect schließt ihn und
      // triggert onAuthStateChange → Navigator-Push passiert via AuthWrapper
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Google-Login fehlgeschlagen: ${e.toString().replaceAll("Exception: ", "")}'; });
      }
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.signInWithApple();
      // OAuth-Flow: s.o.
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Apple-Login fehlgeschlagen: ${e.toString().replaceAll("Exception: ", "")}'; });
      }
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await AuthService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await AuthService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
        );
      }
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }
}
