import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class RateMySpeechWidget extends StatelessWidget {
  const RateMySpeechWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        final isClassic = themeProvider.currentTheme == AppThemeType.toastmasters;
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 24, bottom: 40),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Rate my speech',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF212121),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: isClassic ? const Color(0xFF772432) : const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildHeroSection(context, colors, isClassic),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroSection(BuildContext context, AppThemeColors colors, bool isClassic) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        
        if (isMobile) {
          return _buildMobileLayout(context, colors, isClassic);
        }
        return _buildDesktopLayout(context, colors, isClassic);
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AppThemeColors colors, bool isClassic) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleUploadSpeech(context),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.bannerShadow.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: IntrinsicHeight(
              child: Stack(
                children: [
                  // Background gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors.bannerGradient,
                        ),
                      ),
                    ),
                  ),
                  // Decorative elements
                  _buildDecorativeElements(colors),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left side - Visual
                        Expanded(
                          flex: 5,
                          child: _buildVisualSide(colors),
                        ),
                        // Right side - Content
                        Expanded(
                          flex: 6,
                          child: _buildContentSide(context, colors, isClassic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppThemeColors colors, bool isClassic) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleUploadSpeech(context),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.bannerShadow.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: IntrinsicHeight(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: colors.bannerGradient,
                            ),
                          ),
                        ),
                      ),
                      _buildDecorativeElements(colors),
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildVisualIcon(colors, 80),
                            const SizedBox(height: 24),
                            _buildContentText(colors),
                            const SizedBox(height: 24),
                            _buildActionButton(context, colors),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildVisualSide(AppThemeColors colors) {
    return Stack(
      children: [
        // Large icon with glow
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.mic_rounded,
                size: 100,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ),
        // Floating elements
        Positioned(
          top: 60,
          right: 40,
          child: _buildFloatingIcon(Icons.graphic_eq, colors),
        ),
        Positioned(
          bottom: 80,
          left: 50,
          child: _buildFloatingIcon(Icons.volume_up, colors),
        ),
        Positioned(
          top: 120,
          left: 30,
          child: _buildFloatingIcon(Icons.analytics, colors),
        ),
      ],
    );
  }

  Widget _buildVisualIcon(AppThemeColors colors, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.mic_rounded,
          size: size * 0.5,
          color: Colors.white.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        icon,
        color: Colors.white.withOpacity(0.9),
        size: 24,
      ),
    );
  }

  Widget _buildContentSide(BuildContext context, AppThemeColors colors, bool isClassic) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContentText(colors),
            const SizedBox(height: 24),
            _buildActionButton(context, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildContentText(AppThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get instant AI-powered',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1.2,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'speech evaluation',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1.2,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Upload your video and receive detailed feedback on vocal variety, clarity, filler words, pacing, and more.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.9),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        // Feature list
        _buildFeatureList(colors),
      ],
    );
  }

  Widget _buildFeatureList(AppThemeColors colors) {
    final features = [
      {'icon': Icons.graphic_eq, 'text': 'Vocal Variety'},
      {'icon': Icons.volume_up, 'text': 'Voice Clarity'},
      {'icon': Icons.chat_bubble_outline, 'text': 'Filler Words'},
      {'icon': Icons.speed, 'text': 'Pacing Analysis'},
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: features.map((feature) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                feature['icon'] as IconData,
                size: 16,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 8),
              Text(
                feature['text'] as String,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(BuildContext context, AppThemeColors colors) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_upload_rounded,
                color: colors.bannerGradient[0],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Upload Speech',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.bannerGradient[0],
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: colors.bannerGradient[0],
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleUploadSpeech(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn || authProvider.userId == null) {
      Navigator.of(context).pushNamed('/login');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Speech upload feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildDecorativeElements(AppThemeColors colors) {
    return Stack(
      children: [
        // Large circle
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Medium circle
        Positioned(
          bottom: -80,
          left: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Small circles
        Positioned(
          top: 40,
          left: 40,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: 60,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }
}

