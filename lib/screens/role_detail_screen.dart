import 'package:flutter/material.dart';

class RoleDetailScreen extends StatelessWidget {
  final String meetingId;
  final String meetingTitle;
  final String roleName;

  const RoleDetailScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
    required this.roleName,
  });

  // Role descriptions and icons with detailed information
  static const Map<String, Map<String, dynamic>> _roleInfo = {
    'Toastmaster': {
      'icon': Icons.mic,
      'description': 'The Toastmaster is the meeting host who introduces speakers, keeps the meeting on schedule, and ensures everything runs smoothly. This role requires excellent organizational skills and the ability to think on your feet.',
      'responsibilities': [
        'Welcome members and guests at the beginning of the meeting',
        'Introduce speakers and their speeches with enthusiasm',
        'Keep the meeting on schedule and manage time effectively',
        'Facilitate smooth transitions between meeting segments',
        'Provide brief, engaging introductions for each speaker',
        'Maintain a positive and energetic atmosphere throughout',
        'Handle any unexpected situations with grace',
      ],
      'tips': [
        'Arrive early to review the agenda and speaker information',
        'Prepare introductions that highlight each speaker\'s background',
        'Practice smooth transitions between segments',
        'Keep energy levels high to engage the audience',
      ],
    },
    'General Evaluator': {
      'icon': Icons.rate_review,
      'description': 'The General Evaluator evaluates the evaluators and provides overall feedback on the meeting. This role helps improve the quality of evaluations and the meeting as a whole.',
      'responsibilities': [
        'Evaluate the evaluators and their feedback quality',
        'Provide comprehensive feedback on meeting flow and organization',
        'Comment on the overall meeting quality and atmosphere',
        'Give constructive suggestions for improvement',
        'Observe timing, transitions, and meeting structure',
        'Provide feedback on the Toastmaster\'s performance',
      ],
      'tips': [
        'Take detailed notes throughout the meeting',
        'Focus on both strengths and areas for improvement',
        'Be specific and constructive in your feedback',
        'Help evaluators improve their evaluation skills',
      ],
    },
    'Timer': {
      'icon': Icons.timer,
      'description': 'The Timer tracks time for speeches and reports timing signals to speakers. This role is crucial for helping speakers stay within their time limits and for maintaining meeting schedule.',
      'responsibilities': [
        'Track time for each speech accurately',
        'Display timing signals clearly (green, yellow, red)',
        'Report timing at the end of each speech',
        'Keep track of meeting segments timing',
        'Ensure speakers are aware of their time status',
        'Help maintain the overall meeting schedule',
      ],
      'tips': [
        'Use a reliable timer device or app',
        'Position yourself where speakers can see signals easily',
        'Be consistent with timing signal displays',
        'Report times clearly and concisely',
      ],
    },
    'Grammarian': {
      'icon': Icons.edit_note,
      'description': 'The Grammarian reports on language usage, grammar, and introduces the word of the day. This role helps members improve their language skills and vocabulary.',
      'responsibilities': [
        'Introduce the word of the day and its usage',
        'Listen carefully for language usage throughout the meeting',
        'Report on grammar, word choice, and language patterns',
        'Note interesting, creative, or effective language use',
        'Identify areas where language could be improved',
        'Encourage members to use the word of the day',
      ],
      'tips': [
        'Choose an interesting and useful word of the day',
        'Take notes on language usage throughout the meeting',
        'Balance positive feedback with constructive suggestions',
        'Help members expand their vocabulary',
      ],
    },
    'Ah Counter': {
      'icon': Icons.chat_bubble_outline,
      'description': 'The Ah Counter counts filler words and sounds used during speeches. This role helps speakers become aware of speech habits and improve their delivery.',
      'responsibilities': [
        'Count filler words (um, ah, like, you know, etc.)',
        'Track unnecessary sounds and pauses',
        'Report counts at the end of each speech',
        'Help speakers become aware of their speech habits',
        'Provide encouragement and support',
        'Track improvement over time',
      ],
      'tips': [
        'Focus on common filler words and sounds',
        'Be discreet and respectful when counting',
        'Provide constructive feedback, not criticism',
        'Help speakers understand their patterns',
      ],
    },
    'Table Topics Master': {
      'icon': Icons.question_answer,
      'description': 'The Table Topics Master leads the impromptu speaking portion of the meeting. This role encourages participation and helps members practice thinking on their feet.',
      'responsibilities': [
        'Prepare interesting and engaging impromptu speaking topics',
        'Call on members to speak in a fair and organized manner',
        'Keep the Table Topics segment on time',
        'Encourage participation from all members',
        'Create a supportive and fun atmosphere',
        'Vary topics to keep the segment interesting',
      ],
      'tips': [
        'Prepare topics that are relevant and engaging',
        'Vary difficulty levels to accommodate all members',
        'Keep the energy positive and encouraging',
        'Be creative with topic selection',
      ],
    },
    'Speaker': {
      'icon': Icons.person,
      'description': 'Speakers deliver prepared speeches based on their Toastmasters pathway projects. This role is the core of Toastmasters, helping members develop public speaking skills.',
      'responsibilities': [
        'Prepare and deliver speeches based on project objectives',
        'Follow the specific requirements of your pathway project',
        'Stay within assigned time limits',
        'Engage the audience and maintain their attention',
        'Practice and refine your speech before the meeting',
        'Be open to feedback and continuous improvement',
      ],
      'tips': [
        'Practice your speech multiple times before delivery',
        'Know your material well enough to speak naturally',
        'Use visual aids and gestures effectively',
        'Connect with your audience through eye contact',
        'Focus on your project objectives',
      ],
    },
    'Evaluator': {
      'icon': Icons.feedback,
      'description': 'Evaluators provide constructive feedback on speeches to help speakers improve. This role develops listening skills and the ability to give helpful feedback.',
      'responsibilities': [
        'Listen carefully and attentively to speeches',
        'Provide constructive, balanced feedback',
        'Highlight strengths and areas for improvement',
        'Follow the evaluation format and structure',
        'Be specific and actionable in your feedback',
        'Support and encourage the speaker',
      ],
      'tips': [
        'Take notes during the speech',
        'Balance positive feedback with constructive suggestions',
        'Be specific about what worked well and what could improve',
        'Focus on helping the speaker grow',
        'Use the evaluation form as a guide',
      ],
    },
  };

  @override
  Widget build(BuildContext context) {
    final roleInfo = _roleInfo[roleName] ?? {
      'icon': Icons.person,
      'description': 'Role information',
      'responsibilities': [],
      'tips': [],
    };

    final icon = roleInfo['icon'] as IconData;
    final description = roleInfo['description'] as String;
    final responsibilities = roleInfo['responsibilities'] as List<String>;
    final tips = roleInfo['tips'] as List<String>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(roleName),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212121),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width < 600 ? 20 : 40,
          vertical: 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              minHeight: MediaQuery.of(context).size.height - 200,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Role Icon and Name - Centered
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFC41E3A),
                            Color(0xFF003366),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC41E3A).withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      roleName,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212121),
                        letterSpacing: -1.2,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Description Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFC41E3A),
                                Color(0xFF003366),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'About This Role',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212121),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 17,
                        color: Color(0xFF424242),
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Responsibilities Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFC41E3A),
                                Color(0xFF003366),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Key Responsibilities',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212121),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ...responsibilities.asMap().entries.map((entry) {
                      final index = entry.key;
                      final responsibility = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < responsibilities.length - 1 ? 16 : 0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 8, right: 16),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFC41E3A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                responsibility,
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: Color(0xFF424242),
                                  height: 1.6,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Tips Card (if tips exist)
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFC41E3A).withOpacity(0.05),
                        const Color(0xFF003366).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            color: Color(0xFFC41E3A),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Helpful Tips',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF212121),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ...tips.asMap().entries.map((entry) {
                        final index = entry.key;
                        final tip = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < tips.length - 1 ? 16 : 0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 8, right: 16),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF003366),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF424242),
                                    height: 1.6,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
