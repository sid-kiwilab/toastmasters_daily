import { getFirestore, doc, getDoc, collection, query, orderBy, onSnapshot } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";

function getCode() {
  const q = new URLSearchParams(window.location.search).get('code');
  if (q) return q;
  const m = window.location.pathname.match(/^\/club\/([^\/]+)/);
  return m ? m[1] : null;
}

async function load() {
  const code = getCode();
  if (!code) { show('error', 'Invalid club code'); return; }
  
  let i = 0;
  while (!window.firebaseApp && i++ < 500) await new Promise(r => setTimeout(r, 10));
  if (!window.firebaseApp) { show('error', 'Unable to connect. Please refresh the page.'); return; }
  
  try {
    const db = getFirestore(window.firebaseApp);
    const clubDoc = await getDoc(doc(db, 'club_codes', code));
    if (!clubDoc.exists()) { show('error', 'Club not found. Please check the club code and try again.'); return; }
    
    const uid = clubDoc.data().uid;
    if (!uid) { show('error', 'Invalid club data'); return; }
    
    const userDoc = await getDoc(doc(db, 'users', uid));
    if (!userDoc.exists()) { show('error', 'Club owner information not available'); return; }
    
    const d = userDoc.data();
    
    // Setup real-time meetings listener (will hide loading when done)
    setupMeetingsListener(uid, {
      name: d.club_name || 'Unnamed Club',
      info: d.club_info || null
    });
  } catch (e) {
    console.error(e);
    show('error', 'Unable to load club information. Please try again later.');
  }
}

// Setup real-time meetings listener
function setupMeetingsListener(userId, clubData) {
  try {
    const db = getFirestore(window.firebaseApp);
    const meetingsRef = collection(db, 'users', userId, 'meetings');
    const meetingsQuery = query(meetingsRef, orderBy('created_at', 'desc'));
    
    const meetingsSection = document.getElementById('meetingsSection');
    const meetingsList = document.getElementById('meetingsList');
    
    if (!meetingsSection || !meetingsList) {
      // If elements don't exist, just show content without meetings
      show('content', null, clubData);
      return;
    }
    
    let isFirstSnapshot = true;
    
    const unsubscribe = onSnapshot(meetingsQuery, (snapshot) => {
      const noMeetingsMessage = document.getElementById('noMeetingsMessage');
      meetingsList.innerHTML = '';
      
      if (snapshot.empty) {
        // Show friendly message when no meetings
        if (noMeetingsMessage) {
          const messages = [
            'No meeting today — enjoy the peace! ✨',
            'All clear! No meetings scheduled 🌟',
            'Meeting-free day ahead 🎯',
            'Nothing on the agenda — time to relax ☕',
            'The stage is empty today 🎭'
          ];
          const randomMessage = messages[Math.floor(Math.random() * messages.length)];
          noMeetingsMessage.textContent = randomMessage;
          noMeetingsMessage.style.display = 'block';
        }
        meetingsSection.style.display = 'block';
      } else {
        // Hide no meetings message
        if (noMeetingsMessage) {
          noMeetingsMessage.style.display = 'none';
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
          meetingItem.className = 'meeting-item';
          meetingItem.addEventListener('click', (e) => {
            // Don't navigate if clicking the button
            if (e.target.closest('.join-meeting-button')) {
              return;
            }
            window.location.href = `/meetings/${meetingId}`;
          });
          
          meetingItem.innerHTML = `
            <div style="flex: 1;">
              <div class="meeting-item-title">${meetingTitle}</div>
              <div class="meeting-item-code">${formattedCode}</div>
            </div>
            <button class="join-meeting-button" onclick="event.stopPropagation(); window.location.href='/meetings/${meetingId}'">
              Join Meeting
            </button>
          `;
          
          meetingsList.appendChild(meetingItem);
        });
      }
      
      // Hide loading screen after first snapshot
      if (isFirstSnapshot) {
        isFirstSnapshot = false;
        show('content', null, clubData);
      }
    }, (error) => {
      console.error('Error listening to meetings:', error);
      // Even on error, show the content (without meetings)
      show('content', null, clubData);
    });
    
    // Store unsubscribe function for cleanup if needed
    window.meetingsUnsubscribe = unsubscribe;
    
  } catch (error) {
    console.error('Error setting up meetings listener:', error);
    // Even on error, show the content (without meetings)
    show('content', null, clubData);
  }
}

// Show meeting info dialog (simple version for club page)
function showMeetingInfo(meetingId, meetingTitle) {
  // Format meeting code with space in the middle
  const formattedCode = meetingId.length === 8 
    ? `${meetingId.substring(0, 4)} ${meetingId.substring(4)}`
    : meetingId;
  
  alert(`Meeting: ${meetingTitle}\nCode: ${formattedCode}`);
}

function show(type, msg, data) {
  document.getElementById('loading').style.display = 'none';
  document.getElementById('error').style.display = type === 'error' ? 'block' : 'none';
  document.getElementById('content').style.display = type === 'content' ? 'block' : 'none';
  if (type === 'error') {
    const errorMsg = document.getElementById('errorMessage');
    if (msg.includes('not found')) {
      errorMsg.textContent = 'This club doesn\'t exist. Double check and try again.';
    } else {
      errorMsg.textContent = 'This club doesn\'t exist. Double check and try again.';
    }
  }
  if (type === 'content') {
    const welcomeMessage = document.getElementById('welcomeMessage');
    if (welcomeMessage) {
      welcomeMessage.textContent = `Welcome to ${data.name}!`;
    }
    
    const clubInfoEl = document.getElementById('clubInfo');
    if (data.info) {
      clubInfoEl.textContent = data.info;
      clubInfoEl.style.display = 'block';
    } else {
      clubInfoEl.style.display = 'none';
    }
  }
}

setTimeout(load, 200);

