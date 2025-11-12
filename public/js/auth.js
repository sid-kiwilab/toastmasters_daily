/**
 * Authentication functionality
 * Handles login, signup, reset password, and Firebase Auth initialization
 */

let firebaseAuthLoaded = false;

// Load Firebase Auth SDK
function loadFirebaseAuth() {
  return new Promise((resolve, reject) => {
    if (firebaseAuthLoaded || (typeof firebase !== 'undefined' && firebase.auth)) {
      firebaseAuthLoaded = true;
      resolve();
      return;
    }
    
    if (typeof firebase === 'undefined') {
      const appScript = document.createElement('script');
      appScript.src = 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js';
      appScript.onload = () => {
        const authScript = document.createElement('script');
        authScript.src = 'https://www.gstatic.com/firebasejs/10.7.1/firebase-auth-compat.js';
        authScript.onload = () => {
          firebaseAuthLoaded = true;
          resolve();
        };
        authScript.onerror = reject;
        document.head.appendChild(authScript);
      };
      appScript.onerror = reject;
      document.head.appendChild(appScript);
    } else {
      const authScript = document.createElement('script');
      authScript.src = 'https://www.gstatic.com/firebasejs/10.7.1/firebase-auth-compat.js';
      authScript.onload = () => {
        firebaseAuthLoaded = true;
        resolve();
      };
      authScript.onerror = reject;
      document.head.appendChild(authScript);
    }
  });
}

// Initialize Firebase with Auth
async function initializeFirebaseAuth() {
  let attempts = 0;
  while (typeof firebase === 'undefined' && attempts < 10) {
    await new Promise(resolve => setTimeout(resolve, 100));
    attempts++;
  }
  
  if (typeof firebase === 'undefined') {
    await new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js';
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }
  
  await loadFirebaseAuth();
  
  if (!firebase.apps || !firebase.apps.length) {
    if (typeof firebaseConfig !== 'undefined') {
      firebase.initializeApp(firebaseConfig);
    } else {
      throw new Error('Firebase config not found');
    }
  }
  
  if (!firebase.auth) {
    throw new Error('Firebase Auth SDK failed to load');
  }
}

// Get Firebase Auth error message
function getAuthErrorMessage(errorCode) {
  const errorMessages = {
    'auth/user-not-found': 'No account found with this email.',
    'auth/wrong-password': 'Incorrect password.',
    'auth/invalid-email': 'Invalid email address.',
    'auth/user-disabled': 'This account has been disabled.',
    'auth/too-many-requests': 'Too many failed attempts. Please try again later.',
    'auth/network-request-failed': 'Network error. Please check your connection.',
    'auth/invalid-credential': 'Invalid email or password.',
    'auth/email-already-in-use': 'This email is already registered.',
    'auth/weak-password': 'Password should be at least 6 characters.',
    'auth/invalid-credential': 'Invalid email or password.',
  };
  
  return errorMessages[errorCode] || 'An error occurred. Please try again.';
}

// Handle login
async function handleLogin(email, password) {
  try {
    await initializeFirebaseAuth();
    
    const auth = firebase.auth();
    const userCredential = await auth.signInWithEmailAndPassword(email, password);
    
    if (userCredential.user) {
      showNotification('Login successful!', 'success');
      
      // Close overlay and redirect after a short delay
      setTimeout(() => {
        const loginOverlay = document.getElementById('loginOverlay');
        if (loginOverlay) {
          loginOverlay.classList.remove('show');
        }
        // Redirect to home (which will check auth and redirect to my-meetings if needed)
        window.location.href = '/';
      }, 1000);
      
      return true;
    }
    return false;
  } catch (error) {
    console.error('Login error:', error);
    let errorMessage = 'Login failed. Please try again.';
    if (error.code) {
      errorMessage = getAuthErrorMessage(error.code);
    }
    showNotification(errorMessage, 'error');
    return false;
  }
}

// Handle sign up
async function handleSignUp(email, password) {
  try {
    await initializeFirebaseAuth();
    
    const auth = firebase.auth();
    const userCredential = await auth.createUserWithEmailAndPassword(email, password);
    
    if (userCredential.user) {
      // Send verification email
      await userCredential.user.sendEmailVerification();
      
      showNotification('Account created successfully! Please check your email to verify your account.', 'success');
      
      // Close overlay after a short delay
      setTimeout(() => {
        const loginOverlay = document.getElementById('loginOverlay');
        if (loginOverlay) {
          loginOverlay.classList.remove('show');
        }
        window.location.href = '/';
      }, 2000);
      
      return true;
    }
    return false;
  } catch (error) {
    console.error('Signup error:', error);
    let errorMessage = 'Sign up failed. Please try again.';
    if (error.code) {
      errorMessage = getAuthErrorMessage(error.code);
    }
    showNotification(errorMessage, 'error');
    return false;
  }
}

// Handle reset password
async function handleResetPassword(email) {
  try {
    await initializeFirebaseAuth();
    
    const auth = firebase.auth();
    await auth.sendPasswordResetEmail(email);
    
    showNotification('Password reset email sent! Please check your inbox.', 'success');
    
    // Don't close overlay - user can stay on this screen or manually close
    return true;
  } catch (error) {
    console.error('Reset password error:', error);
    let errorMessage = 'Failed to send reset email. Please try again.';
    if (error.code) {
      errorMessage = getAuthErrorMessage(error.code);
    }
    showNotification(errorMessage, 'error');
    return false;
  }
}

