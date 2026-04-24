// Extract meeting ID from URL pathname
function getMeetingIdFromUrl() {
  const pathname = window.location.pathname;
  // Extract meeting ID from /meetings/{meeting_id}
  const match = pathname.match(/\/meetings\/([^\/]+)/);
  return match ? match[1] : null;
}

// Initialize Firebase

function showError(message) {
  document.getElementById('loading-state').style.display = 'none';
  document.getElementById('error-state').style.display = 'flex';
  document.getElementById('error-message').textContent = message;
}

function showMeetingContent() {
  document.getElementById('loading-state').style.display = 'none';
  document.getElementById('meeting-content').style.display = 'block';
}

// Format date helper
function formatDate(date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const d = new Date(date);
  return `${months[d.getMonth()]} ${String(d.getDate()).padStart(2, '0')}, ${d.getFullYear()}`;
}

// Format time helper
function formatTime(date) {
  const d = new Date(date);
  let hour = d.getHours();
  const minute = String(d.getMinutes()).padStart(2, '0');
  const period = hour < 12 ? 'AM' : 'PM';
  hour = hour % 12 || 12;
  return `${hour}:${minute} ${period}`;
}

// Format full datetime
function formatDateTime(date) {
  const dayName = date.toLocaleDateString('en-US', { weekday: 'long' });
  const dateStr = formatDate(date);
  const timeStr = formatTime(date);
  return `${dayName}, ${dateStr} at ${timeStr}`;
}

// Get random exciting welcome message
function getRandomWelcomeMessage() {
  const messages = [
    'Hi there! 👋',
    "Let's have fun!",
    'Hey!',
    'Welcome aboard!',
    'Hello!',
    'Glad you\'re here!',
    'Welcome to the meeting!',
    'Great to see you!',
    'Ready to get started?',
    'Excited to have you here!',
    'Welcome! Let\'s make it great!',
    'Hello and welcome!',
    'So glad you could join!',
    'Welcome! Time to shine!',
    'Hey there! Ready to go?'
  ];
  return messages[Math.floor(Math.random() * messages.length)];
}

// PDF Viewer using PDF.js for reliable cross-platform rendering

// Cache DOM elements
const pdfElements = {
  overlay: null,
  container: null,
  loading: null,
  header: null,
  meetingContent: null
};

function getPdfElements() {
  if (!pdfElements.overlay) {
    pdfElements.overlay = document.getElementById('pdf-viewer-overlay');
    pdfElements.container = document.getElementById('pdf-viewer-container');
    pdfElements.loading = document.getElementById('pdf-loading');
    pdfElements.header = document.querySelector('.header');
    pdfElements.meetingContent = document.getElementById('meeting-content');
  }
  return pdfElements;
}

function resetLoadingState() {
  const { loading } = getPdfElements();
  loading.innerHTML = '<div class="pdf-loading-spinner"></div><div class="pdf-loading-text">Loading PDF...</div>';
}

async function openPdfViewer(pdfUrl) {
  const { overlay, container, loading, header, meetingContent } = getPdfElements();
  
  // Hide page content
  if (header) header.style.display = 'none';
  if (meetingContent) meetingContent.style.display = 'none';
  
  // Show viewer
  overlay.classList.add('active');
  container.style.display = 'none';
  loading.style.display = 'block';
  resetLoadingState();
  document.body.style.overflow = 'hidden';
  document.body.style.background = '#000000';
  
  try {
    // Load PDF
    currentPdfDoc = await pdfjsLib.getDocument(pdfUrl).promise;
    
    // Render all pages
    await renderAllPages();
    
    // Show PDF, hide loading
    loading.style.display = 'none';
    container.style.display = 'flex';
  } catch (error) {
    console.error('Error loading PDF:', error);
    loading.innerHTML = '<div class="pdf-loading-text" style="color: #ff4444;">Error loading PDF. Please try again.</div>';
  }
}

async function renderAllPages() {
  if (!currentPdfDoc) return;
  
  const { container } = getPdfElements();
  const numPages = currentPdfDoc.numPages;
  const scale = 1.5;
  
  // Clear container
  container.innerHTML = '';
  
  // Render each page
  for (let pageNum = 1; pageNum <= numPages; pageNum++) {
    try {
      const page = await currentPdfDoc.getPage(pageNum);
      const viewport = page.getViewport({ scale });
      
      // Create canvas for this page
      const canvas = document.createElement('canvas');
      canvas.className = 'pdf-page-canvas';
      const ctx = canvas.getContext('2d');
      
      canvas.height = viewport.height;
      canvas.width = viewport.width;
      
      // Render page
      await page.render({
        canvasContext: ctx,
        viewport: viewport
      }).promise;
      
      // Add canvas to container
      container.appendChild(canvas);
    } catch (error) {
      console.error(`Error rendering page ${pageNum}:`, error);
    }
  }
}

function closePdfViewer() {
  const { overlay, container, loading, header, meetingContent } = getPdfElements();
  
  // Hide viewer
  overlay.classList.remove('active');
  document.body.style.overflow = '';
  document.body.style.background = '#ffffff';
  
  // Show page content
  if (header) header.style.display = 'flex';
  if (meetingContent) meetingContent.style.display = 'block';
  
  // Clean up
  currentPdfDoc = null;
  container.innerHTML = '';
  container.style.display = 'none';
  loading.style.display = 'none';
  resetLoadingState();
}

// Wrapper functions for guest entry (using modular component)
async function showGuestEntryDialog() {
  await GuestEntry.show();
}

function closeGuestEntryDialog() {
  GuestEntry.close();
}


function applyOwnerMeetingView() {
  window.isOwnerMeetingView = true;
  const guestSection = document.getElementById('guest-entry-action-section');
  if (guestSection) guestSection.style.display = 'none';
}

function clearOwnerMeetingView() {
  window.isOwnerMeetingView = false;
  const guestSection = document.getElementById('guest-entry-action-section');
  if (guestSection) guestSection.style.display = '';
}

function waitForInitialClubAuth(clubAuth) {
  if (!clubAuth) return Promise.resolve(null);
  return new Promise((resolve) => {
    const unsub = clubAuth.onAuthStateChanged((user) => {
      unsub();
      resolve(user);
    });
  });
}

function setupMeetingOwnerAuthListener() {
  if (meetingOwnerAuthUnsub) {
    meetingOwnerAuthUnsub();
    meetingOwnerAuthUnsub = null;
  }
  const auth = firebase.auth(firebase.app('club'));
  meetingOwnerAuthUnsub = auth.onAuthStateChanged((user) => {
    const creator = window.creatorId;
    if (!creator) return;
    const mc = document.getElementById('meeting-content');
    const visible = mc && mc.style.display !== 'none';
    const isHost = !!(user && user.uid === creator);
    if (isHost) {
      applyOwnerMeetingView();
      const greet = document.getElementById('welcome-greeting');
      if (greet && visible) {
        greet.textContent = "You're viewing this meeting as the host (signed in).";
      }
    } else {
      clearOwnerMeetingView();
      const greet = document.getElementById('welcome-greeting');
      if (greet && visible) {
        greet.textContent = getRandomWelcomeMessage();
      }
    }
    if (window.lastMeetingData && visible) {
      const mid = getMeetingIdFromUrl();
      if (mid) {
        renderAgendaCard(mid, window.lastMeetingData, isHost);
      }
    }
  });
}

// Exit Meeting Dialog functions
function showExitMeetingDialog() {
  const overlay = document.getElementById('exit-meeting-dialog-overlay');
  overlay.classList.add('active');
  document.body.style.overflow = 'hidden';
}

function hideExitMeetingDialog() {
  const overlay = document.getElementById('exit-meeting-dialog-overlay');
  overlay.classList.remove('active');
  document.body.style.overflow = '';
}

function confirmExitMeeting() {
  // Redirect to club page if club code exists, otherwise go to home
  if (window.clubCode) {
    window.location.href = `/clubs/${window.clubCode}`;
  } else {
    window.location.href = '/';
  }
}

function renderAgendaCard(meetingId, meetingData, isHost) {
  const card = document.getElementById('agenda-card');
  if (!card) return;
  const titleEl = document.getElementById('agenda-card-title');
  const descEl = document.getElementById('agenda-card-description');
  const arrow = document.getElementById('agenda-card-arrow');
  const hostRow = document.getElementById('agenda-card-host-actions');
  const uploadBtn = document.getElementById('agenda-upload-btn');
  const changeBtn = document.getElementById('agenda-change-btn');
  const fileInput = document.getElementById('agenda-file-input');
  if (fileInput && meetingId) {
    fileInput.setAttribute('data-meeting-id', meetingId);
  }
  const agendaUrl = meetingData?.agenda_url || meetingData?.agendaUrl;
  card.onclick = null;
  if (uploadBtn) uploadBtn.onclick = null;
  if (changeBtn) changeBtn.onclick = null;
  if (!isHost && !agendaUrl) {
    card.style.display = 'none';
    if (hostRow) hostRow.style.display = 'none';
    return;
  }
  if (!isHost) {
    if (hostRow) hostRow.style.display = 'none';
    if (titleEl) titleEl.textContent = 'View Agenda';
    if (descEl) descEl.textContent = 'Open agenda in full screen';
    if (arrow) arrow.style.display = '';
    card.style.display = 'flex';
    card.style.cursor = 'pointer';
    card.onclick = (e) => {
      e.preventDefault();
      openPdfViewer(agendaUrl);
    };
    return;
  }
  if (hostRow) hostRow.style.display = 'flex';
  if (titleEl) {
    titleEl.textContent = agendaUrl ? 'View Agenda' : 'Agenda';
  }
  if (descEl) {
    descEl.textContent = agendaUrl
      ? 'Open agenda in full screen'
      : 'No agenda uploaded yet.';
  }
  if (arrow) arrow.style.display = agendaUrl ? '' : 'none';
  if (uploadBtn) uploadBtn.style.display = agendaUrl ? 'none' : 'inline-block';
  if (changeBtn) changeBtn.style.display = agendaUrl ? 'inline-block' : 'none';
  card.style.display = 'flex';
  if (agendaUrl) {
    card.style.cursor = 'pointer';
    card.onclick = (e) => {
      e.preventDefault();
      openPdfViewer(agendaUrl);
    };
  } else {
    card.style.cursor = 'default';
  }
  if (uploadBtn) {
    uploadBtn.onclick = (e) => {
      e.stopPropagation();
      if (fileInput) fileInput.click();
    };
  }
  if (changeBtn) {
    changeBtn.onclick = (e) => {
      e.stopPropagation();
      if (fileInput) fileInput.click();
    };
  }
}

function showAgendaUploadDialog(fileName) {
  const overlay = document.getElementById('agenda-upload-dialog-overlay');
  if (!overlay) return;
  const titleEl = document.getElementById('agenda-upload-dialog-title');
  const msgEl = document.getElementById('agenda-upload-dialog-message');
  const nameEl = document.getElementById('agenda-upload-dialog-filename');
  const spinner = document.getElementById('agenda-upload-dialog-spinner');
  const closeBtn = document.getElementById('agenda-upload-dialog-close');
  if (titleEl) titleEl.textContent = 'Upload agenda';
  if (msgEl) msgEl.textContent = 'Reading file…';
  if (nameEl) nameEl.textContent = fileName ? 'File: ' + fileName : '';
  if (spinner) spinner.classList.remove('is-hidden');
  if (closeBtn) closeBtn.style.display = 'none';
  overlay.setAttribute('data-uploading', '1');
  overlay.classList.add('active');
  document.body.style.overflow = 'hidden';
}

function setAgendaUploadDialogMessage(message) {
  const msgEl = document.getElementById('agenda-upload-dialog-message');
  if (msgEl) msgEl.textContent = message;
}

function finishAgendaUploadDialog(success, message) {
  const overlay = document.getElementById('agenda-upload-dialog-overlay');
  const titleEl = document.getElementById('agenda-upload-dialog-title');
  const spinner = document.getElementById('agenda-upload-dialog-spinner');
  const closeBtn = document.getElementById('agenda-upload-dialog-close');
  if (overlay) overlay.removeAttribute('data-uploading');
  if (titleEl) titleEl.textContent = success ? 'Upload complete' : 'Upload failed';
  if (spinner) spinner.classList.add('is-hidden');
  setAgendaUploadDialogMessage(message);
  if (closeBtn) closeBtn.style.display = 'inline-block';
}

function hideAgendaUploadDialog() {
  const overlay = document.getElementById('agenda-upload-dialog-overlay');
  if (!overlay) return;
  if (overlay.hasAttribute('data-uploading')) return;
  overlay.classList.remove('active');
  document.body.style.overflow = '';
  const titleEl = document.getElementById('agenda-upload-dialog-title');
  const nameEl = document.getElementById('agenda-upload-dialog-filename');
  const closeBtn = document.getElementById('agenda-upload-dialog-close');
  if (titleEl) titleEl.textContent = 'Upload agenda';
  if (nameEl) nameEl.textContent = '';
  if (closeBtn) closeBtn.style.display = 'none';
}

async function handleAgendaFileSelect(event) {
  const clearFileInput = function() {
    if (event.target) event.target.value = '';
  };
  const file = event.target.files[0];
  if (!file) return;
  if (!file.name.toLowerCase().endsWith('.pdf')) {
    showAgendaUploadDialog(file.name);
    finishAgendaUploadDialog(false, 'Only PDF files are allowed.');
    clearFileInput();
    return;
  }
  const fileInput = event.target;
  const meetingId = fileInput ? fileInput.getAttribute('data-meeting-id') : null;
  if (!meetingId) {
    showAgendaUploadDialog(file.name);
    finishAgendaUploadDialog(false, 'Meeting ID not found. Please refresh the page.');
    clearFileInput();
    return;
  }
  const clubAuth = firebase.auth(firebase.app('club'));
  const clubUser = clubAuth.currentUser;
  if (!clubUser) {
    showAgendaUploadDialog(file.name);
    finishAgendaUploadDialog(false, 'Please sign in to upload the agenda.');
    clearFileInput();
    return;
  }
  if (!clubFunctions) {
    showAgendaUploadDialog(file.name);
    finishAgendaUploadDialog(false, 'Meeting features are not ready. Please refresh the page.');
    clearFileInput();
    return;
  }
  showAgendaUploadDialog(file.name);
  try {
    const base64Data = await new Promise(function(resolve, reject) {
      const reader = new FileReader();
      reader.onload = function(e) {
        try {
          const data = e.target.result;
          const parts = typeof data === 'string' ? data.split(',') : [];
          if (parts.length < 2) {
            reject(new Error('Could not read the file'));
            return;
          }
          resolve(parts[1]);
        } catch (err) {
          reject(err);
        }
      };
      reader.onerror = function() {
        reject(new Error('Could not read the file'));
      };
      reader.readAsDataURL(file);
    });
    setAgendaUploadDialogMessage('Uploading…');
    const uploadAgendaFn = clubFunctions.httpsCallable('upload_agenda');
    const result = await uploadAgendaFn({
      meetingId: meetingId,
      fileData: base64Data,
      fileName: file.name
    });
    if (result.data && result.data.success) {
      finishAgendaUploadDialog(true, 'Agenda uploaded successfully.');
      try {
        await loadMeetingData();
      } catch (reloadErr) {
        console.error('loadMeetingData after agenda upload:', reloadErr);
      }
    } else {
      const errorMsg = result.data?.error || 'Failed to upload agenda';
      finishAgendaUploadDialog(false, errorMsg);
    }
  } catch (error) {
    console.error('Error uploading agenda:', error);
    const msg = (error && error.message) ? error.message : 'Something went wrong';
    finishAgendaUploadDialog(false, 'Error uploading agenda: ' + msg);
  } finally {
    clearFileInput();
  }
}

// Close PDF viewer on Escape key
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    const pdfOverlay = document.getElementById('pdf-viewer-overlay');
    const exitDialog = document.getElementById('exit-meeting-dialog-overlay');
    const agendaUpload = document.getElementById('agenda-upload-dialog-overlay');
    if (pdfOverlay.classList.contains('active')) {
      closePdfViewer();
    } else if (agendaUpload && agendaUpload.classList.contains('active') && !agendaUpload.hasAttribute('data-uploading')) {
      hideAgendaUploadDialog();
    } else if (exitDialog.classList.contains('active')) {
      hideExitMeetingDialog();
    }
  }
});

async function loadMeetingData() {
  const meetingId = getMeetingIdFromUrl();
  
  if (!meetingId) {
    showError('Invalid meeting ID');
    return;
  }
  
  if (!clubDb) {
    showError('Database not initialized');
    return;
  }
  
  try {
    // Query active_meetings collection to get creator_id
    const activeMeetingDoc = await clubDb.collection('active_meetings').doc(meetingId).get();
    
    if (!activeMeetingDoc.exists) {
      showError('Meeting not found');
      return;
    }
    
    const creatorId = activeMeetingDoc.data()?.creator_id;
    if (!creatorId) {
      showError('Invalid meeting data');
      return;
    }
    
    // Set creatorId globally for guest entry
    window.creatorId = creatorId;
    
    // Update guest entry widget with creatorId
    GuestEntry.init(clubDb, creatorId, null);
    
    // Query users/{creatorId}/meetings/{meetingId} to get meeting details
    const meetingDoc = await clubDb
      .collection('users')
      .doc(creatorId)
      .collection('meetings')
      .doc(meetingId)
      .get();
    
    if (!meetingDoc.exists) {
      showError('Meeting details not found');
      return;
    }
    
    const meetingData = meetingDoc.data();
    window.lastMeetingData = meetingData;
    
    // Query users collection to get club info
    const userDoc = await clubDb.collection('users').doc(creatorId).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    
    const clubAuth = firebase.auth(firebase.app('club'));
    const signedInUid = clubAuth.currentUser?.uid || null;
    const isHostSignedIn = !!signedInUid && signedInUid === creatorId;
    if (isHostSignedIn) {
      applyOwnerMeetingView();
    } else {
      clearOwnerMeetingView();
    }
    
    // Display meeting title
    document.getElementById('meeting-title').textContent = meetingData?.title || 'Untitled Meeting';
    
    document.getElementById('welcome-greeting').textContent = isHostSignedIn
      ? "You're viewing this meeting as the host (signed in)."
      : getRandomWelcomeMessage();
    
    renderAgendaCard(meetingId, meetingData, isHostSignedIn);
    
    // Set up polls and evaluations
    window.meetingId = meetingId;
    window.creatorId = creatorId;
    setupPollsListener(meetingId, creatorId);
    setupEvalsListener(meetingId, creatorId);
    
    // Store club code for exit meeting redirect
    if (userData?.club_code) {
      window.clubCode = userData.club_code;
    }
    
    setupMeetingOwnerAuthListener();
    showMeetingContent();
  } catch (error) {
    console.error('Error loading meeting data:', error);
    showError('Error loading meeting: ' + error.message);
  }
}

// Load guest entry HTML snippet
async function loadGuestEntryHTML() {
  try {
    const response = await fetch('/js/guest-entry.html');
    const html = await response.text();
    const container = document.getElementById('guest-entry-container');
    if (container) {
      container.innerHTML = html;
    }
  } catch (error) {
    console.error('Error loading guest entry HTML:', error);
  }
}

// Initialize
async function init() {
  try {
    // Load guest entry HTML first
    await loadGuestEntryHTML();
    
    const clubAuth = initClubAuth();
    const clubApp = firebase.app('club');
    clubDb = firebase.firestore(clubApp);
    clubFunctions = firebase.functions(clubApp);
    
    await waitForInitialClubAuth(clubAuth);
    
    // Initialize guest entry widget (creatorId will be set in loadMeetingData)
    GuestEntry.init(clubDb, null, null);
    
    loadMeetingData();
  } catch (error) {
    console.error('Error initializing:', error);
    showError('Error initializing: ' + error.message);
  }
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
  cleanupPollsListener();
  if (evalsListener) { evalsListener(); evalsListener = null; }
  if (meetingOwnerAuthUnsub) {
    meetingOwnerAuthUnsub();
    meetingOwnerAuthUnsub = null;
  }
});

// Wait for scripts to load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  setTimeout(init, 100);
}

// Wait for fonts to be ready before showing page content
document.addEventListener('DOMContentLoaded', () => {
  document.fonts.ready.then(() => {
    document.body.classList.add('loaded');
  });
});
