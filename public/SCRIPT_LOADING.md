# Script Loading Pattern

## Overview
This document describes the proper script loading pattern for all pages in this application. Following this pattern ensures:
- Scripts load in the correct dependency order
- No race conditions or "undefined" errors
- Maximum efficiency (no unnecessary waiting)
- Firebase Auth initializes correctly

## Pattern

### Sequential Loading with Callbacks
Always load scripts sequentially using `onload` callbacks to ensure each script is fully loaded before the next one starts.

### Required Script Order
1. `notification.js` - Base notification system
2. `firebase-config.js` - Firebase configuration
3. `auth.js` - Firebase Auth functionality (depends on firebase-config)
4. `main.js` or page-specific JS - Depends on auth.js

### Implementation Template

```html
<script>
  // Load JS with version - sequential loading to ensure order
  const script1 = document.createElement('script');
  script1.src = '/js/notification.js?v=' + APP_VERSION;
  script1.onload = function() {
    const script2 = document.createElement('script');
    script2.src = '/js/firebase-config.js?v=' + APP_VERSION;
    script2.onload = function() {
      const script3 = document.createElement('script');
      script3.src = '/js/auth.js?v=' + APP_VERSION;
      script3.onload = function() {
        // auth.js is loaded, now load main.js or page-specific script
        const script4 = document.createElement('script');
        script4.src = '/js/main.js?v=' + APP_VERSION; // or your page script
        document.body.appendChild(script4);
      };
      document.body.appendChild(script3);
    };
    document.body.appendChild(script2);
  };
  document.body.appendChild(script1);
</script>
```

## Key Points

### ✅ DO:
- Use `onload` callbacks to chain script loading
- Load scripts in dependency order
- Use `APP_VERSION` for cache busting
- Append scripts to `document.body`

### ❌ DON'T:
- Load all scripts in parallel (causes race conditions)
- Use `setTimeout` or polling to wait for scripts
- Load `main.js` before `auth.js` is ready
- Forget to use version numbers in script URLs

## Why This Matters

1. **Dependency Order**: `auth.js` needs `firebase-config.js`, and `main.js` needs `auth.js`
2. **No Race Conditions**: Sequential loading ensures each script is available before the next tries to use it
3. **Efficiency**: No unnecessary waiting or polling - scripts load as fast as possible in the correct order
4. **Reliability**: Prevents "undefined" errors when scripts try to use functions that aren't loaded yet

## Example: Adding a New Page

When creating a new page (e.g., `public/new-page/index.html`):

1. Copy the script loading pattern from `public/index.html`
2. Replace `main.js` with your page-specific script
3. Ensure your page script checks for `initializeFirebaseAuth` if it needs auth

```html
<!-- In your new page -->
<script>
  const script1 = document.createElement('script');
  script1.src = '/js/notification.js?v=' + APP_VERSION;
  script1.onload = function() {
    const script2 = document.createElement('script');
    script2.src = '/js/firebase-config.js?v=' + APP_VERSION;
    script2.onload = function() {
      const script3 = document.createElement('script');
      script3.src = '/js/auth.js?v=' + APP_VERSION;
      script3.onload = function() {
        const script4 = document.createElement('script');
        script4.src = '/js/new-page.js?v=' + APP_VERSION; // Your page script
        document.body.appendChild(script4);
      };
      document.body.appendChild(script3);
    };
    document.body.appendChild(script2);
  };
  document.body.appendChild(script1);
</script>
```

## Notes

- Always use `APP_VERSION` from `version.js` for cache busting
- The pattern uses nested `onload` callbacks to ensure sequential execution
- This pattern is especially critical for Firebase Auth initialization
- If a script doesn't need auth, you can skip `auth.js` but still maintain the sequential pattern for other dependencies

