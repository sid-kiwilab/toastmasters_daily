import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
  StreamSubscription<QuerySnapshot>? _pollsSubscription;

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
        // Get creator_id from the meeting document to fetch polls and agenda
        _creatorId = doc.data()?['creator_id'] as String? ?? doc.data()?['creatorId'] as String?;
        if (_creatorId != null) {
          // Fetch agenda_url from users collection
          await _fetchAgendaUrl(_creatorId!, meetingId);
          // Start real-time listener for polls
          _startPollsListener(_creatorId!, meetingId);
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

  Future<void> _fetchAgendaUrl(String creatorId, String meetingId) async {
    try {
      // Get agenda_url from users/{creatorId}/meetings/{meetingId}
      final meetingData = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .collection('meetings')
          .doc(meetingId)
          .get();
      
      if (meetingData.exists) {
        final data = meetingData.data()!;
        final agendaUrl = data['agenda_url'] as String?;
        
        // Update the meeting object with agenda_url
        if (_meeting != null) {
          // Create a new Meeting object with the agenda_url (even if null, to ensure it's set)
          _meeting = Meeting(
            id: _meeting!.id,
            title: _meeting!.title,
            description: _meeting!.description,
            createdAt: _meeting!.createdAt,
            agendaUrl: agendaUrl,
          );
          notifyListeners(); // Notify listeners that agenda URL has been loaded
        }
      }
    } catch (e) {
      // Silently handle agenda loading errors - meeting will just have no agenda
      print('Error fetching agenda URL: $e');
    }
  }

  void _startPollsListener(String creatorId, String meetingId) {
    // Cancel any existing subscription
    _pollsSubscription?.cancel();
    
    // Set up real-time listener for polls subcollection
    _pollsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(creatorId)
        .collection('meetings')
        .doc(meetingId)
        .collection('polls')
        .orderBy('created_at', descending: false)
        .snapshots()
        .listen(
      (snapshot) {
        _polls = snapshot.docs.map((doc) {
          try {
            return PollWithId(
              id: doc.id,
              poll: Poll.fromMap(doc.data()),
            );
          } catch (e) {
            print('Error parsing poll ${doc.id}: $e');
            return PollWithId(
              id: doc.id,
              poll: Poll(
                question: 'Error loading poll',
                options: ['Error'],
                isActive: false,
              ),
            );
          }
        }).toList();
        
        notifyListeners();
      },
      onError: (error) {
        print('Error in polls listener: $error');
        _polls = [];
        notifyListeners();
      },
    );
  }


  void clearData({bool notify = true}) {
    _pollsSubscription?.cancel();
    _pollsSubscription = null;
    _meeting = null;
    _polls = [];
    _isLoading = false;
    _error = null;
    _creatorId = null;
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollsSubscription?.cancel();
    super.dispose();
  }
}
