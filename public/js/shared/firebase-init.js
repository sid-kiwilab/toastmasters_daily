/**
 * Firebase Initialization
 */

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
import { getAnalytics } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-analytics.js";
import { getAuth, onAuthStateChanged } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { getFirestore, collection, doc, getDoc } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";

// Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyAS_vt-VGqpC4jl-q2K792sVYP_rrlvMFA",
  authDomain: "toastmasters-daily.firebaseapp.com",
  projectId: "toastmasters-daily",
  storageBucket: "toastmasters-daily.firebasestorage.app",
  messagingSenderId: "864717492615",
  appId: "1:864717492615:web:155d3af4fb98a3fdab8322",
  measurementId: "G-HKP7YE09GD"
};

// Initialize Firebase
console.log('[Firebase] Initializing...');
const startTime = performance.now();
const app = initializeApp(firebaseConfig);
window.firebaseApp = app; // Make app available globally
const initTime = performance.now() - startTime;
console.log(`[Firebase] Initialized in ${initTime.toFixed(2)}ms`);

// Initialize Analytics
const analytics = getAnalytics(app);
console.log('[Firebase] Analytics initialized');

// Initialize Auth
const auth = getAuth(app);
console.log('[Firebase] Auth initialized');
window.auth = auth;

// Monitor auth state with timing
const authStateStartTime = performance.now();
console.log('[Auth] Starting auth state check...');

onAuthStateChanged(auth, (user) => {
  const authStateTime = performance.now() - authStateStartTime;
  console.log(`[Auth] Auth state determined in ${authStateTime.toFixed(2)}ms`);

  if (user) {
    console.log('[Auth] ✅ User is authenticated');
    console.log('[Auth] User email:', user.email);
    console.log('[Auth] User UID:', user.uid);
  } else {
    console.log('[Auth] ❌ User is not authenticated');
  }
  
  // Call updateUI if it exists
  if (window.updateUI) {
    window.updateUI(user);
  }
});

// Check if meeting exists in Firestore
export async function checkMeetingExists(meetingId) {
  try {
    const db = getFirestore(app);
    const docRef = doc(db, 'active_meetings', meetingId);
    const docSnap = await getDoc(docRef);
    return docSnap.exists();
  } catch (error) {
    console.error('Error checking meeting:', error);
    return false;
  }
}

// Also make it available on window for backwards compatibility
window.checkMeetingExists = checkMeetingExists;

