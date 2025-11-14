/**
 * Authentication functionality
 */

import { signInWithEmailAndPassword, createUserWithEmailAndPassword, sendPasswordResetEmail } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";

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
  };
  
  return errorMessages[errorCode] || 'An error occurred. Please try again.';
}

// Handle login
async function handleLogin(email, password) {
  try {
    const auth = window.auth;
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    
    if (userCredential.user) {
      return { success: true };
    }
    return { success: false, error: 'Login failed' };
  } catch (error) {
    console.error('Login error:', error);
    let errorMessage = 'Login failed. Please try again.';
    if (error.code) {
      errorMessage = getAuthErrorMessage(error.code);
    }
    return { success: false, error: errorMessage };
  }
}

// Handle sign up
async function handleSignUp(email, password) {
  try {
    const auth = window.auth;
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    
    if (userCredential.user) {
      await userCredential.user.sendEmailVerification();
      return { success: true };
    }
    return { success: false, error: 'Sign up failed' };
  } catch (error) {
    console.error('Signup error:', error);
    let errorMessage = 'Sign up failed. Please try again.';
    if (error.code) {
      errorMessage = getAuthErrorMessage(error.code);
    }
    return { success: false, error: errorMessage };
  }
}

// Handle reset password
async function handleResetPassword(email) {
  try {
    const auth = window.auth;
    await sendPasswordResetEmail(auth, email);
    return { success: true };
  } catch (error) {
    console.error('Reset password error:', error);
    let errorMessage = 'Failed to send reset email. Please try again.';
    if (error.code) {
      errorMessage = getAuthErrorMessage(error.code);
    }
    return { success: false, error: errorMessage };
  }
}

// Make functions globally available
window.handleLogin = handleLogin;
window.handleSignUp = handleSignUp;
window.handleResetPassword = handleResetPassword;

