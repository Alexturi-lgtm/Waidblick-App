import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hunting_regulations.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/profile_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'impressum_screen.dart';
import 'login_screen.dart';
import 'paywall_screen.dart';

/// Einstellungs-Screen – Konto, Region, Daten, App, Rechtliches
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;

  // Konto
  String? _userEmail;
  String? _username;
  bool _isPremium = false;
  String? _renewalDate;

  // Region
  HuntingRegion _selectedRegion = HuntingRegion.other;

  // App-Toggles
  bool _notificationsEnabled = false;
  bool _gpsAutoEnabled = false;

  // Rechtliches
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final region = await SettingsService.getRegion();
    final email = AuthService.currentUser?.email;
    bool premium = false;
    String? username;
    String? renewalDate;

    try {
      premium = await ProfileService.isPremium();
      final profile = await ProfileService.getProfile();
      username = profile?['username'] as String? ??
          profile?['full_name'] as String?;
      if (premium) {
        final expiresRaw = profile?['subscription_expires'] as String?;
        if (expiresRaw != null) {
          try {
            final dt = DateTime.parse(expiresRaw).toLocal();
            renewalDate =
                '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
          } catch (_) {}
        }
      }
    } catch (_) {}

    String version = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _selectedRegion = region;
        _userEmail = email;
        _username = username;
        _isPremium = premium;
        _renewalDate = renewalDate;
        _appVersion = version;
        _loading = false;
      });
    }
  }

  // ── Region helpers ──────────────────────────────────────────────────────────

  String _regionToString(HuntingRegion r) {
    switch (r) {
      case HuntingRegion.bayern:
        return 'Bayern';
      case HuntingRegion.tirol:
        return 'Tirol';
      case HuntingRegion.salzburg:
        return 'Salzburg';
      case HuntingRegion.steiermark:
        return 'Steiermark';
      default:
        return 'Sonstige';
    }
  }

  HuntingRegion _stringToRegion(String s) {
    switch (s) {
      case 'Bayern':
        return HuntingRegion.bayern;
      case 'Tirol':
        return HuntingRegion.tirol;
      case 'Salzburg':
        return HuntingRegion.salzburg;
      case 'Steiermark':
        return HuntingRegion.steiermark;
      default:
        return HuntingRegion.other;
    }
  }

  static const _regionLabels = [
    'Bayern',
    'Tirol',
    'Steiermark',
    'Salzburg',
    'Sonstige',
  ];

  // ── Aktionen ────────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Abmelden?',
        message: 'Möchtest du dich wirklich abmelden?',
        confirmLabel: 'Abmelden',
        destructive: false,
      ),
    );
    if (confirmed != true || !mounted) return;
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _exportData() async {
    try {
      await DatabaseService.instance.load();
      final individuals = DatabaseService.instance.individuals;
      final jsonStr = const JsonEncoder.withIndent('  ')
          .convert(individuals.map((i) => i.toJson()).toList());
      await Share.share(jsonStr, subject: 'Waidblick – Daten-Export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export fehlgeschlagen: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _clearAnalysisHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Analyse-Verlauf löschen?',
        message:
            'Alle lokal gespeicherten Analyse-Daten werden unwiderruflich gelöscht.',
        confirmLabel: 'Löschen',
        destructive: true,
      ),
    );
    if (confirmed != true || !mounted) return;
    // Löscht alle Individuen/Sichtungen aus der lokalen DB
    await DatabaseService.instance.load();
    for (final ind in List.of(DatabaseService.instance.individuals)) {
      await DatabaseService.instance.deleteIndividual(ind.id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analyse-Verlauf gelöscht.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    // Stufe 1
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Konto löschen?',
        message:
            'Dein Konto und alle damit verbundenen Daten werden dauerhaft gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.',
        confirmLabel: 'Weiter',
        destructive: true,
      ),
    );
    if (step1 != true || !mounted) return;

    // Stufe 2 – finale Bestätigung
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Wirklich löschen?',
        message:
            'Letzte Warnung: Alle Daten werden sofort und endgültig gelöscht.',
        confirmLabel: 'Konto endgültig löschen',
        destructive: true,
      ),
    );
    if (step2 != true || !mounted) return;

    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konto gelöscht. Auf Wiedersehen!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link konnte nicht geöffnet werden.')),
        );
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          'EINSTELLUNGEN',
          style: TextStyle(
            color: Color(0xFFF5A623),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF5A623)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                // ── KONTO ──────────────────────────────────────────────────
                _SectionHeader(label: 'KONTO'),
                const SizedBox(height: 8),
                _buildKontoCard(),
                const SizedBox(height: 24),

                // ── REGION ─────────────────────────────────────────────────
                _SectionHeader(label: 'REGION'),
                const SizedBox(height: 8),
                _buildRegionCard(),
                const SizedBox(height: 24),

                // ── DATEN ──────────────────────────────────────────────────
                _SectionHeader(label: 'DATEN'),
                const SizedBox(height: 8),
                _buildDatenCard(),
                const SizedBox(height: 24),

                // ── APP ────────────────────────────────────────────────────
                _SectionHeader(label: 'APP'),
                const SizedBox(height: 8),
                _buildAppCard(),
                const SizedBox(height: 24),

                // ── RECHTLICHES ────────────────────────────────────────────
                _SectionHeader(label: 'RECHTLICHES'),
                const SizedBox(height: 8),
                _buildRechtlichesCard(),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  // ── Konto-Card ──────────────────────────────────────────────────────────────

  Widget _buildKontoCard() {
    if (!AuthService.isLoggedIn) {
      return _Card(
        child: Column(
          children: [
            const Text(
              'Nicht angemeldet',
              style: TextStyle(
                color: WaidblickColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF5A623),
                side: const BorderSide(color: Color(0xFFF5A623)),
              ),
              child: const Text('Anmelden'),
            ),
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + Info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF5A623).withOpacity(0.4),
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFFF5A623),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_username != null && _username!.isNotEmpty)
                      Text(
                        _username!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (_userEmail != null)
                      Text(
                        _userEmail!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Abo-Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _isPremium
                            ? const Color(0xFFF5A623).withOpacity(0.18)
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isPremium ? 'PREMIUM' : 'FREE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: _isPremium
                              ? const Color(0xFFF5A623)
                              : Colors.white.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Verlängerungsdatum (nur Premium)
          if (_isPremium && _renewalDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.autorenew, size: 14, color: Color(0xFFF5A623)),
                const SizedBox(width: 6),
                Text(
                  'Abo läuft bis: $_renewalDate',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          const SizedBox(height: 14),

          // Buttons
          Row(
            children: [
              Expanded(
                child: _GoldOutlineButton(
                  icon: Icons.star_outline,
                  label: 'Abo verwalten',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RedOutlineButton(
                  icon: Icons.logout,
                  label: 'Abmelden',
                  onPressed: _signOut,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Region-Card ─────────────────────────────────────────────────────────────

  Widget _buildRegionCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jagdregion',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Beeinflusst Abschussklassen und Schusszeiten',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _regionToString(_selectedRegion),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFF5A623), width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            iconEnabledColor: const Color(0xFFF5A623),
            items: _regionLabels
                .map(
                  (r) => DropdownMenuItem<String>(
                    value: r,
                    child: Text(r),
                  ),
                )
                .toList(),
            onChanged: (val) async {
              if (val == null) return;
              final region = _stringToRegion(val);
              await SettingsService.setRegion(region);
              if (mounted) setState(() => _selectedRegion = region);
            },
          ),
        ],
      ),
    );
  }

  // ── Daten-Card ──────────────────────────────────────────────────────────────

  Widget _buildDatenCard() {
    return _Card(
      child: Column(
        children: [
          _TappableRow(
            icon: Icons.download_outlined,
            label: 'Alle Daten exportieren',
            onTap: _exportData,
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          _TappableRow(
            icon: Icons.delete_outline,
            label: 'Analyse-Verlauf löschen',
            labelColor: Colors.orangeAccent,
            onTap: _clearAnalysisHistory,
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          _TappableRow(
            icon: Icons.delete_forever_outlined,
            label: 'Konto löschen',
            labelColor: Colors.redAccent,
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }

  // ── App-Card ────────────────────────────────────────────────────────────────

  Widget _buildAppCard() {
    return _Card(
      child: Column(
        children: [
          _ToggleRow(
            icon: Icons.notifications_outlined,
            title: 'Push-Benachrichtigungen',
            subtitle: 'Hinweise zu Jagdzeiten und Updates',
            value: _notificationsEnabled,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          _ToggleRow(
            icon: Icons.gps_fixed_outlined,
            title: 'GPS automatisch verwenden',
            subtitle: 'Standort bei Analysen automatisch ermitteln',
            value: _gpsAutoEnabled,
            onChanged: (v) => setState(() => _gpsAutoEnabled = v),
          ),
        ],
      ),
    );
  }

  // ── Rechtliches-Card ────────────────────────────────────────────────────────

  Widget _buildRechtlichesCard() {
    return _Card(
      child: Column(
        children: [
          _TappableRow(
            icon: Icons.gavel_outlined,
            label: 'Impressum',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImpressumScreen()),
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          _TappableRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Datenschutzerklärung',
            onTap: () => _openUrl('https://waidblick.de/datenschutz'),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          _TappableRow(
            icon: Icons.description_outlined,
            label: 'Nutzungsbedingungen',
            onTap: () => _openUrl('https://waidblick.de/nutzungsbedingungen'),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Colors.white.withOpacity(0.35),
                ),
                const SizedBox(width: 12),
                Text(
                  'Version $_appVersion',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SHARED WIDGETS ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.45), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFF5A623),
          ),
        ],
      ),
    );
  }
}

class _TappableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;

  const _TappableRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = labelColor ?? Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color.withOpacity(0.7), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.25),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _GoldOutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFF5A623),
        side: const BorderSide(color: Color(0xFFF5A623)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _RedOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _RedOutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: Text(
        message,
        style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Abbrechen',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? Colors.redAccent : const Color(0xFFF5A623),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
