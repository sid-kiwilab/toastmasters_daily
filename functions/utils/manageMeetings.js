const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * Creates a new live meeting in Firestore
 * @param {Object} data - The request data object
 * @param {string} data.title - Meeting title
 * @param {string} data.creatorId - ID of the user creating the meeting
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} The created meeting document
 */
exports.createMeeting = functions.https.onCall(async (data, context) => {
  try {
    const db = admin.firestore();
    
    // Validate required fields
    if (!data.title || !data.creatorId) {
      console.error('Missing required fields: title and creatorId are required');
      return { success: false, error: 'Missing required fields' };
    }
    
    // Generate random 8-digit meeting code with space in middle
    const code = Math.floor(10000000 + Math.random() * 90000000).toString();
    const meetingCode = code.slice(0, 4) + ' ' + code.slice(4);
    
    // Create meeting document with minimal required fields
    const meetingDoc = {
      title: data.title,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Use batch write to ensure both operations happen atomically
    const batch = db.batch();
    
    // Add meeting to active_meetings collection
    const activeMeetingRef = db.collection('active_meetings').doc(meetingCode);
    batch.set(activeMeetingRef, meetingDoc);
    
    // Add meeting to user's meetings collection
    const userMeetingRef = db
      .collection('users')
      .doc(data.creatorId)
      .collection('meetings')
      .doc(meetingCode);
    batch.set(userMeetingRef, {
      meetingId: meetingCode,
      title: data.title,
      createdAt: meetingDoc.createdAt
    });
    
    // Commit the batch - both operations succeed or both fail
    await batch.commit();
    
    // Return the created meeting data
    return {
      success: true,
      meeting: {
        id: meetingCode,
        ...meetingDoc
      }
    };
    
  } catch (error) {
    console.error('Error creating meeting:', error);
    return { success: false, error: 'Failed to create meeting' };
  }
});
