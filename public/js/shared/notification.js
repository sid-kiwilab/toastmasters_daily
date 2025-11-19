/**
 * Notification system
 */

function showNotification(message, type = 'info') {
  // Remove existing notifications
  const existingNotifications = document.querySelectorAll('.notification');
  existingNotifications.forEach(n => n.remove());

  // Create notification element
  const notification = document.createElement('div');
  notification.className = `notification ${type}`;
  
  const messageEl = document.createElement('div');
  messageEl.className = 'notification-message';
  messageEl.textContent = message;
  
  const closeBtn = document.createElement('button');
  closeBtn.className = 'notification-close';
  closeBtn.innerHTML = '×';
  closeBtn.onclick = () => {
    notification.classList.add('hide');
    setTimeout(() => notification.remove(), 300);
  };
  
  notification.appendChild(messageEl);
  notification.appendChild(closeBtn);
  
  document.body.appendChild(notification);
  
  // Auto-dismiss after 5 seconds
  setTimeout(() => {
    notification.classList.add('hide');
    setTimeout(() => notification.remove(), 300);
  }, 5000);
}

// Make globally available
window.showNotification = showNotification;

