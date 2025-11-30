import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyChallengeWidget extends StatelessWidget {
  const DailyChallengeWidget({super.key});

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final todayDateString = _getTodayDateString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E1B4B).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Background image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/challenge.webp',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                // Gradient overlay for text readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1E1B4B).withOpacity(0.85),
                          const Color(0xFF312E81).withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join Today\'s Challenge',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.0,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 24),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('daily_challenges')
                    .doc(todayDateString)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Loading challenge...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        snapshot.hasError
                            ? 'Error loading challenge'
                            : 'No challenge available for today',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    );
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  final topic = data?['topic'] as String? ?? 'No topic available';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Topic',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              topic,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Upload a video of yourself delivering this speech and join the community of Toastmasters sharing their progress.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.6,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement video upload
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Video upload coming soon!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.video_library,
                          size: 20,
                        ),
                        label: const Text(
                          'Upload Video',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E1B4B),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
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

