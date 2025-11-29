import 'package:flutter/material.dart';

class ChallengeVideosWidget extends StatelessWidget {
  const ChallengeVideosWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder video data - in real app, this would come from backend
    final List<Map<String, String>> videos = [
      {'name': 'Sarah M.', 'time': '2 hours ago', 'views': '1.2K'},
      {'name': 'John D.', 'time': '5 hours ago', 'views': '856'},
      {'name': 'Maria L.', 'time': '1 day ago', 'views': '2.1K'},
      {'name': 'Alex K.', 'time': '1 day ago', 'views': '934'},
      {'name': 'Emma T.', 'time': '2 days ago', 'views': '1.5K'},
      {'name': 'Mike R.', 'time': '2 days ago', 'views': '678'},
      {'name': 'Lisa P.', 'time': '3 days ago', 'views': '1.8K'},
      {'name': 'David W.', 'time': '3 days ago', 'views': '1.1K'},
    ];

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1200),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'Community Submissions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate columns based on available width (YouTube-like responsive grid)
              int crossAxisCount = 1;
              if (constraints.maxWidth > 1000) {
                crossAxisCount = 4;
              } else if (constraints.maxWidth > 700) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth > 500) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 1;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 40,
                  childAspectRatio: 0.75,
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  return _VideoCard(
                    name: video['name']!,
                    time: video['time']!,
                    views: video['views']!,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final String name;
  final String time;
  final String views;

  const _VideoCard({
    required this.name,
    required this.time,
    required this.views,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Placeholder gradient background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getGradientColors(name),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Play button overlay
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                // Duration badge (bottom right)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '2:45',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Video info
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title/Name
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Metadata
              Row(
                children: [
                  Text(
                    views,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF606060),
                    ),
                  ),
                  const Text(
                    ' • ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF606060),
                    ),
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF606060),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Color> _getGradientColors(String name) {
    final colors = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
      [const Color(0xFF10B981), const Color(0xFF059669)],
      [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
      [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
      [const Color(0xFFEF4444), const Color(0xFFDC2626)],
      [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
    ];
    return colors[name.hashCode % colors.length];
  }
}

