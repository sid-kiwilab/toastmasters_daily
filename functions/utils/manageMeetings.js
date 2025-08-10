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
      creatorId: data.creatorId,
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

/**
 * Cleans up old meetings that are older than 1 week
 * Runs every 24 hours via Cloud Functions scheduled trigger
 * Handles large-scale cleanup safely with pagination and batch limits
 */
exports.cleanUpMeetings = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  try {
    const db = admin.firestore();
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    
    console.error('Starting cleanup of meetings older than:', oneWeekAgo.toISOString());
    
    let totalDeletedCount = 0;
    let batchCount = 0;
    let lastDoc = null;
    const MAX_MEETINGS_PER_RUN = 10000; // Prevent infinite loops
    
    // Process meetings in batches to handle large collections safely
    while (totalDeletedCount < MAX_MEETINGS_PER_RUN) {
      let query = db.collection('active_meetings')
        .orderBy('createdAt', 'asc') // Process oldest first
        .limit(1000); // Process 1000 at a time
      
      // Add pagination if we have a last document
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }
      
      const snapshot = await query.get();
      
      if (snapshot.empty) {
        console.error('No more meetings to process');
        break;
      }
      
      const batch = db.batch();
      let batchDeletedCount = 0;
      let hasOldMeetings = false;
      
      // Process each meeting in this batch
      for (const meetingDoc of snapshot.docs) {
        const meetingData = meetingDoc.data();
        const createdAt = meetingData.createdAt;
        
        // Check if meeting is older than 1 week
        if (createdAt && createdAt.toDate() < oneWeekAgo) {
          const meetingId = meetingDoc.id;
          const creatorId = meetingData.creatorId;
          
          // Delete from active_meetings collection
          batch.delete(meetingDoc.ref);
          
          // Delete from user's meetings subcollection if creatorId exists
          if (creatorId) {
            const userMeetingRef = db
              .collection('users')
              .doc(creatorId)
              .collection('meetings')
              .doc(meetingId);
            batch.delete(userMeetingRef);
          }
          
          batchDeletedCount++;
          hasOldMeetings = true;
          
          // Log every 100 deletions to avoid spam
          if (batchDeletedCount % 100 === 0) {
            console.error(`Marked ${batchDeletedCount} meetings for deletion in current batch`);
          }
        }
        
        // Update lastDoc for pagination
        lastDoc = meetingDoc;
      }
      
      // Commit this batch if we have deletions
      if (batchDeletedCount > 0) {
        try {
          await batch.commit();
          totalDeletedCount += batchDeletedCount;
          batchCount++;
          console.error(`Batch ${batchCount}: Successfully deleted ${batchDeletedCount} old meetings. Total: ${totalDeletedCount}`);
        } catch (batchError) {
          console.error(`Batch ${batchCount} failed:`, batchError);
          // Continue with next batch instead of failing completely
        }
      }
      
      // If no old meetings found in this batch, we're done
      if (!hasOldMeetings) {
        console.error('No more old meetings found, cleanup complete');
        break;
      }
      
      // Safety check: if we processed less than the limit, we're at the end
      if (snapshot.docs.length < 1000) {
        console.error('Reached end of collection, cleanup complete');
        break;
      }
    }
    
    console.error(`Cleanup completed. Total batches: ${batchCount}, Total meetings deleted: ${totalDeletedCount}`);
    
    if (totalDeletedCount >= MAX_MEETINGS_PER_RUN) {
      console.error('Warning: Reached maximum meetings per run limit. More meetings may need cleanup in next run.');
    }
    
    return { 
      success: true, 
      deletedCount: totalDeletedCount,
      batchCount: batchCount
    };
    
  } catch (error) {
    console.error('Error during meeting cleanup:', error);
    return { success: false, error: error.message };
  }
});
