import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'impressum_screen.dart';

// ─── FARB-KONSTANTEN ─────────────────────────────────────────────────────────

const _kGold = Color(0xFFF5A623);
const _kBg = Color(0xFF0A0A0A);
const _kGamsColor = Color(0xFFF5A623); // Gold
const _kRehColor = Color(0xFF4CAF50); // Grün
const _kRotColor = Color(0xFFE53935); // Rot
const _kTableRowA = Color(0xFF141414);
const _kTableRowB = Color(0xFF1A1A1A);
const _kYoung = Color(0xFF4CAF50);
const _kMid = Color(0xFFFFC107);
const _kOld = Color(0xFFF44336);
const _kCardBorder = Color(0x14FFFFFF); // rgba(255,255,255,~0.08)

/// Info-Screen: Wildtier-Steckbriefe, Jagdrecht & Ansprache
class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: const Text(
          'WILDTIER-INFO',
          style: TextStyle(
            color: _kGold,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _kGold,
          indicatorWeight: 3,
          labelColor: _kGold,
          unselectedLabelColor: const Color(0x61FFFFFF),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: '🦌 GAMSWILD'),
            Tab(text: '🦌 REHWILD'),
            Tab(text: '🦌 ROTWILD'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _GamsTab(),
                _RehTab(),
                _RotTab(),
              ],
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _version.isNotEmpty ? 'v$_version  •  ' : '',
                  style:
                      const TextStyle(fontSize: 11, color: const Color(0x61FFFFFF)),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ImpressumScreen()),
                  ),
                  child: const Text(
                    'Impressum',
                    style: TextStyle(
                      fontSize: 11,
                      color: _kGold,
                      decoration: TextDecoration.underline,
                    ),
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

// ─── HAUPT-TABS (eine pro Wildart) ───────────────────────────────────────────

class _GamsTab extends StatefulWidget {
  const _GamsTab();
  @override
  State<_GamsTab> createState() => _GamsTabState();
}

class _GamsTabState extends State<_GamsTab>
    with SingleTickerProviderStateMixin {
  late TabController _sub;
  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 3, vsync: this);
  }
  @override
  void dispose() {
    _sub.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => _WildTab(
        sub: _sub,
        color: _kGamsColor,
        biologie: const _GamsBiologie(),
        jagdrecht: const _GamsJagdrecht(),
        ansprache: const _GamsAnsprache(),
      );
}

class _RehTab extends StatefulWidget {
  const _RehTab();
  @override
  State<_RehTab> createState() => _RehTabState();
}

class _RehTabState extends State<_RehTab>
    with SingleTickerProviderStateMixin {
  late TabController _sub;
  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 3, vsync: this);
  }
  @override
  void dispose() {
    _sub.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => _WildTab(
        sub: _sub,
        color: _kRehColor,
        biologie: const _RehBiologie(),
        jagdrecht: const _RehJagdrecht(),
        ansprache: const _RehAnsprache(),
      );
}

class _RotTab extends StatefulWidget {
  const _RotTab();
  @override
  State<_RotTab> createState() => _RotTabState();
}

class _RotTabState extends State<_RotTab>
    with SingleTickerProviderStateMixin {
  late TabController _sub;
  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 3, vsync: this);
  }
  @override
  void dispose() {
    _sub.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => _WildTab(
        sub: _sub,
        color: _kRotColor,
        biologie: const _RotBiologie(),
        jagdrecht: const _RotJagdrecht(),
        ansprache: const _RotAnsprache(),
      );
}

/// Wiederverwendbares Layout: Sub-TabBar + TabBarView
class _WildTab extends StatelessWidget {
  final TabController sub;
  final Color color;
  final Widget biologie;
  final Widget jagdrecht;
  final Widget ansprache;

  const _WildTab({
    required this.sub,
    required this.color,
    required this.biologie,
    required this.jagdrecht,
    required this.ansprache,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF0D0D0D),
          child: TabBar(
            controller: sub,
            indicatorColor: color,
            indicatorWeight: 2,
            labelColor: color,
            unselectedLabelColor: const Color(0x61FFFFFF),
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1),
            tabs: const [
              Tab(text: 'BIOLOGIE'),
              Tab(text: 'JAGDRECHT'),
              Tab(text: 'ANSPRACHE'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: sub,
            children: [biologie, jagdrecht, ansprache],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAMSWILD
// ═══════════════════════════════════════════════════════════════════════════════

class _GamsBiologie extends StatelessWidget {
  const _GamsBiologie();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
            color: _kGamsColor,
            name: 'GAMSWILD',
            sciName: 'Rupicapra rupicapra'),
        const SizedBox(height: 14),
        const _SectionHeader('STECKBRIEF'),
        const _InfoCard(children: [
          _FactRow('Gewicht ♂', '30–50 kg (Bock)'),
          _FactRow('Gewicht ♀', '24–40 kg (Geiß)'),
          _FactRow('Widerristhöhe', '70–90 cm'),
          _FactRow('Körperlänge', '110–130 cm'),
          _FactRow('Hörner', 'Krucken — beide Geschlechter, lebenslang wachsend'),
          _FactRow('Lebensraum',
              'Felsiges Hochgebirge, alpine Wiesen, bis über 2.500 m'),
          _FactRow('Feinde', 'Wolf, Bär, Luchs, Steinadler (für Kitze)'),
          _FactRow('Lebensdauer', 'Bis ca. 20 Jahre'),
          _FactRow('Besonderheit',
              'Gamsbart (langes Rückenhaar), Windfang (Nase), Brunftfeigen'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('BRUNFT (RANZZEIT)'),
        const _InfoCard(children: [
          _FactRow('Brunftzeit', 'November bis Dezember'),
          _FactRow('Setzzeit', 'Mai / Anfang Juni'),
          _FactRow('Jungtiere', 'Meist 1 Kitz (selten 2–3)'),
          _FactRow('Platzbock',
              'Ranghöchster Bock (8–13 J.) — verteidigt Brunftrudel'),
          _FactRow('Brunftlaut', 'Blädern (Glucksen des Bocks)'),
          _FactRow('Brunftfeigen',
              'Duftdrüsen hinter den Krucken — moschusartig'),
          _FactRow('Imponiergehabe',
              'Aufstellen des Rückenhaars (Gamsbart) — wirkt größer'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('SOZIALLEBEN'),
        const _InfoCard(children: [
          _FactRow('Geißenrudel',
              'Geißen + Kitze + Jährlinge — geführt von Leitgeiß'),
          _FactRow('Böcke', 'Ältere Böcke meist Einzelgänger'),
          _FactRow('Warnsignal', 'Scharfer Pfeifton (Luft durch Nase)'),
          _FactRow('Waidmannssprache',
              'Windfang · Krucken · Gamsbart · Blädern · Ranzzeit · Brunftfeigen'),
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _GamsJagdrecht extends StatefulWidget {
  const _GamsJagdrecht();
  @override
  State<_GamsJagdrecht> createState() => _GamsJagdrechtState();
}

class _GamsJagdrechtState extends State<_GamsJagdrecht> {
  int _bl = 0;

  static const List<List<List<String>>> _data = [
    // Bayern
    [
      [
        'Alle Gams',
        '1. Aug – 15. Dez',
        '16. Dez – 31. Jul',
        'Sanierungsgebiete OBay: Böcke/Jährl./weibl.≤2J: 1.Feb–31.Jul; Kitze: 1.Feb–31.Mär'
      ],
    ],
    // Tirol
    [
      [
        'Alle Gams',
        '1. Aug – 15. Dez',
        '16. Dez – 31. Jul',
        'Bezirk Lienz: 1. Aug – 31. Dez'
      ],
    ],
    // Steiermark
    [
      [
        'Alle Gams',
        '1. Aug – 31. Dez',
        '1. Jan – 31. Jul',
        'Keine Klassen-Differenzierung in Hauptregelung'
      ],
    ],
    // Salzburg
    [
      [
        'Alle Gams',
        '16. Jul – 15. Dez',
        '16. Dez – 15. Jul',
        'Maßnahmengebiete (z.B. Kaprun-Fusch): abweichend möglich'
      ],
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BundeslandPicker(
            selected: _bl, onChanged: (v) => setState(() => _bl = v)),
        const SizedBox(height: 14),
        const _SectionHeader('SCHUSS- & SCHONZEITEN'),
        _SchussZeitenTable(rows: _data[_bl]),
        const SizedBox(height: 14),
        const _SectionHeader('ABSCHUSSKLASSEN'),
        const _AgeClassTable(rows: [
          _AgeRow('Kl. III — Jugend',
              'Kitze, Jährlinge, Jungböcke bis ~3–4 J, junge Geißen',
              _kYoung),
          _AgeRow(
              'Kl. II — Mittel', 'Böcke & Geißen 4–8 Jahre', _kMid),
          _AgeRow(
              'Kl. I — Alt/Ernte', 'Böcke & Geißen ab 9–10 Jahren', _kOld),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('ALTERSBENENNUNG GAMSWILD'),
        const _AltersTable(rows: [
          ['1. LJ', 'Bockkitz', 'Geißkitz', 'Hornspitzen < 2 cm'],
          [
            '2. LJ',
            'Jährlingsbock',
            'Jährlingsgeiß / Schmalgeiß',
            'Krucken 5–8 cm; 1. Jahrring'
          ],
          [
            '3.–5. LJ',
            'Jungbock',
            'Junggeiß',
            'Entwickelter Haken; mittlere Krucken'
          ],
          ['Ab 6. LJ', 'Bock', 'Geiß', 'Kräftige Krucken; brunftaktiv'],
          [
            '8.–13. LJ',
            'Platzbock',
            'Leitgeiß',
            'Ranghöchste Tiere im Rudel'
          ],
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _GamsAnsprache extends StatelessWidget {
  const _GamsAnsprache();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('PRIMÄRMERKMALE'),
        const _InfoCard(children: [
          _NumberedTip(1,
              'KRUCKEN (Jahresringe): Sicherste Methode — Ringe zählen + 1 = Alter. 2. LJ: bis 15 cm; ab 5. LJ: Millimeterringe'),
          _NumberedTip(2,
              'HAKENSTÄRKE & -BIEGUNG: Schwach = jung | Mittlerer Haken = mittelalt | Kräftiger, stark gebogener Haken = alt'),
          _NumberedTip(3,
              'KRUCKENQUERSCHNITT: Bock = kreisrund, kräftig | Geiß = oval, dünner, weniger gebogen'),
          _NumberedTip(4,
              'BOCK vs. GEISS: Bock = Einzelgänger, breiter Vorschlag, kräftigere Krucken | Geiß = im Rudel, schlanker'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('SEKUNDÄRMERKMALE'),
        const _InfoCard(children: [
          _FactRow(
              'Windfang', 'Breit/grob wirkend = alt | Zierlich/spitz = jung'),
          _FactRow('Zügel (Gesicht)',
              'Scharf kontrastreiche Streifen = jung | Verwaschen = alt ✓'),
          _FactRow('Körperbau',
              'Kitz: puppenhaft | Jährling: schlank | Alt: tiefer Vorschlag, breite Brust'),
          _FactRow('Winterfell',
              'Dunkelbraun bis schwarz = ältere Böcke (besonders Brunft)'),
          _FactRow('Pinsel',
              'Langer kräftiger Pinsel am Bock = brunftaktiv, älter'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('ANSPRACHE SCHRITT FÜR SCHRITT'),
        const _InfoCard(children: [
          _NumberedTip(1,
              'Wildart: Gams? — Steinbock unterscheiden (Steinbock: rippenartige, geschwungene Hörner; viel größer)'),
          _NumberedTip(2,
              'Geschlecht: Kruckenform (rund=Bock, oval=Geiß), Körperstärke, Einzelgänger?'),
          _NumberedTip(3,
              'Kitz (1. LJ): Hornspitzen nur Stümpfe, zierlicher Körper, führendes Tier daneben?'),
          _NumberedTip(4,
              'Jährling (2. LJ): Kurze Krucken mit beginnendem Haken, schlanker Körper'),
          _NumberedTip(5,
              'Mittelalt (5.–8. LJ): Kräftige Krucken, Millimeterringe dicht, guter Vorschlag'),
          _NumberedTip(6,
              'Alt (ab 9 J.): Max. Kruckenentwicklung, tiefer Vorschlag, verwaschene Zügel, dunkles Fell beim Bock'),
        ]),
        const SizedBox(height: 14),
        const _WarnCard('⚠️ HÄUFIGE VERWECHSLUNGEN', [
          'Junge Geiß ↔ alter Bock: Kruckenquerschnitt prüfen! Geiß = oval, Bock = rund',
          'Hakelung allein unzuverlässig — Jahresringe zählen!',
          'Schmuckringe können echte Jahresringe vortäuschen',
          'Gamswild ↔ Steinbock: Steinbock rippenartige, geschwungene Hörner; deutlich größer',
          'Schmalgeiß (2. LJ) ↔ junge Geiß: Schmalgeiß hat noch nicht gesetzt',
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REHWILD
// ═══════════════════════════════════════════════════════════════════════════════

class _RehBiologie extends StatelessWidget {
  const _RehBiologie();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
            color: _kRehColor,
            name: 'REHWILD',
            sciName: 'Capreolus capreolus'),
        const SizedBox(height: 14),
        const _SectionHeader('STECKBRIEF'),
        const _InfoCard(children: [
          _FactRow('Status', 'Kleinste & häufigste Hirschart Europas'),
          _FactRow('Gewicht', 'Ø 18–25 kg (Bock & Ricke ähnlich)'),
          _FactRow('Körpertyp',
              'Schlüpfertyp — Hinterläufe länger als Vorderläufe'),
          _FactRow('Spiegel',
              'Ricke: herzförmig | Bock: nierenförmig (bohnenförmig)'),
          _FactRow('Gehörn', 'Nur beim Bock — jährlich abgeworfen'),
          _FactRow('Lebensraum',
              'Waldränder, Agrarland, Parks — hochgradig anpassungsfähig'),
          _FactRow('Lebensdauer', 'Selten über 10 J; max. 15 Jahre'),
          _FactRow('Feinde',
              'Luchs, Wolf, Fuchs (Kitze), Straßenverkehr, Mähmaschinen'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('BRUNFT (BLATTZEIT)'),
        const _InfoCard(children: [
          _FactRow('Blattzeit', 'Mitte Juli bis Mitte August'),
          _FactRow('Keimruhe!',
              'Befruchtetes Ei pausiert bis Dez./Jan. — evolutionärer Einzigartigkeits-Mechanismus'),
          _FactRow('Gesamte Tragzeit',
              'Ca. 40 Wochen (inkl. Keimruhe); echte Entwicklung ~5 Monate'),
          _FactRow('Setzzeit', 'Mai des Folgejahres'),
          _FactRow('Geburten', '1–2 Kitze (Zwillinge häufig)'),
          _FactRow('Hexenringe',
              'Kreisförmige Spurenmuster im Feld durch Brunftjagden'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('SOZIALLEBEN'),
        const _InfoCard(children: [
          _FactRow('Sommer', 'Einzeln oder Ricke + Kitze'),
          _FactRow('Winter',
              '"Sprung" — größere Gruppen zur Energieeinsparung (> 20 Tiere in Agrarlandschaften)'),
          _FactRow('Bock', 'Territorial in der Blattzeit'),
          _FactRow('Waidmannssprache',
              'Blattzeit · Sprung · Geheimgang · Fegen · Abwerfen · Gesäuge · Führende Ricke'),
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RehJagdrecht extends StatefulWidget {
  const _RehJagdrecht();
  @override
  State<_RehJagdrecht> createState() => _RehJagdrechtState();
}

class _RehJagdrechtState extends State<_RehJagdrecht> {
  int _bl = 0;

  static const List<List<List<String>>> _data = [
    // Bayern
    [
      ['Böcke', '16. Apr – 15. Okt', '16. Okt – 15. Apr', ''],
      ['Schmalrehe', '16. Apr – 15. Jan', '16. Jan – 15. Apr', ''],
      ['Geißen + Kitze', '1. Sep – 15. Jan', '16. Jan – 31. Aug', ''],
    ],
    // Tirol
    [
      ['Bock Kl. I + II', '1. Jun – 31. Okt', '1. Nov – 31. Mai', ''],
      [
        'Bock Kl. III + Schmalgeißen',
        '1. Mai – 31. Dez',
        '1. Jan – 30. Apr',
        ''
      ],
      [
        'Führende Geißen + Kitze',
        '1. Jul – 31. Dez',
        '1. Jan – 30. Jun',
        ''
      ],
    ],
    // Steiermark
    [
      [
        'Bock Kl. I+II (Lowland)',
        '16. Mai – 15. Okt',
        '16. Okt – 15. Mai',
        'Lowland-Bezirke*'
      ],
      [
        'Bock Kl. III (Lowland)',
        '16. Apr – 15. Okt',
        '16. Okt – 15. Apr',
        'Lowland-Bezirke*'
      ],
      [
        'Bock Kl. I+II (übrige)',
        '1. Jun – 31. Okt',
        '1. Nov – 31. Mai',
        'Übrige Bezirke'
      ],
      [
        'Bock Kl. III (übrige)',
        '1. Mai – 31. Okt',
        '1. Nov – 30. Apr',
        'Übrige Bezirke'
      ],
      [
        'Führ. Geißen + Kitze',
        '16. Aug – 31. Dez',
        '1. Jan – 15. Aug',
        ''
      ],
    ],
    // Salzburg
    [
      ['Bock Kl. III', '1. Mai – 31. Okt', '1. Nov – 30. Apr', ''],
      ['Bock Kl. I + II', '1. Jun – 31. Okt', '1. Nov – 31. Mai', ''],
      ['Schmalrehe', '1. Mai – 31. Dez', '1. Jan – 30. Apr', ''],
      [
        'Nichtführende Geißen',
        '1. Mai – 31. Dez',
        '1. Jan – 30. Apr',
        ''
      ],
      [
        'Führende Geißen + Kitze',
        '1. Aug – 31. Dez',
        '1. Jan – 31. Jul',
        ''
      ],
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BundeslandPicker(
            selected: _bl, onChanged: (v) => setState(() => _bl = v)),
        const SizedBox(height: 14),
        const _SectionHeader('SCHUSS- & SCHONZEITEN'),
        _SchussZeitenTable(rows: _data[_bl]),
        const SizedBox(height: 14),
        const _SectionHeader('ABSCHUSSKLASSEN'),
        const _AgeClassTable(rows: [
          _AgeRow('Kl. III — Jugend',
              'Bockkitze, Jährlingsböcke (1.–2. LJ), Schmalgeißen',
              _kYoung),
          _AgeRow('Kl. II — Mittel', 'Böcke 3.–5. LJ', _kMid),
          _AgeRow('Kl. I — Alt', 'Böcke ab 6. LJ', _kOld),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('ALTERSBENENNUNG REHWILD'),
        const _AltersTable(rows: [
          [
            '1. LJ',
            'Bockkitz',
            'Rickenkitz / Geißkitz',
            'Kitz; Flecken bis ~8 Wochen'
          ],
          [
            '2. LJ',
            'Jährl.bock / Schmalreh',
            'Schmalricke / Schmalreh',
            'Erster Gehörnansatz beim Bock'
          ],
          [
            'Ab 2. Setzen',
            '—',
            'Altricke / Altgeiß',
            'Nach dem ersten Setzen'
          ],
          [
            '3.–5. LJ',
            'Mittelalter Bock',
            'Ricke',
            'Ausgereifter Körperbau'
          ],
          [
            'Ab 6. LJ',
            'Alter Bock',
            'Altricke',
            'Bulliger Körperbau; heimlich'
          ],
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RehAnsprache extends StatelessWidget {
  const _RehAnsprache();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('PRIMÄRMERKMALE'),
        const _InfoCard(children: [
          _NumberedTip(1,
              'KÖRPERBAU (PRIMÄR!): Schlüpfertyp — Senkrücken + hängende Bauchlinie + schwerer Körper = alter Bock'),
          _NumberedTip(2,
              'TRÄGER (Hals): Fast senkrecht, schlank = jung | Waagerecht, breit, kurz wirkend = alt'),
          _NumberedTip(3,
              'VORDERLÄUFE-STAND: Eng, schlaksig = jung | Weit auseinander, kräftig = alt'),
          _NumberedTip(4,
              'GESICHTSAUSDRUCK: Kindlich/offen/neugierig = jung | Eckig/ernst/argwöhnisch = alt'),
          _NumberedTip(5,
              'SPIEGEL: Herzförmig = Ricke | Nierenförmig (bohnenförmig) = Bock'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('SEKUNDÄRMERKMALE'),
        const _InfoCard(children: [
          _FactRow('Gehörn (Bock)',
              'Rosenstöcke: hoch/dünn = jung | niedrig/breit = alt; Rosen tief+wulstig = älter'),
          _FactRow('Abwurf-Zeitpunkt',
              'Früh (Okt.) = alter Bock | Spät (Dez./Jan.) = junger Bock'),
          _FactRow('Fegen-Zeitpunkt',
              'Früh (März) = alter Bock | Spät (Mai/Jun.) = junger Bock'),
          _FactRow('Verhalten',
              'Heimlich/misstrauisch/spät aus Deckung = alt | Lebhaft/neugierig/früh = jung'),
          _FactRow('Verfärbung', 'Spät = alter Bock | Früh = jung'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('RICKEN-ANSPRACHE'),
        const _InfoCard(children: [
          _FactRow('Kitz', 'Sehr klein, zutraulich, nahe bei Ricke'),
          _FactRow('Schmalricke',
              'Schlank, hochläufig, noch kein Kitz; herzförmiger Spiegel'),
          _FactRow('Altricke', 'Ausgereifter Körper; führt Kitz(e)'),
          _FactRow('Gelttier (Ricke)',
              'Ohne Kitz im Sommer → aufmerksam, heimlich'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('ANSPRACHE SCHRITT FÜR SCHRITT'),
        const _InfoCard(children: [
          _NumberedTip(1,
              'Geschlecht: Gehörn sichtbar = Bock | Spiegel herzförmig = Ricke | Spiegel nierenförmig = Bock'),
          _NumberedTip(2,
              'Körpergröße: Kitz deutlich kleiner, Mutter in der Nähe?'),
          _NumberedTip(3,
              'Trägerhaltung: Fast senkrecht = jung | Waagerecht = alt'),
          _NumberedTip(4, 'Vorschlag (Brust): Schmal = jung | Breit = alt'),
          _NumberedTip(5,
              'Verhalten: Leichtsinnig/neugierig = jung | Heimlich/spät aus Deckung = alt'),
          _NumberedTip(6, 'Abschussplan prüfen + Schusszeit beachten'),
        ]),
        const SizedBox(height: 14),
        const _WarnCard('⚠️ HÄUFIGE VERWECHSLUNGEN', [
          'Junger Bock ↔ Kitz: Gehörnansatz prüfen; Körpergröße; Verhalten',
          'Schmalricke ↔ Altricke: Schmalricke schlanker/hochläufiger; kein Kitz',
          'Alter Bock ↔ Mittelalter Bock: Trägerhaltung; Vorderläufe-Abstand',
          'ACHTUNG: "Blume" = NUR beim Hasen! Beim Reh heißt es SPIEGEL!',
          'Rehwild ↔ Gamswild-Kitz: Lebensraum beachten — Reh in Wald/Feld',
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROTWILD
// ═══════════════════════════════════════════════════════════════════════════════

class _RotBiologie extends StatelessWidget {
  const _RotBiologie();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
            color: _kRotColor,
            name: 'ROTWILD',
            sciName: 'Cervus elaphus'),
        const SizedBox(height: 14),
        const _SectionHeader('STECKBRIEF'),
        const _InfoCard(children: [
          _FactRow('Status', 'Größte heimische Wildart Mitteleuropas'),
          _FactRow('Gewicht Hirsch', '100–250 kg'),
          _FactRow('Gewicht Alttier', '70–110 kg'),
          _FactRow('Schulterhöhe',
              'Hirsch bis 150 cm | Alttier 120–130 cm'),
          _FactRow('Geweih',
              'Nur Hirsch — Knochen (kein Horn!), jährlich abgeworfen'),
          _FactRow('Geweihwachstum',
              'Bis 2,8 cm/Tag — schnellstes Wachstum im Tierreich!'),
          _FactRow('Lebensraum',
              'Große Wälder; saisonale Wanderungen (Sommer: Hochlagen)'),
          _FactRow('Lebensdauer',
              'In freier Wildbahn selten über 14–15 J; max. ~20 J'),
          _FactRow('Feinde',
              'Wolf (Hauptprädator), Bär, Luchs; Jagd = Hauptregulierungsfaktor'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('BRUNFT'),
        const _InfoCard(children: [
          _FactRow('Brunftzeit', 'Mitte September bis Mitte Oktober'),
          _FactRow('Brunftlaut',
              'Röhren — tiefes, weittragendes Stöhnen'),
          _FactRow('Platzhirsch',
              'Dominanter Hirsch verteidigt Alttiergruppe gegen Nebenbuhler'),
          _FactRow('Brunftverhalten',
              'Röhren · Suhlen · Schälen · Fegen an Bäumen · Drohgebärden'),
          _FactRow('Gewichtsverlust',
              'Bis 25% in der Brunft (kaum Nahrungsaufnahme)'),
          _FactRow('Setzzeit', 'Mai bis Juni; meist 1 Kalb'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('SOZIALLEBEN'),
        const _InfoCard(children: [
          _FactRow('Kahlwildrudel',
              'Alttiere + Kälber + Jährlinge (stabiler Verwandtschaftsverband, Leittier führt)'),
          _FactRow('Hirschrudel',
              'Männliche Tiere außerhalb der Brunft getrennt'),
          _FactRow('Suhlen',
              'Schlammbad zur Kühlung, Parasitenbekämpfung & Duftmarkierung'),
          _FactRow('Waidmannssprache',
              'Röhren · Suhlen · Schälen · Bast · Fegen · Kahlwild · Gelttier · Schälen'),
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RotJagdrecht extends StatefulWidget {
  const _RotJagdrecht();
  @override
  State<_RotJagdrecht> createState() => _RotJagdrechtState();
}

class _RotJagdrechtState extends State<_RotJagdrecht> {
  int _bl = 0;

  static const List<List<List<String>>> _data = [
    // Bayern
    [
      ['Kälber', '1. Aug – 31. Jan', '1. Feb – 31. Jul', ''],
      ['Hirsche (alle Kl.)', '1. Aug – 31. Jan', '1. Feb – 31. Jul', ''],
      ['Alttiere', '1. Aug – 31. Jan', '1. Feb – 31. Jul', ''],
      [
        'Schmalspießer + Schmaltiere',
        '1. Jun – 31. Jan',
        '1. Feb – 31. Mai',
        ''
      ],
    ],
    // Tirol
    [
      ['Hirsch Kl. I', '1. Aug – 15. Nov', '16. Nov – 31. Jul', ''],
      ['Hirsch Kl. II + III', '1. Aug – 31. Dez', '1. Jan – 31. Jul', ''],
      [
        'Schmalspießer + Schmaltiere',
        '1. Mai – 31. Dez',
        '1. Jan – 30. Apr',
        ''
      ],
      [
        'Führende Tiere + Kälber',
        '1. Jul – 31. Dez',
        '1. Jan – 30. Jun',
        ''
      ],
    ],
    // Steiermark
    [
      ['Hirsche Kl. I, II, III', '1. Aug – 31. Dez', '1. Jan – 31. Jul', ''],
      [
        'Nichtführende Alttiere',
        '1. Jun – 31. Dez',
        '1. Jan – 31. Mai',
        ''
      ],
      [
        'Schmaltiere + Schmalspießer',
        '15. Mai – 31. Dez',
        '1. Jan – 14. Mai',
        ''
      ],
      [
        'Führende Alttiere + Kälber',
        '1. Jul – 31. Dez',
        '1. Jan – 30. Jun',
        ''
      ],
    ],
    // Salzburg
    [
      [
        'Rotwild-Zeiten',
        '—',
        '—',
        '⚠️ Bitte bei sbg-jaegerschaft.at aktuell nachschlagen'
      ],
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BundeslandPicker(
            selected: _bl, onChanged: (v) => setState(() => _bl = v)),
        const SizedBox(height: 14),
        const _SectionHeader('SCHUSS- & SCHONZEITEN'),
        _SchussZeitenTable(rows: _data[_bl]),
        const SizedBox(height: 14),
        const _SectionHeader('ABSCHUSSKLASSEN'),
        const _AgeClassTable(rows: [
          _AgeRow('Kl. III — Jugend',
              'Kälber + Hirsche bis ~4. LJ (Bayern: ~50% Abschuss)',
              _kYoung),
          _AgeRow('Kl. II — Mittel',
              'Hirsche 5.–9. LJ (Bayern: ~20%; selektiv)', _kMid),
          _AgeRow('Kl. I — Ernte',
              'Hirsche ab 10. LJ (Bayern: ~30%)', _kOld),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('ALTERSBENENNUNG ROTWILD'),
        const _AltersTable(rows: [
          [
            '1. LJ',
            'Hirschkalb',
            'Wildkalb / Tierkalb',
            'Fleckentarnkleid; kein Geweih'
          ],
          [
            '2. LJ',
            'Schmalspießer (Spießer)',
            'Schmaltier',
            'Zwei Spieße; Schmaltier noch nicht gekalbt'
          ],
          [
            '3. LJ',
            'Gabler / 6-Ender',
            'Junges Alttier',
            '2–4 Enden je Stange'
          ],
          [
            '3.–9. LJ',
            'Mittelalter Hirsch (Kl. II)',
            'Alttier',
            '8–12+ Ender; Mittelklasse'
          ],
          [
            'Ab 10. LJ',
            'Alter Hirsch / Platzhirsch (Kl. I)',
            'Altes Alttier',
            'Vollreifer Trophäenträger; Röhren dominant'
          ],
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('KAHLWILDBEGRIFFE'),
        const _InfoCard(children: [
          _FactRow('Kahlwild', 'Alttiere + Kälber (kein Geweih → "kahl")'),
          _FactRow(
              'Führendes Tier', 'Alttier mit Kalb — NICHT erlegen!'),
          _FactRow('Gelttier', 'Unfruchtbares Alttier ohne Kalb'),
          _FactRow('Tirol-Regel',
              'Kl. III statt Kl. I/II zulässig; Kl. II statt Kl. I NICHT!'),
          _FactRow('Steiermark',
              'Unbegrenzte Kahlwildbejagung in Gebieten mit geringer Dichte möglich'),
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RotAnsprache extends StatelessWidget {
  const _RotAnsprache();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('PRIMÄRMERKMALE'),
        const _InfoCard(children: [
          _NumberedTip(1,
              'KÖRPERBAU (PRIMÄR): Massiver, breiter Körper + hängender Vorschlag = alter Hirsch'),
          _NumberedTip(2,
              'LICHTERBÖGEN (Augenbrauenbögen): Flach = jung | Knochig hervorstehend = alter Hirsch (ab ~10. Kopf) — VERLÄSSLICHSTES Körpermerkmal!'),
          _NumberedTip(3,
              'TRÄGER (Hals): Schlank/aufrecht = jung | Breit/kurz wirkend/waagerecht = alt'),
          _NumberedTip(4,
              'MÄHNE: Keine/wenig = jung | Ausgeprägte Brunftmähne = reifer Hirsch'),
          _NumberedTip(5,
              'VORSCHLAG/BRUSTSPITZ: Fehlt = jung | Deutlich ausgeprägt = alt'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('SEKUNDÄRMERKMALE'),
        const _InfoCard(children: [
          _FactRow('Geweih',
              'Kein zuverlässiges Altersmerkmal allein! Genetik + Ernährung entscheidend'),
          _FactRow('Rosenstöcke',
              'Höhe nimmt ab mit Alter (jährliches Abwerfen); Durchmesser nimmt zu'),
          _FactRow('Rosen',
              'Tief+wulstig, nahe an Lichter gerückt = älterer Hirsch'),
          _FactRow('Äserbereich',
              'Breit+massiv = alt | Schmal = jung'),
          _FactRow('Verhalten Brunft',
              'Röhrt, suhlt, schält — je dominanter desto älter'),
          _FactRow('Geweihregression',
              'Einfachere Formen bei sehr alten Hirschen (Senium)'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('KAHLWILD-ANSPRACHE'),
        const _InfoCard(children: [
          _FactRow('Wildkalb', 'Sehr klein; Flecken bis Herbst; unselbständig'),
          _FactRow('Schmaltier', 'Schlank, hochläufig; noch nicht gekalbt; allein'),
          _FactRow('Alttier', 'Ausgereifter Körper; führt Kalb oder allein'),
          _FactRow('Gelttier', 'Ohne Kalb im Sommer → erfahren, heimlich'),
          _FactRow('Führendes Tier', 'Mit Kalb — SCHUTZ: nie Tier mit Kalb erlegen!'),
        ]),
        const SizedBox(height: 14),
        const _SectionHeader('ANSPRACHE SCHRITT FÜR SCHRITT'),
        const _InfoCard(children: [
          _NumberedTip(1,
              'Wildart: Rotwild? Größe, Körperbau, Lebensraum (kein Damwild = Schaufelgeweih, gefleckt)'),
          _NumberedTip(2,
              'Geschlecht: Geweih = Hirsch | Kein Geweih + Rosenstöcke sichtbar = Spießer (Winter) | Keine Rosenstöcke = Alttier/Kalb'),
          _NumberedTip(3,
              'Körpergröße + Proportionen: Kindchenschema + schlanker Träger = jung'),
          _NumberedTip(4,
              'Lichterbögen prüfen: flach = jung | knochig hervorstehend = alt (Kl. I)'),
          _NumberedTip(5,
              'Brustspitz/Mähne: Fehlt/wenig = jung | Ausgeprägt = reifer Hirsch'),
          _NumberedTip(6,
              'Kahlwild: Kalb = klein+Flecken | Schmaltier = schlank+allein | Führendes Tier SCHONEN!'),
        ]),
        const SizedBox(height: 14),
        const _WarnCard('⚠️ HÄUFIGE VERWECHSLUNGEN', [
          'Spießer (Winter, Geweih abgeworfen) ↔ Alttier: Rosenstöcke beim Spießer sichtbar!',
          'Schmaltier ↔ Wildkalb: Kalb deutlich kleiner, noch fleckig',
          'Kl. I ↔ Kl. II Hirsch: Lichterbögen + Rosenstockdurchmesser + Trägerhaltung',
          'Rotwild ↔ Damwild: Damwild = Schaufelgeweih + geflecktes Sommerfell',
          'Alttier ≠ Rehwild: Rotwild deutlich größer, langer Kopf, Wamme sichtbar!',
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  final Color color;
  final String name;
  final String sciName;

  const _HeroCard({
    required this.color,
    required this.name,
    required this.sciName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.28),
            color.withOpacity(0.07),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.45), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                '🦌',
                style: TextStyle(
                  fontSize: 72,
                  color: color.withOpacity(0.13),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sciName,
                  style: const TextStyle(
                    color: const Color(0x61FFFFFF),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
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

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: const Color(0x61FFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kCardBorder, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;
  const _FactRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0x8AFFFFFF),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: const Color(0xDEFFFFFF),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberedTip extends StatelessWidget {
  final int number;
  final String text;
  const _NumberedTip(this.number, this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: _kGold.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _kGold.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kGold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: const Color(0xDEFFFFFF),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarnCard extends StatelessWidget {
  final String title;
  final List<String> items;
  const _WarnCard(this.title, this.items);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFFFC107), size: 14),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: const Color(0xB3FFFFFF),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── BUNDESLAND-PICKER ────────────────────────────────────────────────────────

class _BundeslandPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  static const _labels = ['Bayern', 'Tirol', 'Steiermark', 'Salzburg'];

  const _BundeslandPicker(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (i) {
        final active = i == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? _kGold.withOpacity(0.18)
                    : const Color(0xFF111111),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? _kGold.withOpacity(0.7)
                      : _kCardBorder,
                ),
              ),
              child: Text(
                _labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? _kGold : const Color(0x61FFFFFF),
                  fontSize: 11,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── SCHUSSZEITEN-TABELLE ────────────────────────────────────────────────────

class _SchussZeitenTable extends StatelessWidget {
  final List<List<String>> rows;
  const _SchussZeitenTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          // Header
          Container(
            color: _kGold.withOpacity(0.2),
            child: const Row(
              children: [
                _TCell('Kategorie', isHeader: true, flex: 3),
                _TCell('Schusszeit', isHeader: true, flex: 3),
                _TCell('Schonzeit', isHeader: true, flex: 3),
                _TCell('Hinweis', isHeader: true, flex: 4),
              ],
            ),
          ),
          ...rows.asMap().entries.map((e) {
            final row = e.value;
            final bg =
                e.key.isEven ? _kTableRowA : _kTableRowB;
            return Container(
              color: bg,
              child: Row(
                children: [
                  _TCell(row[0], flex: 3),
                  _TCell(row[1], flex: 3, color: const Color(0xFF81C784)),
                  _TCell(row[2], flex: 3, color: const Color(0xFFEF9A9A)),
                  _TCell(row.length > 3 ? row[3] : '', flex: 4,
                      color: const Color(0x61FFFFFF)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final int flex;
  final Color? color;

  const _TCell(this.text,
      {this.isHeader = false, this.flex = 1, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight:
                isHeader ? FontWeight.w700 : FontWeight.normal,
            color: isHeader
                ? _kGold
                : (color ?? const Color(0xDEFFFFFF)),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ─── ALTERSKLASSEN-TABELLE ───────────────────────────────────────────────────

class _AgeRow {
  final String klasse;
  final String inhalt;
  final Color color;
  const _AgeRow(this.klasse, this.inhalt, this.color);
}

class _AgeClassTable extends StatelessWidget {
  final List<_AgeRow> rows;
  const _AgeClassTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: rows.map((row) {
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            color: row.color.withOpacity(0.08),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: row.color,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    row.klasse,
                    style: TextStyle(
                      color: row.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    row.inhalt,
                    style: const TextStyle(
                        color: const Color(0xB3FFFFFF), fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── ALTERSBENENNUNG-TABELLE ─────────────────────────────────────────────────

class _AltersTable extends StatelessWidget {
  final List<List<String>> rows;
  const _AltersTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Container(
            color: _kGold.withOpacity(0.2),
            child: const Row(
              children: [
                _TCell('Alter', isHeader: true, flex: 2),
                _TCell('Männlich ♂', isHeader: true, flex: 3),
                _TCell('Weiblich ♀', isHeader: true, flex: 3),
                _TCell('Besonderheit', isHeader: true, flex: 4),
              ],
            ),
          ),
          ...rows.asMap().entries.map((e) {
            final row = e.value;
            final bg = e.key.isEven ? _kTableRowA : _kTableRowB;
            return Container(
              color: bg,
              child: Row(
                children: [
                  _TCell(row[0], flex: 2,
                      color: _kGold.withOpacity(0.85)),
                  _TCell(row[1], flex: 3),
                  _TCell(row[2], flex: 3),
                  _TCell(row[3], flex: 4, color: const Color(0x8AFFFFFF)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
