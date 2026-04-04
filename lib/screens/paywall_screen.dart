import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Paywall-Screen: Zeigt Freemium-Limit und Upgrade-Optionen.
class PaywallScreen extends StatelessWidget {
  final bool isLookbookLimit;

  const PaywallScreen({super.key, this.isLookbookLimit = false});

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
                isLookbookLimit
                    ? '3 Lookbook-Einträge gratis. Für unbegrenzte Einträge:'
                    : '5 Analysen/Monat gratis. Für unbegrenzte Analysen:',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: WaidblickColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),

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
                  // TODO: In-App-Purchase implementieren
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
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Button 2: Jahresabo
              OutlinedButton(
                onPressed: () {
                  // TODO: In-App-Purchase implementieren
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('In-App-Purchase kommt bald!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: WaidblickColors.primary,
                  side: const BorderSide(color: WaidblickColors.primary, width: 1.5),
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
              const SizedBox(height: 8),

              // Button 3: Schließen
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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
