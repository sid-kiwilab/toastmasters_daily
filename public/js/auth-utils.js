/**
 * Shared Firebase Authentication Utilities
 * Provides reusable functions for Firebase auth across pages
 */

// Initialize Firebase Auth instances
function initFirebaseAuth() {
  let memberAuth = null;
  let clubAuth = null;

  // Initialize member Firebase app
  try {
    const memberApp = firebase.initializeApp(FirebaseConfigs.member, 'member');
    memberAuth = firebase.auth(memberApp);
  } catch (e) {
    if (e.code === 'app/duplicate-app') {
      memberAuth = firebase.auth(firebase.app('member'));
    } else {
      console.warn('Member Firebase initialization error:', e);
    }
  }

  // Initialize club Firebase app
  try {
    const clubApp = firebase.initializeApp(FirebaseConfigs.club, 'club');
    clubAuth = firebase.auth(clubApp);
  } catch (e) {
    if (e.code === 'app/duplicate-app') {
      clubAuth = firebase.auth(firebase.app('club'));
    } else {
      console.warn('Club Firebase initialization error:', e);
    }
  }

  return { memberAuth, clubAuth };
}

// Initialize only member auth (for member-specific pages)
function initMemberAuth() {
  let memberAuth = null;
  try {
    const memberApp = firebase.initializeApp(FirebaseConfigs.member, 'member');
    memberAuth = firebase.auth(memberApp);
  } catch (e) {
    if (e.code === 'app/duplicate-app') {
      memberAuth = firebase.auth(firebase.app('member'));
    } else {
      console.warn('Member Firebase initialization error:', e);
    }
  }
  return memberAuth;
}

// Initialize only club auth (for club-specific pages)
function initClubAuth() {
  let clubAuth = null;
  try {
    const clubApp = firebase.initializeApp(FirebaseConfigs.club, 'club');
    clubAuth = firebase.auth(clubApp);
  } catch (e) {
    if (e.code === 'app/duplicate-app') {
      clubAuth = firebase.auth(firebase.app('club'));
    } else {
      console.warn('Club Firebase initialization error:', e);
    }
  }
  return clubAuth;
}

// Get formatted error message for Firebase auth errors (uses notifications.js if available)
function getAuthErrorMessage(error) {
  if (typeof getUserFriendlyErrorMessage !== 'undefined') {
    return getUserFriendlyErrorMessage(error);
  }
  
  // Fallback if notifications.js not loaded
  const errorMessages = {
    'auth/invalid-credential': 'Invalid email or password. Please check your credentials.',
    'auth/popup-closed-by-user': 'Sign-in was cancelled.',
    'auth/popup-blocked': 'Popup was blocked. Please allow popups and try again.',
    'auth/network-request-failed': 'Network error. Please check your connection and try again.',
    'auth/account-exists-with-different-credential': 'An account already exists with this email. Please use a different sign-in method.',
    'auth/email-already-in-use': 'This email is already registered.',
    'auth/weak-password': 'Password is too weak. Please use at least 6 characters.',
    'auth/invalid-email': 'Invalid email address.',
    'auth/user-not-found': 'No account found with this email.',
    'auth/wrong-password': 'Incorrect password.',
  };

  return errorMessages[error.code] || error.message || 'An error occurred. Please try again.';
}

// Create Google Auth Provider with scopes
function createGoogleProvider() {
  const provider = new firebase.auth.GoogleAuthProvider();
  provider.addScope('profile');
  provider.addScope('email');
  // Force account selection prompt (don't auto-select)
  provider.setCustomParameters({
    prompt: 'select_account'
  });
  return provider;
}

// Handle logout for member auth
async function logoutMember(memberAuth, redirectPath = '/') {
  try {
    if (memberAuth) {
      await memberAuth.signOut();
    }
    localStorage.removeItem('authToken');
    sessionStorage.removeItem('authToken');
    window.location.href = redirectPath;
  } catch (error) {
    console.error('Logout error:', error);
    window.location.href = redirectPath;
  }
}

// Handle logout for club auth
async function logoutClub(clubAuth, redirectPath = '/') {
  try {
    if (clubAuth) {
      await clubAuth.signOut();
    }
    localStorage.removeItem('authToken');
    sessionStorage.removeItem('authToken');
    window.location.href = redirectPath;
  } catch (error) {
    console.error('Logout error:', error);
    window.location.href = redirectPath;
  }
}

// Handle logout for both member and club auth
async function logoutAll(memberAuth, clubAuth, redirectPath = '/') {
  const promises = [];
  if (memberAuth) {
    promises.push(memberAuth.signOut().catch(err => console.warn('Member logout error:', err)));
  }
  if (clubAuth) {
    promises.push(clubAuth.signOut().catch(err => console.warn('Club logout error:', err)));
  }
  
  await Promise.all(promises);
  localStorage.removeItem('authToken');
  sessionStorage.removeItem('authToken');
  window.location.href = redirectPath;
}

