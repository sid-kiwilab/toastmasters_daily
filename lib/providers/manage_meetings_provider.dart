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
      createdAt: data['createdAt']?.toDate(),
      agendaUrl: data['agendaUrl'],
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
}
