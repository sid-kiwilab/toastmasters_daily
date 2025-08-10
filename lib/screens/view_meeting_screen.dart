import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/view_meeting_provider.dart';
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${meeting.id}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  meeting.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Text(
                  'Polls (${provider.polls.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...provider.polls.map((poll) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll.question,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...poll.options.map((option) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $option'),
                        )),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}
