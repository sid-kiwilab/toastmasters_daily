import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/guest_entry_widget.dart';

class GuestEntryScreen extends StatefulWidget {
  final String? meetingId;
  final String? clubCode;
  
  const GuestEntryScreen({
    super.key,
    this.meetingId,
    this.clubCode,
  }) : assert(meetingId != null || clubCode != null, 'Either meetingId or clubCode must be provided');

  @override
  State<GuestEntryScreen> createState() => _GuestEntryScreenState();
}

class _GuestEntryScreenState extends State<GuestEntryScreen> {
  String? _creatorId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.meetingId != null) {
      // If meetingId provided, GuestEntryWidget will get creatorId from it
      _isLoading = false;
    } else if (widget.clubCode != null) {
      _loadCreatorIdFromClub();
    }
  }

  Future<void> _loadCreatorIdFromClub() async {
    try {
      // Get club code document to find user ID (creator ID)
      final clubCodeDoc = await FirebaseFirestore.instance
          .collection('club_codes')
          .doc(widget.clubCode!)
          .get();

      if (!clubCodeDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final uid = clubCodeDoc.data()?['uid'] as String?;
      if (uid == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _creatorId = uid;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading creator ID from club: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (widget.meetingId != null) {
      return GuestEntryWidget(meetingId: widget.meetingId);
    } else if (_creatorId != null) {
      return GuestEntryWidget(creatorId: _creatorId);
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load guest entry form',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF212121),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

