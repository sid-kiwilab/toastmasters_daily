import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/view_meeting_provider.dart';
import '../providers/manage_meetings_provider.dart';
import '../utils/theme.dart';

class ViewMeetingScreen extends StatefulWidget {
  final String meetingId;

  const ViewMeetingScreen({
    super.key,
    required this.meetingId,
  });

  @override
  State<ViewMeetingScreen> createState() => _ViewMeetingScreenState();
}

class _ViewMeetingScreenState extends State<ViewMeetingScreen> {
  late ViewMeetingProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ViewMeetingProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.initialize(widget.meetingId);
    });
  }

  @override
  void dispose() {
    _provider.clearData(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ViewMeetingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Text('Error: ${provider.error}'),
            );
          }

          final meeting = provider.meeting;
          if (meeting == null) {
            return const Center(child: Text('Meeting not found'));
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    meeting.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: ${meeting.id}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (provider.polls.isNotEmpty) ...[
                    Text(
                      'Polls (${provider.polls.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ...provider.polls.asMap().entries.map((entry) {
                      final index = entry.key;
                      final pollWithId = entry.value;
                      return _buildPollCard(pollWithId, index + 1);
                    }),
                  ] else ...[
                    Text(
                      'No polls available',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPollCard(PollWithId pollWithId, int pollNumber) {
    final poll = pollWithId.poll;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Poll $pollNumber',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              poll.question,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (poll.isActive) ...[
              Text(
                'Vote for your preferred option:',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ...poll.options.map((option) => _buildVoteButton(pollWithId.id, option)),
              const SizedBox(height: 24),
              Text(
                'Total Responses: ${poll.totalResponses}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This poll is not currently active',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildPollResults(poll),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton(String pollId, String option) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: () => _voteOnPoll(pollId, option),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: Theme.of(context).textTheme.titleMedium,
        ),
        child: Text(option),
      ),
    );
  }

  Widget _buildPollResults(Poll poll) {
    if (poll.totalResponses == 0) {
      return Text(
        'No votes yet',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Results:',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ...poll.options.map((option) {
          final votes = poll.tallies[option] ?? 0;
          final percentage = poll.totalResponses > 0 
              ? (votes / poll.totalResponses * 100).toStringAsFixed(1)
              : '0.0';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        option,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '$votes votes ($percentage%)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: poll.totalResponses > 0 ? votes / poll.totalResponses : 0,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _voteOnPoll(String pollId, String option) {
    _provider.voteOnPoll(pollId, option);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voted for: $option'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
