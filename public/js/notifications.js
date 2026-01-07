/**
 * Toast Notification System
 * Provides standardized, user-friendly notifications across the website
 */

class NotificationSystem {
  constructor() {
    this.container = null;
    this.init();
  }

  init() {
    // Create notification container if it doesn't exist
    if (!document.getElementById('notification-container')) {
      const container = document.createElement('div');
      container.id = 'notification-container';
      container.style.cssText = `
        position: fixed;
        bottom: 24px;
        right: 24px;
        z-index: 10000;
        display: flex;
        flex-direction: column;
        gap: 12px;
        max-width: 400px;
        pointer-events: none;
      `;
      document.body.appendChild(container);
      this.container = container;
    } else {
      this.container = document.getElementById('notification-container');
    }
  }

  show(message, type = 'info', duration = 5000) {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    
    // Icon based on type
    const icons = {
      success: '✓',
      error: '✕',
      warning: '⚠',
      info: 'ℹ'
    };

    // Colors based on type
    const colors = {
      success: { bg: '#10B981', border: '#059669', icon: '#FFFFFF' },
      error: { bg: '#EF4444', border: '#DC2626', icon: '#FFFFFF' },
      warning: { bg: '#F59E0B', border: '#D97706', icon: '#FFFFFF' },
      info: { bg: '#3B82F6', border: '#2563EB', icon: '#FFFFFF' }
    };

    const color = colors[type] || colors.info;
    const icon = icons[type] || icons.info;

    notification.style.cssText = `
      background: ${color.bg};
      color: white;
      padding: 16px 20px;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
      display: flex;
      align-items: center;
      gap: 12px;
      font-family: 'GoogleSans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
      font-size: 14px;
      line-height: 1.5;
      pointer-events: auto;
      animation: slideInRight 0.3s ease-out;
      border-left: 4px solid ${color.border};
    `;

    notification.innerHTML = `
      <span style="
        background: rgba(255, 255, 255, 0.2);
        border-radius: 50%;
        width: 24px;
        height: 24px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 14px;
        font-weight: bold;
        flex-shrink: 0;
      ">${icon}</span>
      <span style="flex: 1;">${message}</span>
      <button style="
        background: none;
        border: none;
        color: white;
        cursor: pointer;
        padding: 4px;
        font-size: 18px;
        line-height: 1;
        opacity: 0.8;
        transition: opacity 0.2s;
      " onclick="this.parentElement.remove()" onmouseover="this.style.opacity='1'" onmouseout="this.style.opacity='0.8'">×</button>
    `;

    // Add animation styles if not already added
    if (!document.getElementById('notification-styles')) {
      const style = document.createElement('style');
      style.id = 'notification-styles';
      style.textContent = `
        @keyframes slideInRight {
          from {
            transform: translateX(100%);
            opacity: 0;
          }
          to {
            transform: translateX(0);
            opacity: 1;
          }
        }
        @keyframes slideOutRight {
          from {
            transform: translateX(0);
            opacity: 1;
          }
          to {
            transform: translateX(100%);
            opacity: 0;
          }
        }
        .notification-removing {
          animation: slideOutRight 0.3s ease-in forwards;
        }
      `;
      document.head.appendChild(style);
    }

    this.container.appendChild(notification);

    // Auto-remove after duration
    if (duration > 0) {
      setTimeout(() => {
        notification.classList.add('notification-removing');
        setTimeout(() => {
          if (notification.parentElement) {
            notification.remove();
          }
        }, 300);
      }, duration);
    }

    return notification;
  }

  success(message, duration = 5000) {
    return this.show(message, 'success', duration);
  }

  error(message, duration = 6000) {
    return this.show(message, 'error', duration);
  }

  warning(message, duration = 5000) {
    return this.show(message, 'warning', duration);
  }

  info(message, duration = 5000) {
    return this.show(message, 'info', duration);
  }
}

// Create global instance
const notifications = new NotificationSystem();

// User-friendly error messages for Firebase auth errors
function getUserFriendlyErrorMessage(error) {
  const errorMessages = {
    // Authentication errors
    'auth/invalid-credential': 'Invalid email or password. Please check your credentials and try again.',
    'auth/wrong-password': 'Incorrect password. Please try again or reset your password.',
    'auth/user-not-found': 'No account found with this email address.',
    'auth/email-already-in-use': 'This email is already registered. Please sign in instead.',
    'auth/weak-password': 'Password is too weak. Please use at least 6 characters.',
    'auth/invalid-email': 'Please enter a valid email address.',
    'auth/user-disabled': 'This account has been disabled. Please contact support.',
    'auth/too-many-requests': 'Too many failed attempts. Please try again later.',
    
    // Popup/network errors
    'auth/popup-closed-by-user': 'Sign-in was cancelled.',
    'auth/popup-blocked': 'Popup was blocked by your browser. Please allow popups and try again.',
    'auth/network-request-failed': 'Network error. Please check your internet connection and try again.',
    'auth/account-exists-with-different-credential': 'An account already exists with this email using a different sign-in method.',
    
    // General errors
    'auth/operation-not-allowed': 'This sign-in method is not enabled. Please contact support.',
    'auth/requires-recent-login': 'For security, please sign in again to complete this action.',
    'auth/invalid-verification-code': 'Invalid verification code. Please try again.',
    'auth/invalid-verification-id': 'Verification session expired. Please try again.',
  };

  // Return user-friendly message or fallback
  if (error && error.code && errorMessages[error.code]) {
    return errorMessages[error.code];
  }
  
  if (error && error.message) {
    // Try to extract a user-friendly message from the error
    const message = error.message.toLowerCase();
    if (message.includes('invalid') || message.includes('incorrect')) {
      return 'Invalid credentials. Please check your email and password.';
    }
    if (message.includes('network') || message.includes('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    if (message.includes('timeout')) {
      return 'Request timed out. Please try again.';
    }
  }

  // Default fallback
  return 'An error occurred. Please try again. If the problem persists, contact support.';
}

