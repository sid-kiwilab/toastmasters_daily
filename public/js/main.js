/**
 * Main page functionality
 */

const codeInput = document.getElementById('codeInput');
const joinButton = document.getElementById('joinButton');

// Format input to "1234 5678"
codeInput.addEventListener('input', function(e) {
  let digits = e.target.value.replace(/\D/g, '');
  digits = digits.substring(0, 8);
  
  if (digits.length > 4) {
    e.target.value = digits.substring(0, 4) + ' ' + digits.substring(4, 8);
  } else {
    e.target.value = digits;
  }
});

// Block 9th digit
codeInput.addEventListener('keydown', function(e) {
  if (['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab', 'Enter'].includes(e.key) || e.ctrlKey || e.metaKey) {
    return;
  }
  const digits = codeInput.value.replace(/\D/g, '');
  if (digits.length >= 8 && /^[0-9]$/.test(e.key)) {
    e.preventDefault();
    return false;
  }
}, true);

