/**
 * Login page functionality
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
    
    const script = document.createElement('script');
    script.src = 'https://www.gstatic.com/firebasejs/10.7.1/firebase-auth-compat.js';
    script.onload = () => {
      firebaseAuthLoaded = true;
      resolve();
    };
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

// Initialize Firebase with Auth
async function initializeFirebaseAuth() {
  await loadFirebaseAuth();
  await initializeFirebase();
  
  if (!firebase.apps || !firebase.apps.length) {
    firebase.initializeApp(firebaseConfig);
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
  };
  
  return errorMessages[errorCode] || 'An error occurred. Please try again.';
}

// Handle login form submission
async function handleLogin(event) {
  event.preventDefault();
  
  const emailInput = document.getElementById('emailInput');
  const passwordInput = document.getElementById('passwordInput');
  const loginButton = document.getElementById('loginSubmitButton');
  const loginButtonText = document.getElementById('loginButtonText');
  
  const email = emailInput.value.trim();
  const password = passwordInput.value;
  
  // Validation
  if (!email) {
    showNotification('Please enter your email', 'error');
    return;
  }
  
  if (!password) {
    showNotification('Please enter your password', 'error');
    return;
  }
  
  // Show loading state
  loginButton.disabled = true;
  loginButtonText.innerHTML = '<span class="spinner"></span>';
  
  try {
    await initializeFirebaseAuth();
    
    const auth = firebase.auth();
    const userCredential = await auth.signInWithEmailAndPassword(email, password);
    
    if (userCredential.user) {
      showNotification('Login successful!', 'success');
      
      // Redirect after a short delay
      setTimeout(() => {
        // Redirect to home or dashboard - adjust as needed
        window.location.href = '/';
      }, 1000);
    }
  } catch (error) {
    console.error('Login error:', error);
    
    let errorMessage = 'Login failed. Please try again.';
    if (error.code) {
      errorMessage = getAuthErrorMessage(error.code);
    }
    
    showNotification(errorMessage, 'error');
    
    loginButton.disabled = false;
    loginButtonText.textContent = 'Login';
  }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  const loginForm = document.getElementById('loginForm');
  if (loginForm) {
    loginForm.addEventListener('submit', handleLogin);
  }
  
  // Check if user is already logged in
  initializeFirebaseAuth().then(() => {
    const auth = firebase.auth();
    auth.onAuthStateChanged((user) => {
      if (user) {
        // User is already logged in, redirect to home
        window.location.href = '/';
      }
    });
  });
});

