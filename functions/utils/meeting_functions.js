const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * Creates a new live meeting in Firestore
 * @param {Object} data - The request data object
 * @param {string} data.title - Meeting title
 * @param {string} data.creator_id - ID of the user creating the meeting
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} The created meeting document
 */
exports.create_meeting = functions.https.onCall(async (data, context) => {
  try {
    const db = admin.firestore();
    
    // Validate required fields
    if (!data.title || !data.creator_id) {
      console.error('Missing required fields: title and creator_id are required');
      return { success: false, error: 'Missing required fields' };
    }
    
    // Verify subscription is active
    const userDoc = await db.collection('users').doc(data.creator_id).get();
    
    if (!userDoc.exists) {
      console.error('User document not found:', data.creator_id);
      return { success: false, error: 'User profile not found' };
    }
    
    const subscriptionStatus = userDoc.data()?.subscription;
    // If subscription field doesn't exist or is not 'active', deny access
    if (subscriptionStatus !== 'active') {
      console.error('Subscription not active for user:', data.creator_id, 'Status:', subscriptionStatus || 'not set');
      return { 
        success: false, 
        error: 'Creating meetings requires an active subscription' 
      };
    }
    
    // Generate random 8-digit meeting code
    const meeting_code = Math.floor(10000000 + Math.random() * 90000000).toString();
    
    // Create meeting document with minimal required fields
    const meeting_doc = {
      title: data.title,
      creator_id: data.creator_id,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Use batch write to ensure both operations happen atomically
    const batch = db.batch();
    
    // Add meeting to active_meetings collection
    const active_meeting_ref = db.collection('active_meetings').doc(meeting_code);
    batch.set(active_meeting_ref, meeting_doc);
    
    // Add meeting to user's meetings collection
    const user_meeting_ref = db
      .collection('users')
      .doc(data.creator_id)
      .collection('meetings')
      .doc(meeting_code);
    batch.set(user_meeting_ref, meeting_doc);
    
    // Commit the batch - both operations succeed or both fail
    await batch.commit();
    
    // Return the created meeting data
    return {
      success: true,
      meeting: {
        id: meeting_code,
        ...meeting_doc
      }
    };
    
  } catch (error) {
    console.error('Error creating meeting:', error);
    return { success: false, error: 'Failed to create meeting' };
  }
});

/**
 * Deletes a meeting from both active_meetings and user's meetings collection
 * @param {Object} data - The request data object
 * @param {string} data.meeting_id - ID of the meeting to delete
 * @param {string} data.creator_id - ID of the user who created the meeting
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} Success status
 */
exports.delete_meeting = functions.https.onCall(async (data, context) => {
  try {
    const db = admin.firestore();
    
    // Validate required fields
    if (!data.meeting_id || !data.creator_id) {
      console.error('Missing required fields: meeting_id and creator_id are required');
      return { success: false, error: 'Missing required fields' };
    }
    
    const meeting_id = data.meeting_id;
    const creator_id = data.creator_id;
    
    // Use transaction to ensure both deletions happen atomically
    await db.runTransaction(async (transaction) => {
      // Read both documents first
      const active_meeting_ref = db.collection('active_meetings').doc(meeting_id);
      const user_meeting_ref = db
        .collection('users')
        .doc(creator_id)
        .collection('meetings')
        .doc(meeting_id);
      
      const active_meeting_doc = await transaction.get(active_meeting_ref);
      const user_meeting_doc = await transaction.get(user_meeting_ref);
      
      // Verify the meeting belongs to the creator
      if (active_meeting_doc.exists) {
        const meeting_data = active_meeting_doc.data();
        if (meeting_data && meeting_data.creator_id !== creator_id) {
          throw new Error('Unauthorized: Meeting does not belong to this user');
        }
      }
      
      // Delete from both collections
      if (active_meeting_doc.exists) {
        transaction.delete(active_meeting_ref);
      }
      
      if (user_meeting_doc.exists) {
        transaction.delete(user_meeting_ref);
      }
    });
    
    // Delete agenda file from Firebase Storage if it exists
    try {
      const bucket = admin.storage().bucket();
      const agenda_file_path = `agendas/${meeting_id}.pdf`;
      const agenda_file = bucket.file(agenda_file_path);
      
      const [exists] = await agenda_file.exists();
      if (exists) {
        await agenda_file.delete();
        console.log(`Deleted agenda file: ${agenda_file_path}`);
      }
    } catch (storage_error) {
      console.error(`Error deleting agenda file for meeting ${meeting_id}:`, storage_error);
      // Continue even if storage deletion fails
    }
    
    return {
      success: true,
      message: 'Meeting deleted successfully'
    };
    
  } catch (error) {
    console.error('Error deleting meeting:', error);
    return { 
      success: false, 
      error: error.message || 'Failed to delete meeting' 
    };
  }
});

