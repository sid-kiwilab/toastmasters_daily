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
        club_code: parseInt(existingClubCode, 10),
      }, { merge: true });
      console.log(`Synced existing club code ${existingClubCode} to user document for user ${user.uid}`);
      return;
    }
    
    // Generate unique 8-digit club code
    let clubCode;
    let attempts = 0;
    const maxAttempts = 20; // Increased for extra safety (probability of failure: ~10^-80 even with 1M codes)
    
    do {
      clubCode = Math.floor(10000000 + Math.random() * 90000000).toString();
      
      // Check if code exists as document ID in club_codes collection
      const existingClubCodeDoc = await db.collection('club_codes').doc(clubCode).get();
      
      // Also check if any user already has this club_code value (as number)
      const existingUserWithCode = await db.collection('users')
        .where('club_code', '==', parseInt(clubCode, 10))
        .limit(1)
        .get();
      
      if (!existingClubCodeDoc.exists && existingUserWithCode.empty) {
        break; // Code is available
      }
      
      attempts++;
      if (attempts >= maxAttempts) {
        console.error('Failed to generate unique club code after', maxAttempts, 'attempts');
        throw new Error('Failed to generate unique club code');
      }
    } while (attempts < maxAttempts);
    
    // Use transaction to ensure atomicity - ALL READS FIRST, THEN ALL WRITES
    await db.runTransaction(async (transaction) => {
      // Read new club_code document to verify it doesn't exist
      const clubCodeRef = db.collection('club_codes').doc(clubCode);
      const clubCodeDoc = await transaction.get(clubCodeRef);
      
      if (clubCodeDoc.exists) {
        throw new Error('Club code collision detected during transaction');
      }
      
      // Read user document to check if it already exists
      const userDocSnap = await transaction.get(userDocRef);
      
      // NOW DO ALL WRITES (after all reads)
      // Create club_codes document with the generated 8-digit code
      transaction.set(clubCodeRef, { uid: user.uid });
      
      // Create user document with club_code as number and created_at
      transaction.set(userDocRef, {
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        club_code: parseInt(clubCode, 10), // Store as number, not string
      });
    });
    
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
