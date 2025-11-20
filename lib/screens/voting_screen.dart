import 'package:flutter/material.dart';
import '../widgets/voting_widget.dart';

class VotingScreen extends StatelessWidget {
  final String meetingId;
  
  const VotingScreen({
    super.key,
    required this.meetingId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F0F0),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Voting',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    color: const Color(0xFF424242),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Voting Widget
            Expanded(
              child: VotingWidget(meetingId: meetingId),
            ),
          ],
        ),
      ),
    );
  }
}

