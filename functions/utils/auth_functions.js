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
    
    // Create user document with created_at timestamp
    await userDocRef.set({
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`Created user document for user ${user.uid}`);
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
          // Convert to string for document ID (club_code is stored as number)
          const clubCodeString = typeof clubCode === 'number' ? clubCode.toString() : clubCode;
          const clubCodeRef = db.collection('club_codes').doc(clubCodeString);
          await clubCodeRef.delete();
          console.log(`Deleted club code ${clubCodeString} for user ${user.uid}`);
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
