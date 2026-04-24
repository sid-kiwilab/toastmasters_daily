// Escape HTML
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

/** HTML id for poll item — avoid special chars; pair with getElementById in selectPollOption */
function safePollItemElementId(pollId) {
  return 'poll-' + String(pollId == null ? '' : pollId).replace(/[^a-zA-Z0-9_-]/g, '_');
}

function isPollHost() {
  try {
    if (!window.isOwnerMeetingView || !window.creatorId) return false;
    const u = firebase.auth(firebase.app('club')).currentUser;
    return !!u && u.uid === window.creatorId;
  } catch (e) {
    return false;
  }
}

function getDisplayPollsOrder() {
  if (isPollHost()) return pollsOrder;
  return activePollsOrder;
}

function updatePollsActionCardVisibility() {
  const card = document.getElementById('polls-card');
  if (!card) return;
  const show = activePollsOrder.length > 0 || isPollHost();
  card.style.display = show ? 'flex' : 'none';
}

window.syncMeetingPollsActionCard = updatePollsActionCardVisibility;
window.isPollHost = isPollHost;

function updateHostPollsToolbar() {
  const addBtn = document.getElementById('polls-add-poll-btn');
  if (!addBtn) return;
  addBtn.style.display = isPollHost() ? 'inline-block' : 'none';
}

function openHostCreatePoll() {
  if (!isPollHost()) return;
  hostPollUiMode = 'create';
  hostEditPollId = null;
  selectedPollIndex = 0;
  renderPolls();
}

function openHostEditPoll(pollId) {
  if (!isPollHost() || !pollsData[pollId]) return;
  hostPollUiMode = 'edit';
  hostEditPollId = pollId;
  renderPolls();
}

function closeHostCompose() {
  hostPollUiMode = 'none';
  hostEditPollId = null;
  const display = getDisplayPollsOrder();
  if (selectedPollIndex >= display.length) {
    selectedPollIndex = Math.max(0, display.length - 1);
  }
  renderPolls();
}

// Get device ID for polls (reuses same device ID as guest entry)
function getPollsDeviceId() {
  if (!pollsDeviceId) {
    const key = 'web_device_id';
    let deviceId = localStorage.getItem(key);
    if (!deviceId) {
      deviceId = sessionStorage.getItem(key);
      if (deviceId) {
        localStorage.setItem(key, deviceId);
      }
    }
    if (!deviceId) {
      const fingerprint = {
        userAgent: navigator.userAgent,
        language: navigator.language,
        platform: navigator.platform,
        screen: `${screen.width}x${screen.height}`,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
      };
      const fingerprintStr = JSON.stringify(fingerprint);
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
    pollsDeviceId = deviceId;
  }
  return pollsDeviceId;
}

function applyPollsSnapshot(snapshot) {
  if (snapshot && snapshot.metadata && snapshot.metadata.fromCache && snapshot.metadata.hasPendingWrites) {
    console.warn('Polls data is from cache and may be stale');
  }

  pollsData = {};
  pollsOrder = [];

  snapshot.docs.forEach((doc) => {
    if (!doc.exists) return;
    try {
      const data = doc.data();
      pollsData[doc.id] = {
        id: doc.id,
        question: data.question || '',
        options: Array.isArray(data.options) ? data.options : [],
        tallies: data.tallies || {},
        device_votes: data.device_votes || {},
        is_active: data.is_active !== false,
        created_at: data.created_at
      };
      pollsOrder.push(doc.id);
    } catch (docError) {
      console.error(`Error parsing poll document ${doc.id}:`, docError);
    }
  });

  try {
    pollsOrder.sort((a, b) => {
      const aTime = pollsData[a]?.created_at?.toMillis?.() || 0;
      const bTime = pollsData[b]?.created_at?.toMillis?.() || 0;
      return aTime - bTime;
    });
  } catch (sortError) {
    console.error('Error sorting polls:', sortError);
  }

  activePollsOrder = pollsOrder.filter((pollId) => {
    const p = pollsData[pollId];
    return p && p.is_active !== false;
  });

  if (hostPollUiMode === 'edit' && hostEditPollId && !pollsData[hostEditPollId]) {
    hostPollUiMode = 'none';
    hostEditPollId = null;
  }
  const display = getDisplayPollsOrder();
  if (hostPollUiMode === 'none' && display.length) {
    if (selectedPollIndex < 0 || selectedPollIndex >= display.length) {
      selectedPollIndex = 0;
    }
  } else if (hostPollUiMode === 'none' && !display.length) {
    selectedPollIndex = 0;
  }

  updatePollsActionCardVisibility();
  updateHostPollsToolbar();
  checkExistingVotes();

  const overlay = document.getElementById('polls-viewer-overlay');
  if (overlay && overlay.style.display !== 'none') {
    const composing = isPollHost() && (hostPollUiMode === 'create' || hostPollUiMode === 'edit');
    if (!composing) {
      renderPolls();
    }
  }
}

function setupPollsListener(meetingId, creatorId) {
  if (!clubDb || !meetingId || !creatorId) {
    console.warn('Cannot setup polls listener: missing required parameters');
    return;
  }

  const pollsCard = document.getElementById('polls-card');
  if (pollsCard) {
    pollsCard.onclick = (e) => {
      e.preventDefault();
      showPollsViewer();
    };
  }

  const addBtn = document.getElementById('polls-add-poll-btn');
  if (addBtn) {
    addBtn.onclick = (e) => {
      e.preventDefault();
      e.stopPropagation();
      openHostCreatePoll();
    };
  }

  if (pollsListener) {
    pollsListener();
    pollsListener = null;
  }

  const pollsRef = clubDb
    .collection('users')
    .doc(creatorId)
    .collection('meetings')
    .doc(meetingId)
    .collection('polls')
    .orderBy('created_at', 'asc');

  pollsListener = pollsRef.onSnapshot((snapshot) => {
    try {
      applyPollsSnapshot(snapshot);
    } catch (error) {
      console.error('Error processing polls snapshot:', error);
    }
  }, (error) => {
    console.error('Error listening to polls:', error);
    if (pollsCard) {
      pollsCard.style.display = 'none';
    }
    const overlay = document.getElementById('polls-viewer-overlay');
    if (overlay && overlay.style.display !== 'none') {
      showPollsError('Error loading polls. Please refresh the page.');
    }
  });
}

function cleanupPollsListener() {
  if (pollsListener) {
    pollsListener();
    pollsListener = null;
  }
}

function updatePollsVotingOverlay() {
  const el = document.getElementById('polls-voting-fullscreen');
  const btn = document.getElementById('polls-refresh-btn');
  if (btn) {
    btn.disabled = !!isVoting;
  }
  const addBtn = document.getElementById('polls-add-poll-btn');
  if (addBtn) addBtn.disabled = !!isVoting;
  if (!el) return;
  if (!isVoting) {
    el.classList.remove('is-visible');
    el.setAttribute('aria-hidden', 'true');
    return;
  }
  el.classList.add('is-visible');
  el.setAttribute('aria-hidden', 'false');
}

window.refreshMeetingPolls = async function() {
  if (isVoting || pollsRefreshing) return;
  const mid = window.meetingId;
  const cid = window.creatorId;
  if (!mid || !cid || !clubDb) return;

  pollsRefreshGeneration++;
  const myPollsRefreshGen = pollsRefreshGeneration;
  pollsRefreshing = true;
  const btn = document.getElementById('polls-refresh-btn');
  const refreshFs = document.getElementById('polls-refresh-fullscreen');
  if (btn) {
    btn.disabled = true;
    btn.textContent = 'Refreshing…';
  }
  if (refreshFs) {
    refreshFs.classList.add('is-visible');
    refreshFs.setAttribute('aria-hidden', 'false');
  }

  const refreshStartedAt = Date.now();
  const minPollsRefreshVisibleMs = 750;

  try {
    const pollsRef = clubDb
      .collection('users')
      .doc(cid)
      .collection('meetings')
      .doc(mid)
      .collection('polls')
      .orderBy('created_at', 'asc');

    let snapshot;
    try {
      snapshot = await pollsRef.get({ source: 'server' });
    } catch (serverErr) {
      console.warn('Server-only poll fetch failed, falling back:', serverErr);
      snapshot = await pollsRef.get();
    }
    applyPollsSnapshot(snapshot);
  } catch (error) {
    console.error('Error refreshing polls:', error);
    showPollsError('Could not refresh polls. Please try again.');
  } finally {
    const elapsed = Date.now() - refreshStartedAt;
    const remaining = minPollsRefreshVisibleMs - elapsed;
    if (remaining > 0) {
      await new Promise((resolve) => { setTimeout(resolve, remaining); });
    }
    pollsRefreshing = false;
    if (myPollsRefreshGen !== pollsRefreshGeneration) {
      return;
    }
    if (btn) {
      btn.textContent = 'Refresh polls';
      btn.disabled = !!isVoting;
    }
    if (refreshFs) {
      refreshFs.classList.remove('is-visible');
      refreshFs.setAttribute('aria-hidden', 'true');
    }
  }
};

function checkExistingVotes() {
  const deviceId = getPollsDeviceId();
  if (!deviceId) return;
  userVotes = {};
  pollsOrder.forEach((pollId) => {
    const poll = pollsData[pollId];
    if (poll && poll.device_votes && poll.device_votes[deviceId]) {
      userVotes[pollId] = poll.device_votes[deviceId];
    }
  });
}

function showPollsViewer() {
  const overlay = document.getElementById('polls-viewer-overlay');
  if (!overlay) {
    console.error('Polls viewer overlay not found');
    return;
  }
  if (!isPollHost()) {
    hostPollUiMode = 'none';
    hostEditPollId = null;
  }
  selectedPollIndex = 0;
  overlay.style.display = 'block';
  document.body.style.overflow = 'hidden';
  pollsRefreshing = false;
  const rfsOpen = document.getElementById('polls-refresh-fullscreen');
  if (rfsOpen) {
    rfsOpen.classList.remove('is-visible');
    rfsOpen.setAttribute('aria-hidden', 'true');
  }
  const refreshBtnOpen = document.getElementById('polls-refresh-btn');
  if (refreshBtnOpen) {
    refreshBtnOpen.disabled = false;
    refreshBtnOpen.textContent = 'Refresh polls';
  }
  if (window.updatePollsHintForHost) {
    window.updatePollsHintForHost();
  }
  updateHostPollsToolbar();
  renderPolls();
  updatePollsVotingOverlay();
}

function switchPollTab(index) {
  if (isVoting) return;
  if (isPollHost() && (hostPollUiMode === 'create' || hostPollUiMode === 'edit')) {
    hostPollUiMode = 'none';
    hostEditPollId = null;
  }
  const display = getDisplayPollsOrder();
  if (index < 0 || index >= display.length) return;
  selectedPollIndex = index;
  renderPolls();
}

function closePollsViewer() {
  pollsRefreshGeneration++;
  hostPollUiMode = 'none';
  hostEditPollId = null;
  if (window.hideHostPollDeleteDialog) {
    window.hideHostPollDeleteDialog();
  }
  if (window.hideHostPollToggleDialog) {
    window.hideHostPollToggleDialog();
  }
  const overlay = document.getElementById('polls-viewer-overlay');
  if (overlay) {
    overlay.style.display = 'none';
    document.body.style.overflow = '';
  }
  pollsRefreshing = false;
  const voteFs = document.getElementById('polls-voting-fullscreen');
  if (voteFs) {
    voteFs.classList.remove('is-visible');
    voteFs.setAttribute('aria-hidden', 'true');
  }
  const refreshFs = document.getElementById('polls-refresh-fullscreen');
  if (refreshFs) {
    refreshFs.classList.remove('is-visible');
    refreshFs.setAttribute('aria-hidden', 'true');
  }
  const btn = document.getElementById('polls-refresh-btn');
  if (btn) {
    btn.disabled = false;
    btn.textContent = 'Refresh polls';
  }
}

function buildHostActionBar(pollId) {
  const bar = document.createElement('div');
  bar.className = 'poll-host-actions';
  const p = pollsData[pollId];
  const isActive = p && p.is_active !== false;
  if (!isActive) {
    const onBtn = document.createElement('button');
    onBtn.type = 'button';
    onBtn.className = 'poll-host-btn';
    onBtn.setAttribute('data-host-action', 'activate');
    onBtn.setAttribute('data-poll-id', pollId);
    onBtn.textContent = 'Turn on';
    bar.appendChild(onBtn);
  } else {
    const offBtn = document.createElement('button');
    offBtn.type = 'button';
    offBtn.className = 'poll-host-btn';
    offBtn.setAttribute('data-host-action', 'deactivate');
    offBtn.setAttribute('data-poll-id', pollId);
    offBtn.textContent = 'Turn off';
    bar.appendChild(offBtn);
  }
  const ed = document.createElement('button');
  ed.type = 'button';
  ed.className = 'poll-host-btn poll-host-btn--secondary';
  ed.setAttribute('data-host-action', 'edit');
  ed.setAttribute('data-poll-id', pollId);
  ed.textContent = 'Edit';
  bar.appendChild(ed);
  const del = document.createElement('button');
  del.type = 'button';
  del.className = 'poll-host-btn poll-host-btn--danger';
  del.setAttribute('data-host-action', 'delete');
  del.setAttribute('data-poll-id', pollId);
  del.textContent = 'Delete';
  bar.appendChild(del);
  return bar;
}

function buildComposeCard() {
  const isEdit = hostPollUiMode === 'edit' && hostEditPollId;
  const src = isEdit && pollsData[hostEditPollId] ? pollsData[hostEditPollId] : null;
  const question = src ? (src.question || '') : '';
  const options = src && src.options && src.options.length
    ? src.options.slice()
    : ['', ''];
  const isAct = src ? src.is_active !== false : true;

  const wrap = document.createElement('div');
  wrap.className = 'poll-item active poll-item--compose';

  const top = document.createElement('div');
  top.className = 'poll-compose-top';
  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.className = 'poll-compose-cancel';
  cancel.setAttribute('data-compose-action', 'cancel');
  cancel.textContent = 'Cancel';
  top.appendChild(cancel);
  wrap.appendChild(top);

  const header = document.createElement('div');
  header.className = 'poll-header poll-header--compose';
  const qInput = document.createElement('input');
  qInput.type = 'text';
  qInput.className = 'poll-question poll-question-input';
  qInput.id = 'polls-compose-question';
  qInput.maxLength = 200;
  qInput.placeholder = 'Question';
  qInput.value = question;
  header.appendChild(qInput);
  wrap.appendChild(header);

  if (isEdit) {
    const h = document.createElement('p');
    h.className = 'poll-compose-hint';
    h.textContent = 'Editing poll — it will look like this to everyone when you save.';
    wrap.appendChild(h);
  } else {
    const h = document.createElement('p');
    h.className = 'poll-compose-hint';
    h.textContent = 'This preview matches what members see. Add at least two choices.';
    wrap.appendChild(h);
  }

  const list = document.createElement('div');
  list.className = 'poll-options';
  list.id = 'polls-compose-options';
  options.forEach((opt, i) => {
    const row = document.createElement('div');
    row.className = 'poll-option poll-option--compose';
    const inner = document.createElement('input');
    inner.type = 'text';
    inner.className = 'poll-option-input';
    inner.placeholder = 'Option ' + (i + 1);
    inner.maxLength = 120;
    inner.value = opt;
    const rm = document.createElement('button');
    rm.type = 'button';
    rm.className = 'poll-option-remove';
    rm.setAttribute('data-compose', 'remove-option');
    rm.setAttribute('aria-label', 'Remove');
    rm.textContent = '×';
    if (options.length <= 2) {
      rm.style.display = 'none';
    }
    row.appendChild(inner);
    row.appendChild(rm);
    list.appendChild(row);
  });
  wrap.appendChild(list);

  const addRow = document.createElement('button');
  addRow.type = 'button';
  addRow.className = 'poll-compose-add';
  addRow.setAttribute('data-compose-action', 'add-option');
  addRow.textContent = 'Add another choice';
  wrap.appendChild(addRow);

  const actRow = document.createElement('div');
  actRow.className = 'poll-compose-active-row';
  const lab = document.createElement('label');
  lab.className = 'poll-compose-active-label';
  const cb = document.createElement('input');
  cb.type = 'checkbox';
  cb.id = 'polls-compose-active';
  cb.checked = isAct;
  const span = document.createElement('span');
  span.textContent = 'Active (members can vote when on)';
  lab.appendChild(cb);
  lab.appendChild(span);
  actRow.appendChild(lab);
  wrap.appendChild(actRow);

  const actions = document.createElement('div');
  actions.className = 'poll-compose-bar';
  const save = document.createElement('button');
  save.type = 'button';
  save.className = 'poll-compose-save';
  save.setAttribute('data-compose-action', 'save');
  save.textContent = isEdit ? 'Save changes' : 'Create poll';
  actions.appendChild(save);
  wrap.appendChild(actions);

  return wrap;
}

async function runHostSaveCompose() {
  if (!isPollHost() || !clubDb) return;
  const mid = window.meetingId;
  const uid = window.creatorId;
  const q = document.getElementById('polls-compose-question');
  const wrap = document.getElementById('polls-compose-options');
  const actEl = document.getElementById('polls-compose-active');
  if (!q || !wrap) return;
  const question = (q.value || '').trim();
  const options = Array.from(wrap.querySelectorAll('.poll-option-input'))
    .map((i) => (i.value || '').trim())
    .filter((o) => o.length > 0);
  const isAct = actEl ? actEl.checked : true;
  if (!question) {
    showPollsError('Add a question');
    return;
  }
  if (options.length < 2) {
    showPollsError('Add at least 2 different choices');
    return;
  }
  const coll = clubDb.collection('users').doc(uid).collection('meetings').doc(mid).collection('polls');
  try {
    if (hostPollUiMode === 'edit' && hostEditPollId) {
      const ref = coll.doc(hostEditPollId);
      const ex = await ref.get();
      if (!ex.exists) {
        showPollsError('Poll not found');
        return;
      }
      const d = ex.data();
      const existingTallies = d.tallies || {};
      const existingOptions = d.options || [];
      const newTallies = {};
      options.forEach((newOpt, index) => {
        if (index < existingOptions.length) {
          const oldAt = existingOptions[index];
          newTallies[newOpt] = existingTallies[oldAt] !== undefined ? existingTallies[oldAt] : 0;
        } else {
          newTallies[newOpt] = 0;
        }
      });
      await ref.update({
        question: question,
        options: options,
        is_active: isAct,
        tallies: newTallies,
        total_responses: d.total_responses || 0,
        device_votes: d.device_votes || {}
      });
      showPollsSuccess('Poll updated');
    } else {
      const id = 'poll_' + Date.now();
      await coll.doc(id).set({
        question: question,
        options: options,
        is_active: isAct,
        tallies: Object.fromEntries(options.map((o) => [o, 0])),
        total_responses: 0,
        device_votes: {},
        created_at: firebase.firestore.FieldValue.serverTimestamp()
      });
      showPollsSuccess('Poll created');
    }
    hostPollUiMode = 'none';
    hostEditPollId = null;
    renderPolls();
  } catch (e) {
    console.error('Host save poll', e);
    showPollsError((e && e.message) || 'Could not save poll');
  }
}

function handleContainerClickForHost(event) {
  if (!isPollHost()) return;
  const t = event.target;
  if (!t) return;
  if (t.closest('input, textarea, select')) {
    if (!t.classList || !t.classList.contains('poll-question-input')) {
      return;
    }
  }
  const compose = event.target && event.target.closest && event.target.closest('.poll-item--compose');
  if (compose) {
    const a = event.target && event.target.closest && event.target.closest('[data-compose-action]');
    if (a) {
      event.preventDefault();
      const what = a.getAttribute('data-compose-action');
      if (what === 'cancel') {
        closeHostCompose();
        return;
      }
      if (what === 'save') {
        runHostSaveCompose();
        return;
      }
      if (what === 'add-option') {
        const list = document.getElementById('polls-compose-options');
        if (!list) return;
        const count = list.children.length;
        const row = document.createElement('div');
        row.className = 'poll-option poll-option--compose';
        const inner = document.createElement('input');
        inner.type = 'text';
        inner.className = 'poll-option-input';
        inner.placeholder = 'Option ' + (count + 1);
        inner.maxLength = 120;
        const rm = document.createElement('button');
        rm.type = 'button';
        rm.className = 'poll-option-remove';
        rm.setAttribute('data-compose', 'remove-option');
        rm.textContent = '×';
        row.appendChild(inner);
        row.appendChild(rm);
        list.appendChild(row);
        list.querySelectorAll('.poll-option-remove').forEach((b) => {
          b.style.display = list.children.length > 2 ? 'inline-block' : 'none';
        });
        return;
      }
    }
    if ((t.closest && t.closest('.poll-option-remove')) || (t.classList && t.classList.contains('poll-option-remove'))) {
      const btn = t.closest ? t.closest('.poll-option-remove') : t;
      if (!btn) return;
      event.preventDefault();
      const list = document.getElementById('polls-compose-options');
      if (!list || list.children.length <= 2) return;
      btn.parentElement && btn.parentElement.remove();
      list.querySelectorAll('.poll-option-remove').forEach((b) => {
        b.style.display = list.children.length > 2 ? 'inline-block' : 'none';
      });
    }
    return;
  }
  const hostA = t.closest && t.closest('[data-host-action]');
  if (!hostA) return;
  event.preventDefault();
  event.stopPropagation();
  const pollId = hostA.getAttribute('data-poll-id');
  const action = hostA.getAttribute('data-host-action');
  if (!pollId) return;
  if (action === 'edit') {
    openHostEditPoll(pollId);
    return;
  }
  if (action === 'delete') {
    if (window.showHostPollDeleteDialog) window.showHostPollDeleteDialog(pollId);
    return;
  }
  if (action === 'activate' || action === 'deactivate') {
    showHostPollToggleDialog(pollId, action === 'activate');
  }
}

function showHostPollToggleDialog(pollId, willBeActive) {
  const overlay = document.getElementById('polls-toggle-dialog-overlay');
  if (!overlay) return;
  overlay.setAttribute('data-poll-id', pollId);
  overlay.setAttribute('data-will-be-active', willBeActive ? '1' : '0');
  const titleEl = document.getElementById('polls-toggle-dialog-title');
  const msg = document.getElementById('polls-toggle-dialog-message');
  const btn = document.getElementById('polls-toggle-confirm-btn');
  if (willBeActive) {
    if (titleEl) titleEl.textContent = 'Turn this poll on?';
    if (msg) {
      msg.textContent = 'This poll will show in the meeting for all members, and they can cast votes. Continue?';
    }
    if (btn) btn.textContent = 'Turn on';
  } else {
    if (titleEl) titleEl.textContent = 'Turn this poll off?';
    if (msg) {
      msg.textContent = 'Members will not see this poll in their list. Existing vote counts are kept, and you can turn it on again later. Continue?';
    }
    if (btn) btn.textContent = 'Turn off';
  }
  if (btn) btn.disabled = false;
  overlay.classList.add('active');
  document.body.style.overflow = 'hidden';
}

function hideHostPollToggleDialog() {
  const overlay = document.getElementById('polls-toggle-dialog-overlay');
  if (!overlay) return;
  overlay.classList.remove('active');
  const pollsO = document.getElementById('polls-viewer-overlay');
  if (pollsO && pollsO.style.display !== 'none') {
    document.body.style.overflow = 'hidden';
  } else {
    document.body.style.overflow = '';
  }
  overlay.removeAttribute('data-poll-id');
  overlay.removeAttribute('data-will-be-active');
  const btn = document.getElementById('polls-toggle-confirm-btn');
  if (btn) {
    btn.disabled = false;
    btn.textContent = 'Confirm';
  }
}

async function confirmHostPollToggle() {
  const overlay = document.getElementById('polls-toggle-dialog-overlay');
  if (!overlay) return;
  const pollId = overlay.getAttribute('data-poll-id');
  const w = overlay.getAttribute('data-will-be-active');
  const willBeActive = w === '1';
  if (!pollId) return;
  const btn = document.getElementById('polls-toggle-confirm-btn');
  if (btn) btn.disabled = true;
  hideHostPollToggleDialog();
  await hostSetPollActive(pollId, willBeActive);
}

async function hostSetPollActive(pollId, active) {
  if (!isPollHost() || !clubDb) return;
  const mid = window.meetingId;
  const uid = window.creatorId;
  if (!mid || !uid) return;
  try {
    await clubDb
      .collection('users')
      .doc(uid)
      .collection('meetings')
      .doc(mid)
      .collection('polls')
      .doc(pollId)
      .update({ is_active: active });
    if (showPollsSuccess) showPollsSuccess(active ? 'Poll is on' : 'Poll is off');
  } catch (e) {
    if (showPollsError) showPollsError((e && e.message) || 'Could not update');
  }
}

let hostPollsCardClickBound = false;
function ensureHostPollsCardListener() {
  if (hostPollsCardClickBound) return;
  const container = document.getElementById('polls-container');
  if (!container) return;
  hostPollsCardClickBound = true;
  container.addEventListener('click', handleContainerClickForHost, true);
}

// Render polls — same look for host & guest; host gets tabs for all + compose + action bar
function renderPolls() {
  if (window.updatePollsHintForHost) {
    window.updatePollsHintForHost();
  }
  updateHostPollsToolbar();
  const container = document.getElementById('polls-container');
  if (!container) return;
  ensureHostPollsCardListener();

  container.removeEventListener('click', handlePollOptionClickDelegated);
  container.removeEventListener('click', handlePollTabClickDelegated);

  if (isPollHost() && (hostPollUiMode === 'create' || hostPollUiMode === 'edit')) {
    container.innerHTML = '';
    const frag = document.createDocumentFragment();
    const c = buildComposeCard();
    frag.appendChild(c);
    container.appendChild(frag);
    updatePollsVotingOverlay();
    return;
  }

  const display = getDisplayPollsOrder();

  if (display.length === 0) {
    if (isPollHost()) {
      container.innerHTML = '';
      const empty = document.createElement('div');
      empty.className = 'polls-vote-empty-host';
      const t = document.createElement('p');
      t.className = 'polls-loading';
      t.textContent = 'No polls yet.';
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'polls-empty-add';
      b.textContent = 'Add a poll';
      b.onclick = (e) => {
        e.preventDefault();
        openHostCreatePoll();
      };
      empty.appendChild(t);
      empty.appendChild(b);
      container.appendChild(empty);
    } else {
      container.innerHTML = '<div class="polls-loading">No active polls available</div>';
    }
    updatePollsVotingOverlay();
    return;
  }

  if (selectedPollIndex < 0 || selectedPollIndex >= display.length) {
    selectedPollIndex = 0;
  }

  const selectedPollId = display[selectedPollIndex];
  const poll = pollsData[selectedPollId];
  if (!poll) {
    container.innerHTML = '<div class="polls-loading">Error loading poll</div>';
    updatePollsVotingOverlay();
    return;
  }

  const fragment = document.createDocumentFragment();
  const tabsContainer = document.createElement('div');
  tabsContainer.className = 'polls-tabs-container';
  display.forEach((pid, index) => {
    const pObj = pollsData[pid];
    if (!pObj) return;
    const isInact = pObj.is_active === false;
    const isSelected = index === selectedPollIndex;
    const tab = document.createElement('div');
    tab.className = `polls-tab ${isSelected ? 'selected' : ''} ${isVoting ? 'disabled' : ''} ${isInact && isPollHost() ? 'inactive' : ''}`.replace(/\s+/g, ' ').trim();
    tab.setAttribute('data-poll-index', String(index));
    tab.style.cursor = isVoting ? 'not-allowed' : 'pointer';
    const tabNumber = document.createElement('span');
    tabNumber.className = 'polls-tab-number';
    tabNumber.textContent = String(index + 1);
    tab.appendChild(tabNumber);
    tabsContainer.appendChild(tab);
  });
  fragment.appendChild(tabsContainer);

  const isActive = poll.is_active !== false;
  const canVote = isActive && !isVoting;
  const selectedOption = userVotes[selectedPollId];

  const pollItem = document.createElement('div');
  pollItem.className = 'poll-item active';
  pollItem.id = safePollItemElementId(selectedPollId);

  if (isPollHost()) {
    if (!isActive) {
      const badge = document.createElement('div');
      badge.className = 'poll-inactive-badge';
      badge.textContent = 'This poll is off';
      pollItem.appendChild(badge);
    }
    const bar = buildHostActionBar(selectedPollId);
    pollItem.appendChild(bar);
  }

  const pollHeader = document.createElement('div');
  pollHeader.className = 'poll-header';
  const pollQuestion = document.createElement('div');
  pollQuestion.className = 'poll-question';
  pollQuestion.textContent = poll.question || '';
  pollHeader.appendChild(pollQuestion);
  pollItem.appendChild(pollHeader);

  const pollOptions = document.createElement('div');
  pollOptions.className = 'poll-options';

  poll.options.forEach((option) => {
    const isSel = selectedOption === option;
    const isVotingThis = isVoting && votingPollId === selectedPollId && votingOption === option;
    const optionDiv = document.createElement('div');
    const den = !canVote;
    optionDiv.className = `poll-option ${isSel ? 'selected' : ''} ${isVotingThis ? 'voting' : ''} ${den ? 'disabled' : ''}`.replace(/\s+/g, ' ').trim();
    optionDiv.setAttribute('data-poll-id', String(selectedPollId));
    optionDiv.setAttribute('data-option', String(option));
    if (canVote) {
      optionDiv.style.cursor = 'pointer';
    } else {
      optionDiv.style.cursor = 'not-allowed';
    }
    const checkDiv = document.createElement('div');
    checkDiv.className = 'poll-option-check';
    if (isVotingThis) {
      const spinner = document.createElement('div');
      spinner.className = 'poll-option-loading';
      checkDiv.appendChild(spinner);
    } else if (isSel) {
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('fill', 'none');
      svg.setAttribute('stroke', 'currentColor');
      svg.setAttribute('viewBox', '0 0 24 24');
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('stroke-linecap', 'round');
      path.setAttribute('stroke-linejoin', 'round');
      path.setAttribute('stroke-width', '2');
      path.setAttribute('d', 'M5 13l4 4L19 7');
      svg.appendChild(path);
      checkDiv.appendChild(svg);
    }
    const optionText = document.createElement('div');
    optionText.className = 'poll-option-text';
    optionText.textContent = option || '';
    optionDiv.appendChild(checkDiv);
    optionDiv.appendChild(optionText);
    pollOptions.appendChild(optionDiv);
  });
  pollItem.appendChild(pollOptions);
  fragment.appendChild(pollItem);

  container.innerHTML = '';
  container.appendChild(fragment);
  container.addEventListener('click', handlePollOptionClickDelegated);
  container.addEventListener('click', handlePollTabClickDelegated);
  updatePollsVotingOverlay();
}

function handlePollTabClickDelegated(event) {
  const tab = event.target && event.target.closest && event.target.closest('.polls-tab');
  if (!tab) return;
  if (tab.classList.contains('disabled') || isVoting) return;
  const indexStr = tab.getAttribute('data-poll-index');
  if (indexStr === null) return;
  const index = parseInt(indexStr, 10);
  if (isNaN(index)) return;
  switchPollTab(index);
}

function handlePollOptionClickDelegated(event) {
  if (isPollHost() && event.target && event.target.closest && event.target.closest('.poll-item--compose')) {
    return;
  }
  const optionDiv = event.target && event.target.closest && event.target.closest('.poll-option');
  if (!optionDiv) return;
  if (optionDiv.classList.contains('disabled') || isVoting) return;
  if (isPollHost() && optionDiv.classList.contains('poll-option--compose')) return;
  const pollId = optionDiv.getAttribute('data-poll-id');
  const option = optionDiv.getAttribute('data-option');
  if (!pollId || !option) return;
  selectPollOption(pollId, option);
}

async function selectPollOption(pollId, option) {
  if (isVoting) {
    return;
  }
  if (!pollId || !option) {
    showPollsError('Invalid poll data');
    return;
  }
  if (isPollHost() && (hostPollUiMode === 'create' || hostPollUiMode === 'edit')) {
    return;
  }
  const deviceId = getPollsDeviceId();
  if (!deviceId) {
    showPollsError('Device ID not available. Please refresh the page.');
    return;
  }
  if (!window.meetingId) {
    showPollsError('Meeting ID not available. Please refresh the page.');
    return;
  }
  const p = pollsData[pollId];
  if (!p) {
    showPollsError('Poll not found');
    return;
  }
  if (p.is_active === false) {
    showPollsError('This poll is not active');
    return;
  }
  if (!p.options.includes(option)) {
    showPollsError('Invalid option selected');
    return;
  }
  isVoting = true;
  votingPollId = pollId;
  votingOption = option;
  renderPolls();
  const pollElement = document.getElementById(safePollItemElementId(pollId));
  if (pollElement) {
    pollElement.classList.add('poll-voting');
  }
  try {
    const clubApp = firebase.app('club');
    if (!clubApp) {
      throw new Error('Firebase app not initialized');
    }
    const functions = firebase.functions(clubApp);
    const submitVote = functions.httpsCallable('submit_vote');
    const result = await submitVote({
      meeting_id: window.meetingId,
      poll_id: pollId,
      option: option,
      device_id: deviceId
    });
    if (!result || !result.data) {
      throw new Error('Invalid response from server');
    }
    if (result.data.success) {
      userVotes[pollId] = option;
    } else {
      throw new Error(result.data.error || 'Failed to submit vote');
    }
  } catch (error) {
    delete userVotes[pollId];
    let errorMessage = 'Failed to submit vote. ';
    if (error.code === 'unavailable') {
      errorMessage += 'Please check your connection.';
    } else if (error.code === 'deadline-exceeded') {
      errorMessage += 'Request timed out. Try again.';
    } else {
      errorMessage += (error && error.message) || 'Please try again.';
    }
    showPollsError(errorMessage);
  } finally {
    isVoting = false;
    votingPollId = null;
    votingOption = null;
    if (pollElement) {
      pollElement.classList.remove('poll-voting');
    }
    renderPolls();
  }
}

function showPollsError(message) {
  const container = document.getElementById('polls-container');
  if (!container) return;
  const existing = container.querySelectorAll('.polls-error, .polls-success');
  existing.forEach((e) => e.remove());
  const err = document.createElement('div');
  err.className = 'polls-error';
  err.textContent = message;
  container.insertBefore(err, container.firstChild);
  setTimeout(() => { if (err.parentNode) err.remove(); }, 5000);
}

function showPollsSuccess(message) {
  const container = document.getElementById('polls-container');
  if (!container) return;
  const existing = container.querySelectorAll('.polls-error, .polls-success');
  existing.forEach((e) => e.remove());
  const o = document.createElement('div');
  o.className = 'polls-success';
  o.textContent = message;
  container.insertBefore(o, container.firstChild);
  setTimeout(() => { if (o.parentNode) o.remove(); }, 3000);
}

function showHostPollDeleteDialog(pollId) {
  const overlay = document.getElementById('polls-delete-dialog-overlay');
  if (!overlay) return;
  overlay.setAttribute('data-poll-id', pollId);
  if (window.meetingId) overlay.setAttribute('data-meeting-id', window.meetingId);
  const delBtn = document.getElementById('polls-delete-confirm-btn');
  if (delBtn) {
    delBtn.disabled = false;
    delBtn.textContent = 'Delete';
  }
  overlay.classList.add('active');
  document.body.style.overflow = 'hidden';
}
function hideHostPollDeleteDialog() {
  const overlay = document.getElementById('polls-delete-dialog-overlay');
  if (!overlay) return;
  overlay.classList.remove('active');
  const pollsO = document.getElementById('polls-viewer-overlay');
  if (pollsO && pollsO.style.display !== 'none') {
    document.body.style.overflow = 'hidden';
  } else {
    document.body.style.overflow = '';
  }
  overlay.removeAttribute('data-poll-id');
  overlay.removeAttribute('data-meeting-id');
  const delBtn = document.getElementById('polls-delete-confirm-btn');
  if (delBtn) {
    delBtn.disabled = false;
    delBtn.textContent = 'Delete';
  }
}
async function confirmHostPollDelete() {
  const overlay = document.getElementById('polls-delete-dialog-overlay');
  if (!overlay) return;
  const pollId = overlay.getAttribute('data-poll-id');
  const meetingId = overlay.getAttribute('data-meeting-id') || window.meetingId;
  const uid = window.creatorId;
  const delBtn = document.getElementById('polls-delete-confirm-btn');
  if (!pollId || !meetingId || !uid || !clubDb) return;
  if (delBtn) {
    delBtn.disabled = true;
    delBtn.textContent = 'Deleting…';
  }
  try {
    await clubDb
      .collection('users')
      .doc(uid)
      .collection('meetings')
      .doc(meetingId)
      .collection('polls')
      .doc(pollId)
      .delete();
    hideHostPollDeleteDialog();
    if (hostEditPollId === pollId) {
      hostPollUiMode = 'none';
      hostEditPollId = null;
    }
    showPollsSuccess('Poll deleted');
    renderPolls();
  } catch (e) {
    showPollsError((e && e.message) || 'Could not delete');
    if (delBtn) {
      delBtn.disabled = false;
      delBtn.textContent = 'Delete';
    }
  }
}
window.showHostPollDeleteDialog = showHostPollDeleteDialog;
window.hideHostPollDeleteDialog = hideHostPollDeleteDialog;
window.confirmHostPollDelete = confirmHostPollDelete;
window.showHostPollToggleDialog = showHostPollToggleDialog;
window.hideHostPollToggleDialog = hideHostPollToggleDialog;
window.confirmHostPollToggle = confirmHostPollToggle;

window.showPollsSuccess = showPollsSuccess;
window.showPollsError = showPollsError;
window.openHostCreatePoll = openHostCreatePoll;
window.closeHostCompose = closeHostCompose;
window.getDisplayPollsOrder = getDisplayPollsOrder;
window.updatePollsHintForHost = function() {
  const g = document.getElementById('polls-viewer-hint-guest');
  const h = document.getElementById('polls-viewer-hint-host');
  if (!g || !h) return;
  if (isPollHost()) {
    g.style.display = 'none';
    h.style.display = 'block';
  } else {
    g.style.display = 'block';
    h.style.display = 'none';
  }
};
