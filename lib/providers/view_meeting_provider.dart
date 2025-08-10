import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_meetings_provider.dart';

class ViewMeetingProvider extends ChangeNotifier {
  Meeting? _meeting;
  List<Poll> _polls = [];
  bool _isLoading = false;
  String? _error;

  Meeting? get meeting => _meeting;
  List<Poll> get polls => _polls;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
        // Get creatorId from the meeting document to fetch polls
        final creatorId = doc.data()?['creatorId'] as String?;
        if (creatorId != null) {
          await _fetchPolls(creatorId, meetingId);
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
            return Poll.fromMap(pollData);
          }).toList();
        }
      }
    } catch (e) {
      // Silently handle poll loading errors for now
    }
  }

  void clearData() {
    _meeting = null;
    _polls = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
