import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_meetings_provider.dart';

class PollWithId {
  final String id;
  final Poll poll;

  PollWithId({required this.id, required this.poll});
}

class ViewMeetingProvider extends ChangeNotifier {
  Meeting? _meeting;
  List<PollWithId> _polls = [];
  bool _isLoading = false;
  String? _error;
  String? _creatorId;

  Meeting? get meeting => _meeting;
  List<PollWithId> get polls => _polls;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get creatorId => _creatorId;

  void initialize(String meetingId) {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    _fetchMeeting(meetingId);
  }

  Future<void> _fetchMeeting(String meetingId) async {
    try {
      // Get meeting from active_meetings collection
      final doc = await FirebaseFirestore.instance
          .collection('active_meetings')
          .doc(meetingId)
          .get();

      if (doc.exists) {
        _meeting = Meeting.fromFirestore(doc);
        // Get creator_id from the meeting document to fetch polls
        _creatorId = doc.data()?['creator_id'] as String? ?? doc.data()?['creatorId'] as String?;
        if (_creatorId != null) {
          await _fetchPolls(_creatorId!, meetingId);
        }
      } else {
        _error = 'Meeting not found';
      }
    } catch (e) {
      _error = 'Error loading meeting: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchPolls(String creatorId, String meetingId) async {
    try {
      // Get polls from users/{creatorId}/meetings/{meetingId}
      final meetingData = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .collection('meetings')
          .doc(meetingId)
          .get();
      
      if (meetingData.exists) {
        final data = meetingData.data()!;
        final pollsData = data['polls'] as Map<String, dynamic>?;
        
        if (pollsData != null) {
          _polls = pollsData.entries.map((entry) {
            final pollData = entry.value as Map<String, dynamic>;
            return PollWithId(
              id: entry.key,
              poll: Poll.fromMap(pollData),
            );
          }).toList();
        }
      }
    } catch (e) {
      // Silently handle poll loading errors for now
    }
  }

  Future<void> voteOnPoll(String pollId, String selectedOption) async {
    if (_creatorId == null || _meeting == null) return;

    try {
      // Update the poll tallies in Firestore
      final pollRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_creatorId!)
          .collection('meetings')
          .doc(_meeting!.id);

      // Get current poll data
      final meetingDoc = await pollRef.get();
      if (meetingDoc.exists) {
        final data = meetingDoc.data()!;
        final pollsData = data['polls'] as Map<String, dynamic>?;
        
        if (pollsData != null && pollsData.containsKey(pollId)) {
          final pollData = pollsData[pollId] as Map<String, dynamic>;
          final tallies = Map<String, int>.from(pollData['tallies'] ?? {});
          
          // Increment the selected option
          tallies[selectedOption] = (tallies[selectedOption] ?? 0) + 1;
          
          // Update total responses
          final totalResponses = (pollData['totalResponses'] ?? 0) + 1;
          
          // Update the poll data
          pollsData[pollId] = {
            ...pollData,
            'tallies': tallies,
            'totalResponses': totalResponses,
          };
          
          // Update the document
          await pollRef.update({'polls': pollsData});
          
          // Refresh polls data
          await _fetchPolls(_creatorId!, _meeting!.id);
        }
      }
    } catch (e) {
      _error = 'Error voting: $e';
      notifyListeners();
    }
  }

  void clearData({bool notify = true}) {
    _meeting = null;
    _polls = [];
    _isLoading = false;
    _error = null;
    _creatorId = null;
    if (notify) {
      notifyListeners();
    }
  }
}
