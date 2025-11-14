/**
 * Base page functionality
 * Auth gate and logout functionality
 */

import { signOut } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { getFirestore, doc, getDoc, setDoc } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";

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
        loadClubName(user.uid);
        setupLogoutButton();
        setupClubNameEdit(user.uid);
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

// Load club name from Firestore
async function loadClubName(userId) {
  try {
    const db = getFirestore(window.firebaseApp || undefined);
    const userDocRef = doc(db, 'users', userId);
    const userDocSnap = await getDoc(userDocRef);
    
    const clubNameDisplay = document.getElementById('clubNameDisplay');
    if (clubNameDisplay) {
      if (userDocSnap.exists() && userDocSnap.data().club_name) {
        clubNameDisplay.textContent = userDocSnap.data().club_name;
      } else {
        clubNameDisplay.textContent = 'Not set';
      }
    }
  } catch (error) {
    console.error('Error loading club name:', error);
  }
}

// Setup club name edit functionality
function setupClubNameEdit(userId) {
  const editButton = document.getElementById('editClubNameButton');
  const saveButton = document.getElementById('saveClubNameButton');
  const cancelButton = document.getElementById('cancelClubNameButton');
  const clubNameDisplay = document.getElementById('clubNameDisplay');
  const clubNameInput = document.getElementById('clubNameInput');
  const clubNameSpinner = document.getElementById('clubNameSpinner');
  
  if (!editButton || !saveButton || !cancelButton || !clubNameDisplay || !clubNameInput || !clubNameSpinner) {
    return;
  }
  
  let originalValue = '';
  let isSaving = false;
  
  function enterEditMode() {
    originalValue = clubNameDisplay.textContent === 'Not set' ? '' : clubNameDisplay.textContent;
    clubNameInput.value = originalValue;
    clubNameDisplay.style.display = 'none';
    clubNameInput.style.display = 'block';
    editButton.style.display = 'none';
    saveButton.style.display = 'flex';
    cancelButton.style.display = 'flex';
    clubNameSpinner.style.display = 'none';
    clubNameInput.focus();
    clubNameInput.select();
  }
  
  function exitEditMode() {
    clubNameDisplay.style.display = '';
    clubNameInput.style.display = 'none';
    editButton.style.display = 'flex';
    saveButton.style.display = 'none';
    cancelButton.style.display = 'none';
    clubNameSpinner.style.display = 'none';
    clubNameInput.value = '';
    isSaving = false;
  }
  
  editButton.addEventListener('click', function() {
    if (!isSaving) {
      enterEditMode();
    }
  });
  
  cancelButton.addEventListener('click', function() {
    if (!isSaving) {
      exitEditMode();
    }
  });
  
  saveButton.addEventListener('click', async function() {
    if (isSaving) return;
    
    const newValue = clubNameInput.value.trim();
    
    // Show spinner and disable buttons
    isSaving = true;
    saveButton.style.display = 'none';
    cancelButton.style.display = 'none';
    clubNameSpinner.style.display = 'block';
    clubNameInput.disabled = true;
    
    try {
      const db = getFirestore(window.firebaseApp || undefined);
      const userDocRef = doc(db, 'users', userId);
      
      if (newValue) {
        await setDoc(userDocRef, { club_name: newValue }, { merge: true });
        clubNameDisplay.textContent = newValue;
        showNotification('Club name saved successfully', 'success');
      } else {
        await setDoc(userDocRef, { club_name: '' }, { merge: true });
        clubNameDisplay.textContent = 'Not set';
        showNotification('Club name cleared', 'success');
      }
      
      exitEditMode();
    } catch (error) {
      console.error('Error saving club name:', error);
      showNotification('Error saving club name. Please try again.', 'error');
      // Re-enable editing on error
      isSaving = false;
      saveButton.style.display = 'flex';
      cancelButton.style.display = 'flex';
      clubNameSpinner.style.display = 'none';
      clubNameInput.disabled = false;
    }
  });
  
  // Allow Enter key to save
  clubNameInput.addEventListener('keydown', function(e) {
    if (isSaving) return;
    
    if (e.key === 'Enter') {
      e.preventDefault();
      saveButton.click();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      cancelButton.click();
    }
  });
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

