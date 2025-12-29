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
    
    // Create file path: agendas/{meetingId}.pdf
    const filePath = `agendas/${data.meetingId}.pdf`;
    
    // Convert base64 to buffer
    const fileBuffer = Buffer.from(data.fileData, 'base64');
    
    // Upload file to Firebase Storage
    const file = bucket.file(filePath);
    
    // Check if file already exists
    const [exists] = await file.exists();
    
    await file.save(fileBuffer, {
      metadata: {
        contentType: 'application/pdf',
        metadata: {
          meeting_id: data.meetingId,
          original_file_name: data.fileName,
          uploaded_at: new Date().toISOString()
        }
      }
    });

    // Make the file publicly readable (optional - you can adjust this)
    await file.makePublic();
    
    // Get the public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;
    
    // Store agenda reference in Firestore - only in users collection
    const db = admin.firestore();
    
    try {
      // First get creator_id from active_meetings
      const activeMeetingRef = db.collection('active_meetings').doc(data.meetingId);
      const activeMeetingDoc = await activeMeetingRef.get();
      
      if (!activeMeetingDoc.exists) {
        return { success: false, error: 'Meeting not found' };
      }
      
      const creator_id = activeMeetingDoc.data().creator_id;
      if (!creator_id) {
        return { success: false, error: 'Meeting creator not found' };
      }
      
      // Update only the user's meetings document with agenda_url
      const userMeetingRef = db.collection('club').doc(creator_id).collection('meetings').doc(data.meetingId);
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


