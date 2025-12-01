import 'package:flutter/material.dart';
import 'youtube_video_overlay.dart';

class HomeBannerWidget extends StatelessWidget {
  const HomeBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1200),
      margin: EdgeInsets.only(
        left: isMobile ? 12 : 20,
        right: isMobile ? 12 : 20,
        bottom: isMobile ? 16 : 24,
      ),
      padding: EdgeInsets.only(
        top: isMobile ? 32 : 64,
        bottom: isMobile ? 32 : 64,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1), // Indigo
            Color(0xFF8B5CF6), // Purple
          ],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: isMobile ? 12 : 20,
            offset: Offset(0, isMobile ? 4 : 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build your voice,',
                  style: TextStyle(
                    fontSize: isMobile ? 28 : 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: isMobile ? -0.8 : -1.5,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Text(
                  'one day at a time',
                  style: TextStyle(
                    fontSize: isMobile ? 28 : 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: isMobile ? -0.8 : -1.5,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 24),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black87,
                      builder: (context) => const YoutubeVideoOverlay(
                        videoId: '50fOXQpA38w',
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.play_circle_outline,
                    size: isMobile ? 18 : 20,
                  ),
                  label: Text(
                    'Learn How',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6366F1),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 24,
                      vertical: isMobile ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                    ),
                    elevation: 0,
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
