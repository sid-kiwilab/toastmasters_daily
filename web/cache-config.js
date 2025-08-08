// Cache busting configuration
// Increment this version number whenever you make changes that require browser cache clearing
window.CACHE_CONFIG = {
  version: '1',
  timestamp: Date.now()
};

// Function to append cache busting parameters to URLs
window.addCacheBusting = function(url) {
  const separator = url.includes('?') ? '&' : '?';
  return url + separator + 'v=' + window.CACHE_CONFIG.version + '&t=' + window.CACHE_CONFIG.timestamp;
};

// Add cache busting to script tags after page load
window.addEventListener('load', function() {
  // Add version parameters to Flutter scripts
  const scripts = document.querySelectorAll('script[src*="main.dart.js"], script[src*="flutter_bootstrap.js"]');
  scripts.forEach(script => {
    if (script.src && !script.src.includes('v=')) {
      script.src = window.addCacheBusting(script.src);
    }
  });
});
