import 'package:flutter/material.dart';

class RoleHoldersListScreen extends StatelessWidget {
  final String meetingId;
  final String meetingTitle;

  const RoleHoldersListScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
  });

  // Standard Toastmasters roles
  static const List<Map<String, dynamic>> _standardRoles = [
    {
      'name': 'Toastmaster',
      'icon': Icons.mic,
      'description': 'The meeting host who introduces speakers and keeps the meeting on schedule',
    },
    {
      'name': 'General Evaluator',
      'icon': Icons.rate_review,
      'description': 'Evaluates the evaluators and provides overall meeting feedback',
    },
    {
      'name': 'Timer',
      'icon': Icons.timer,
      'description': 'Tracks time for speeches and reports timing signals',
    },
    {
      'name': 'Grammarian',
      'icon': Icons.edit_note,
      'description': 'Reports on language usage, grammar, and word of the day',
    },
    {
      'name': 'Ah Counter',
      'icon': Icons.chat_bubble_outline,
      'description': 'Counts filler words and sounds used during speeches',
    },
    {
      'name': 'Table Topics Master',
      'icon': Icons.question_answer,
      'description': 'Leads the impromptu speaking portion of the meeting',
    },
    {
      'name': 'Speaker',
      'icon': Icons.person,
      'description': 'Members giving prepared speeches',
    },
    {
      'name': 'Evaluator',
      'icon': Icons.feedback,
      'description': 'Members providing feedback on speeches',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Roles'),
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
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Meeting Title
              Text(
                meetingTitle,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                  letterSpacing: -1,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a role to learn more',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              
              // Role Cards
              ..._standardRoles.map((role) {
                final roleName = role['name'] as String;
                final icon = role['icon'] as IconData;
                final description = role['description'] as String;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Convert role name to URL-friendly format (lowercase with hyphens)
                        final urlRoleName = roleName.toLowerCase().replaceAll(' ', '-');
                        Navigator.of(context).pushNamed(
                          '/meetings/$meetingId/roles/$urlRoleName',
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFC41E3A),
                                    Color(0xFF003366),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFC41E3A).withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    roleName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF212121),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF757575),
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

