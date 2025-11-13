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
        
        // User is authenticated, set up page
        setupLogoutButton();
        populateUserEmail(user);
        populateAppVersion();
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
  const logoutDialogOverlay = document.getElementById('logoutDialogOverlay');
  const logoutCancelButton = document.getElementById('logoutCancelButton');
  const logoutConfirmButton = document.getElementById('logoutConfirmButton');
  
  if (logoutButton && logoutDialogOverlay) {
    // Show dialog on logout button click
    logoutButton.addEventListener('click', function() {
      logoutDialogOverlay.classList.add('show');
    });
    
    // Close dialog on cancel
    if (logoutCancelButton) {
      logoutCancelButton.addEventListener('click', function() {
        logoutDialogOverlay.classList.remove('show');
      });
    }
    
    // Close dialog on overlay click
    logoutDialogOverlay.addEventListener('click', function(e) {
      if (e.target === logoutDialogOverlay) {
        logoutDialogOverlay.classList.remove('show');
      }
    });
    
    // Close dialog on Escape key
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && logoutDialogOverlay.classList.contains('show')) {
        logoutDialogOverlay.classList.remove('show');
      }
    });
    
    // Handle logout confirmation
    if (logoutConfirmButton) {
      logoutConfirmButton.addEventListener('click', async function() {
        try {
          if (typeof firebase !== 'undefined' && firebase.auth) {
            const auth = firebase.auth();
            await auth.signOut();
            logoutDialogOverlay.classList.remove('show');
            showNotification('Logged out successfully', 'success');
            // Redirect will happen via auth state change listener
          }
        } catch (error) {
          console.error('Error logging out:', error);
          logoutDialogOverlay.classList.remove('show');
          showNotification('Error logging out. Please try again.', 'error');
        }
      });
    }
  }
}

// Populate user email
function populateUserEmail(user) {
  const userEmailElement = document.getElementById('userEmail');
  if (userEmailElement && user && user.email) {
    userEmailElement.textContent = user.email;
  }
}

// Populate app version
function populateAppVersion() {
  const appVersionElement = document.getElementById('appVersion');
  if (appVersionElement) {
    // APP_VERSION is loaded synchronously in <head>, so it should always be available
    if (typeof APP_VERSION !== 'undefined') {
      appVersionElement.textContent = APP_VERSION;
    } else {
      // This should never happen, but fallback just in case
      appVersionElement.textContent = 'Unknown';
    }
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

