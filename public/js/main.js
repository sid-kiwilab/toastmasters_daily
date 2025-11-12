/**
 * Main page functionality
 */

const codeInput = document.getElementById('codeInput');
const joinButton = document.getElementById('joinButton');
const joinButtonText = document.getElementById('joinButtonText');

// Format input to "1234 5678" - strictly limit to 8 digits
codeInput.addEventListener('input', function(e) {
  let digits = e.target.value.replace(/\D/g, '');
  // Hard limit to 8 digits
  digits = digits.substring(0, 8);
  
  // Format with space after 4 digits
  if (digits.length > 4) {
    e.target.value = digits.substring(0, 4) + ' ' + digits.substring(4, 8);
  } else {
    e.target.value = digits;
  }
});

// Block 9th digit - prevent any input that would exceed 8 digits
codeInput.addEventListener('keydown', function(e) {
  // Allow navigation and editing keys
  if (['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab', 'Enter'].includes(e.key) || e.ctrlKey || e.metaKey) {
    return;
  }
  
  // Check if trying to add a digit when we already have 8
  const digits = codeInput.value.replace(/\D/g, '');
  if (digits.length >= 8 && /^[0-9]$/.test(e.key)) {
    e.preventDefault();
    e.stopPropagation();
    e.stopImmediatePropagation();
    return false;
  }
}, true);

// Also block on paste
codeInput.addEventListener('paste', function(e) {
  e.preventDefault();
  const pasted = (e.clipboardData || window.clipboardData).getData('text');
  const digits = pasted.replace(/\D/g, '').substring(0, 8);
  const currentDigits = codeInput.value.replace(/\D/g, '');
  const totalDigits = (currentDigits + digits).substring(0, 8);
  
  if (totalDigits.length > 4) {
    codeInput.value = totalDigits.substring(0, 4) + ' ' + totalDigits.substring(4, 8);
  } else {
    codeInput.value = totalDigits;
  }
});

// Handle Enter key
codeInput.addEventListener('keypress', function(e) {
  if (e.key === 'Enter') {
    handleJoin();
  }
});

// Join button click
joinButton.addEventListener('click', handleJoin);

async function handleJoin() {
  const code = codeInput.value.trim();
  const digitsOnly = code.replace(/\D/g, '');

  // Validation checks
  if (digitsOnly.length === 0) {
    showNotification('Please enter a meeting code');
    return;
  }

  if (digitsOnly.length !== 8) {
    showNotification('Code must be 8 digits');
    return;
  }

  // Show loading state
  joinButton.disabled = true;
  joinButtonText.innerHTML = '<span class="spinner"></span>';

  try {
    // Check if meeting exists in Firestore
    const meetingExists = await checkMeetingExists(digitsOnly);
    
    if (!meetingExists) {
      showNotification('Meeting not found. Please check your code.');
      joinButton.disabled = false;
      joinButtonText.textContent = 'Join';
      return;
    }

    // Meeting exists, navigate to it
    window.location.href = `/meetings/${digitsOnly}`;
  } catch (error) {
    console.error('Error checking meeting:', error);
    showNotification('Error checking meeting. Please try again.');
    joinButton.disabled = false;
    joinButtonText.textContent = 'Join';
  }
}

