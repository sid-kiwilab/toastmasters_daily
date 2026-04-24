// Evaluations

function setupEvalsListener(meetingId, creatorId) {
  if (!clubDb || !meetingId || !creatorId) return;
  const card = document.getElementById('evals-card');
  if (card) card.onclick = (e) => { e.preventDefault(); showEvalsViewer(); };
  if (evalsListener) evalsListener();
  evalsListener = clubDb.collection('users').doc(creatorId).collection('meetings').doc(meetingId).collection('evals')
    .onSnapshot((snap) => {
      evalsData = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      evalsData.sort((a, b) => {
        const ta = (a.updated_at || a.created_at)?.toMillis?.() ?? 0;
        const tb = (b.updated_at || b.created_at)?.toMillis?.() ?? 0;
        return tb - ta;
      });
      const overlay = document.getElementById('evals-viewer-overlay');
      if (overlay && overlay.style.display !== 'none') renderEvals();
    });
}

function showEvalsViewer() {
  document.getElementById('evals-form').reset();
  document.getElementById('evals-form-mode').textContent = 'New evaluation';
  document.getElementById('evals-form').classList.remove('editing');
  document.getElementById('evals-submit-btn').textContent = 'Submit';
  document.getElementById('evals-error').style.display = 'none';
  document.getElementById('evals-viewer-overlay').style.display = 'block';
  document.body.style.overflow = 'hidden';
  renderEvals();
}

function closeEvalsViewer() {
  document.getElementById('evals-viewer-overlay').style.display = 'none';
  document.body.style.overflow = '';
}

function buildEvalsListHtml(evals, deviceId, showActionsOnlyForMine) {
  if (!evals.length) return '<p class="polls-loading">No evaluations yet.</p>';
  const byPerson = {};
  evals.forEach(e => {
    const name = (e.evaluatee || '').trim() || 'Unknown';
    if (!byPerson[name]) byPerson[name] = [];
    byPerson[name].push(e);
  });
  const names = Object.keys(byPerson).sort();
  return names.map(name => {
    const items = byPerson[name];
    return items.map(e => {
      const isMine = e.evaluator_device_id === deviceId;
      const byLine = e.evaluator_display_name ? 'By ' + escapeHtml(e.evaluator_display_name) : 'Anonymous';
      const ts = e.updated_at || e.created_at;
      const timeStr = ts && ts.toDate ? ts.toDate().toLocaleString() : '';
      const showActions = showActionsOnlyForMine ? isMine : true;
      const actionsHtml = showActions && isMine
        ? '<div class="evals-item-actions"><button type="button" class="evals-item-edit" data-eval-id="' + escapeHtml(e.id) + '">Edit</button><button type="button" class="evals-item-delete" data-eval-id="' + escapeHtml(e.id) + '">Delete</button></div>'
        : '';
      const content = e.content || '';
      const truncated = content.length > 200 ? content.slice(0, 200) + '…' : content;
      const moreBtn = content.length > 200 ? '<button type="button" class="evals-item-more" data-eval-id="' + escapeHtml(e.id) + '">Show more</button>' : '';
      return '<div class="evals-item" data-eval-id="' + escapeHtml(e.id) + '">' +
        '<div class="evals-item-for">Evaluation for <span class="evals-item-for-name">' + escapeHtml(name) + '</span></div>' +
        '<div class="evals-item-content">' + escapeHtml(truncated) + '</div>' + moreBtn +
        '<div class="evals-item-by">' + byLine + (timeStr ? ' · ' + timeStr : '') + '</div>' +
        actionsHtml + '</div>';
    }).join('');
  }).join('');
}

function renderEvals() {
  const list = document.getElementById('evals-list');
  if (!list) return;
  const deviceId = getPollsDeviceId();
  list.innerHTML = buildEvalsListHtml(evalsData, deviceId, true);
  const container = document.getElementById('evals-viewer-overlay');
  if (!container) return;
  container.querySelectorAll('.evals-item-edit').forEach(el => {
    el.onclick = () => {
      const ev = evalsData.find(x => x.id === el.getAttribute('data-eval-id'));
      if (!ev) return;
      editingEvalId = ev.id;
      document.getElementById('evals-evaluatee').value = ev.evaluatee || '';
      document.getElementById('evals-content').value = ev.content || '';
      document.getElementById('evals-display-name').value = ev.evaluator_display_name || '';
      document.getElementById('evals-submit-btn').textContent = 'Update';
      document.getElementById('evals-form-mode').textContent = 'Editing evaluation';
      document.getElementById('evals-form').classList.add('editing');
      document.getElementById('evals-form').scrollIntoView({ behavior: 'smooth', block: 'start' });
    };
  });
  container.querySelectorAll('.evals-item-delete').forEach(el => {
    el.onclick = () => showEvalsDeleteDialog(el.getAttribute('data-eval-id'));
  });
  container.querySelectorAll('.evals-item-more').forEach(el => {
    el.onclick = () => {
      const card = el.closest('.evals-item');
      const ev = evalsData.find(x => x.id === card.getAttribute('data-eval-id'));
      if (!ev) return;
      const contentDiv = card.querySelector('.evals-item-content');
      if (!contentDiv) return;
      const full = ev.content || '';
      if (el.textContent === 'Show more') {
        contentDiv.textContent = full;
        el.textContent = 'Show less';
      } else {
        contentDiv.textContent = full.length > 200 ? full.slice(0, 200) + '…' : full;
        el.textContent = 'Show more';
      }
    };
  });
}

function showEvalsDeleteDialog(evalId) {
  evalToDeleteId = evalId;
  const btn = document.getElementById('evals-delete-confirm-btn');
  btn.textContent = 'Delete';
  btn.disabled = false;
  document.getElementById('evals-delete-dialog-overlay').classList.add('active');
  btn.onclick = async () => {
    if (!evalToDeleteId) return;
    btn.textContent = 'Deleting...';
    btn.disabled = true;
    await deleteEval(evalToDeleteId);
    hideEvalsDeleteDialog();
  };
}

function hideEvalsDeleteDialog() {
  document.getElementById('evals-delete-dialog-overlay').classList.remove('active');
  const btn = document.getElementById('evals-delete-confirm-btn');
  btn.textContent = 'Delete';
  btn.disabled = false;
  evalToDeleteId = null;
}

async function deleteEval(evalId) {
  const errEl = document.getElementById('evals-error');
  errEl.style.display = 'none';
  try {
    const submitEvalFn = firebase.functions(firebase.app('club')).httpsCallable('delete_eval');
    const result = await submitEvalFn({ meeting_id: window.meetingId, device_id: getPollsDeviceId(), eval_id: evalId });
    if (result.data && result.data.success) {
      if (editingEvalId === evalId) {
        document.getElementById('evals-form').reset();
        document.getElementById('evals-form-mode').textContent = 'New evaluation';
        document.getElementById('evals-form').classList.remove('editing');
        document.getElementById('evals-submit-btn').textContent = 'Submit';
        editingEvalId = null;
      }
      renderEvals();
    } else {
      errEl.textContent = result.data?.error || 'Could not delete.';
      errEl.style.display = 'block';
    }
  } catch (e) {
    errEl.textContent = e.message || 'Could not delete.';
    errEl.style.display = 'block';
  }
}

async function submitEval(event) {
  event.preventDefault();
  const evaluatee = document.getElementById('evals-evaluatee').value.trim();
  const content = document.getElementById('evals-content').value.trim();
  const displayName = document.getElementById('evals-display-name').value.trim();
  const errEl = document.getElementById('evals-error');
  const btn = document.getElementById('evals-submit-btn');
  if (!evaluatee || !content) {
    errEl.textContent = 'Please fill who you\'re evaluating and your feedback.';
    errEl.style.display = 'block';
    return false;
  }
  errEl.style.display = 'none';
  btn.disabled = true;
  btn.textContent = 'Sending...';
  try {
    const submitEvalFn = firebase.functions(firebase.app('club')).httpsCallable('submit_eval');
    const result = await submitEvalFn({ meeting_id: window.meetingId, device_id: getPollsDeviceId(), evaluatee, content, evaluator_display_name: displayName || null });
    if (result.data && result.data.success) {
      document.getElementById('evals-form').reset();
      document.getElementById('evals-form-mode').textContent = 'New evaluation';
      document.getElementById('evals-form').classList.remove('editing');
      btn.textContent = 'Submit';
      editingEvalId = null;
      renderEvals();
    } else {
      errEl.textContent = result.data?.error || 'Failed to submit.';
      errEl.style.display = 'block';
    }
  } catch (e) {
    errEl.textContent = e.message || 'Failed to submit.';
    errEl.style.display = 'block';
  }
  btn.disabled = false;
  if (editingEvalId) btn.textContent = 'Update';
  return false;
}

