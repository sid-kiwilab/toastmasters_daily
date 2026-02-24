/**
 * Guest Entry Widget - Modular Component
 * 
 * Usage:
 * 1. Include guest-entry.css in your page
 * 2. Include guest-entry.html snippet in your page (or load dynamically)
 * 3. Include this guest-entry.js file
 * 4. Call GuestEntry.init(clubDb, creatorId, onSuccessCallback)
 * 5. Call GuestEntry.show() to display the dialog
 * 
 * Requirements:
 * - window.creatorId must be set (or pass creatorId to init)
 * - clubDb (Firestore instance) must be available
 * - firebase must be loaded
 */

const GuestEntry = (function() {
  'use strict';
  
  let clubDb = null;
  let creatorId = null;
  let guestDeviceId = null;
  let guestHasSubmittedToday = false;
  let guestPreviousData = null;
  let onSuccessCallback = null;
  
  // Get device ID for guest tracking
  function getGuestDeviceId() {
    const key = 'web_device_id';
    let deviceId = localStorage.getItem(key);
    if (!deviceId) {
      deviceId = sessionStorage.getItem(key);
      if (deviceId) {
        localStorage.setItem(key, deviceId);
      }
    }
    if (!deviceId) {
      // Generate simple device ID
      const fingerprint = {
        userAgent: navigator.userAgent,
        language: navigator.language,
        platform: navigator.platform,
        screen: `${screen.width}x${screen.height}`,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
      };
      const fingerprintStr = JSON.stringify(fingerprint);
      // Simple hash
      let hash = 0;
      for (let i = 0; i < fingerprintStr.length; i++) {
        const char = fingerprintStr.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash;
      }
      deviceId = 'web_' + Math.abs(hash).toString(16).substring(0, 16);
      localStorage.setItem(key, deviceId);
      sessionStorage.setItem(key, deviceId);
    }
    return deviceId;
  }
  
  // Get today's date string (YYYY-MM-DD)
  function getTodayDateString() {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
  
  // Escape HTML to prevent XSS
  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
  
  // Load guest data from Firestore
  async function loadGuestData() {
    // Always get device ID first
    guestDeviceId = getGuestDeviceId();
    
    const currentCreatorId = creatorId || window.creatorId;
    if (!currentCreatorId || !clubDb) {
      return;
    }
    
    try {
      const todayDateString = getTodayDateString();
      
      const guestDoc = await clubDb
        .collection('users')
        .doc(currentCreatorId)
        .collection('guests')
        .doc(guestDeviceId)
        .get();
      
      if (guestDoc.exists) {
        const data = guestDoc.data();
        const lastEntryDate = data.last_entry_date;
        guestHasSubmittedToday = lastEntryDate === todayDateString;
        
        if (!guestHasSubmittedToday && data.attendance_count > 0) {
          guestPreviousData = {
            name: data.name || '',
            email: data.email || '',
            phone: data.phone || '',
            hear_about_us: data.hear_about_us || ''
          };
        }
      }
    } catch (error) {
      console.error('Error loading guest data:', error);
      guestHasSubmittedToday = false;
      guestPreviousData = null;
    }
  }
  
  // Show appropriate view based on guest state
  function showGuestEntryView() {
    const alreadySubmittedView = document.getElementById('guest-entry-already-submitted');
    const isThisYouView = document.getElementById('guest-entry-is-this-you');
    const formView = document.getElementById('guest-entry-form-view');
    const errorDiv = document.getElementById('guest-entry-error');
    
    if (!alreadySubmittedView || !isThisYouView || !formView || !errorDiv) {
      console.error('Guest entry HTML elements not found. Make sure guest-entry.html is included.');
      return;
    }
    
    // Hide all views
    alreadySubmittedView.style.display = 'none';
    isThisYouView.style.display = 'none';
    formView.style.display = 'none';
    errorDiv.style.display = 'none';
    
    if (guestHasSubmittedToday) {
      alreadySubmittedView.style.display = 'block';
    } else if (guestPreviousData) {
      // Show previous info
      const previousInfoDiv = document.getElementById('guest-entry-previous-info');
      if (previousInfoDiv) {
        previousInfoDiv.innerHTML = `
          <div class="guest-entry-previous-info-item">
            <span class="guest-entry-previous-info-label">Name:</span>
            <span class="guest-entry-previous-info-value">${escapeHtml(guestPreviousData.name || 'N/A')}</span>
          </div>
          <div class="guest-entry-previous-info-item">
            <span class="guest-entry-previous-info-label">Email:</span>
            <span class="guest-entry-previous-info-value">${escapeHtml(guestPreviousData.email || 'N/A')}</span>
          </div>
          ${guestPreviousData.phone ? `
          <div class="guest-entry-previous-info-item">
            <span class="guest-entry-previous-info-label">Phone:</span>
            <span class="guest-entry-previous-info-value">${escapeHtml(guestPreviousData.phone)}</span>
          </div>
          ` : ''}
        `;
      }
      isThisYouView.style.display = 'block';
    } else {
      formView.style.display = 'block';
    }
  }
  
  // Handle "Yes, that's me"
  async function handleGuestYesMe() {
    const currentCreatorId = creatorId || window.creatorId;
    if (!currentCreatorId || !clubDb || !guestDeviceId) {
      showGuestError('Error: Missing required information');
      return;
    }
    
    try {
      const submitBtn = document.querySelector('#guest-entry-is-this-you .guest-entry-btn-submit');
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.textContent = 'Submitting...';
      }
      
      const todayDateString = getTodayDateString();
      const guestDocRef = clubDb.collection('users').doc(currentCreatorId).collection('guests').doc(guestDeviceId);
      
      const batch = clubDb.batch();
      
      const mainData = {
        name: guestPreviousData.name || '',
        email: guestPreviousData.email || '',
        hear_about_us: guestPreviousData.hear_about_us || '',
        last_entry_date: todayDateString,
        last_updated: firebase.firestore.FieldValue.serverTimestamp(),
        attendance_count: firebase.firestore.FieldValue.increment(1)
      };
      if (guestPreviousData.phone) {
        mainData.phone = guestPreviousData.phone;
      }
      
      batch.set(guestDocRef, mainData, { merge: true });
      batch.set(guestDocRef.collection('attendances').doc(todayDateString), {
        entry_date: todayDateString,
        created_at: firebase.firestore.FieldValue.serverTimestamp()
      });
      
      await batch.commit();
      
      // Refresh data
      await loadGuestData();
      showGuestEntryView();
      
      // Show success and close after 1 second
      setTimeout(() => {
        // Close the dialog first
        const overlay = document.getElementById('guest-entry-overlay');
        if (overlay) {
          overlay.style.display = 'none';
          document.body.style.overflow = '';
        }
        // Then call success callback if provided
        if (onSuccessCallback) {
          onSuccessCallback();
        }
      }, 1000);
    } catch (error) {
      console.error('Error submitting guest info:', error);
      showGuestError('Error submitting information. Please try again.');
      const submitBtn = document.querySelector('#guest-entry-is-this-you .guest-entry-btn-submit');
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Yes, that\'s me';
      }
    }
  }
  
  // Handle "No, that's not me"
  function handleGuestNotMe() {
    guestPreviousData = null;
    showGuestEntryView();
  }
  
  // Show error message
  function showGuestError(message) {
    const errorDiv = document.getElementById('guest-entry-error');
    if (errorDiv) {
      errorDiv.textContent = message;
      errorDiv.style.display = 'block';
    }
  }
  
  // Submit guest form
  async function submitGuestForm(event) {
    event.preventDefault();
    
    // Ensure device ID is set
    if (!guestDeviceId) {
      guestDeviceId = getGuestDeviceId();
    }
    
    const currentCreatorId = creatorId || window.creatorId;
    if (!currentCreatorId) {
      showGuestError('Error: Club information not available. Please refresh the page.');
      return;
    }
    
    if (!clubDb) {
      showGuestError('Error: Database not initialized. Please refresh the page.');
      return;
    }
    
    if (!guestDeviceId) {
      showGuestError('Error: Could not identify your device. Please refresh the page.');
      return;
    }
    
    if (guestHasSubmittedToday) {
      showGuestError('You have already submitted your information for today.');
      return;
    }
    
    const name = document.getElementById('guest-entry-name').value.trim();
    const email = document.getElementById('guest-entry-email').value.trim();
    const hear = document.getElementById('guest-entry-hear').value;
    const phone = document.getElementById('guest-entry-phone').value.trim();
    
    if (!name || !email || !hear) {
      showGuestError('Please fill in all required fields.');
      return;
    }
    
    try {
      const submitBtn = document.getElementById('guest-entry-submit-btn');
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.textContent = 'Submitting...';
      }
      
      const todayDateString = getTodayDateString();
      const guestDocRef = clubDb.collection('users').doc(currentCreatorId).collection('guests').doc(guestDeviceId);
      
      const batch = clubDb.batch();
      
      const mainData = {
        name: name,
        email: email,
        hear_about_us: hear,
        last_entry_date: todayDateString,
        last_updated: firebase.firestore.FieldValue.serverTimestamp(),
        attendance_count: firebase.firestore.FieldValue.increment(1)
      };
      if (phone) {
        mainData.phone = phone;
      }
      
      batch.set(guestDocRef, mainData, { merge: true });
      batch.set(guestDocRef.collection('attendances').doc(todayDateString), {
        entry_date: todayDateString,
        created_at: firebase.firestore.FieldValue.serverTimestamp()
      });
      
      await batch.commit();
      
      // Refresh data
      await loadGuestData();
      showGuestEntryView();
      
      // Show success and close after 1 second
      setTimeout(() => {
        // Close the dialog first
        const overlay = document.getElementById('guest-entry-overlay');
        if (overlay) {
          overlay.style.display = 'none';
          document.body.style.overflow = '';
        }
        // Then call success callback if provided
        if (onSuccessCallback) {
          onSuccessCallback();
        }
      }, 1000);
    } catch (error) {
      console.error('Error submitting guest form:', error);
      showGuestError('Error submitting information. Please try again.');
      const submitBtn = document.getElementById('guest-entry-submit-btn');
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Submit';
      }
    }
  }
  
  // Public API
  return {
    /**
     * Initialize the guest entry widget
     * @param {Object} db - Firestore database instance
     * @param {string} uid - Creator/Club owner user ID (optional, can use window.creatorId)
     * @param {Function} onSuccess - Callback function called after successful submission
     */
    init: function(db, uid, onSuccess) {
      clubDb = db;
      creatorId = uid || null;
      onSuccessCallback = onSuccess || null;
      
      // Attach button handlers (these are called from HTML onclick attributes)
      window.handleGuestYesMe = handleGuestYesMe;
      window.handleGuestNotMe = handleGuestNotMe;
      window.closeGuestEntryDialog = this.close.bind(this);
      
      // Attach form submit handler (will be re-attached in show() if needed)
      const form = document.getElementById('guest-entry-form');
      if (form) {
        // Remove existing listener if any (to prevent duplicates)
        form.removeEventListener('submit', submitGuestForm);
        form.addEventListener('submit', submitGuestForm);
      }
    },
    
    /**
     * Show the guest entry dialog
     */
    show: async function() {
      const overlay = document.getElementById('guest-entry-overlay');
      if (!overlay) {
        console.error('Guest entry overlay not found. Make sure guest-entry.html is included.');
        return;
      }
      
      // Ensure device ID is set
      if (!guestDeviceId) {
        guestDeviceId = getGuestDeviceId();
      }
      
      // Reset form
      const form = document.getElementById('guest-entry-form');
      if (form) {
        form.reset();
        // Ensure form submit handler is attached (in case HTML was loaded after init)
        form.removeEventListener('submit', submitGuestForm);
        form.addEventListener('submit', submitGuestForm);
      }
      const errorDiv = document.getElementById('guest-entry-error');
      if (errorDiv) {
        errorDiv.style.display = 'none';
      }
      const submitBtn = document.getElementById('guest-entry-submit-btn');
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Submit';
      }
      
      // Load guest data and show appropriate view
      await loadGuestData();
      showGuestEntryView();
      
      overlay.style.display = 'flex';
      document.body.style.overflow = 'hidden';
    },
    
    /**
     * Close the guest entry dialog
     */
    close: function() {
      const overlay = document.getElementById('guest-entry-overlay');
      if (overlay) {
        overlay.style.display = 'none';
        document.body.style.overflow = '';
      }
    }
  };
})();

