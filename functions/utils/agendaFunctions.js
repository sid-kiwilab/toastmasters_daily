const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * Uploads an agenda PDF to Firebase Storage
 * @param {Object} data - The request data object
 * @param {string} data.meetingId - Meeting ID for the agenda
 * @param {string} data.fileData - Base64 encoded PDF file data
 * @param {string} data.fileName - Original filename
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} Upload result with download URL
 */
exports.uploadAgenda = functions.https.onCall(async (data, context) => {
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
          meetingId: data.meetingId,
          originalFileName: data.fileName,
          uploadedAt: new Date().toISOString()
        }
      }
    });

    // Make the file publicly readable (optional - you can adjust this)
    await file.makePublic();
    
    // Get the public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;
    
    // Store agenda reference in Firestore and update meeting documents
    const db = admin.firestore();
    
    try {
      // Use a transaction to update both collections atomically
      await db.runTransaction(async (transaction) => {
        // STEP 1: ALL READS FIRST
        // Read the active meeting document
        const activeMeetingRef = db.collection('active_meetings').doc(data.meetingId);
        const activeMeetingDoc = await transaction.get(activeMeetingRef);
        
        if (!activeMeetingDoc.exists) {
          return; // Exit transaction early if document doesn't exist
        }
        
        // Read the user meeting document (if creatorId exists)
        const creatorId = activeMeetingDoc.data().creatorId;
        
        let userMeetingDoc = null;
        if (creatorId) {
          const userMeetingRef = db.collection('users').doc(creatorId).collection('meetings').doc(data.meetingId);
          userMeetingDoc = await transaction.get(userMeetingRef);
        }
        
        // STEP 2: ALL WRITES AFTER ALL READS
        // Update the active meetings collection
        transaction.update(activeMeetingRef, {
          agendaUrl: publicUrl
        });
        
        // Update the user's meetings subcollection if it exists
        if (creatorId && userMeetingDoc && userMeetingDoc.exists) {
          const userMeetingRef = db.collection('users').doc(creatorId).collection('meetings').doc(data.meetingId);
          transaction.update(userMeetingRef, {
            agendaUrl: publicUrl
          });
        }
      });
    } catch (transactionError) {
      console.error(`Transaction failed for meeting ${data.meetingId}:`, transactionError);
      return { success: false, error: 'Failed to update Firestore documents' };
    }

    return {
      success: true,
      agenda: {
        meetingId: data.meetingId,
        fileName: data.fileName,
        downloadUrl: publicUrl,
        fileSize: fileBuffer.length
      }
    };

  } catch (error) {
    console.error('Error uploading agenda:', error);
    return { 
      success: false, 
      error: 'Failed to upload agenda: ' + error.message 
    };
  }
});


