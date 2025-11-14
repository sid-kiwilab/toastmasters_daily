/**
 * Base page functionality
 * Auth gate and logout functionality
 */

import { signOut } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { getFirestore, doc, getDoc, setDoc, collection, addDoc, query, where, getDocs, runTransaction } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";

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
        loadOrGenerateClubCode(user.uid);
        setupClubCodeRegenerate(user.uid);
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

// Load or generate club code
async function loadOrGenerateClubCode(userId) {
  try {
    const db = getFirestore(window.firebaseApp || undefined);
    const userDocRef = doc(db, 'users', userId);
    const userDocSnap = await getDoc(userDocRef);
    
    const clubCodeDisplay = document.getElementById('clubCodeDisplay');
    if (!clubCodeDisplay) return;
    
    let clubCode = '';
    
    // Check if user already has a club_code stored
    if (userDocSnap.exists() && userDocSnap.data().club_code) {
      clubCode = userDocSnap.data().club_code;
    } else {
      // Check if a club_codes document already exists for this user
      const clubCodesRef = collection(db, 'club_codes');
      const q = query(clubCodesRef, where('uid', '==', userId));
      const querySnapshot = await getDocs(q);
      
      if (!querySnapshot.empty) {
        // Use existing document ID
        clubCode = querySnapshot.docs[0].id;
        // Save to user document
        await setDoc(userDocRef, { club_code: clubCode }, { merge: true });
      } else {
        // Use transaction to create club_codes document and update user document atomically
        await runTransaction(db, async (transaction) => {
          // Create new document reference in club_codes collection
          const newClubCodeRef = doc(collection(db, 'club_codes'));
          clubCode = newClubCodeRef.id;
          
          // Set both documents in the transaction
          transaction.set(newClubCodeRef, {
            uid: userId
          });
          transaction.set(userDocRef, {
            club_code: clubCode
          }, { merge: true });
        });
      }
    }
    
    clubCodeDisplay.textContent = clubCode;
    
    // Show buttons when code is loaded
    const regenerateButton = document.getElementById('regenerateClubCodeButton');
    const downloadQRButton = document.getElementById('downloadQRCodeButton');
    if (regenerateButton && clubCode) {
      regenerateButton.style.display = 'flex';
    }
    if (downloadQRButton && clubCode && typeof QRCode !== 'undefined') {
      downloadQRButton.style.display = 'flex';
    }
  } catch (error) {
    console.error('Error loading/generating club code:', error);
    const clubCodeDisplay = document.getElementById('clubCodeDisplay');
    if (clubCodeDisplay) {
      clubCodeDisplay.textContent = 'Error loading code';
    }
  }
}

// Setup club code regenerate functionality
function setupClubCodeRegenerate(userId) {
  const regenerateButton = document.getElementById('regenerateClubCodeButton');
  const downloadQRButton = document.getElementById('downloadQRCodeButton');
  const regenerateDialogOverlay = document.getElementById('regenerateCodeDialogOverlay');
  const regenerateCancelButton = document.getElementById('regenerateCodeCancelButton');
  const regenerateConfirmButton = document.getElementById('regenerateCodeConfirmButton');
  const clubCodeSpinner = document.getElementById('clubCodeSpinner');
  const clubCodeDisplay = document.getElementById('clubCodeDisplay');
  
  if (!regenerateButton || !regenerateDialogOverlay || !regenerateCancelButton || !regenerateConfirmButton || !clubCodeSpinner) {
    return;
  }
  
  let isRegenerating = false;
  
  // Download QR code
  if (downloadQRButton && clubCodeDisplay) {
    downloadQRButton.addEventListener('click', async function() {
      const code = clubCodeDisplay.textContent;
      if (!code || code === 'Loading...' || code === 'Error loading code') {
        return;
      }
      
      try {
        // Check if QRCode library is available
        if (typeof QRCode === 'undefined') {
          showNotification('QR code library not loaded. Please refresh the page.', 'error');
          return;
        }
        
        // Get club name from Firestore
        const db = getFirestore(window.firebaseApp || undefined);
        const userDocRef = doc(db, 'users', userId);
        const userDocSnap = await getDoc(userDocRef);
        let clubName = '';
        if (userDocSnap.exists() && userDocSnap.data().club_name) {
          clubName = userDocSnap.data().club_name;
        }
        
        // A4 dimensions in pixels at 150 DPI (good print quality)
        // A4: 210mm x 297mm = 8.27" x 11.69"
        const a4Width = 1240; // 210mm at 150 DPI
        const a4Height = 1754; // 297mm at 150 DPI
        
        // Create a temporary container for QR code generation
        const tempContainer = document.createElement('div');
        tempContainer.style.position = 'absolute';
        tempContainer.style.left = '-9999px';
        document.body.appendChild(tempContainer);
        
        // Generate QR code using qrcodejs library
        // Encode the base URL + club code
        const baseUrl = window.location.origin;
        const qrCodeData = `${baseUrl}/${code}`;
        const qrCodeSize = 600;
        const qrCode = new QRCode(tempContainer, {
          text: qrCodeData,
          width: qrCodeSize,
          height: qrCodeSize,
          colorDark: '#000000',
          colorLight: '#FFFFFF',
          correctLevel: QRCode.CorrectLevel.H
        });
        
        // Wait for QR code to be generated
        await new Promise((resolve) => {
          const checkQR = setInterval(() => {
            const img = tempContainer.querySelector('img');
            if (img && img.complete) {
              clearInterval(checkQR);
              resolve();
            }
          }, 50);
          // Timeout after 2 seconds
          setTimeout(() => {
            clearInterval(checkQR);
            resolve();
          }, 2000);
        });
        
        // Get the QR code image
        const qrImg = tempContainer.querySelector('img');
        if (!qrImg) {
          throw new Error('Failed to generate QR code');
        }
        
        // Create canvas for A4 sheet
        const canvas = document.createElement('canvas');
        canvas.width = a4Width;
        canvas.height = a4Height;
        const ctx = canvas.getContext('2d');
        
        // Fill white background
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(0, 0, a4Width, a4Height);
        
        // Center QR code on A4 sheet
        const qrX = (a4Width - qrCodeSize) / 2;
        const qrY = (a4Height - qrCodeSize) / 2 - 100; // Slightly above center to make room for text
        ctx.drawImage(qrImg, qrX, qrY);
        
        // Add club name below QR code
        if (clubName) {
          ctx.fillStyle = '#000000';
          ctx.font = 'bold 54px Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          const textY = qrY + qrCodeSize + 60;
          ctx.fillText(clubName, a4Width / 2, textY);
        }
        
        // Clean up temporary container
        document.body.removeChild(tempContainer);
        
        // Convert canvas to blob and download
        const fileName = clubName ? `club-code-${clubName.replace(/[^a-z0-9]/gi, '-').toLowerCase()}.png` : `club-code-${code}.png`;
        canvas.toBlob(function(blob) {
          const url = URL.createObjectURL(blob);
          const link = document.createElement('a');
          link.download = fileName;
          link.href = url;
          link.click();
          URL.revokeObjectURL(url);
          showNotification('QR code downloaded', 'success');
        }, 'image/png');
      } catch (error) {
        console.error('Error generating QR code:', error);
        showNotification('Error generating QR code. Please try again.', 'error');
      }
    });
  }
  
  // Show confirmation dialog when regenerate button is clicked
  regenerateButton.addEventListener('click', function() {
    if (isRegenerating) return;
    regenerateDialogOverlay.style.display = 'flex';
  });
  
  // Cancel button
  regenerateCancelButton.addEventListener('click', function() {
    regenerateDialogOverlay.style.display = 'none';
  });
  
  // Close dialog when clicking overlay
  regenerateDialogOverlay.addEventListener('click', function(e) {
    if (e.target === regenerateDialogOverlay) {
      regenerateDialogOverlay.style.display = 'none';
    }
  });
  
  // Confirm regeneration
  regenerateConfirmButton.addEventListener('click', async function() {
    if (isRegenerating) return;
    
    isRegenerating = true;
    regenerateDialogOverlay.style.display = 'none';
    regenerateButton.style.display = 'none';
    clubCodeSpinner.style.display = 'block';
    
    try {
      const db = getFirestore(window.firebaseApp || undefined);
      const userDocRef = doc(db, 'users', userId);
      const userDocSnap = await getDoc(userDocRef);
      
      let oldClubCode = '';
      if (userDocSnap.exists() && userDocSnap.data().club_code) {
        oldClubCode = userDocSnap.data().club_code;
      }
      
      // Use transaction to delete old code, create new code, and update user document atomically
      await runTransaction(db, async (transaction) => {
        // Delete old club_codes document if it exists
        if (oldClubCode) {
          const oldClubCodeRef = doc(db, 'club_codes', oldClubCode);
          const oldDocSnap = await transaction.get(oldClubCodeRef);
          if (oldDocSnap.exists()) {
            transaction.delete(oldClubCodeRef);
          }
        }
        
        // Create new document reference in club_codes collection
        const newClubCodeRef = doc(collection(db, 'club_codes'));
        const newClubCode = newClubCodeRef.id;
        
        // Set both documents in the transaction
        transaction.set(newClubCodeRef, {
          uid: userId
        });
        transaction.set(userDocRef, {
          club_code: newClubCode
        }, { merge: true });
      });
      
      // Reload the code
      await loadOrGenerateClubCode(userId);
      showNotification('Club code regenerated successfully', 'success');
    } catch (error) {
      console.error('Error regenerating club code:', error);
      showNotification('Error regenerating club code. Please try again.', 'error');
    } finally {
      isRegenerating = false;
      regenerateButton.style.display = 'flex';
      clubCodeSpinner.style.display = 'none';
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

