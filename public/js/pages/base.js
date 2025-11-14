/**
 * Base page functionality
 * Auth gate and logout functionality
 */

import { signOut } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";

// Check auth and setup base page
async function checkAuthAndSetup() {
  try {
    // Wait for auth to be available
    let attempts = 0;
    while (!window.auth && attempts < 50) {
      await new Promise(resolve => setTimeout(resolve, 10));
      attempts++;
    }
    
    if (!window.auth) {
      console.error('Auth not available - redirecting to home');
      window.location.href = '/';
      return;
    }
    
    const auth = window.auth;
    
    // Use onAuthStateChanged to wait for auth state to be determined
    let initialCheckDone = false;
    
    const unsubscribe = auth.onAuthStateChanged((user) => {
      if (!initialCheckDone) {
        initialCheckDone = true;
        
        if (!user) {
          // Not authenticated, redirect to home
          unsubscribe();
          window.location.href = '/';
          return;
        }
        
        // User is authenticated, set up logout button and update user info
        updateUserInfo(user);
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

// Update user info on base page
function updateUserInfo(user) {
  const userEmailElement = document.getElementById('userEmail');
  if (userEmailElement && user && user.email) {
    userEmailElement.textContent = user.email;
  }
}

// Setup logout button
function setupLogoutButton() {
  const logoutButton = document.getElementById('logoutButton');
  const logoutDialogOverlay = document.getElementById('logoutDialogOverlay');
  const logoutCancelButton = document.getElementById('logoutCancelButton');
  const logoutConfirmButton = document.getElementById('logoutConfirmButton');
  
  if (logoutButton) {
    logoutButton.addEventListener('click', function() {
      // Show confirmation dialog
      if (logoutDialogOverlay) {
        logoutDialogOverlay.classList.add('show');
      }
    });
  }
  
  // Handle cancel button
  if (logoutCancelButton && logoutDialogOverlay) {
    logoutCancelButton.addEventListener('click', function() {
      logoutDialogOverlay.classList.remove('show');
    });
  }
  
  // Handle confirm button
  if (logoutConfirmButton && logoutDialogOverlay) {
    logoutConfirmButton.addEventListener('click', async function() {
      try {
        if (window.auth) {
          await signOut(window.auth);
          logoutDialogOverlay.classList.remove('show');
          showNotification('Logged out successfully', 'success');
          // Redirect will happen via auth state change listener
          setTimeout(() => {
            window.location.href = '/';
          }, 1000);
        }
      } catch (error) {
        console.error('Error logging out:', error);
        logoutDialogOverlay.classList.remove('show');
        showNotification('Error logging out. Please try again.', 'error');
      }
    });
  }
  
  // Close dialog when clicking outside
  if (logoutDialogOverlay) {
    logoutDialogOverlay.addEventListener('click', function(e) {
      if (e.target === logoutDialogOverlay) {
        logoutDialogOverlay.classList.remove('show');
      }
    });
  }
  
  // Close dialog on Escape key
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && logoutDialogOverlay && logoutDialogOverlay.classList.contains('show')) {
      logoutDialogOverlay.classList.remove('show');
    }
  });
}

// Start auth check when script loads
checkAuthAndSetup();

