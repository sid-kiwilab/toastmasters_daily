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
 * Deletes a meeting from both active_meetings and the user's meetings doc, including
 * all nested subcollections (polls, evals, etc.) under users/.../meetings/{id}.
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
    
    const active_meeting_ref = db.collection('active_meetings').doc(meeting_id);
    const user_meeting_ref = db
      .collection('users')
      .doc(creator_id)
      .collection('meetings')
      .doc(meeting_id);

    const [active_meeting_doc, user_meeting_doc] = await Promise.all([
      active_meeting_ref.get(),
      user_meeting_ref.get(),
    ]);

    if (active_meeting_doc.exists) {
      const meeting_data = active_meeting_doc.data();
      if (meeting_data && meeting_data.creator_id !== creator_id) {
        return { success: false, error: 'Unauthorized: Meeting does not belong to this user' };
      }
    }

    // Agendas live in Storage (must run before recursiveDelete, which drops agenda_url on the user meeting doc)
    // upload_agenda uses agendas/{creator_id}/{meetingId}_{timestamp}.pdf; older code used agendas/{meetingId}.pdf
    try {
      const bucket = admin.storage().bucket();
      const [versioned] = await bucket.getFiles({ prefix: `agendas/${creator_id}/${meeting_id}_` });
      for (const f of versioned) {
        await f.delete();
        console.log(`Deleted agenda file: ${f.name}`);
      }
      const legacy = bucket.file(`agendas/${meeting_id}.pdf`);
      const [legacyExists] = await legacy.exists();
      if (legacyExists) {
        await legacy.delete();
        console.log(`Deleted legacy agenda file: agendas/${meeting_id}.pdf`);
      }
      if (user_meeting_doc.exists) {
        const agendaUrl = user_meeting_doc.get('agenda_url') ?? user_meeting_doc.data()?.agenda_url;
        if (agendaUrl) {
          try {
            const u = new URL(String(agendaUrl));
            if (u.hostname === 'storage.googleapis.com' && u.pathname) {
              const segs = u.pathname.split('/').filter(Boolean);
              if (segs[0] === bucket.name) {
                const objectPath = segs.slice(1).join('/');
                if (objectPath && !objectPath.startsWith(`agendas/${creator_id}/${meeting_id}_`)) {
                  const obj = bucket.file(decodeURIComponent(objectPath));
                  const [exists] = await obj.exists();
                  if (exists) {
                    await obj.delete();
                    console.log(`Deleted agenda from agenda_url: ${objectPath}`);
                  }
                }
              }
            }
          } catch (urlErr) {
            console.error(`Error parsing/deleting agenda_url for meeting ${meeting_id}:`, urlErr);
          }
        }
      }
    } catch (storage_error) {
      console.error(`Error deleting agenda file(s) for meeting ${meeting_id}:`, storage_error);
    }

    // users/{id}/meetings/{id} may have polls, evals, and other nested data — delete recursively
    try {
      await db.recursiveDelete(user_meeting_ref);
    } catch (recursive_error) {
      console.error(
        `Error recursive-deleting user meeting ${meeting_id} for ${creator_id}:`,
        recursive_error,
      );
      return { success: false, error: 'Failed to delete meeting data' };
    }

    if (active_meeting_doc.exists) {
      await active_meeting_ref.delete();
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

