import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class Meeting {
  final String id;
  final String title;
  final String description;
  final DateTime? createdAt;
  final String? agendaUrl;
  final Map<String, dynamic>? polls;

  Meeting({
    required this.id,
    required this.title,
    required this.description,
    this.createdAt,
    this.agendaUrl,
    this.polls,
  });

  factory Meeting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Meeting(
      id: doc.id,
      title: data['title'] ?? 'Untitled Meeting',
      description: data['description'] ?? 'No description',
      createdAt: data['createdAt']?.toDate(),
      agendaUrl: data['agendaUrl'],
      polls: data['polls'],
    );
  }
}

class Poll {
  final String question;
  final List<String> options;
  final bool isActive;
  final Map<String, int> tallies;
  final int totalResponses;
  final DateTime createdAt;

  Poll({
    required this.question,
    required this.options,
    this.isActive = false,
    Map<String, int>? tallies,
    this.totalResponses = 0,
    DateTime? createdAt,
  }) : 
    tallies = tallies ?? Map.fromIterable(options, value: (_) => 0),
    createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'isActive': isActive,
      'tallies': tallies,
      'totalResponses': totalResponses,
      'createdAt': createdAt,
    };
  }

  factory Poll.fromMap(Map<String, dynamic> map) {
    return Poll(
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      isActive: map['isActive'] ?? false,
      tallies: Map<String, int>.from(map['tallies'] ?? {}),
      totalResponses: map['totalResponses'] ?? 0,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }
}

class ManageMeetingsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Meeting> _meetings = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot>? _meetingsSubscription;

  // Getters
  List<Meeting> get meetings => _meetings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize the provider
  void initialize() {
    final user = _auth.currentUser;
    if (user != null) {
      _startListening(user.uid);
    }
  }

  // Start listening to meetings
  void _startListening(String userId) {
    // Cancel any existing subscription
    _meetingsSubscription?.cancel();
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _meetingsSubscription = _firestore
          .collection('users')
          .doc(userId)
          .collection('meetings')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          _isLoading = false;
          _error = null;
          
          _meetings = snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList();
          notifyListeners();
        },
        onError: (error) {
          _isLoading = false;
          _error = 'Error loading meetings: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      _isLoading = false;
      _error = 'Error initializing meetings listener: $e';
      notifyListeners();
    }
  }

  // Stop listening and dispose resources
  @override
  void dispose() {
    _meetingsSubscription?.cancel();
    super.dispose();
  }

  // Clear meetings (for logout)
  void clearMeetings() {
    _meetingsSubscription?.cancel();
    _meetings = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // View agenda functionality
  Future<void> viewAgenda(BuildContext context, String agendaUrl) async {
    try {
      // For web, we can use url_launcher to open in a new tab
      // For mobile, we can use url_launcher to open in the default browser
      // First, let's check if the URL is valid
      if (agendaUrl.isEmpty) {
        throw Exception('Agenda URL is empty');
      }

      // Parse the URL and add cache-busting parameters to ensure fresh content
      final Uri baseUrl = Uri.parse(agendaUrl);
      final Uri url = baseUrl.replace(
        queryParameters: {
          ...baseUrl.queryParameters,
          't': DateTime.now().millisecondsSinceEpoch.toString(), // Cache buster
          'v': DateTime.now().toIso8601String(), // Version timestamp
        },
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // Opens in default browser/app
        );
      } else {
        throw Exception('Could not launch agenda URL');
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening agenda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Polls management methods
  Future<void> createPoll(String meetingId, Poll poll) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final meetingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meetings')
          .doc(meetingId);

      // Get current polls or initialize empty map
      final meetingDoc = await meetingRef.get();
      final currentData = meetingDoc.data() ?? {};
      final currentPolls = Map<String, dynamic>.from(currentData['polls'] ?? {});

      // Generate unique poll ID
      final pollId = 'poll_${DateTime.now().millisecondsSinceEpoch}';
      currentPolls[pollId] = poll.toMap();

      // Update the meeting document with new polls
      await meetingRef.update({'polls': currentPolls});

      // Refresh meetings list
      _refreshMeetings();
    } catch (e) {
      throw Exception('Failed to create poll: $e');
    }
  }

  Future<void> updatePoll(String meetingId, String pollId, Poll poll) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final meetingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meetings')
          .doc(meetingId);

      // Get current polls
      final meetingDoc = await meetingRef.get();
      final currentData = meetingDoc.data() ?? {};
      final currentPolls = Map<String, dynamic>.from(currentData['polls'] ?? {});

      // Update the specific poll
      currentPolls[pollId] = poll.toMap();

      // Update the meeting document
      await meetingRef.update({'polls': currentPolls});

      // Refresh meetings list
      _refreshMeetings();
    } catch (e) {
      throw Exception('Failed to update poll: $e');
    }
  }

  Future<void> deletePoll(String meetingId, String pollId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final meetingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meetings')
          .doc(meetingId);

      // Get current polls
      final meetingDoc = await meetingRef.get();
      final currentData = meetingDoc.data() ?? {};
      final currentPolls = Map<String, dynamic>.from(currentData['polls'] ?? {});

      // Remove the specific poll
      currentPolls.remove(pollId);

      // Update the meeting document
      await meetingRef.update({'polls': currentPolls});

      // Refresh meetings list
      _refreshMeetings();
    } catch (e) {
      throw Exception('Failed to delete poll: $e');
    }
  }

  Future<void> submitPollResponse(String meetingId, String pollId, String option) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final meetingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meetings')
          .doc(meetingId);

      // Get current polls
      final meetingDoc = await meetingRef.get();
      final currentData = meetingDoc.data() ?? {};
      final currentPolls = Map<String, dynamic>.from(currentData['polls'] ?? {});
      
      if (!currentPolls.containsKey(pollId)) {
        throw Exception('Poll not found');
      }

      final pollData = currentPolls[pollId];
      final tallies = Map<String, int>.from(pollData['tallies'] ?? {});
      
      // Increment the selected option's tally
      if (tallies.containsKey(option)) {
        tallies[option] = (tallies[option] ?? 0) + 1;
      }

      // Update total responses
      final totalResponses = (pollData['totalResponses'] ?? 0) + 1;

      // Update the poll data
      currentPolls[pollId] = {
        ...pollData,
        'tallies': tallies,
        'totalResponses': totalResponses,
      };

      // Update the meeting document
      await meetingRef.update({'polls': currentPolls});

      // Refresh meetings list
      _refreshMeetings();
    } catch (e) {
      throw Exception('Failed to submit poll response: $e');
    }
  }

  // Helper method to refresh meetings
  void _refreshMeetings() {
    final user = _auth.currentUser;
    if (user != null) {
      _startListening(user.uid);
    }
  }

  // Get polls for a specific meeting
  Future<Map<String, Poll>> getPollsForMeeting(String meetingId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final meetingRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meetings')
          .doc(meetingId);

      final meetingDoc = await meetingRef.get();
      if (!meetingDoc.exists) {
        throw Exception('Meeting not found');
      }

      final data = meetingDoc.data() ?? {};
      final pollsData = Map<String, dynamic>.from(data['polls'] ?? {});
      
      final Map<String, Poll> polls = {};
      pollsData.forEach((pollId, pollData) {
        try {
          polls[pollId] = Poll.fromMap(Map<String, dynamic>.from(pollData));
        } catch (e) {
          // Skip invalid poll data
          print('Error parsing poll $pollId: $e');
        }
      });
      
      return polls;
    } catch (e) {
      throw Exception('Failed to get polls: $e');
    }
  }
}
