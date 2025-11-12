/**
 * Main page functionality
 */

const codeInput = document.getElementById('codeInput');
const joinButton = document.getElementById('joinButton');
const joinButtonText = document.getElementById('joinButtonText');
const loginButton = document.getElementById('loginButton');

// Login overlay elements
const loginOverlay = document.getElementById('loginOverlay');
const closeLoginOverlay = document.getElementById('closeLoginOverlay');
const loginOverlayForm = document.getElementById('loginOverlayForm');

// Login button click handler - show overlay
if (loginButton) {
  loginButton.addEventListener('click', function() {
    if (loginOverlay) {
      loginOverlay.classList.add('show');
      // Focus on email input when overlay opens
      const emailInput = document.getElementById('loginEmailInput');
      if (emailInput) {
        setTimeout(() => emailInput.focus(), 100);
      }
    }
  });
}

// Close overlay handlers
if (closeLoginOverlay) {
  closeLoginOverlay.addEventListener('click', function() {
    if (loginOverlay) {
      loginOverlay.classList.remove('show');
    }
  });
}

// Close overlay on Escape key
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape' && loginOverlay && loginOverlay.classList.contains('show')) {
    loginOverlay.classList.remove('show');
  }
});

// Tab switching
const authTabs = document.querySelectorAll('.auth-tab');
const authTabContents = document.querySelectorAll('.auth-tab-content');

authTabs.forEach(tab => {
  tab.addEventListener('click', function() {
    const targetTab = this.getAttribute('data-tab');
    
    // Remove active class from all tabs and contents
    authTabs.forEach(t => t.classList.remove('active'));
    authTabContents.forEach(c => c.classList.remove('active'));
    
    // Add active class to clicked tab and corresponding content
    this.classList.add('active');
    const targetContent = document.getElementById(targetTab + 'Tab');
    if (targetContent) {
      targetContent.classList.add('active');
    }
  });
});

// Password visibility toggle
function setupPasswordToggle(toggleId, inputId) {
  const toggle = document.getElementById(toggleId);
  const input = document.getElementById(inputId);
  
  if (toggle && input) {
    toggle.addEventListener('click', function() {
      const isPassword = input.type === 'password';
      input.type = isPassword ? 'text' : 'password';
      
      const eyeIcon = toggle.querySelector('.eye-icon');
      const eyeOffIcon = toggle.querySelector('.eye-off-icon');
      
      if (eyeIcon && eyeOffIcon) {
        if (isPassword) {
          eyeIcon.style.display = 'none';
          eyeOffIcon.style.display = 'block';
        } else {
          eyeIcon.style.display = 'block';
          eyeOffIcon.style.display = 'none';
        }
      }
    });
  }
}

// Setup all password toggles
setupPasswordToggle('loginPasswordToggle', 'loginPasswordInput');
setupPasswordToggle('signupPasswordToggle', 'signupPasswordInput');
setupPasswordToggle('signupConfirmPasswordToggle', 'signupConfirmPasswordInput');

// Login form submission handler
if (loginOverlayForm) {
  loginOverlayForm.addEventListener('submit', async function(e) {
    e.preventDefault();
    
    const emailInput = document.getElementById('loginEmailInput');
    const passwordInput = document.getElementById('loginPasswordInput');
    const loginSubmitButton = document.getElementById('loginSubmitButton');
    const loginButtonText = document.getElementById('loginButtonText');
    
    const email = emailInput.value.trim();
    const password = passwordInput.value;
    
    // Validation
    if (!email) {
      showNotification('Please enter your email', 'error');
      return;
    }
    
    if (!password) {
      showNotification('Please enter your password', 'error');
      return;
    }
    
    // Show loading state
    loginSubmitButton.disabled = true;
    loginButtonText.innerHTML = '<span class="spinner"></span>';
    
    // Handle login
    const success = await handleLogin(email, password);
    
    if (!success) {
      loginSubmitButton.disabled = false;
      loginButtonText.textContent = 'Login';
    }
  });
}

// Sign up form submission handler
const signupOverlayForm = document.getElementById('signupOverlayForm');
if (signupOverlayForm) {
  signupOverlayForm.addEventListener('submit', async function(e) {
    e.preventDefault();
    
    const emailInput = document.getElementById('signupEmailInput');
    const passwordInput = document.getElementById('signupPasswordInput');
    const confirmPasswordInput = document.getElementById('signupConfirmPasswordInput');
    const signupSubmitButton = document.getElementById('signupSubmitButton');
    const signupButtonText = document.getElementById('signupButtonText');
    
    const email = emailInput.value.trim();
    const password = passwordInput.value;
    const confirmPassword = confirmPasswordInput.value;
    
    // Validation
    if (!email) {
      showNotification('Please enter your email', 'error');
      return;
    }
    
    if (!password) {
      showNotification('Please enter a password', 'error');
      return;
    }
    
    if (password.length < 6) {
      showNotification('Password must be at least 6 characters', 'error');
      return;
    }
    
    if (password !== confirmPassword) {
      showNotification('Passwords do not match', 'error');
      return;
    }
    
    // Show loading state
    signupSubmitButton.disabled = true;
    signupButtonText.innerHTML = '<span class="spinner"></span>';
    
    // Handle sign up
    const success = await handleSignUp(email, password);
    
    if (!success) {
      signupSubmitButton.disabled = false;
      signupButtonText.textContent = 'Sign Up';
    }
  });
}

// Reset password form submission handler
const resetOverlayForm = document.getElementById('resetOverlayForm');
if (resetOverlayForm) {
  resetOverlayForm.addEventListener('submit', async function(e) {
    e.preventDefault();
    
    const emailInput = document.getElementById('resetEmailInput');
    const resetSubmitButton = document.getElementById('resetSubmitButton');
    const resetButtonText = document.getElementById('resetButtonText');
    
    const email = emailInput.value.trim();
    
    // Validation
    if (!email) {
      showNotification('Please enter your email', 'error');
      return;
    }
    
    // Show loading state
    resetSubmitButton.disabled = true;
    resetButtonText.innerHTML = '<span class="spinner"></span>';
    
    // Handle reset password
    const success = await handleResetPassword(email);
    
    // Reset button state (same for success or failure)
    resetSubmitButton.disabled = false;
    resetButtonText.textContent = 'Send Link';
    
    if (success) {
      // Clear the form on success
      emailInput.value = '';
    }
  });
}

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

