const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Cloud Function that triggers when a user is created
exports.create_user_document = functions.auth.user().onCreate(async (user) => {
  try {
    const db = admin.firestore();
    const userDocRef = db.collection('users').doc(user.uid);
    
    // Check if user document already exists (idempotency check)
    const userDocSnap = await userDocRef.get();
    if (userDocSnap.exists) {
      console.log(`User document already exists for user ${user.uid}, skipping creation.`);
      return;
    }
    
    // Calculate trial end date (30 days from now)
    const trialEndDate = new Date();
    trialEndDate.setDate(trialEndDate.getDate() + 30);
    
    // Create user document with created_at timestamp and trial_end_date
    await userDocRef.set({
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      trial_end_date: admin.firestore.Timestamp.fromDate(trialEndDate),
    });
    
    console.log(`Created user document for user ${user.uid} with trial ending on ${trialEndDate.toISOString()}`);
  } catch (error) {
    console.error('Error creating user document:', error);
  }
});

// Cloud Function that triggers when a user is deleted
exports.delete_user_document = functions.auth.user().onDelete(async (user) => {
  try {
    const db = admin.firestore();
    const userRef = db.collection('users').doc(user.uid);
    
    // Get user document to find club_code
    const userDocSnap = await userRef.get();
    
    // Delete club_codes document when it belongs to this user (doc shape: { uid })
    if (userDocSnap.exists) {
      const userData = userDocSnap.data();
      const clubCode = userData?.club_code;

      if (clubCode != null && clubCode !== '') {
        try {
          const clubCodeString =
            typeof clubCode === 'number' ? clubCode.toString() : String(clubCode);
          const clubCodeRef = db.collection('club_codes').doc(clubCodeString);
          const clubCodeSnap = await clubCodeRef.get();

          if (clubCodeSnap.exists) {
            const owner = clubCodeSnap.get('uid');
            if (owner != null && owner !== user.uid) {
              console.warn(
                `Skipping club_codes/${clubCodeString} delete: owned by ${owner}, not ${user.uid}`,
              );
            } else {
              await clubCodeRef.delete();
              console.log(`Deleted club_codes/${clubCodeString} for user ${user.uid}`);
            }
          }
        } catch (clubCodeError) {
          console.error(`Error deleting club code ${clubCode} for user ${user.uid}:`, clubCodeError);
          // Continue; still remove user data below
        }
      }
    }

    // Recursively delete users/{uid}, all subcollections, and any nested subcollections
    // (e.g. meetings/*/{evals,polls,...}, guests/*, …)
    await db.recursiveDelete(userRef);

    console.log(`Successfully deleted user document and all associated data for user ${user.uid}`);
  } catch (error) {
    console.error('Error deleting user document and subcollections:', error);
  }
});
