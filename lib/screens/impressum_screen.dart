import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';

/// Impressum-Screen gemäß § 5 TMG
class ImpressumScreen extends StatefulWidget {
  const ImpressumScreen({super.key});

  @override
  State<ImpressumScreen> createState() => _ImpressumScreenState();
}

class _ImpressumScreenState extends State<ImpressumScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Impressum')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'IMPRESSUM',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: WaidblickColors.primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Angaben gemäß § 5 TMG',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          _ImpressumBlock(
            title: 'Anbieter',
            content: 'Turok GmbH\nAlexander Turi\nWiener Straße 7\n82049 Pullach',
          ),
          const SizedBox(height: 16),
          _ImpressumBlock(
            title: 'Kontakt',
            content: 'E-Mail: waidblick@proton.me',
          ),
          const SizedBox(height: 16),
          _ImpressumBlock(
            title: 'Haftungshinweis',
            content:
                'Die KI-gestützte Wildtiererkennung dient als Entscheidungshilfe '
                'und ersetzt nicht die jagdliche Erfahrung. '
                'Keine Haftung für Fehleinschätzungen.',
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              _version.isNotEmpty ? 'App Version: $_version' : '',
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

class _ImpressumBlock extends StatelessWidget {
  final String title;
  final String content;

  const _ImpressumBlock({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
      ],
    );
  }
}
