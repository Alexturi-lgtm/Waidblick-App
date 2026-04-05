import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/payment_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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
  bool _purchasingMonthly = false;
  bool _purchasingYearly = false;
  bool _restoringPurchases = false;

  // Dynamische Preise (aus RevenueCat, Fallback auf Hardcoded)
  String _monthlyPrice = '12,99\u00a0€/Monat';
  String _yearlyPrice = '99\u00a0€/Jahr';

  static const String _backendUrl = 'http://204.168.216.110';

  @override
  void initState() {
    super.initState();
    _loadDynamicPrices();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Versucht Preise dynamisch aus RevenueCat zu laden
  Future<void> _loadDynamicPrices() async {
    try {
      final products = await PaymentService.getProducts();
      if (!mounted) return;
      for (final product in products) {
        final id = product.identifier;
        final price = product.priceString;
        if (id == 'de.waidblick.premium.monthly') {
          setState(() => _monthlyPrice = '$price/Monat');
        } else if (id == 'de.waidblick.premium.yearly') {
          setState(() => _yearlyPrice = '$price/Jahr');
        }
      }
    } catch (_) {
      // Fallback-Preise bleiben bestehen
    }
  }

  Future<void> _purchaseMonthly() async {
    setState(() => _purchasingMonthly = true);
    try {
      final result = await PaymentService.purchaseMonthly();
      if (!mounted) return;
      if (result.success) {
        await _onPurchaseSuccess();
      } else if (!result.cancelled) {
        _showError(result.error ?? 'Kauf fehlgeschlagen.');
      }
    } finally {
      if (mounted) setState(() => _purchasingMonthly = false);
    }
  }

  Future<void> _purchaseYearly() async {
    setState(() => _purchasingYearly = true);
    try {
      final result = await PaymentService.purchaseYearly();
      if (!mounted) return;
      if (result.success) {
        await _onPurchaseSuccess();
      } else if (!result.cancelled) {
        _showError(result.error ?? 'Kauf fehlgeschlagen.');
      }
    } finally {
      if (mounted) setState(() => _purchasingYearly = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _restoringPurchases = true);
    try {
      final isPremium = await PaymentService.restorePurchases();
      if (!mounted) return;
      if (isPremium) {
        await _onPurchaseSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kein aktives Abo gefunden.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Wiederherstellen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _restoringPurchases = false);
    }
  }

  Future<void> _onPurchaseSuccess() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Premium aktiviert! Waidmannsheil!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.pop(context, true);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _checkBetaAccess() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;
    setState(() => _checkingEmail = true);

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/check-beta'),
        body: {'email': email},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String;

      if (status == 'granted') {
        final expires = data['expires'] as String;
        final prefs = await SharedPreferences.getInstance();
        final expiryDate = DateTime.parse(expires);
        await prefs.setBool('premium_active', true);
        await prefs.setInt('premium_expiry_ms', expiryDate.millisecondsSinceEpoch);
        if (mounted) {
          setState(() => _checkingEmail = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Beta-Zugang aktiv bis $expires. Waidmannsheil!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context);
        }
        return;
      } else if (status == 'expired') {
        final expires = data['expires'] as String;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Beta-Zugang abgelaufen am $expires.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _checkingEmail = false);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Verbindungsfehler. Später nochmal versuchen.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _checkingEmail = false);
      }
      return;
    }

    // status == denied
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
                onPressed: _purchasingMonthly ? null : _purchaseMonthly,
                style: FilledButton.styleFrom(
                  backgroundColor: WaidblickColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _purchasingMonthly
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Column(
                        children: [
                          Text(
                            'Premium — $_monthlyPrice',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'Monatlich kündbar',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),

              // Button 2: Jahresabo
              OutlinedButton(
                onPressed: _purchasingYearly ? null : _purchaseYearly,
                style: OutlinedButton.styleFrom(
                  foregroundColor: WaidblickColors.primary,
                  side: const BorderSide(
                      color: WaidblickColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _purchasingYearly
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WaidblickColors.primary,
                        ),
                      )
                    : Column(
                        children: [
                          Text(
                            'Jahresabo — $_yearlyPrice',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'Spart 57 € gegenüber Monatsabo',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),

              // Käufe wiederherstellen
              TextButton(
                onPressed: _restoringPurchases ? null : _restorePurchases,
                child: _restoringPurchases
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WaidblickColors.textSecondary,
                        ),
                      )
                    : const Text(
                        'Käufe wiederherstellen',
                        style: TextStyle(
                            color: WaidblickColors.textSecondary, fontSize: 13),
                      ),
              ),

              // ── oder ── Divider
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'oder',
                        style: TextStyle(
                            color: WaidblickColors.textSecondary, fontSize: 13),
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
                  hintStyle:
                      const TextStyle(color: WaidblickColors.textSecondary),
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
                  side: const BorderSide(
                      color: WaidblickColors.primary, width: 1),
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
