import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/club_code_entry_widget.dart';

class ActionTilesWidget extends StatelessWidget {
  const ActionTilesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What would you like to do?',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF212121),
                ),
              ),
              SizedBox(height: isMobile ? 10 : 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate tile height: image (320 square) + spacing (12) + title (~24 with line height) + spacing (4) + description (~20 with line height) + buffer (10)
                  final maxCardWidth = isMobile
                      ? (constraints.maxWidth > 240 ? 240.0 : constraints.maxWidth)
                      : (constraints.maxWidth > 320 ? 320.0 : constraints.maxWidth);
                  final cardHeight = maxCardWidth; // Square aspect ratio
                  final tileHeight = cardHeight + (isMobile ? 10 : 12) + (isMobile ? 20 : 24) + (isMobile ? 3 : 4) + (isMobile ? 18 : 20) + (isMobile ? 8 : 10); // Image + spacing + title + spacing + description + buffer
                  
                  return SizedBox(
                    height: tileHeight,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildTile(
                          context: context,
                          imageAsset: 'assets/images/join_meeting.webp',
                          title: 'Join Meeting',
                          description: 'Enter club code to join',
                          onTap: () => _showJoinMeetingDialog(context),
                        ),
                        SizedBox(width: isMobile ? 12 : 16),
                        _buildTile(
                          context: context,
                          imageAsset: 'assets/images/create_meeting.webp',
                          title: 'Create Meeting',
                          description: 'Start a new meeting',
                          onTap: () => _navigateToCreateMeeting(context),
                        ),
                        SizedBox(width: isMobile ? 12 : 16),
                        _buildTile(
                          context: context,
                          imageAsset: 'assets/images/daily_challenge.webp',
                          title: 'Daily Challenge',
                          description: 'Practice & grow your skills',
                          onTap: () => _navigateToDailyChallenge(context),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required String imageAsset,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate width (use most of available space, max 320px on desktop, 240px on mobile)
        final maxCardWidth = isMobile
            ? (constraints.maxWidth > 240 ? 240.0 : constraints.maxWidth)
            : (constraints.maxWidth > 320 ? 320.0 : constraints.maxWidth);
        // Square aspect ratio
        final cardHeight = maxCardWidth;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                child: Container(
                  width: maxCardWidth,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: isMobile ? 8 : 12,
                        offset: Offset(0, isMobile ? 2 : 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                    child: _AssetImageWithShimmer(
                      imageAsset: imageAsset,
                      width: maxCardWidth,
                      height: cardHeight,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: isMobile ? 10 : 12),
            _ShimmerText(
              text: title,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF212121),
              ),
              imageAsset: imageAsset,
            ),
            SizedBox(height: isMobile ? 3 : 4),
            _ShimmerText(
              text: description,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
              imageAsset: imageAsset,
            ),
          ],
        );
      },
    );
  }

  void _showJoinMeetingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ClubCodeEntryWidget(),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCreateMeeting(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      Navigator.of(context).pushNamed('/base');
    } else {
      Navigator.of(context).pushNamed('/club-login');
    }
  }

  void _navigateToDailyChallenge(BuildContext context) {
    // TODO: Implement daily challenge navigation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Daily Challenge coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final AnimationController controller;

  const _ShimmerLoader({
    required this.width,
    required this.height,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final shimmerPosition = controller.value * 2 - 1; // -1 to 1
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey.shade300,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Base color
                Container(
                  width: width,
                  height: height,
                  color: Colors.grey.shade300,
                ),
                // Shimmer effect - subtle
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      width * shimmerPosition,
                      0,
                    ),
                    child: Container(
                      width: width * 0.4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.2),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssetImageWithShimmer extends StatefulWidget {
  final String imageAsset;
  final double width;
  final double height;

  const _AssetImageWithShimmer({
    required this.imageAsset,
    required this.width,
    required this.height,
  });

  @override
  State<_AssetImageWithShimmer> createState() => _AssetImageWithShimmerState();
}

class _AssetImageWithShimmerState extends State<_AssetImageWithShimmer>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final image = AssetImage(widget.imageAsset);
      final completer = image.resolve(ImageConfiguration.empty);
      completer.addListener(ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _shimmerController.stop();
          }
        },
        onError: (exception, stackTrace) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _shimmerController.stop();
          }
        },
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _shimmerController.stop();
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _ShimmerLoader(
        width: widget.width,
        height: widget.height,
        controller: _shimmerController,
      );
    }

    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.width * devicePixelRatio).round();
    final cacheHeight = (widget.height * devicePixelRatio).round();

    return Image.asset(
      widget.imageAsset,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }
}

class _ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final String imageAsset;

  const _ShimmerText({
    required this.text,
    required this.style,
    required this.imageAsset,
  });

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _checkImageLoaded();
  }

  Future<void> _checkImageLoaded() async {
    try {
      final image = AssetImage(widget.imageAsset);
      final completer = image.resolve(ImageConfiguration.empty);
      completer.addListener(ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _shimmerController.stop();
          }
        },
        onError: (exception, stackTrace) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _shimmerController.stop();
          }
        },
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _shimmerController.stop();
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading) {
      return Text(
        widget.text,
        style: widget.style,
      );
    }

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerPosition = _shimmerController.value * 2 - 1;
        // Estimate text width based on text length and font size
        final estimatedWidth = widget.text.length * (widget.style.fontSize! * 0.6);
        final textWidth = estimatedWidth.clamp(50.0, 320.0);
        
        return Container(
          constraints: BoxConstraints(
            maxWidth: 320,
            minWidth: 50,
          ),
          height: widget.style.fontSize! * 1.2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade300,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  width: textWidth,
                  height: double.infinity,
                  color: Colors.grey.shade300,
                ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      textWidth * shimmerPosition,
                      0,
                    ),
                    child: Container(
                      width: textWidth * 0.4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.2),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
