import 'package:flutter/material.dart';
import '../widgets/age_class_badge.dart';
import '../models/age_estimate.dart';

/// Info-Screen: Erklärt Altersklassen, Merkmale und Bedienungshinweise.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Info & Anleitung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Über die App
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pets, size: 28),
                      const SizedBox(width: 8),
                      Text('Über WAIDBLICK',
                          style: theme.textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'WAIDBLICK hilft Jägerinnen und Jägern, das Alter von Gämsen '
                    'per Foto zu schätzen. Die KI analysiert morphologische Merkmale '
                    'und gibt eine Wahrscheinlichkeitsverteilung über 5 Altersklassen aus.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Die Schätzung verbessert sich mit jedem zusätzlichen Foto '
                    '(Bayessches Update). Mehrere Perspektiven erhöhen die Genauigkeit.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Kurzanleitung
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, size: 24),
                      const SizedBox(width: 8),
                      Text('Kurzanleitung',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StepItem(
                    step: '1',
                    text: 'Im Tab "Analyse" auf den Kamera-Button tippen.',
                  ),
                  _StepItem(
                    step: '2',
                    text: 'Foto aus der Galerie wählen oder direkt fotografieren.',
                  ),
                  _StepItem(
                    step: '3',
                    text:
                        'Ergebnis prüfen. Für mehr Genauigkeit: "Weiteres Foto" tippen '
                        '— jedes neue Foto verbessert die Schätzung!',
                  ),
                  _StepItem(
                    step: '4',
                    text:
                        'Mit "Im Lookbook speichern" die Analyse ins Lookbook eintragen.',
                  ),
                  _StepItem(
                    step: '5',
                    text:
                        'Im Lookbook können Analysen verwaltet und mit '
                        'neuen Sichtungen angereichert werden.',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mehr Fotos = bessere Genauigkeit!\n'
                            'Optimal: Seitenaufnahme in gutem Licht.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Perspektiven-Gewichtung
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Perspektiven & Qualität',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const Text(
                      'Das System gewichtet Fotos je nach Perspektive:'),
                  const SizedBox(height: 8),
                  _PerspRow(icon: Icons.arrow_back, label: 'Seitenaufnahme', weight: '100%', best: true),
                  _PerspRow(icon: Icons.rotate_right, label: 'Halbseitig', weight: '75%'),
                  _PerspRow(icon: Icons.face, label: 'Frontalaufnahme', weight: '50%'),
                  _PerspRow(icon: Icons.arrow_forward, label: 'Hintenaufnahme', weight: '35%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Altersklassen
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Altersklassen', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ..._ageClassData.map(
                    (data) => _AgeClassInfo(
                      ageClass: data.ageClass,
                      age: data.age,
                      description: data.description,
                      features: data.features,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Analysierte Merkmale
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analysierte Merkmale',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                      'Die KI bewertet folgende morphologische Merkmale:'),
                  const SizedBox(height: 12),
                  ..._featureDescriptions.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lens,
                              size: 8, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  TextSpan(
                                    text: '${f.$1}: ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: f.$2),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Version
          Center(
            child: Text(
              'WAIDBLICK v1.2.0 — KI-Bildanalyse mit Gemini Vision',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// --- Hilfsdaten ---

class _AgeClassEntry {
  final AgeClass ageClass;
  final String age;
  final String description;
  final List<String> features;
  const _AgeClassEntry(this.ageClass, this.age, this.description, this.features);
}

const _ageClassData = [
  _AgeClassEntry(
    AgeClass.kitz,
    '0–1 Jahr',
    'Im ersten Lebensjahr. Kleiner Körperbau, helles Fell.',
    ['Heller Zügel-Kontrast', 'Glänzendes Fell', 'Kleiner Körper', 'Keine Hornbiegung'],
  ),
  _AgeClassEntry(
    AgeClass.jung,
    '1–3 Jahre',
    'Jährling bis Zweijähriger. Schlank, voll entwickelte Proportionen.',
    ['Noch deutlicher Zügel-Kontrast', 'Schlanke Flanken', 'Gerade Rückenlinie', 'Kurze Hörner'],
  ),
  _AgeClassEntry(
    AgeClass.mittel,
    '3–7 Jahre',
    'Mittleres Alter. Vollständig entwickelt, gute Konstitution.',
    ['Mittlerer Kontrast', 'Normale Flanken', 'Gerade bis leicht konkave Linie', 'Mittlere Hornlänge'],
  ),
  _AgeClassEntry(
    AgeClass.alt,
    '7–12 Jahre',
    'Alter Bock / alte Geis. Sichtbare Altersmerkmale.',
    ['Schwacher Zügel-Kontrast', 'Leicht eingefallene Flanken', 'Konkave Rückenlinie', 'Stark gebogene Hörner'],
  ),
  _AgeClassEntry(
    AgeClass.sehrAlt,
    '>12 Jahre',
    'Sehr alte Tiere. Deutliche Abnutzungserscheinungen.',
    ['Kein Zügel-Kontrast', 'Stark eingefallene Flanken', 'Deutlich konkave Linie', 'Sehr starke Hornbiegung', 'Steife Bewegung'],
  ),
];

const _featureDescriptions = [
  ('Zügel-Kontrast', 'Kontrast des hellen Abzeichens um die Schnauze. Hoch = jung, niedrig = alt.'),
  ('Flanken eingefallen', 'Hohlheit der Flankenpartie. Stark eingefallen = hohes Alter.'),
  ('Rückenlinie konkav', 'Durchhängen der Rückenlinie. Konkav = alt/sehr alt.'),
  ('Träger-Masse', 'Muskelmasse im Schulterbereich. Bei Böcken und alten Tieren erhöht.'),
  ('Krucken-Häkel', 'Biegungsgrad der Hornspitzen. Stark gebogen = alt/sehr alt.'),
  ('Körperschwerpunkt vorne', 'Vorverlagerung durch Muskelschwund am Hinterteil = alt.'),
  ('Fellglanz', 'Qualität und Glanz des Fells. Hoch = jung und gesund.'),
  ('Bewegungssteifheit', 'Steifigkeit beim Gehen. Stark = alt/sehr alt.'),
];

// --- Helper Widgets ---

class _StepItem extends StatelessWidget {
  final String step;
  final String text;
  const _StepItem({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(step,
                style: const TextStyle(fontSize: 11, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PerspRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String weight;
  final bool best;
  const _PerspRow(
      {required this.icon,
      required this.label,
      required this.weight,
      this.best = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            weight,
            style: TextStyle(
              fontWeight: best ? FontWeight.bold : FontWeight.normal,
              color: best ? Colors.green : null,
            ),
          ),
          if (best) ...[
            const SizedBox(width: 4),
            const Icon(Icons.star, size: 14, color: Colors.amber),
          ],
        ],
      ),
    );
  }
}

class _AgeClassInfo extends StatelessWidget {
  final AgeClass ageClass;
  final String age;
  final String description;
  final List<String> features;

  const _AgeClassInfo({
    required this.ageClass,
    required this.age,
    required this.description,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AgeClassBadge(ageClass: ageClass),
              const SizedBox(width: 8),
              Text(age,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: features
                .map(
                  (f) => Chip(
                    label: Text(f,
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
