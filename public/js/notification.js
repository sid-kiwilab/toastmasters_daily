/**
 * Notification System
 * A reusable notification system for displaying messages
 */

function showNotification(message, type = 'error', duration = 4000) {
  // Remove existing notification
  const existing = document.querySelector('.notification');
  if (existing) {
    existing.remove();
  }

  // Create notification element
  const notification = document.createElement('div');
  notification.className = `notification ${type}`;
  notification.innerHTML = `
    <div class="notification-message">${message}</div>
    <button class="notification-close" onclick="this.parentElement.remove()">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M12 4L4 12M4 4l8 8"/>
      </svg>
    </button>
  `;

  // Add to body
  document.body.appendChild(notification);

  // Auto-dismiss after duration
  setTimeout(() => {
    if (notification.parentElement) {
      notification.classList.add('hide');
      setTimeout(() => notification.remove(), 300);
    }
  }, duration);
}

