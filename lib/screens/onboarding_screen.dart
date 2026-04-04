import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      icon: Icons.camera_alt_outlined,
      title: 'Foto schießen',
      subtitle: 'Fotografiere das Wild direkt im Revier',
      description:
          'Nutze die Kamera oder lade ein Foto aus deiner Galerie hoch. '
          'WAIDBLICK unterstützt Gams, Rehwild und Rotwild.',
    ),
    _OnboardingSlide(
      icon: Icons.document_scanner_outlined,
      title: 'KI analysiert',
      subtitle: 'WAIDBLICK erkennt Wildart, Alter und Geschlecht in Sekunden',
      description:
          'Unsere KI-Analyse kombiniert modernste Computer Vision mit '
          'jagdlichem Fachwissen für präzise Altersbestimmung.',
    ),
    _OnboardingSlide(
      icon: Icons.verified_outlined,
      title: 'Sicher entscheiden',
      subtitle:
          'Fundierte Entscheidungshilfe — rechtssicher und nachvollziehbar',
      description:
          'Erhalte detaillierte Merkmale, Konfidenz-Werte und jagdrechtliche '
          'Einschätzungen für deine Region.',
    ),
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: WaidblickColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A1A0F), // very dark forest green
                  Color(0xFF141414),
                  Color(0xFF0D0D0D),
                ],
              ),
            ),
          ),

          // Subtle pattern overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: Image.asset(
                'assets/images/waidblick-bg.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar: Skip button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo text
                      const Text(
                        'WAIDBLICK',
                        style: TextStyle(
                          color: Color(0xFFc9a84c),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      // Skip button — min 48dp touch target
                      if (!isLast)
                        SizedBox(
                          height: 48,
                          child: TextButton(
                            onPressed: _finishOnboarding,
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  WaidblickColors.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                            ),
                            child: const Text(
                              'Überspringen',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 48, width: 120),
                    ],
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (_, i) =>
                        _SlideWidget(slide: _slides[i], isActive: i == _currentPage),
                  ),
                ),

                // Page indicators
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? const Color(0xFFc9a84c)
                              : WaidblickColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),

                // Action button: Weiter / Los geht's
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFc9a84c),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isLast ? 'Los geht\'s 🎯' : 'Weiter',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
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

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}

class _SlideWidget extends StatelessWidget {
  final _OnboardingSlide slide;
  final bool isActive;

  const _SlideWidget({required this.slide, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          AnimatedScale(
            scale: isActive ? 1.0 : 0.85,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1B5E20).withOpacity(0.25),
                border: Border.all(
                  color: const Color(0xFFc9a84c).withOpacity(0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFc9a84c).withOpacity(0.15),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                slide.icon,
                size: 54,
                color: const Color(0xFFc9a84c),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            slide.title,
            style: const TextStyle(
              color: Color(0xFFc9a84c),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subtitle (main message)
          Text(
            slide.subtitle,
            style: const TextStyle(
              color: WaidblickColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            slide.description,
            style: const TextStyle(
              color: WaidblickColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
