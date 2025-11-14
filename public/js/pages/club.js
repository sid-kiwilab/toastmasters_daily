import { getFirestore, doc, getDoc } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";

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
    show('content', null, {
      name: d.club_name || 'Unnamed Club',
      info: d.club_info || null
    });
  } catch (e) {
    console.error(e);
    show('error', 'Unable to load club information. Please try again later.');
  }
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
    document.getElementById('name').textContent = data.name;
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

