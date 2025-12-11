import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SpeakingSkillsWidget extends StatelessWidget {
  const SpeakingSkillsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        final isClassic = themeProvider.currentTheme == AppThemeType.toastmasters;
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 24, bottom: 40, left: 20, right: 20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header matching action tiles style
                  const Text(
                    'Level up your speaking skills!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Challenge cards grid
                  _buildChallengeGrid(colors, isClassic),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChallengeGrid(AppThemeColors colors, bool isClassic) {
    // Theme-specific color schemes with good contrast
    final List<List<Color>> challengeGradients;
    
    if (isClassic) {
      // Toastmasters classic theme colors
      challengeGradients = [
        [const Color(0xFF004165), const Color(0xFF005A8A)], // Loyal Blue variants
        [const Color(0xFF772432), const Color(0xFF9A2F42)], // True Maroon variants
        [const Color(0xFF003049), const Color(0xFF004165)], // Darker blue variants
        [const Color(0xFF5A1A25), const Color(0xFF772432)], // Darker maroon variants
        [const Color(0xFF004165), const Color(0xFF0066A3)], // Blue to lighter blue
        [const Color(0xFF772432), const Color(0xFF9D3A4F)], // Maroon to lighter maroon
      ];
    } else {
      // Purple quirky theme colors
      challengeGradients = [
        [const Color(0xFF6366F1), const Color(0xFF818CF8)], // Indigo to lighter indigo
        [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)], // Purple to lighter purple
        [const Color(0xFF4F46E5), const Color(0xFF6366F1)], // Darker indigo to indigo
        [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)], // Darker purple to purple
        [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], // Indigo to purple
        [const Color(0xFF818CF8), const Color(0xFFA78BFA)], // Light indigo to light purple
      ];
    }

    final challenges = [
      {
        'icon': Icons.gesture,
        'title': 'Body Language',
        'description': 'Master non-verbal communication',
        'progress': 0.0,
        'gradient': challengeGradients[0],
      },
      {
        'icon': Icons.mic,
        'title': 'Voice Master',
        'description': 'Practice vocal variety',
        'progress': 0.0,
        'gradient': challengeGradients[1],
      },
      {
        'icon': Icons.lightbulb_outline,
        'title': 'Table Topics Pro',
        'description': 'Master impromptu speaking',
        'progress': 0.0,
        'gradient': challengeGradients[2],
      },
      {
        'icon': Icons.feedback_outlined,
        'title': 'Evaluator Expert',
        'description': 'Give constructive feedback',
        'progress': 0.0,
        'gradient': challengeGradients[3],
      },
      {
        'icon': Icons.text_fields,
        'title': 'Grammarian Guru',
        'description': 'Track word usage',
        'progress': 0.0,
        'gradient': challengeGradients[4],
      },
      {
        'icon': Icons.auto_stories,
        'title': 'Storyteller',
        'description': 'Craft compelling narratives',
        'progress': 0.0,
        'gradient': challengeGradients[5],
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 600
                ? 2
                : 1;
        final spacing = 20.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1.1,
          ),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            return _buildChallengeCard(
              context,
              challenges[index],
            );
          },
        );
      },
    );
  }

  Widget _buildChallengeCard(BuildContext context, Map<String, dynamic> challenge) {
    final progress = challenge['progress'] as double;
    final gradient = challenge['gradient'] as List<Color>;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Handle challenge tap
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${challenge['title']} challenge coming soon! 🎉'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(
                          challenge['icon'] as IconData,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Title and description
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge['title'] as String,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          challenge['description'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    // Progress bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

