import 'package:flutter/material.dart';

/// Foto-Anleitung Screen — erklärt wie man optimale Fotos für die Analyse macht.
class PhotoGuideScreen extends StatefulWidget {
  const PhotoGuideScreen({super.key});

  @override
  State<PhotoGuideScreen> createState() => _PhotoGuideScreenState();
}

class _PhotoGuideScreenState extends State<PhotoGuideScreen> {
  String _selectedWildart = 'gams'; // 'gams', 'reh', 'hirsch'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto-Anleitung'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Section 1: Das perfekte Foto ──────────────────────────────────
          _SectionHeader(
            icon: Icons.checklist_rounded,
            title: 'Das perfekte Foto',
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          _ChecklistCard(
            items: const [
              _CheckItem(ok: true, text: 'Tier nimmt 40–70% des Bildes ein'),
              _CheckItem(ok: true, text: 'Scharf (keine Bewegungsunschärfe)'),
              _CheckItem(ok: true, text: 'Seitenaufnahme wenn möglich'),
              _CheckItem(
                  ok: true,
                  text: 'Gutes Licht (keine harte Mittagssonne, kein Gegenlicht)'),
              _CheckItem(ok: true, text: 'Gehörn vollständig sichtbar (Rehbock)'),
              _CheckItem(
                  ok: true, text: 'Beide Seiten des Körpers erkennbar'),
              _CheckItem(
                  ok: false, text: 'Nicht: Tier 1/10 Bildgröße (zu weit weg)'),
              _CheckItem(
                  ok: false,
                  text: 'Nicht: Bild zu dunkel (Dämmerung ohne Unterstützung)'),
              _CheckItem(ok: false, text: 'Nicht: Verwackelt'),
              _CheckItem(
                  ok: false,
                  text: 'Nicht: Tier hinter Büschen/Gras (verdeckt)'),
            ],
          ),
          const SizedBox(height: 20),

          // ── Section 2: Schärfe ───────────────────────────────────────────
          _SectionHeader(
            icon: Icons.camera_enhance_rounded,
            title: 'Schärfe',
            color: Colors.blue,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            color: Colors.blue,
            children: [
              _InfoRow(
                icon: Icons.do_not_touch_rounded,
                text: 'Ruhig halten — Atemtechnik: ausatmen, dann drücken',
              ),
              _InfoRow(
                icon: Icons.photo_camera_back,
                text: 'Burst-Modus nutzen (mehrere Fotos = eines ist scharf)',
              ),
              _InfoRow(
                icon: Icons.phone_iphone,
                text: 'Beide Hände am Gerät, Ellbogen abstützen',
              ),
              _InfoRow(
                icon: Icons.landscape,
                text: 'Stativ oder natürliche Auflage (Ast, Stein)',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Section 3: Größe im Bild ────────────────────────────────────
          _SectionHeader(
            icon: Icons.zoom_in_rounded,
            title: 'Tier-Größe im Bild',
            color: Colors.orange,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            color: Colors.orange,
            children: [
              _InfoRow(
                icon: Icons.aspect_ratio,
                text: 'Ideal: Tier nimmt 40–70% der Bildfläche ein',
              ),
              _InfoRow(
                icon: Icons.zoom_in,
                text: 'Näher heran gehen oder optischen Zoom nutzen',
              ),
              _InfoRow(
                icon: Icons.warning_amber_rounded,
                text: 'Unter 20% Bildfläche: Analyse sehr ungenau',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SizeVisualizer(),
          const SizedBox(height: 20),

          // ── Section 4: Perspektive ──────────────────────────────────────
          _SectionHeader(
            icon: Icons.view_in_ar_rounded,
            title: 'Perspektive',
            color: Colors.purple,
          ),
          const SizedBox(height: 8),
          // Wildart-Switcher
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gams', label: Text('Gämse')),
              ButtonSegment(value: 'reh', label: Text('Reh')),
              ButtonSegment(value: 'hirsch', label: Text('Hirsch')),
            ],
            selected: {_selectedWildart},
            onSelectionChanged: (v) => setState(() => _selectedWildart = v.first),
          ),
          const SizedBox(height: 12),
          _WildartPerspectiveGrid(wildart: _selectedWildart),
          const SizedBox(height: 12),
          _PerspectiveCard(),
          const SizedBox(height: 20),

          // ── Section 5: Licht ────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.wb_sunny_rounded,
            title: 'Licht',
            color: Colors.amber,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            color: Colors.amber,
            children: [
              _InfoRow(
                icon: Icons.wb_twilight,
                text: 'Morgen- und Abenddämmerung: optimales, weiches Licht',
              ),
              _InfoRow(
                icon: Icons.wb_sunny,
                text: 'Harte Mittagssonne vermeiden (starke Schatten)',
              ),
              _InfoRow(
                icon: Icons.flare,
                text: 'Kein Gegenlicht — Sonne hinter dem Fotografen',
              ),
              _InfoRow(
                icon: Icons.nights_stay,
                text: 'Dämmerung: Bildstabilisator aktivieren',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Section 6: Ehrliche Grenzen ─────────────────────────────────
          _SectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'Was wir NICHT analysieren können',
            color: Colors.red,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            color: Colors.red,
            children: [
              _InfoRow(
                icon: Icons.close,
                text: 'Gewicht oder Körpermaße direkt messen',
              ),
              _InfoRow(
                icon: Icons.close,
                text: 'Gesundheitszustand (Krankheiten, Verletzungen)',
              ),
              _InfoRow(
                icon: Icons.close,
                text: 'Genaue Altersbestimmung ohne Zahn-Gutachten',
              ),
              _InfoRow(
                icon: Icons.close,
                text:
                    'Tier hinter Büschen/Gras: verdeckte Körperteile werden nicht erkannt',
              ),
              _InfoRow(
                icon: Icons.close,
                text: 'Nachtbilder ohne Beleuchtung',
              ),
              _InfoRow(
                icon: Icons.close,
                text:
                    'Thermografische oder Wärmebilder (andere Kameratechnik)',
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Footer
          Center(
            child: Text(
              'WAIDBLICK • Foto-Tipps für präzise Analyse',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _CheckItem {
  final bool ok;
  final String text;

  const _CheckItem({required this.ok, required this.text});
}

class _ChecklistCard extends StatelessWidget {
  final List<_CheckItem> items;

  const _ChecklistCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.ok
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: item.ok ? Colors.green : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.text,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Color color;
  final List<Widget> children;

  const _InfoCard({required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      color: color.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: children),
      ),
    );
  }
}

/// Visuelle Darstellung der Tier-Größe im Bild
class _SizeVisualizer extends StatelessWidget {
  const _SizeVisualizer();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              'Tier-Größe im Bild',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _SizeExample(
              label: 'Zu klein (<20%)',
              fraction: 0.15,
              color: Colors.red,
              icon: Icons.close,
            ),
            const SizedBox(height: 8),
            _SizeExample(
              label: 'Ausreichend (20–40%)',
              fraction: 0.30,
              color: Colors.orange,
              icon: Icons.remove,
            ),
            const SizedBox(height: 8),
            _SizeExample(
              label: 'Ideal (40–70%) ✅',
              fraction: 0.55,
              color: Colors.green,
              icon: Icons.check,
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeExample extends StatelessWidget {
  final String label;
  final double fraction;
  final Color color;
  final IconData icon;

  const _SizeExample({
    required this.label,
    required this.fraction,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        SizedBox(
          width: 160,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey.shade200,
            ),
            child: FractionallySizedBox(
              widthFactor: fraction,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: color.withValues(alpha: 0.6),
                ),
                child: Center(
                  child: Text(
                    '${(fraction * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Perspektiv-Bilder-Grid mit echten Illustrationen
class _WildartPerspectiveGrid extends StatelessWidget {
  final String wildart; // 'gams', 'reh', 'hirsch'

  const _WildartPerspectiveGrid({required this.wildart});

  static const Map<String, String> _labels = {
    'vorn': 'Von vorne',
    'seite': 'Seitenansicht',
    'hinten': 'Von hinten',
    '45grad': 'Halbprofil',
  };

  static const Map<String, double> _scores = {
    'seite': 1.0,
    '45grad': 0.75,
    'vorn': 0.5,
    'hinten': 0.35,
  };

  @override
  Widget build(BuildContext context) {
    final perspectives = ['seite', '45grad', 'vorn', 'hinten'];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: perspectives.map((persp) {
        final score = _scores[persp] ?? 0.5;
        final color = score >= 0.9 ? Colors.green
            : score >= 0.7 ? Colors.lightGreen
            : score >= 0.5 ? Colors.orange
            : Colors.red;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/guide/${wildart}_${persp}.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  color: Colors.black.withOpacity(0.55),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _labels[persp] ?? persp,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${(score * 100).round()}%',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Visuell Perspektiv-Gewichtung
class _PerspectiveCard extends StatelessWidget {
  const _PerspectiveCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      color: Colors.purple.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _PerspectiveRow(
              icon: Icons.view_agenda_rounded,
              label: 'Seite',
              subLabel: 'Optimal',
              fraction: 1.0,
              color: Colors.green,
              percent: 100,
            ),
            const SizedBox(height: 8),
            _PerspectiveRow(
              icon: Icons.turn_slight_right,
              label: 'Halbprofil',
              subLabel: 'Gut',
              fraction: 0.75,
              color: Colors.lightGreen,
              percent: 75,
            ),
            const SizedBox(height: 8),
            _PerspectiveRow(
              icon: Icons.face_rounded,
              label: 'Front',
              subLabel: 'Ausreichend',
              fraction: 0.5,
              color: Colors.orange,
              percent: 50,
            ),
            const SizedBox(height: 8),
            _PerspectiveRow(
              icon: Icons.arrow_back_ios_new_rounded,
              label: 'Hinten',
              subLabel: 'Schwach',
              fraction: 0.35,
              color: Colors.red,
              percent: 35,
            ),
          ],
        ),
      ),
    );
  }
}

class _PerspectiveRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subLabel;
  final double fraction;
  final Color color;
  final int percent;

  const _PerspectiveRow({
    required this.icon,
    required this.label,
    required this.subLabel,
    required this.fraction,
    required this.color,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                subLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey.shade200,
            ),
            child: FractionallySizedBox(
              widthFactor: fraction,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            '$percent%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ),
      ],
    );
  }
}
