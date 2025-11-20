const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * Cron job to delete meetings older than a week
 * Runs every 24 hours
 */
exports.cleanup_old_meetings = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const db = admin.firestore();
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    const oneWeekAgoTimestamp = admin.firestore.Timestamp.fromDate(oneWeekAgo);
    
    console.log(`Starting cleanup of meetings older than ${oneWeekAgo.toISOString()}`);
    
    try {
      // Query active_meetings for meetings older than a week
      const oldMeetingsSnapshot = await db
        .collection('active_meetings')
        .where('created_at', '<', oneWeekAgoTimestamp)
        .get();
      
      if (oldMeetingsSnapshot.empty) {
        console.log('No old meetings found to delete');
        return null;
      }
      
      console.log(`Found ${oldMeetingsSnapshot.size} old meetings to delete`);
      
      // Process deletions in batches (Firestore batch limit is 500)
      const batchSize = 500;
      const meetings = oldMeetingsSnapshot.docs;
      let deletedCount = 0;
      let errorCount = 0;
      
      for (let i = 0; i < meetings.length; i += batchSize) {
        const batch = meetings.slice(i, i + batchSize);
        
        // Use a transaction for each meeting to ensure atomic deletion
        for (const meetingDoc of batch) {
          try {
            const meetingId = meetingDoc.id;
            const meetingData = meetingDoc.data();
            const creatorId = meetingData.creator_id;
            
            if (!creatorId) {
              console.warn(`Meeting ${meetingId} has no creator_id, skipping`);
              continue;
            }
            
            // Use transaction to delete from both places atomically
            await db.runTransaction(async (transaction) => {
              const activeMeetingRef = db.collection('active_meetings').doc(meetingId);
              const userMeetingRef = db
                .collection('users')
                .doc(creatorId)
                .collection('meetings')
                .doc(meetingId);
              
              // Read both documents
              const activeMeetingDoc = await transaction.get(activeMeetingRef);
              const userMeetingDoc = await transaction.get(userMeetingRef);
              
              // Delete from both collections if they exist
              if (activeMeetingDoc.exists) {
                transaction.delete(activeMeetingRef);
              }
              
              if (userMeetingDoc.exists) {
                transaction.delete(userMeetingRef);
              }
            });
            
            deletedCount++;
            console.log(`Deleted meeting ${meetingId} for creator ${creatorId}`);
            
            // Also try to delete agenda file from Storage
            try {
              const bucket = admin.storage().bucket();
              const agendaFilePath = `agendas/${meetingId}.pdf`;
              const agendaFile = bucket.file(agendaFilePath);
              
              const [exists] = await agendaFile.exists();
              if (exists) {
                await agendaFile.delete();
                console.log(`Deleted agenda file: ${agendaFilePath}`);
              }
            } catch (storageError) {
              console.error(`Error deleting agenda file for meeting ${meetingId}:`, storageError);
              // Continue even if storage deletion fails
            }
            
          } catch (error) {
            errorCount++;
            console.error(`Error deleting meeting ${meetingDoc.id}:`, error);
          }
        }
      }
      
      console.log(`Cleanup completed. Deleted: ${deletedCount}, Errors: ${errorCount}`);
      return {
        deleted: deletedCount,
        errors: errorCount,
        total: oldMeetingsSnapshot.size
      };
      
    } catch (error) {
      console.error('Error in cleanup_old_meetings cron job:', error);
      throw error;
    }
  });

