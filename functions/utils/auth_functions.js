const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Cloud Function that triggers when a user is created
exports.create_user_document = functions.auth.user().onCreate(async (user) => {
  try {
    const db = admin.firestore();
    const userDocRef = db.collection('users').doc(user.uid);
    
    // Check if user document already exists (idempotency check)
    const userDocSnap = await userDocRef.get();
    if (userDocSnap.exists && userDocSnap.data()?.club_code) {
      console.log(`User document and club code already exist for user ${user.uid}, skipping creation.`);
      return;
    }
    
    // Check if club code already exists for this user
    const existingClubCodesQuery = await db.collection('club_codes')
      .where('uid', '==', user.uid)
      .limit(1)
      .get();
    
    if (!existingClubCodesQuery.empty) {
      // Club code already exists, just sync it to user document
      const existingClubCode = existingClubCodesQuery.docs[0].id;
      await userDocRef.set({
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        club_code: existingClubCode,
      }, { merge: true });
      console.log(`Synced existing club code ${existingClubCode} to user document for user ${user.uid}`);
      return;
    }
    
    // Create a new club code document
    const clubCodeRef = db.collection('club_codes').doc();
    const clubCode = clubCodeRef.id;
    
    // Use batch write to ensure both operations happen atomically
    const batch = db.batch();
    
    // Create club_codes document
    batch.set(clubCodeRef, { uid: user.uid });
    
    // Create user document with club_code and created_at
    batch.set(userDocRef, {
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      club_code: clubCode,
    });
    
    // Commit the batch - both operations succeed or both fail
    await batch.commit();
    
    console.log(`Created user document and club code ${clubCode} for user ${user.uid}`);
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
    
    // Delete club code if it exists
    if (userDocSnap.exists) {
      const userData = userDocSnap.data();
      const clubCode = userData?.club_code;
      
      if (clubCode) {
        try {
          const clubCodeRef = db.collection('club_codes').doc(clubCode);
          await clubCodeRef.delete();
          console.log(`Deleted club code ${clubCode} for user ${user.uid}`);
        } catch (clubCodeError) {
          console.error(`Error deleting club code ${clubCode} for user ${user.uid}:`, clubCodeError);
          // Continue with user deletion even if club code deletion fails
        }
      }
    }
    
    // Delete all subcollections first
    const collections = await userRef.listCollections();
    
    for (const collection of collections) {
      // Get all documents in the subcollection
      const snapshot = await collection.get();
      
      // Delete each document in the subcollection
      const deletePromises = snapshot.docs.map(doc => doc.ref.delete());
      await Promise.all(deletePromises);
    }
    
    // Delete the user document itself
    await userRef.delete();
    
    console.log(`Successfully deleted user document and all associated data for user ${user.uid}`);
  } catch (error) {
    console.error('Error deleting user document and subcollections:', error);
  }
});
