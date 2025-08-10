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
    
    // Use a transaction to update both collections atomically
    await db.runTransaction(async (transaction) => {
      // Update the active meetings collection
      const activeMeetingRef = db.collection('activeMeetings').doc(data.meetingId);
      const activeMeetingDoc = await transaction.get(activeMeetingRef);
      
      if (activeMeetingDoc.exists) {
        transaction.update(activeMeetingRef, {
          agenda_url: publicUrl
        });
        
        // Update the meetings subcollection (for user's meetings)
        const creatorId = activeMeetingDoc.data().creatorId;
        if (creatorId) {
          const userMeetingRef = db.collection('users').doc(creatorId).collection('meetings').doc(data.meetingId);
          const userMeetingDoc = await transaction.get(userMeetingRef);
          
          if (userMeetingDoc.exists) {
            transaction.update(userMeetingRef, {
              agenda_url: publicUrl
            });
          }
        }
      }
    });


    
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


