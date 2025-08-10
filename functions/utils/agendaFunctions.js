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
    
    console.log(`Starting file upload for meeting ${data.meetingId}`);
    console.log(`File path: ${filePath}`);
    console.log(`File size: ${fileBuffer.length} bytes`);
    
    // Upload file to Firebase Storage
    const file = bucket.file(filePath);
    
    // Check if file already exists
    const [exists] = await file.exists();
    if (exists) {
      console.log(`File already exists at ${filePath}, will overwrite`);
    } else {
      console.log(`File does not exist at ${filePath}, creating new file`);
    }
    
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
    
    console.log(`File uploaded successfully to ${filePath}`);

    // Make the file publicly readable (optional - you can adjust this)
    await file.makePublic();
    console.log(`File made public`);
    
    // Get the public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;
    console.log(`Public URL generated: ${publicUrl}`);
    
    // Store agenda reference in Firestore and update meeting documents
    const db = admin.firestore();
    
    console.log(`Starting Firestore update for meeting ${data.meetingId}`);
    console.log(`Public URL: ${publicUrl}`);
    
    try {
      // Use a transaction to update both collections atomically
      await db.runTransaction(async (transaction) => {
        console.log(`Transaction started for meeting ${data.meetingId}`);
        
        // STEP 1: ALL READS FIRST
        // Read the active meeting document
        const activeMeetingRef = db.collection('active_meetings').doc(data.meetingId);
        const activeMeetingDoc = await transaction.get(activeMeetingRef);
        
        if (!activeMeetingDoc.exists) {
          console.log(`Active meeting document does NOT exist for ${data.meetingId}`);
          console.log(`Available collections:`, await db.listCollections());
          return; // Exit transaction early if document doesn't exist
        }
        
        console.log(`Active meeting document exists for ${data.meetingId}`);
        console.log(`Current data:`, activeMeetingDoc.data());
        
        // Read the user meeting document (if creatorId exists)
        const creatorId = activeMeetingDoc.data().creatorId;
        console.log(`Creator ID from active meeting: ${creatorId}`);
        
        let userMeetingDoc = null;
        if (creatorId) {
          const userMeetingRef = db.collection('users').doc(creatorId).collection('meetings').doc(data.meetingId);
          userMeetingDoc = await transaction.get(userMeetingRef);
          
          if (userMeetingDoc.exists) {
            console.log(`User meeting document exists for users/${creatorId}/meetings/${data.meetingId}`);
            console.log(`Current user meeting data:`, userMeetingDoc.data());
          } else {
            console.log(`User meeting document does NOT exist for users/${creatorId}/meetings/${data.meetingId}`);
          }
        } else {
          console.log(`No creatorId found in active meeting document`);
        }
        
        // STEP 2: ALL WRITES AFTER ALL READS
        // Update the active meetings collection
        transaction.update(activeMeetingRef, {
          agenda_url: publicUrl,
          agenda_updated_at: new Date().toISOString()
        });
        console.log(`Scheduled update for active_meetings/${data.meetingId} with agenda_url: ${publicUrl}`);
        
        // Update the user's meetings subcollection if it exists
        if (creatorId && userMeetingDoc && userMeetingDoc.exists) {
          const userMeetingRef = db.collection('users').doc(creatorId).collection('meetings').doc(data.meetingId);
          transaction.update(userMeetingRef, {
            agenda_url: publicUrl,
            agenda_updated_at: new Date().toISOString()
          });
          console.log(`Scheduled update for users/${creatorId}/meetings/${data.meetingId} with agenda_url: ${publicUrl}`);
        }
      });
      
      console.log(`Transaction completed for meeting ${data.meetingId}`);
    } catch (transactionError) {
      console.error(`Transaction failed for meeting ${data.meetingId}:`, transactionError);
      throw new Error(`Failed to update Firestore documents: ${transactionError.message}`);
    }
    
    // Verify the updates were made
    try {
      const activeMeetingRef = db.collection('active_meetings').doc(data.meetingId);
      const activeMeetingDoc = await activeMeetingRef.get();
      
      if (activeMeetingDoc.exists) {
        const data = activeMeetingDoc.data();
        console.log(`Verification - active_meetings/${data.meetingId} now has:`, data);
      }
    } catch (verifyError) {
      console.log(`Error during verification:`, verifyError);
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


