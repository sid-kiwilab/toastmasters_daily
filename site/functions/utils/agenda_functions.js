const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { rateLimit } = require('./rate_limiter_functions');

// Rate limit configuration for agenda functions
const RATE_LIMITS = {
  upload_agenda: { max_calls: 10, window_seconds: 60 }, // 10 per minute (file uploads)
};

/**
 * Uploads an agenda PDF to Firebase Storage
 * @param {Object} data - The request data object
 * @param {string} data.meetingId - Meeting ID for the agenda
 * @param {string} data.fileData - Base64 encoded PDF file data
 * @param {string} data.fileName - Original filename
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} Upload result with download URL
 */
const upload_agenda_handler = async (data, context) => {
  try {
    // Validate required fields
    if (!data.meetingId || !data.fileData || !data.fileName) {
      console.error('Missing required fields: meetingId, fileData, and fileName are required');
      return { success: false, error: 'Missing required fields' };
    }

    // Validate file type (only PDFs allowed)
    if (!data.fileName.toLowerCase().endsWith('.pdf')) {
      console.error('Invalid file type: Only PDF files are allowed');
      return { success: false, error: 'Only PDF files are allowed' };
    }

    // Get Firebase Storage bucket
    const bucket = admin.storage().bucket();
    
    // Get creator_id first to build the file path
    const db = admin.firestore();
    const activeMeetingRef = db.collection('active_meetings').doc(data.meetingId);
    const activeMeetingDoc = await activeMeetingRef.get();
    
    if (!activeMeetingDoc.exists) {
      return { success: false, error: 'Meeting not found' };
    }
    
    const creator_id = activeMeetingDoc.data().creator_id;
    if (!creator_id) {
      return { success: false, error: 'Meeting creator not found' };
    }
    
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
      return { success: false, error: 'Uploading agendas requires an active subscription or trial' };
    }
    
    // Create unique file path with timestamp: agendas/{user_id}/{meetingId}_{timestamp}.pdf
    const timestamp = Date.now();
    const filePath = `agendas/${creator_id}/${data.meetingId}_${timestamp}.pdf`;
    
    // Convert base64 to buffer
    const fileBuffer = Buffer.from(data.fileData, 'base64');
    
    // Upload file to Firebase Storage (no need to check/delete, each upload is unique)
    const file = bucket.file(filePath);
    
    await file.save(fileBuffer, {
      metadata: {
        contentType: 'application/pdf',
        metadata: {
          meeting_id: data.meetingId,
          user_id: creator_id,
          original_file_name: data.fileName,
          uploaded_at: new Date().toISOString()
        }
      }
    });

    // Make the file publicly readable
    await file.makePublic();
    
    // Get the public URL with timestamp for cache-busting
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}?t=${timestamp}`;
    
    try {
      // Update the user's meetings document with the new agenda_url
      const userMeetingRef = db.collection('users').doc(creator_id).collection('meetings').doc(data.meetingId);
      await userMeetingRef.update({
        agenda_url: publicUrl
      });
    } catch (error) {
      console.error(`Error updating agenda URL for meeting ${data.meetingId}:`, error);
      return { success: false, error: 'Failed to update Firestore document' };
    }

    return {
      success: true,
      agenda: {
        meeting_id: data.meetingId,
        file_name: data.fileName,
        download_url: publicUrl,
        file_size: fileBuffer.length
      }
    };

  } catch (error) {
    console.error('Error uploading agenda:', error);
    return { 
      success: false, 
      error: 'Failed to upload agenda: ' + error.message 
    };
  }
};

// Wrap with rate limiting
exports.upload_agenda = functions.https.onCall(
  rateLimit(upload_agenda_handler, {
    ...RATE_LIMITS.upload_agenda,
    function_name: 'upload_agenda'
  })
);


