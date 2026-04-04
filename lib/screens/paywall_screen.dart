import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Paywall-Screen: Freemium-Limit + Beta-Zugang per E-Mail-Whitelist
class PaywallScreen extends StatefulWidget {
  final bool isLookbookLimit;

  const PaywallScreen({super.key, this.isLookbookLimit = false});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _emailController = TextEditingController();
  bool _checkingEmail = false;

  // Hardcodierte Beta-Whitelist (später auf Hetzner-Backend auslagern)
  static const List<String> _betaWhitelist = [
    'alex.turi@hotmail.de',
    'elena@example.com',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkBetaAccess() async {
    final email = _emailController.text.trim().toLowerCase();
    setState(() => _checkingEmail = true);

    await Future.delayed(const Duration(milliseconds: 600)); // UX-Delay

    final isWhitelisted = _betaWhitelist.contains(email);

    if (isWhitelisted) {
      // Premium für 30 Tage setzen
      final prefs = await SharedPreferences.getInstance();
      final expiryMs =
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
      await prefs.setBool('premium_active', true);
      await prefs.setInt('premium_expiry_ms', expiryMs);

      if (mounted) {
        setState(() => _checkingEmail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Beta-Zugang aktiviert! Viel Waidmannsheil.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context);
      }
    } else {
      if (mounted) {
        setState(() => _checkingEmail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '❌ Diese E-Mail ist nicht für den Beta-Zugang freigeschalten.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaidblickColors.background,
      appBar: AppBar(
        backgroundColor: WaidblickColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close, color: WaidblickColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'WAIDBLICK',
          style: TextStyle(
            color: WaidblickColors.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Icon
              const Center(
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 72,
                  color: WaidblickColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              // Titel
              const Text(
                'Dein Kontingent ist aufgebraucht',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: WaidblickColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // Subtext
              Text(
                widget.isLookbookLimit
                    ? '3 Lookbook-Einträge gratis. Für unbegrenzte Einträge:'
                    : '5 Analysen/Monat gratis. Für unbegrenzte Analysen:',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: WaidblickColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Premium-Features Liste
              _featureRow(Icons.all_inclusive, 'Unbegrenzte Analysen'),
              _featureRow(Icons.menu_book_outlined, 'Unbegrenztes Lookbook'),
              _featureRow(Icons.picture_as_pdf_outlined, 'PDF-Export'),
              _featureRow(Icons.location_on_outlined, 'Regionale Altersklassen'),
              _featureRow(Icons.offline_bolt_outlined, 'Offline-Modus (bald)'),

              const Spacer(),

              // Button 1: Monatsabo
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('In-App-Purchase kommt bald!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: WaidblickColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Premium — 12,99 €/Monat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Monatlich kündbar',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Button 2: Jahresabo
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('In-App-Purchase kommt bald!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: WaidblickColors.primary,
                  side:
                      const BorderSide(color: WaidblickColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Jahresabo — 99 €/Jahr',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Spart 57 € gegenüber Monatsabo',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),

              // ── oder ── Divider
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'oder',
                        style: TextStyle(
                            color: WaidblickColors.textSecondary,
                            fontSize: 13),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),

              // E-Mail Beta-Zugang
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: WaidblickColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'E-Mail-Adresse eingeben',
                  hintStyle: const TextStyle(
                      color: WaidblickColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: WaidblickColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: WaidblickColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: WaidblickColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _checkingEmail ? null : _checkBetaAccess,
                style: OutlinedButton.styleFrom(
                  foregroundColor: WaidblickColors.primary,
                  side:
                      const BorderSide(color: WaidblickColors.primary, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _checkingEmail
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WaidblickColors.primary,
                        ),
                      )
                    : const Text(
                        'Beta-Zugang prüfen',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),

              const SizedBox(height: 8),

              // Schließen
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Schließen',
                  style: TextStyle(color: WaidblickColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: WaidblickColors.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: WaidblickColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
