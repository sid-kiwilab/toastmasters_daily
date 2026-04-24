// Escape HTML
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Polls functionality

// Get device ID for polls (reuses same device ID as guest entry)
function getPollsDeviceId() {
  if (!pollsDeviceId) {
    // Use the same device ID key as guest entry to share device identity
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
    const poll = pollsData[pollId];
    return poll && poll.is_active === true;
  });
  
  if (selectedPollIndex >= activePollsOrder.length) {
    selectedPollIndex = Math.max(0, activePollsOrder.length - 1);
  }
  
  const currentPollsCard = document.getElementById('polls-card');
  if (currentPollsCard) {
    currentPollsCard.style.display = activePollsOrder.length > 0 ? 'flex' : 'none';
  }
  
  checkExistingVotes();
  
  const overlay = document.getElementById('polls-viewer-overlay');
  if (overlay && overlay.style.display !== 'none') {
    renderPolls();
  }
}

// Setup polls listener
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

// Cleanup polls listener
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
      await new Promise(function(resolve) {
        setTimeout(resolve, remaining);
      });
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

// Check existing votes
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

// Show polls viewer
function showPollsViewer() {
  const overlay = document.getElementById('polls-viewer-overlay');
  if (!overlay) {
    console.error('Polls viewer overlay not found');
    return;
  }
  
  // Reset to first poll when opening
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
  renderPolls();
  updatePollsVotingOverlay();
}

// Switch to a different poll tab
function switchPollTab(index) {
  if (isVoting) return; // Don't allow switching while voting
  if (index < 0 || index >= activePollsOrder.length) return;
  
  selectedPollIndex = index;
  renderPolls();
}

// Close polls viewer
function closePollsViewer() {
  pollsRefreshGeneration++;
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

// Render polls
function renderPolls() {
  const container = document.getElementById('polls-container');
  if (!container) return;
  
  if (activePollsOrder.length === 0) {
    container.innerHTML = '<div class="polls-loading">No active polls available</div>';
    updatePollsVotingOverlay();
    return;
  }
  
  // Validate selected index before rendering
  if (selectedPollIndex < 0 || selectedPollIndex >= activePollsOrder.length) {
    selectedPollIndex = 0; // Reset to first poll if invalid
  }
  
  // Use event delegation instead of individual listeners (prevents memory leaks)
  // Always remove old listeners before adding new ones (safe even if doesn't exist)
  container.removeEventListener('click', handlePollOptionClickDelegated);
  container.removeEventListener('click', handlePollTabClickDelegated);
  
  // Use DocumentFragment for better performance
  const fragment = document.createDocumentFragment();
  
  // Create tabs container
  const tabsContainer = document.createElement('div');
  tabsContainer.className = 'polls-tabs-container';
  
  // Create tabs (numbered pills)
  activePollsOrder.forEach((pollId, index) => {
    const poll = pollsData[pollId];
    if (!poll) return;
    
    const isSelected = index === selectedPollIndex;
    const tab = document.createElement('div');
    tab.className = `polls-tab ${isSelected ? 'selected' : ''} ${isVoting ? 'disabled' : ''}`;
    tab.setAttribute('data-poll-index', String(index));
    
    if (!isVoting) {
      tab.style.cursor = 'pointer';
    } else {
      tab.style.cursor = 'not-allowed';
    }
    
    const tabNumber = document.createElement('span');
    tabNumber.className = 'polls-tab-number';
    tabNumber.textContent = String(index + 1);
    
    tab.appendChild(tabNumber);
    tabsContainer.appendChild(tab);
  });
  
  fragment.appendChild(tabsContainer);
  
  // Show only the selected poll (index already validated above)
  const selectedPollId = activePollsOrder[selectedPollIndex];
  if (!selectedPollId) {
    container.innerHTML = '<div class="polls-loading">Error loading poll</div>';
    updatePollsVotingOverlay();
    return;
  }
  
  const poll = pollsData[selectedPollId];
  if (!poll) {
    container.innerHTML = '<div class="polls-loading">Poll data not found</div>';
    updatePollsVotingOverlay();
    return;
  }
  
  const isActive = poll.is_active && !isVoting;
  const selectedOption = userVotes[selectedPollId];
  
  // Create poll item element
  const pollItem = document.createElement('div');
  pollItem.className = 'poll-item active';
  pollItem.id = `poll-${escapeHtml(selectedPollId)}`;
  
  // Poll header
  const pollHeader = document.createElement('div');
  pollHeader.className = 'poll-header';
  
  const pollQuestion = document.createElement('div');
  pollQuestion.className = 'poll-question';
  pollQuestion.textContent = poll.question || '';
  
  pollHeader.appendChild(pollQuestion);
  
  // Poll options
  const pollOptions = document.createElement('div');
  pollOptions.className = 'poll-options';
  
  poll.options.forEach((option) => {
    const isSelected = selectedOption === option;
    const isVotingThisOption = isVoting && votingPollId === selectedPollId && votingOption === option;
    const optionDiv = document.createElement('div');
    optionDiv.className = `poll-option ${isSelected ? 'selected' : ''} ${isVotingThisOption ? 'voting' : ''} ${!isActive ? 'disabled' : ''}`;
    
    // Use data attributes (setAttribute safely handles special characters)
    optionDiv.setAttribute('data-poll-id', String(selectedPollId));
    optionDiv.setAttribute('data-option', String(option));
    
    if (isActive && !isVoting) {
      optionDiv.style.cursor = 'pointer';
    } else {
      optionDiv.style.cursor = 'not-allowed';
    }
    
    const checkDiv = document.createElement('div');
    checkDiv.className = 'poll-option-check';
    
    if (isVotingThisOption) {
      // Show loading spinner
      const spinner = document.createElement('div');
      spinner.className = 'poll-option-loading';
      checkDiv.appendChild(spinner);
    } else if (isSelected) {
      // Show checkmark
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
  
  pollItem.appendChild(pollHeader);
  pollItem.appendChild(pollOptions);
  fragment.appendChild(pollItem);
  
  // Clear and append
  container.innerHTML = '';
  container.appendChild(fragment);
  
  // Use event delegation (single listeners on container, prevents memory leaks)
  container.addEventListener('click', handlePollOptionClickDelegated);
  container.addEventListener('click', handlePollTabClickDelegated);
  
  updatePollsVotingOverlay();
}

// Event delegation handler for poll tabs
function handlePollTabClickDelegated(event) {
  // Find the closest polls-tab element
  const tab = event.target.closest('.polls-tab');
  if (!tab) return;
  
  // Check if disabled or voting
  if (tab.classList.contains('disabled') || isVoting) return;
  
  const indexStr = tab.getAttribute('data-poll-index');
  if (indexStr === null) return;
  
  const index = parseInt(indexStr, 10);
  if (isNaN(index)) return;
  
  switchPollTab(index);
}

// Event delegation handler for poll options (prevents memory leaks from multiple listeners)
function handlePollOptionClickDelegated(event) {
  // Find the closest poll-option element
  const optionDiv = event.target.closest('.poll-option');
  if (!optionDiv) return;
  
  // Check if disabled
  if (optionDiv.classList.contains('disabled') || isVoting) return;
  
  const pollId = optionDiv.getAttribute('data-poll-id');
  const option = optionDiv.getAttribute('data-option');
  
  if (!pollId || !option) {
    console.error('Missing poll ID or option');
    return;
  }
  
  selectPollOption(pollId, option);
}


// Select poll option
async function selectPollOption(pollId, option) {
  // Prevent concurrent votes
  if (isVoting) {
    console.warn('Vote already in progress');
    return;
  }
  
  // Validate inputs
  if (!pollId || !option) {
    showPollsError('Invalid poll data');
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
  
  // Validate poll exists and is active
  const poll = pollsData[pollId];
  if (!poll) {
    showPollsError('Poll not found');
    return;
  }
  
  if (!poll.is_active) {
    showPollsError('This poll is no longer active');
    return;
  }
  
  if (!poll.options.includes(option)) {
    showPollsError('Invalid option selected');
    return;
  }
  
  isVoting = true;
  votingPollId = pollId;
  votingOption = option;
  
  // Re-render to show loading spinner
  renderPolls();
  
  const pollElement = document.getElementById(`poll-${escapeHtml(pollId)}`);
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
      // Update local state optimistically
      userVotes[pollId] = option;
      // Real-time listener will update the UI with actual data
    } else {
      throw new Error(result.data.error || 'Failed to submit vote');
    }
  } catch (error) {
    console.error('Error submitting vote:', error);
    
    // Show user-friendly error message
    let errorMessage = 'Failed to submit vote. ';
    if (error.code === 'unavailable') {
      errorMessage += 'Please check your internet connection and try again.';
    } else if (error.code === 'deadline-exceeded') {
      errorMessage += 'Request timed out. Please try again.';
    } else {
      errorMessage += error.message || 'Please try again.';
    }
    
    showPollsError(errorMessage);

    // Revert optimistic update
    delete userVotes[pollId];
  } finally {
    isVoting = false;
    votingPollId = null;
    votingOption = null;
    
    if (pollElement) {
      pollElement.classList.remove('poll-voting');
    }
    
    // Re-render to remove loading spinner and show checkmark
    renderPolls();
  }
}

// Show polls error message
function showPollsError(message) {
  const container = document.getElementById('polls-container');
  if (!container) return;
  
  // Remove any existing error messages first
  const existingErrors = container.querySelectorAll('.polls-error');
  existingErrors.forEach(err => err.remove());
  
  const errorDiv = document.createElement('div');
  errorDiv.className = 'polls-error';
  errorDiv.style.cssText = 'background: #FEE2E2; color: #DC2626; padding: 12px 16px; border-radius: 8px; margin-bottom: 20px; font-size: 14px;';
  errorDiv.textContent = message;
  
  // Insert at top
  container.insertBefore(errorDiv, container.firstChild);
  
  // Remove after 5 seconds
  setTimeout(() => {
    if (errorDiv.parentNode) {
      errorDiv.remove();
    }
  }, 5000);
}

