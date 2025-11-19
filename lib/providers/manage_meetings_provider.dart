import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

class Meeting {
  final String id;
  final String title;
  final String description;
  final DateTime? createdAt;
  final String? agendaUrl;

  Meeting({
    required this.id,
    required this.title,
    required this.description,
    this.createdAt,
    this.agendaUrl,
  });

  factory Meeting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Meeting(
      id: doc.id,
      title: data['title'] ?? 'Untitled Meeting',
      description: data['description'] ?? 'No description',
      createdAt: data['created_at']?.toDate(),
      agendaUrl: data['agendaUrl'] ?? data['agenda_url'],
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
  final Map<String, String>? deviceVotes; // deviceId -> selectedOption

  Poll({
    required this.question,
    required this.options,
    this.isActive = false,
    Map<String, int>? tallies,
    this.totalResponses = 0,
    DateTime? createdAt,
    this.deviceVotes,
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
      'deviceVotes': deviceVotes,
    };
  }

  factory Poll.fromMap(Map<String, dynamic> map) {
    return Poll(
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      isActive: map['is_active'] ?? map['isActive'] ?? false,
      tallies: Map<String, int>.from(map['tallies'] ?? {}),
      totalResponses: map['total_responses'] ?? map['totalResponses'] ?? 0,
      createdAt: map['created_at']?.toDate() ?? map['createdAt']?.toDate() ?? DateTime.now(),
      deviceVotes: map['device_votes'] != null 
          ? Map<String, String>.from(map['device_votes'])
          : map['deviceVotes'] != null 
          ? Map<String, String>.from(map['deviceVotes'])
          : null,
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
          .orderBy('created_at', descending: true)
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
          // Check if it's an index error
          final errorString = error.toString();
          if (errorString.contains('index') || errorString.contains('requires an index')) {
            _error = 'Firestore index required. Please create the index as shown in the error message.';
          } else {
            _error = 'Error loading meetings: $error';
          }
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

  // Helper method to get polls collection reference
  Future<CollectionReference> _getPollsCollectionRef(String meetingId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    // Verify meeting exists
    final meetingRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('meetings')
        .doc(meetingId);
    
    final meetingDoc = await meetingRef.get();
    if (!meetingDoc.exists) {
      throw Exception('Meeting not found');
    }
    
    return meetingRef.collection('polls');
  }

  // Polls management methods - using subcollection
  Future<String> createPoll(String meetingId, Poll poll) async {
    try {
      final pollsRef = await _getPollsCollectionRef(meetingId);
      
      // Generate unique poll ID
      final pollId = 'poll_${DateTime.now().millisecondsSinceEpoch}';
      
      // Convert poll to map with snake_case fields
      final pollMap = {
        'question': poll.question,
        'options': poll.options,
        'is_active': poll.isActive,
        'tallies': Map.fromIterable(poll.options, key: (option) => option, value: (_) => 0),
        'total_responses': 0,
        'device_votes': <String, String>{},
        'created_at': FieldValue.serverTimestamp(),
      };
      
      // Create poll document in subcollection
      await pollsRef.doc(pollId).set(pollMap);
      
      return pollId;
    } catch (e) {
      throw Exception('Failed to create poll: $e');
    }
  }

  Future<void> updatePoll(String meetingId, String pollId, Poll poll) async {
    try {
      final pollsRef = await _getPollsCollectionRef(meetingId);
      
      // Get existing poll
      final pollDoc = await pollsRef.doc(pollId).get();
      if (!pollDoc.exists) {
        throw Exception('Poll not found');
      }

      final existingData = pollDoc.data() as Map<String, dynamic>;
      final oldOptions = List<String>.from(existingData['options'] ?? []);
      final newOptions = poll.options;
      
      // Get existing tallies and device votes
      final existingTallies = Map<String, int>.from(existingData['tallies'] ?? {});
      final existingDeviceVotes = Map<String, String>.from(existingData['device_votes'] ?? {});

      // Build position-based mapping ONLY for true renames (not deletions or moves)
      // A rename is: old option doesn't exist in new list AND new option doesn't exist in old list
      final positionMapping = <String, String>{};
      final minLength = oldOptions.length < newOptions.length ? oldOptions.length : newOptions.length;
      for (int i = 0; i < minLength; i++) {
        final oldOption = oldOptions[i];
        final newOption = newOptions[i];
        
        // Only map if this is a true rename:
        // 1. Old option doesn't exist in new list (was renamed or deleted)
        // 2. New option doesn't exist in old list (is a new name, not moved)
        // 3. They're different (not the same option)
        if (oldOption != newOption && 
            !newOptions.contains(oldOption) && 
            !oldOptions.contains(newOption)) {
          // This is a rename: old option was renamed to new option at same position
          positionMapping[oldOption] = newOption;
        }
        // If oldOption == newOption: same option, handle by name
        // If oldOption exists in new list: it was moved, handle by name
        // If newOption exists in old list: it was moved, handle by name
        // If oldOption doesn't exist in new list AND newOption exists in old list: deletion, don't map
      }
      
      // Build new tallies: preserve votes for renamed/moved options, lose votes for deleted options
      final newTallies = <String, int>{};
      for (final entry in existingTallies.entries) {
        final oldOption = entry.key;
        
        // First check: was this option renamed? (position mapping exists and old option not in new list)
        if (positionMapping.containsKey(oldOption) && !newOptions.contains(oldOption)) {
          // Option was renamed at same position
          final newOption = positionMapping[oldOption]!;
          newTallies[newOption] = (newTallies[newOption] ?? 0) + entry.value;
        } else if (newOptions.contains(oldOption)) {
          // Option still exists (moved or unchanged) - preserve by name
          newTallies[oldOption] = (newTallies[oldOption] ?? 0) + entry.value;
        }
        // If option doesn't exist in new list and isn't in position mapping, it was deleted - votes lost
      }
      
      // Ensure all new options have entries
      for (final option in newOptions) {
        if (!newTallies.containsKey(option)) {
          newTallies[option] = 0;
        }
      }

      // Build new device votes: preserve votes for existing options, remove votes for deleted options
      final newDeviceVotes = <String, String>{};
      int removedVotesCount = 0;
      
      for (final entry in existingDeviceVotes.entries) {
        final deviceId = entry.key;
        final oldVotedOption = entry.value;
        
        // First check: was this option renamed? (position mapping exists and old option not in new list)
        if (positionMapping.containsKey(oldVotedOption) && !newOptions.contains(oldVotedOption)) {
          // Option was renamed at same position
          final newVotedOption = positionMapping[oldVotedOption]!;
          if (newOptions.contains(newVotedOption)) {
            newDeviceVotes[deviceId] = newVotedOption;
          } else {
            // Shouldn't happen, but safety check
            removedVotesCount++;
          }
        } else if (newOptions.contains(oldVotedOption)) {
          // Option still exists (moved or unchanged) - preserve by name
          newDeviceVotes[deviceId] = oldVotedOption;
        } else {
          // Option was deleted - remove the vote
          removedVotesCount++;
        }
      }
      
      // Calculate new total responses
      final existingTotalResponses = existingData['total_responses'] ?? 0;
      final newTotalResponses = (existingTotalResponses - removedVotesCount).clamp(0, double.infinity).toInt();

      // Update poll document
      await pollsRef.doc(pollId).update({
        'question': poll.question,
        'options': newOptions,
        'is_active': poll.isActive,
        'tallies': newTallies,
        'device_votes': newDeviceVotes,
        'total_responses': newTotalResponses,
      });
    } catch (e) {
      throw Exception('Failed to update poll: $e');
    }
  }

  Future<void> deletePoll(String meetingId, String pollId) async {
    try {
      final pollsRef = await _getPollsCollectionRef(meetingId);
      
      // Verify poll exists
      final pollDoc = await pollsRef.doc(pollId).get();
      if (!pollDoc.exists) {
        throw Exception('Poll not found');
      }

      // Delete poll document
      await pollsRef.doc(pollId).delete();
    } catch (e) {
      throw Exception('Failed to delete poll: $e');
    }
  }

  Future<void> submitPollResponse(String meetingId, String pollId, String option, String deviceId) async {
    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('submit_vote').call({
        'meeting_id': meetingId,
        'poll_id': pollId,
        'option': option,
        'device_id': deviceId,
      });

      if (result.data['success'] != true) {
        throw Exception(result.data['error'] ?? 'Failed to submit vote');
      }

      // Note: Real-time updates will come through listeners, no need to refresh manually
    } catch (e) {
      throw Exception('Failed to submit poll response: $e');
    }
  }


  // Get polls for a specific meeting from polls subcollection
  // Accepts creatorId parameter to support viewing polls from any creator
  Future<Map<String, Poll>> getPollsForMeeting(String meetingId, {String? creatorId}) async {
    try {
      String? userId = creatorId;
      
      // If creatorId not provided, use current user (for own meetings)
      if (userId == null) {
        final user = _auth.currentUser;
        if (user == null) throw Exception('User not authenticated');
        userId = user.uid;
      }

      final pollsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('meetings')
          .doc(meetingId)
          .collection('polls');

      final querySnapshot = await pollsRef.orderBy('created_at', descending: false).get();
      
      final Map<String, Poll> polls = {};
      for (final doc in querySnapshot.docs) {
        try {
          polls[doc.id] = Poll.fromMap(doc.data());
        } catch (e) {
          print('Error parsing poll ${doc.id}: $e');
        }
      }
      
      return polls;
    } catch (e) {
      throw Exception('Failed to get polls: $e');
    }
  }
}
