const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { rateLimit } = require('./rate_limiter_functions');

// Rate limit configuration for meeting functions
const RATE_LIMITS = {
  create_meeting: { max_calls: 10, window_seconds: 60 }, // 10 per minute
  delete_meeting: { max_calls: 20, window_seconds: 60 }, // 20 per minute
};

/**
 * Creates a new live meeting in Firestore
 * @param {Object} data - The request data object
 * @param {string} data.title - Meeting title
 * @param {string} data.creator_id - ID of the user creating the meeting
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} The created meeting document
 */
const create_meeting_handler = async (data, context) => {
  try {
    const db = admin.firestore();
    
    // Validate required fields
    if (!data.title || !data.creator_id) {
      console.error('Missing required fields: title and creator_id are required');
      return { success: false, error: 'Missing required fields' };
    }
    
    // Verify subscription is active OR trial is active
    const userDoc = await db.collection('users').doc(data.creator_id).get();
    
    if (!userDoc.exists) {
      console.error('User document not found:', data.creator_id);
      return { success: false, error: 'User profile not found' };
    }
    
    const userData = userDoc.data();
    const subscriptionStatus = userData?.subscription;
    const trialEndDate = userData?.trial_end_date;
    
    // Check if subscription is active
    const isSubscriptionActive = subscriptionStatus === 'active';
    
    // Check if trial is active (trial_end_date exists and hasn't passed)
    let isTrialActive = false;
    if (trialEndDate) {
      const trialEnd = trialEndDate.toDate();
      const now = new Date();
      isTrialActive = trialEnd > now;
    }
    
    // Allow if either subscription is active OR trial is active
    if (!isSubscriptionActive && !isTrialActive) {
      console.error('No active subscription or trial for user:', data.creator_id, 
        'Subscription:', subscriptionStatus || 'not set', 
        'Trial end date:', trialEndDate ? trialEndDate.toDate() : 'not set');
      return { 
        success: false, 
        error: 'Creating meetings requires an active subscription or trial' 
      };
    }
    
    // Convert meeting_datetime if provided
    let meeting_datetime = null;
    if (data.meeting_datetime) {
      // If it's a timestamp string or number, convert it
      if (typeof data.meeting_datetime === 'string' || typeof data.meeting_datetime === 'number') {
        meeting_datetime = admin.firestore.Timestamp.fromDate(new Date(data.meeting_datetime));
      } else if (data.meeting_datetime.seconds) {
        // If it's already a Firestore timestamp-like object
        meeting_datetime = admin.firestore.Timestamp.fromMillis(data.meeting_datetime.seconds * 1000);
      }
    }
    
    // Check 3 meetings per day limit (single range query to avoid composite index)
    if (meeting_datetime) {
      const meetingDate = meeting_datetime.toDate();
      const dateStart = new Date(meetingDate);
      dateStart.setHours(0, 0, 0, 0);
      const dateEnd = new Date(meetingDate);
      dateEnd.setHours(23, 59, 59, 999);
      
      const meetingsQuery = await db
        .collection('users')
        .doc(data.creator_id)
        .collection('meetings')
        .where('meeting_datetime', '>=', admin.firestore.Timestamp.fromDate(dateStart))
        .limit(3)
        .get();
      
      let sameDateCount = 0;
      meetingsQuery.forEach(doc => {
        const dt = doc.data().meeting_datetime?.toDate();
        if (dt && dt >= dateStart && dt <= dateEnd) sameDateCount++;
      });
      
      if (sameDateCount >= 3) {
        return { success: false, error: 'You can only create a maximum of 3 meetings per day.' };
      }
    }
    
    // Create meeting document with minimal required fields
    const meeting_doc = {
      title: data.title,
      creator_id: data.creator_id,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Add meeting_datetime if provided
    if (meeting_datetime) {
      meeting_doc.meeting_datetime = meeting_datetime;
    }
    
    // Use batch write to ensure both operations happen atomically
    const batch = db.batch();
    
    // Create meeting in active_meetings collection with auto-generated ID
    const active_meeting_ref = db.collection('active_meetings').doc(); // Firestore auto-generates the ID
    const meeting_id = active_meeting_ref.id; // Get the auto-generated ID
    batch.set(active_meeting_ref, meeting_doc);
    
    // Add meeting to user's meetings collection (use same auto-generated ID)
    const user_meeting_ref = db
      .collection('users')
      .doc(data.creator_id)
      .collection('meetings')
      .doc(meeting_id); // Use the same auto-generated ID
    batch.set(user_meeting_ref, meeting_doc);
    
    // Commit the batch - both operations succeed or both fail
    await batch.commit();
    
    // Return the created meeting data
    return {
      success: true,
      meeting: {
        id: meeting_id, // Return the auto-generated ID
        ...meeting_doc
      }
    };
    
  } catch (error) {
    console.error('Error creating meeting:', error);
    return { success: false, error: 'Failed to create meeting' };
  }
};

// Wrap with rate limiting
exports.create_meeting = functions.https.onCall(
  rateLimit(create_meeting_handler, {
    ...RATE_LIMITS.create_meeting,
    function_name: 'create_meeting'
  })
);

/**
 * Deletes a meeting from both active_meetings and user's meetings collection
 * @param {Object} data - The request data object
 * @param {string} data.meeting_id - ID of the meeting to delete
 * @param {string} data.creator_id - ID of the user who created the meeting
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} Success status
 */
const delete_meeting_handler = async (data, context) => {
  try {
    const db = admin.firestore();
    
    // Validate required fields
    if (!data.meeting_id || !data.creator_id) {
      console.error('Missing required fields: meeting_id and creator_id are required');
      return { success: false, error: 'Missing required fields' };
    }
    
    const meeting_id = data.meeting_id;
    const creator_id = data.creator_id;
    
    // Verify subscription is active OR trial is active
    const userDoc = await db.collection('users').doc(creator_id).get();
    if (!userDoc.exists) {
      return { success: false, error: 'User profile not found' };
    }
    const userData = userDoc.data();
    const isSubscriptionActive = userData?.subscription === 'active';
    let isTrialActive = false;
    if (userData?.trial_end_date) {
      const trialEnd = userData.trial_end_date.toDate();
      isTrialActive = trialEnd > new Date();
    }
    if (!isSubscriptionActive && !isTrialActive) {
      return { success: false, error: 'Deleting meetings requires an active subscription or trial' };
    }
    
    // Delete all polls in the polls subcollection first
    try {
      const polls_ref = db
        .collection('users')
        .doc(creator_id)
        .collection('meetings')
        .doc(meeting_id)
        .collection('polls');
      
      const polls_snapshot = await polls_ref.get();
      
      if (!polls_snapshot.empty) {
        // Use batch to delete all polls (Firestore batch limit is 500 operations)
        let batch = db.batch();
        let batch_count = 0;
        const total_polls = polls_snapshot.size;
        
        for (const poll_doc of polls_snapshot.docs) {
          batch.delete(poll_doc.ref);
          batch_count++;
          
          // Commit batch if we reach 500 operations (Firestore limit)
          if (batch_count >= 500) {
            await batch.commit();
            batch = db.batch(); // Create new batch
            batch_count = 0;
          }
        }
        
        // Commit remaining deletions
        if (batch_count > 0) {
          await batch.commit();
        }
        
        console.log(`Deleted ${total_polls} poll(s) for meeting ${meeting_id}`);
      }
    } catch (polls_error) {
      console.error(`Error deleting polls for meeting ${meeting_id}:`, polls_error);
      // Continue with meeting deletion even if polls deletion fails
    }
    
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
};

// Wrap with rate limiting
exports.delete_meeting = functions.https.onCall(
  rateLimit(delete_meeting_handler, {
    ...RATE_LIMITS.delete_meeting,
    function_name: 'delete_meeting'
  })
);

