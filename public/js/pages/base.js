/**
 * Base page functionality
 * Auth gate and logout functionality
 */

import { signOut } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { getFirestore, doc, getDoc, setDoc, collection, addDoc, query, where, getDocs, runTransaction, onSnapshot, orderBy } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";
import { getFunctions, httpsCallable } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-functions.js";

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
        loadClubInfo(user.uid);
        loadOrGenerateClubCode(user.uid);
        setupClubCodeRegenerate(user.uid);
        setupLogoutButton();
        setupClubNameEdit(user.uid);
        setupClubInfoDialog(user.uid);
        setupCreateMeetingDialog(user.uid);
        setupMeetingsListener(user.uid);
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

// Load club info from Firestore
async function loadClubInfo(userId) {
  try {
    const db = getFirestore(window.firebaseApp || undefined);
    const userDocRef = doc(db, 'users', userId);
    const userDocSnap = await getDoc(userDocRef);
    
    const clubInfoPreview = document.getElementById('clubInfoPreview');
    if (clubInfoPreview) {
      if (userDocSnap.exists() && userDocSnap.data().club_info) {
        const info = userDocSnap.data().club_info;
        clubInfoPreview.textContent = info.length > 50 ? info.substring(0, 50) + '...' : info;
      } else {
        clubInfoPreview.textContent = 'Not set';
      }
    }
  } catch (error) {
    console.error('Error loading club info:', error);
  }
}

// Setup club info dialog
function setupClubInfoDialog(userId) {
  const editButton = document.getElementById('editClubInfoButton');
  const dialogOverlay = document.getElementById('clubInfoDialogOverlay');
  const closeButton = document.getElementById('closeClubInfoDialog');
  const cancelButton = document.getElementById('clubInfoCancelButton');
  const saveButton = document.getElementById('clubInfoSaveButton');
  const textarea = document.getElementById('clubInfoTextarea');
  
  if (!editButton || !dialogOverlay || !textarea) return;
  
  function openDialog() {
    // Load current club info
    const db = getFirestore(window.firebaseApp || undefined);
    const userDocRef = doc(db, 'users', userId);
    getDoc(userDocRef).then((docSnap) => {
      if (docSnap.exists() && docSnap.data().club_info) {
        textarea.value = docSnap.data().club_info;
      } else {
        textarea.value = '';
      }
    });
    dialogOverlay.style.display = 'flex';
    setTimeout(() => textarea.focus(), 100);
  }
  
  function closeDialog() {
    dialogOverlay.style.display = 'none';
  }
  
  editButton.addEventListener('click', openDialog);
  if (closeButton) closeButton.addEventListener('click', closeDialog);
  if (cancelButton) cancelButton.addEventListener('click', closeDialog);
  
  if (saveButton) {
    saveButton.addEventListener('click', async function() {
      const newClubInfo = textarea.value.trim();
      saveButton.disabled = true;
      saveButton.textContent = 'Saving...';
      
      try {
        const db = getFirestore(window.firebaseApp || undefined);
        const userDocRef = doc(db, 'users', userId);
        await setDoc(userDocRef, { club_info: newClubInfo || null }, { merge: true });
        
        // Update preview
        const clubInfoPreview = document.getElementById('clubInfoPreview');
        if (clubInfoPreview) {
          clubInfoPreview.textContent = newClubInfo.length > 50 ? newClubInfo.substring(0, 50) + '...' : (newClubInfo || 'Not set');
        }
        
        closeDialog();
        showNotification('Club info saved successfully', 'success');
      } catch (error) {
        console.error('Error saving club info:', error);
        showNotification('Error saving club info', 'error');
      } finally {
        saveButton.disabled = false;
        saveButton.textContent = 'Save';
      }
    });
  }
  
  // Close on overlay click
  dialogOverlay.addEventListener('click', function(e) {
    if (e.target === dialogOverlay) {
      closeDialog();
    }
  });
  
  // Close on Escape key
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && dialogOverlay.style.display === 'flex') {
      closeDialog();
    }
  });
}

// Setup create meeting dialog
function setupCreateMeetingDialog(userId) {
  const createButton = document.getElementById('createMeetingButton');
  const dialogOverlay = document.getElementById('createMeetingDialogOverlay');
  const closeButton = document.getElementById('closeCreateMeetingDialog');
  const cancelButton = document.getElementById('createMeetingCancelButton');
  const confirmButton = document.getElementById('createMeetingConfirmButton');
  const nameInput = document.getElementById('meetingNameInput');
  
  if (!createButton || !dialogOverlay || !nameInput) return;
  
  function openDialog() {
    nameInput.value = '';
    dialogOverlay.style.display = 'flex';
    setTimeout(() => nameInput.focus(), 100);
  }
  
  function closeDialog() {
    dialogOverlay.style.display = 'none';
    nameInput.value = '';
  }
  
  createButton.addEventListener('click', openDialog);
  if (closeButton) closeButton.addEventListener('click', closeDialog);
  if (cancelButton) cancelButton.addEventListener('click', closeDialog);
  
  if (confirmButton) {
    confirmButton.addEventListener('click', async function() {
      const meetingName = nameInput.value.trim();
      
      if (!meetingName) {
        showNotification('Please enter a meeting name', 'error');
        return;
      }
      
      confirmButton.disabled = true;
      confirmButton.textContent = 'Creating...';
      
      try {
        const functions = getFunctions(window.firebaseApp || undefined);
        const createMeeting = httpsCallable(functions, 'createMeeting');
        
        const result = await createMeeting({
          title: meetingName,
          creator_id: userId
        });
        
        const data = result.data;
        
        if (data.success && data.meeting) {
          showNotification('Meeting created successfully!', 'success');
          closeDialog();
        } else {
          showNotification(data.error || 'Failed to create meeting', 'error');
          confirmButton.disabled = false;
          confirmButton.textContent = 'Create';
        }
      } catch (error) {
        console.error('Error creating meeting:', error);
        showNotification('Error creating meeting. Please try again.', 'error');
        confirmButton.disabled = false;
        confirmButton.textContent = 'Create';
      }
    });
  }
  
  // Close on overlay click
  dialogOverlay.addEventListener('click', function(e) {
    if (e.target === dialogOverlay) {
      closeDialog();
    }
  });
  
  // Close on Escape key
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && dialogOverlay.style.display === 'flex') {
      closeDialog();
    }
  });
  
  // Allow Enter to create
  if (nameInput) {
    nameInput.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' && !confirmButton.disabled) {
        e.preventDefault();
        confirmButton.click();
      }
    });
  }
}

// Setup real-time meetings listener
function setupMeetingsListener(userId) {
  try {
    const db = getFirestore(window.firebaseApp || undefined);
    const meetingsRef = collection(db, 'users', userId, 'meetings');
    const meetingsQuery = query(meetingsRef, orderBy('created_at', 'desc'));
    
    const meetingsSection = document.getElementById('meetingsSection');
    const meetingsList = document.getElementById('meetingsList');
    
    if (!meetingsSection || !meetingsList) return;
    
    const unsubscribe = onSnapshot(meetingsQuery, (snapshot) => {
      meetingsList.innerHTML = '';
      
      if (snapshot.empty) {
        meetingsSection.style.display = 'none';
        return;
      }
      
      meetingsSection.style.display = 'block';
      
      snapshot.docs.forEach((meetingDoc) => {
        const meetingData = meetingDoc.data();
        const meetingId = meetingDoc.id;
        const meetingTitle = meetingData.title || 'Untitled Meeting';
        
        // Format meeting code with space in the middle (e.g., "1234 5678")
        const formattedCode = meetingId.length === 8 
          ? `${meetingId.substring(0, 4)} ${meetingId.substring(4)}`
          : meetingId;
        
        const meetingItem = document.createElement('div');
        meetingItem.className = 'settings-item clickable';
        meetingItem.style.cursor = 'pointer';
        meetingItem.addEventListener('click', () => {
          showMeetingInfo(meetingId, meetingTitle);
        });
        
        meetingItem.innerHTML = `
          <div class="settings-item-content">
            <div class="settings-item-icon">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                <line x1="16" y1="2" x2="16" y2="6"/>
                <line x1="8" y1="2" x2="8" y2="6"/>
                <line x1="3" y1="10" x2="21" y2="10"/>
              </svg>
            </div>
            <div class="settings-item-text" style="flex: 1;">
              <div class="settings-item-label">${meetingTitle}</div>
              <div class="settings-item-value" style="font-family: 'Courier New', monospace; letter-spacing: 2px;">${formattedCode}</div>
            </div>
            <div class="settings-item-arrow">
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M6 4l4 4-4 4"/>
              </svg>
            </div>
          </div>
        `;
        
        meetingsList.appendChild(meetingItem);
      });
    }, (error) => {
      console.error('Error listening to meetings:', error);
    });
    
    // Store unsubscribe function for cleanup if needed
    window.meetingsUnsubscribe = unsubscribe;
    
  } catch (error) {
    console.error('Error setting up meetings listener:', error);
  }
}

// Show meeting info dialog
function showMeetingInfo(meetingId, meetingTitle) {
  const dialogOverlay = document.getElementById('meetingInfoDialogOverlay');
  const closeButton = document.getElementById('closeMeetingInfoDialog');
  const closeButton2 = document.getElementById('meetingInfoCloseButton');
  const titleEl = document.getElementById('meetingInfoTitle');
  const codeEl = document.getElementById('meetingInfoCode');
  
  if (!dialogOverlay || !titleEl || !codeEl) return;
  
  // Format meeting code with space in the middle
  const formattedCode = meetingId.length === 8 
    ? `${meetingId.substring(0, 4)} ${meetingId.substring(4)}`
    : meetingId;
  
  titleEl.textContent = meetingTitle;
  codeEl.textContent = formattedCode;
  
  dialogOverlay.style.display = 'flex';
  
  function closeDialog() {
    dialogOverlay.style.display = 'none';
  }
  
  if (closeButton) {
    closeButton.onclick = closeDialog;
  }
  if (closeButton2) {
    closeButton2.onclick = closeDialog;
  }
  
  // Close on overlay click
  dialogOverlay.onclick = function(e) {
    if (e.target === dialogOverlay) {
      closeDialog();
    }
  };
  
  // Close on Escape key
  const handleEscape = function(e) {
    if (e.key === 'Escape' && dialogOverlay.style.display === 'flex') {
      closeDialog();
      document.removeEventListener('keydown', handleEscape);
    }
  };
  document.addEventListener('keydown', handleEscape);
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

