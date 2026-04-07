import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/settings_service.dart';
import '../models/hunting_regulations.dart';
import '../theme/app_theme.dart';
import 'impressum_screen.dart';
import 'paywall_screen.dart';
import 'login_screen.dart';

/// Einstellungs-Screen: Region, Benachrichtigungen, Konto, Datenschutz
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  HuntingRegion _selectedRegion = HuntingRegion.other;
  bool _loading = true;
  bool _learningEnabled = false;
  bool _notificationsEnabled = false;

  // Account & Voucher
  String? _userEmail;
  String _subscriptionLabel = 'Free';
  bool _voucherLoading = false;
  final TextEditingController _voucherController = TextEditingController();

  static const List<Map<String, String>> _regionItems = [
    {'value': 'Bayern', 'label': 'Bayern'},
    {'value': 'Tirol', 'label': 'Tirol'},
    {'value': 'Salzburg', 'label': 'Salzburg'},
    {'value': 'Steiermark', 'label': 'Steiermark'},
    {'value': 'Vorarlberg', 'label': 'Vorarlberg'},
    {'value': 'Kärnten', 'label': 'Kärnten'},
    {'value': 'Sonstige', 'label': 'Sonstige Region'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  String _regionFromEnum(HuntingRegion r) {
    switch (r) {
      case HuntingRegion.bayern: return 'Bayern';
      case HuntingRegion.tirol: return 'Tirol';
      case HuntingRegion.salzburg: return 'Salzburg';
      case HuntingRegion.steiermark: return 'Steiermark';
      default: return 'Sonstige';
    }
  }

  Future<void> _loadSettings() async {
    final region = await SettingsService.getRegion();
    final learning = await SettingsService.getLearningEnabled();
    final email = AuthService.currentUser?.email;
    String subLabel = 'Free';
    try {
      final isPremium = await ProfileService.isPremium();
      if (isPremium) {
        final profile = await AuthService.getProfile();
        final status =
            profile?['subscription_status'] as String? ?? 'premium';
        subLabel = status == 'beta' ? 'Beta' : 'Premium';
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _selectedRegion = region;
        _learningEnabled = learning;
        _userEmail = email;
        _subscriptionLabel = subLabel;
        _loading = false;
      });
    }
  }

  Future<void> _redeemVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Code eingeben.')),
      );
      return;
    }
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst anmelden.')),
      );
      return;
    }
    setState(() => _voucherLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://204.168.216.110/redeem-voucher'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({'code': code}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final expiresRaw = data?['expires_at'] as String?;
        String expiresStr = '';
        if (expiresRaw != null) {
          try {
            final dt = DateTime.parse(expiresRaw).toLocal();
            expiresStr =
                ' bis ${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
          } catch (_) {}
        }
        _voucherController.clear();
        setState(() => _subscriptionLabel = 'Premium');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Premium aktiv$expiresStr 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code ungültig oder bereits verwendet.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Netzwerkfehler beim Einlösen.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _voucherLoading = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaidblickColors.background,
      appBar: AppBar(
        backgroundColor: WaidblickColors.background,
        elevation: 0,
        title: const Text(
          'EINSTELLUNGEN',
          style: TextStyle(
            color: WaidblickColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: WaidblickColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── REGION ──────────────────────────────────────────────
                _SectionHeader(label: 'REGION'),
                const SizedBox(height: 8),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jagdregion',
                        style: TextStyle(
                          color: WaidblickColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Bestimmt die Abschussklassen und Jagdrecht-Hinweise',
                        style: TextStyle(
                          color: WaidblickColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _regionFromEnum(_selectedRegion),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: WaidblickColors.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: WaidblickColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: WaidblickColors.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        dropdownColor: WaidblickColors.surfaceVariant,
                        style: const TextStyle(
                            color: WaidblickColors.textPrimary,
                            fontSize: 14),
                        items: _regionItems
                            .map((r) => DropdownMenuItem<String>(
                                  value: r['value'],
                                  child: Text(r['label']!),
                                ))
                            .toList(),
                        onChanged: (val) async {
                          if (val == null) return;
                          HuntingRegion region;
                          switch (val) {
                            case 'Bayern':
                              region = HuntingRegion.bayern;
                              break;
                            case 'Tirol':
                              region = HuntingRegion.tirol;
                              break;
                            case 'Salzburg':
                              region = HuntingRegion.salzburg;
                              break;
                            case 'Steiermark':
                              region = HuntingRegion.steiermark;
                              break;
                            default:
                              region = HuntingRegion.other;
                          }
                          await SettingsService.setRegion(region);
                          if (mounted) {
                            setState(() => _selectedRegion = region);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── BENACHRICHTIGUNGEN ────────────────────────────────────
                _SectionHeader(label: 'BENACHRICHTIGUNGEN'),
                const SizedBox(height: 8),
                _SettingsCard(
                  child: _ToggleRow(
                    icon: Icons.notifications_outlined,
                    title: 'Push-Benachrichtigungen',
                    subtitle: 'Hinweise zu Jagdzeiten und Updates',
                    value: _notificationsEnabled,
                    onChanged: (v) =>
                        setState(() => _notificationsEnabled = v),
                  ),
                ),
                const SizedBox(height: 20),

                // ── KONTO ─────────────────────────────────────────────────
                _SectionHeader(label: 'KONTO'),
                const SizedBox(height: 8),
                if (AuthService.isLoggedIn) ...[
                  _SettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: WaidblickColors.primary
                                    .withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: WaidblickColors.primary
                                        .withOpacity(0.4)),
                              ),
                              child: const Icon(Icons.person_outline,
                                  color: WaidblickColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_userEmail != null)
                                    Text(
                                      _userEmail!,
                                      style: const TextStyle(
                                        color: WaidblickColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _subscriptionLabel == 'Free'
                                          ? WaidblickColors.surfaceVariant
                                          : WaidblickColors.primary
                                              .withOpacity(0.15),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _subscriptionLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _subscriptionLabel == 'Free'
                                            ? WaidblickColors.textSecondary
                                            : WaidblickColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: WaidblickColors.border, height: 1),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.star_outline,
                                    size: 16),
                                label: const Text('Abonnement',
                                    style: TextStyle(fontSize: 12)),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const PaywallScreen()),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: WaidblickColors.primary,
                                  side: const BorderSide(
                                      color: WaidblickColors.primary),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.logout, size: 16),
                                label: const Text('Ausloggen',
                                    style: TextStyle(fontSize: 12)),
                                onPressed: _signOut,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(
                                      color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Gutschein
                  _SettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎟️ Gutschein-Code',
                          style: TextStyle(
                            color: WaidblickColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _voucherController,
                                decoration: InputDecoration(
                                  hintText: 'Code eingeben',
                                  hintStyle: const TextStyle(
                                      color: WaidblickColors.textSecondary,
                                      fontSize: 13),
                                  filled: true,
                                  fillColor: WaidblickColors.surfaceVariant,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: WaidblickColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: WaidblickColors.border),
                                  ),
                                ),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: WaidblickColors.textPrimary),
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _voucherLoading
                                  ? null
                                  : _redeemVoucher,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: WaidblickColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                              child: _voucherLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text('Einlösen',
                                      style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _SettingsCard(
                    child: Center(
                      child: Column(
                        children: [
                          const Text(
                            'Nicht angemeldet',
                            style: TextStyle(
                                color: WaidblickColors.textSecondary,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: WaidblickColors.primary,
                              side: const BorderSide(
                                  color: WaidblickColors.primary),
                            ),
                            child: const Text('Anmelden'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // ── DATENSCHUTZ ───────────────────────────────────────────
                _SectionHeader(label: 'DATENSCHUTZ & LEARNING'),
                const SizedBox(height: 8),
                _SettingsCard(
                  child: _ToggleRow(
                    icon: Icons.psychology_outlined,
                    title: 'Fotos zum Learning bereitstellen',
                    subtitle:
                        'Anonyme Fotos helfen das KI-Modell zu verbessern',
                    value: _learningEnabled,
                    onChanged: (v) async {
                      await SettingsService.setLearningEnabled(v);
                      if (mounted) setState(() => _learningEnabled = v);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // ── IMPRESSUM ─────────────────────────────────────────────
                _SectionHeader(label: 'RECHTLICHES'),
                const SizedBox(height: 8),
                _SettingsCard(
                  child: Column(
                    children: [
                      _TappableRow(
                        icon: Icons.gavel_outlined,
                        label: 'Impressum',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ImpressumScreen()),
                        ),
                      ),
                      const Divider(
                          color: WaidblickColors.border, height: 1),
                      _TappableRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Datenschutzerklärung',
                        onTap: () {
                          // TODO: Datenschutz-Screen
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── HELPER WIDGETS ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: WaidblickColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WaidblickColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x14FFFFFF),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: WaidblickColors.textSecondary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: WaidblickColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: WaidblickColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: WaidblickColors.primary,
        ),
      ],
    );
  }
}

class _TappableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TappableRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon,
                color: WaidblickColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: WaidblickColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: WaidblickColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
