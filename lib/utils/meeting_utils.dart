import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for meeting-related operations
class MeetingUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Gets the creator_id for a meeting from active_meetings collection
  /// Returns null if meeting not found or creator_id doesn't exist
  static Future<String?> getCreatorId(String meetingId) async {
    try {
      final doc = await _firestore
          .collection('active_meetings')
          .doc(meetingId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data();
      return data?['creator_id'] as String?;
    } catch (e) {
      print('Error getting creator_id for meeting $meetingId: $e');
      return null;
    }
  }
}

