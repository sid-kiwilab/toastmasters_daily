/**
 * Base page functionality
 * Auth gate and logout functionality
 */

// Wait for Firebase Auth to be ready, then check authentication
async function checkAuthAndSetup() {
  try {
    // Initialize Firebase Auth
    await initializeFirebaseAuth();
    
    const auth = firebase.auth();
    
    // Use onAuthStateChanged to wait for auth state to be determined
    // This is more reliable than checking currentUser immediately
    let initialCheckDone = false;
    
    const unsubscribe = auth.onAuthStateChanged((user) => {
      if (!initialCheckDone) {
        // First check - initial auth state
        initialCheckDone = true;
        
        if (!user) {
          // Not authenticated, redirect to home
          unsubscribe();
          window.location.href = '/';
          return;
        }
        
        // User is authenticated, set up logout button
        setupLogoutButton();
      } else {
        // Subsequent changes (e.g., logout)
        if (!user) {
          // User logged out, redirect to home
          unsubscribe();
          window.location.href = '/';
        }
      }
    });
    
    // Timeout after 3 seconds - if auth state hasn't been determined, assume not authenticated
    setTimeout(() => {
      if (!initialCheckDone) {
        initialCheckDone = true;
        unsubscribe();
        console.error('Auth state check timeout - redirecting to home');
        window.location.href = '/';
      }
    }, 3000);
  } catch (error) {
    console.error('Error checking auth:', error);
    // On error, redirect to home for safety
    window.location.href = '/';
  }
}

// Setup logout button
function setupLogoutButton() {
  const logoutButton = document.getElementById('logoutButton');
  
  if (logoutButton) {
    logoutButton.addEventListener('click', async function() {
      try {
        if (typeof firebase !== 'undefined' && firebase.auth) {
          const auth = firebase.auth();
          await auth.signOut();
          showNotification('Logged out successfully', 'success');
          // Redirect will happen via auth state change listener
        }
      } catch (error) {
        console.error('Error logging out:', error);
        showNotification('Error logging out. Please try again.', 'error');
      }
    });
  }
}

// Start auth check when script loads
if (typeof initializeFirebaseAuth !== 'undefined') {
  checkAuthAndSetup();
} else {
  // Wait for auth.js to load
  let attempts = 0;
  const checkInterval = setInterval(() => {
    attempts++;
    if (typeof initializeFirebaseAuth !== 'undefined') {
      clearInterval(checkInterval);
      checkAuthAndSetup();
    } else if (attempts >= 50) {
      // After 500ms, give up and redirect
      clearInterval(checkInterval);
      console.error('initializeFirebaseAuth not available - redirecting to home');
      window.location.href = '/';
    }
  }, 10);
}

