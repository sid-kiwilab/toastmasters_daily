/**
 * Firebase Configuration
 * Initialize Firebase and provide utility functions
 */

// Firebase configuration
const firebaseConfig = {
  apiKey: 'AIzaSyAS_vt-VGqpC4jl-q2K792sVYP_rrlvMFA',
  projectId: 'toastmasters-daily',
  authDomain: 'toastmasters-daily.firebaseapp.com',
  storageBucket: 'toastmasters-daily.firebasestorage.app',
};

// Initialize Firebase
let firebaseInitialized = false;

async function initializeFirebase() {
  if (firebaseInitialized) return;
  
  // Check if Firebase is already loaded (from auth.js)
  if (typeof firebase !== 'undefined' && firebase.apps && firebase.apps.length > 0) {
    // Firebase App is already initialized, just need to ensure Firestore is loaded
    if (!firebase.firestore) {
      await loadFirestoreSDK();
    }
    firebaseInitialized = true;
    return;
  }
  
  // Firebase not loaded yet, load it (shouldn't happen if auth.js loaded first)
  if (typeof firebase === 'undefined' || !firebase.firestore) {
    await loadFirebaseSDK();
  }
  
  if (!firebase.apps || !firebase.apps.length) {
    firebase.initializeApp(firebaseConfig);
  }
  
  firebaseInitialized = true;
}

function loadFirestoreSDK() {
  return new Promise((resolve, reject) => {
    if (typeof firebase !== 'undefined' && firebase.firestore) {
      resolve();
      return;
    }
    
    // Only load Firestore, Firebase App should already be loaded
    const firestoreScript = document.createElement('script');
    firestoreScript.src = 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore-compat.js';
    firestoreScript.onload = resolve;
    firestoreScript.onerror = reject;
    document.head.appendChild(firestoreScript);
  });
}

function loadFirebaseSDK() {
  return new Promise((resolve, reject) => {
    if (typeof firebase !== 'undefined' && firebase.firestore) {
      resolve();
      return;
    }
    
    // Only load if Firebase App is not already loaded
    if (typeof firebase === 'undefined') {
      const script = document.createElement('script');
      script.src = 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js';
      script.onload = () => {
        const firestoreScript = document.createElement('script');
        firestoreScript.src = 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore-compat.js';
        firestoreScript.onload = resolve;
        firestoreScript.onerror = reject;
        document.head.appendChild(firestoreScript);
      };
      script.onerror = reject;
      document.head.appendChild(script);
    } else {
      // Firebase App is loaded, just load Firestore
      loadFirestoreSDK().then(resolve).catch(reject);
    }
  });
}

// Check if meeting exists in Firestore
async function checkMeetingExists(meetingId) {
  try {
    await initializeFirebase();
    
    const db = firebase.firestore();
    const docRef = db.collection('active_meetings').doc(meetingId);
    const doc = await docRef.get();
    
    return doc.exists;
  } catch (error) {
    console.error('Error checking meeting:', error);
    return false;
  }
}

