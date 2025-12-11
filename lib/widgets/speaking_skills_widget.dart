import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SpeakingSkillsWidget extends StatefulWidget {
  const SpeakingSkillsWidget({super.key});

  @override
  State<SpeakingSkillsWidget> createState() => _SpeakingSkillsWidgetState();
}

class _SpeakingSkillsWidgetState extends State<SpeakingSkillsWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;
  bool _isScrollable = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrowVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScrollability();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScrollability() {
    if (!mounted) return;
    final isScrollable = _scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0;
    setState(() {
      _isScrollable = isScrollable;
      _updateArrowVisibility();
    });
  }

  void _updateArrowVisibility() {
    if (!_scrollController.hasClients) return;
    
    final position = _scrollController.position;
    final showLeft = position.pixels > 0;
    final showRight = position.pixels < position.maxScrollExtent;
    
    if (mounted && (_showLeftArrow != showLeft || _showRightArrow != showRight || _isScrollable != (position.maxScrollExtent > 0))) {
      setState(() {
        _showLeftArrow = showLeft;
        _showRightArrow = showRight;
        _isScrollable = position.maxScrollExtent > 0;
      });
    }
  }

  void _scrollLeft() {
    if (_scrollController.hasClients) {
      // Card width (~227.2px) + spacing (16px) = ~243.2px
      const scrollDistance = 243.2;
      _scrollController.animateTo(
        _scrollController.offset - scrollDistance,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollRight() {
    if (_scrollController.hasClients) {
      // Card width (~227.2px) + spacing (16px) = ~243.2px
      const scrollDistance = 243.2;
      _scrollController.animateTo(
        _scrollController.offset + scrollDistance,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
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
                  // Challenge cards horizontal scroll
                  _buildChallengeScroll(isClassic),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChallengeScroll(bool isClassic) {
    // Theme-specific icon colors
    final List<Color> iconColors;
    
    if (isClassic) {
      // Toastmasters classic theme colors
      iconColors = [
        const Color(0xFF772432), // True Maroon
        const Color(0xFF003049), // Darker blue
        const Color(0xFF5A1A25), // Darker maroon
        const Color(0xFF004165), // Loyal Blue
        const Color(0xFF772432), // True Maroon
      ];
    } else {
      // Purple quirky theme colors
      iconColors = [
        const Color(0xFF8B5CF6), // Purple
        const Color(0xFF4F46E5), // Darker indigo
        const Color(0xFF7C3AED), // Darker purple
        const Color(0xFF6366F1), // Indigo
        const Color(0xFF8B5CF6), // Purple
      ];
    }

    final challenges = [
      {
        'image': 'assets/images/2.webp',
        'title': 'Voice Master',
        'iconColor': iconColors[0],
      },
      {
        'image': 'assets/images/3.webp',
        'title': 'Table Topics Pro',
        'iconColor': iconColors[1],
      },
      {
        'image': 'assets/images/4.webp',
        'title': 'Evaluator Expert',
        'iconColor': iconColors[2],
      },
      {
        'image': 'assets/images/5.webp',
        'title': 'Grammarian Guru',
        'iconColor': iconColors[3],
      },
      {
        'image': 'assets/images/6.webp',
        'title': 'Storyteller',
        'iconColor': iconColors[4],
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate tile width based on full max width (1200px) to fit all 5 tiles
        // Max width: 1200px, 5 tiles, 4 gaps of 16px = 64px spacing
        // Available width: 1200 - 64 = 1136px
        // Each tile: 1136 / 5 = 227.2px
        const maxWidth = 1200.0;
        const spacing = 16.0;
        const numberOfTiles = 5;
        const totalSpacing = spacing * (numberOfTiles - 1); // 4 gaps
        const cardWidth = (maxWidth - totalSpacing) / numberOfTiles; // ~227.2px
        const aspectRatio = 1.5; // 3:2 horizontal card ratio (visually pleasing)
        final cardHeight = cardWidth / aspectRatio; // ~151.5px
        final tileHeight = cardHeight;
        
        // Check scrollability when viewport changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkScrollability();
        });
        
        return Stack(
          children: [
            SizedBox(
              height: tileHeight,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _checkScrollability();
                  });
                  return false;
                },
                child: ListView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildChallengeCard(context, challenges[0], cardWidth, cardHeight),
                    const SizedBox(width: spacing),
                    _buildChallengeCard(context, challenges[1], cardWidth, cardHeight),
                    const SizedBox(width: spacing),
                    _buildChallengeCard(context, challenges[2], cardWidth, cardHeight),
                    const SizedBox(width: spacing),
                    _buildChallengeCard(context, challenges[3], cardWidth, cardHeight),
                    const SizedBox(width: spacing),
                    _buildChallengeCard(context, challenges[4], cardWidth, cardHeight),
                  ],
                ),
              ),
            ),
            // Left arrow
            if (_isScrollable && _showLeftArrow)
              Positioned(
                left: 8,
                top: tileHeight * 0.35,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _scrollLeft,
                          borderRadius: BorderRadius.circular(20),
                          child: const Icon(
                            Icons.chevron_left,
                            color: Color(0xFF212121),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Right arrow
            if (_isScrollable && _showRightArrow)
              Positioned(
                right: 8,
                top: tileHeight * 0.35,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _scrollRight,
                          borderRadius: BorderRadius.circular(20),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF212121),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildChallengeCard(
    BuildContext context,
    Map<String, dynamic> challenge,
    double cardWidth,
    double cardHeight,
  ) {
    final imageAsset = challenge['image'] as String;
    
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${challenge['title']} challenge coming soon! 🎉'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Title centered vertically on the left
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Center(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          challenge['title'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF212121),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                // Image on the right, full height
                SizedBox(
                  width: cardHeight, // Square image area
                  height: cardHeight,
                  child: Builder(
                    builder: (context) {
                      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
                      final cacheWidth = (cardHeight * devicePixelRatio * 1.5).round();
                      final cacheHeight = (cardHeight * devicePixelRatio * 1.5).round();
                      
                      return Image.asset(
                        imageAsset,
                        width: cardHeight,
                        height: cardHeight,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                        cacheWidth: cacheWidth,
                        cacheHeight: cacheHeight,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

