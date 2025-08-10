const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Cloud Function that triggers when a user is created
exports.createUserDocument = functions.auth.user().onCreate(async (user) => {
  try {
    // Create a user document in Firestore with only createdAt
    const userDoc = {
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Store the user document in the 'users' collection
    await admin.firestore()
      .collection('users')
      .doc(user.uid)
      .set(userDoc);

  } catch (error) {
    console.error('Error creating user document:', error);
  }
});

// Cloud Function that triggers when a user is deleted
exports.deleteUserDocument = functions.auth.user().onDelete(async (user) => {
  try {
    const userRef = admin.firestore().collection('users').doc(user.uid);
    
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
  } catch (error) {
    console.error('Error deleting user document and subcollections:', error);
  }
});
