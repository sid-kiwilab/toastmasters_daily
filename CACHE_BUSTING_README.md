# Cache Busting System

This Flutter web app includes a cache busting system to ensure that browsers load the latest version of your application when you deploy updates.

## How to Use

### 1. Version Management

The cache busting system uses version numbers to force browsers to reload cached resources. Here's how to manage versions:

#### In `lib/main.dart`:
```dart
// Cache busting version - increment this when making changes that require browser cache clearing
const String appVersion = '1.0.0';
```

#### In `web/cache-config.js`:
```javascript
window.CACHE_CONFIG = {
  version: '1',  // Increment this number when deploying changes
  timestamp: Date.now()
};
```

### 2. When to Update Versions

Update the version numbers in **both** files when you:
- Make significant changes to your app
- Deploy new features
- Fix bugs that require fresh cache
- Update dependencies
- Make any changes that users should see immediately

### 3. Deployment Process

1. **Before deploying**, increment the version numbers:
   - Update `appVersion` in `lib/main.dart`
   - Update `version` in `web/cache-config.js`

2. **Build and deploy** your app:
   ```bash
   flutter build web
   firebase deploy
   ```

### 4. How It Works

- **JavaScript files**: Cache busting is applied automatically through URL parameters
- **HTML files**: No-cache headers are set to prevent caching
- **Static assets**: Long-term caching is enabled for better performance
- **Flutter resources**: Version parameters are appended to force reload
- **Modern compatibility**: Uses non-intrusive approach compatible with Flutter's modern initialization

### 5. File Structure

```
web/
├── index.html          # Main HTML file with cache busting script
├── cache-config.js     # Cache configuration (update version here)
└── ...

lib/
└── main.dart          # Flutter app with version constant
```

### 6. Firebase Configuration

The `firebase.json` file includes:
- No-cache headers for JS and HTML files
- Long-term caching for static assets (CSS, images)
- Proper cache control for optimal performance

### 7. Technical Details

The cache busting system:
- **Does NOT interfere** with Flutter's modern `engineInitializer.initializeEngine()` approach
- **Automatically adds** version parameters to Flutter script URLs
- **Uses non-intrusive** DOM manipulation after page load
- **Maintains compatibility** with all Flutter web versions

## Example Version Update

**Before deployment:**
```dart
// lib/main.dart
const String appVersion = '1.0.0';
```

```javascript
// web/cache-config.js
window.CACHE_CONFIG = {
  version: '1',
  timestamp: Date.now()
};
```

**After making changes:**
```dart
// lib/main.dart
const String appVersion = '1.0.1';
```

```javascript
// web/cache-config.js
window.CACHE_CONFIG = {
  version: '2',
  timestamp: Date.now()
};
```

This ensures that all users will get the latest version of your app when you deploy, without any conflicts with Flutter's initialization system.
