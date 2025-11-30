import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/club_code_entry_widget.dart';

class ActionTilesWidget extends StatelessWidget {
  const ActionTilesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What would you like to do?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate tile height: image (320/1.618 ≈ 198) + spacing (12) + title (~24 with line height) + spacing (4) + description (~20 with line height) + buffer (10)
                  final maxCardWidth = constraints.maxWidth > 320 ? 320.0 : constraints.maxWidth;
                  final cardHeight = maxCardWidth / 1.618;
                  final tileHeight = cardHeight + 12 + 24 + 4 + 20 + 10; // Image + spacing + title + spacing + description + buffer
                  
                  return SizedBox(
                    height: tileHeight,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildTile(
                          context: context,
                          imageUrl: 'https://firebasestorage.googleapis.com/v0/b/toastmasters-daily.firebasestorage.app/o/images%2Fjoin_meeting.webp?alt=media&token=6bdd28ab-26d8-4d3a-898f-2bad2d1db12c',
                          title: 'Join Meeting',
                          description: 'Enter club code to join',
                          onTap: () => _showJoinMeetingDialog(context),
                        ),
                        const SizedBox(width: 16),
                        _buildTile(
                          context: context,
                          imageUrl: 'https://firebasestorage.googleapis.com/v0/b/toastmasters-daily.firebasestorage.app/o/images%2Fcreate_meeting.webp?alt=media&token=e28774a7-6ae6-409e-8f23-724aae15f9b3',
                          title: 'Create Meeting',
                          description: 'Start a new meeting',
                          onTap: () => _navigateToCreateMeeting(context),
                        ),
                        const SizedBox(width: 16),
                        _buildTile(
                          context: context,
                          imageUrl: 'https://firebasestorage.googleapis.com/v0/b/toastmasters-daily.firebasestorage.app/o/images%2Fdaily_challenge.webp?alt=media&token=e9ebcb6d-78db-4fc5-ba16-3413fd30f398',
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
    required String imageUrl,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate width (use most of available space, max 320px)
        final maxCardWidth = constraints.maxWidth > 320 ? 320.0 : constraints.maxWidth;
        // Golden ratio landscape: height = width / 1.618
        final cardHeight = maxCardWidth / 1.618;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: maxCardWidth,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _NetworkImageWithShimmer(
                      imageUrl: imageUrl,
                      width: maxCardWidth,
                      height: cardHeight,
                      onLoadingStateChanged: (isLoading) {
                        // This will be handled by the state
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ShimmerText(
              text: title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF212121),
              ),
              imageUrl: imageUrl,
            ),
            const SizedBox(height: 4),
            _ShimmerText(
              text: description,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B7280),
              ),
              imageUrl: imageUrl,
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

class _NetworkImageWithShimmer extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final ValueChanged<bool>? onLoadingStateChanged;

  const _NetworkImageWithShimmer({
    required this.imageUrl,
    required this.width,
    required this.height,
    this.onLoadingStateChanged,
  });

  @override
  State<_NetworkImageWithShimmer> createState() => _NetworkImageWithShimmerState();
}

class _NetworkImageWithShimmerState extends State<_NetworkImageWithShimmer>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasError = false;
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
      final image = NetworkImage(widget.imageUrl);
      final completer = image.resolve(ImageConfiguration.empty);
      completer.addListener(ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            widget.onLoadingStateChanged?.call(false);
          }
        },
        onError: (exception, stackTrace) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
            widget.onLoadingStateChanged?.call(false);
          }
        },
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
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
    if (_hasError) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 48,
        ),
      );
    }

    if (_isLoading) {
      return _ShimmerLoader(
        width: widget.width,
        height: widget.height,
        controller: _shimmerController,
      );
    }

    return Image.network(
      widget.imageUrl,
      fit: BoxFit.cover,
      width: widget.width,
      height: widget.height,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
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

class _ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final String imageUrl;

  const _ShimmerText({
    required this.text,
    required this.style,
    required this.imageUrl,
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
      final image = NetworkImage(widget.imageUrl);
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
