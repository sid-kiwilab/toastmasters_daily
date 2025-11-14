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
exports.createMeeting = functions.https.onCall(async (data, context) => {
  try {
    const db = admin.firestore();
    
    // Validate required fields
    if (!data.title || !data.creator_id) {
      console.error('Missing required fields: title and creator_id are required');
      return { success: false, error: 'Missing required fields' };
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
    
    let total_deleted_count = 0;
    let batch_count = 0;
    let last_doc = null;
    const MAX_MEETINGS_PER_RUN = 10000; // Prevent infinite loops
    
    // Process meetings in batches to handle large collections safely
    while (total_deleted_count < MAX_MEETINGS_PER_RUN) {
      let query = db.collection('active_meetings')
        .orderBy('created_at', 'asc') // Process oldest first
        .limit(1000); // Process 1000 at a time
      
      // Add pagination if we have a last document
      if (last_doc) {
        query = query.startAfter(last_doc);
      }
      
      const snapshot = await query.get();
      
      if (snapshot.empty) {
        console.error('No more meetings to process');
        break;
      }
      
      const batch = db.batch();
      let batch_deleted_count = 0;
      let has_old_meetings = false;
      
      // Process each meeting in this batch
      for (const meeting_doc of snapshot.docs) {
        const meeting_data = meeting_doc.data();
        const created_at = meeting_data.created_at;
        
        // Check if meeting is older than 1 week
        if (created_at && created_at.toDate() < oneWeekAgo) {
          const meeting_id = meeting_doc.id;
          const creator_id = meeting_data.creator_id;
          
          // Delete from active_meetings collection
          batch.delete(meeting_doc.ref);
          
          // Delete from user's meetings subcollection if creator_id exists
          if (creator_id) {
            const user_meeting_ref = db
              .collection('users')
              .doc(creator_id)
              .collection('meetings')
              .doc(meeting_id);
            batch.delete(user_meeting_ref);
          }
          
          // Delete agenda file from Firebase Storage if it exists
          try {
            const bucket = admin.storage().bucket();
            const agenda_file_path = `agendas/${meeting_id}.pdf`;
            const agenda_file = bucket.file(agenda_file_path);
            
            // Check if file exists before attempting to delete
            const [exists] = await agenda_file.exists();
            if (exists) {
              await agenda_file.delete();
              console.error(`Deleted agenda file: ${agenda_file_path}`);
            }
          } catch (storage_error) {
            console.error(`Error deleting agenda file for meeting ${meeting_id}:`, storage_error);
            // Continue with cleanup even if storage deletion fails
          }
          
          batch_deleted_count++;
          has_old_meetings = true;
          
          // Log every 100 deletions to avoid spam
          if (batch_deleted_count % 100 === 0) {
            console.error(`Marked ${batch_deleted_count} meetings for deletion in current batch`);
          }
        }
        
        // Update last_doc for pagination
        last_doc = meeting_doc;
      }
      
      // Commit this batch if we have deletions
      if (batch_deleted_count > 0) {
        try {
          await batch.commit();
          total_deleted_count += batch_deleted_count;
          batch_count++;
          console.error(`Batch ${batch_count}: Successfully deleted ${batch_deleted_count} old meetings. Total: ${total_deleted_count}`);
        } catch (batch_error) {
          console.error(`Batch ${batch_count} failed:`, batch_error);
          // Continue with next batch instead of failing completely
        }
      }
      
      // If no old meetings found in this batch, we're done
      if (!has_old_meetings) {
        console.error('No more old meetings found, cleanup complete');
        break;
      }
      
      // Safety check: if we processed less than the limit, we're at the end
      if (snapshot.docs.length < 1000) {
        console.error('Reached end of collection, cleanup complete');
        break;
      }
    }
    
    console.error(`Cleanup completed. Total batches: ${batch_count}, Total meetings deleted: ${total_deleted_count}`);
    
    if (total_deleted_count >= MAX_MEETINGS_PER_RUN) {
      console.error('Warning: Reached maximum meetings per run limit. More meetings may need cleanup in next run.');
    }
    
    return { 
      success: true, 
      deleted_count: total_deleted_count,
      batch_count: batch_count
    };
    
  } catch (error) {
    console.error('Error during meeting cleanup:', error);
    return { success: false, error: error.message };
  }
});
