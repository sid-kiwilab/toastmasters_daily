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

    console.log(`User document created for UID: ${user.uid}`);
  } catch (error) {
    console.error('Error creating user document:', error);
  }
});

// Cloud Function that triggers when a user is deleted
exports.deleteUserDocument = functions.auth.user().onDelete(async (user) => {
  try {
    // Delete the user document from Firestore
    await admin.firestore()
      .collection('users')
      .doc(user.uid)
      .delete();

    console.log(`User document deleted for UID: ${user.uid}`);
  } catch (error) {
    console.error('Error deleting user document:', error);
  }
});
