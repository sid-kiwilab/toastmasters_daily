import 'dart:html' as html;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class WebDeviceIdentifier {
  static const String _deviceIdKey = 'web_device_id';
  static const String _fingerprintKey = 'web_fingerprint';
  static const String _lastGeneratedKey = 'web_last_generated';
  
  /// Gets or creates a persistent device ID that works even in incognito mode
  static Future<String> getDeviceId() async {
    try {
      // Strategy 1: Try to get existing ID from localStorage
      String? existingId = html.window.localStorage[_deviceIdKey];
      
      if (existingId != null && existingId.isNotEmpty) {
        print('Found existing device ID in localStorage: $existingId');
        return existingId;
      }
      
      // Strategy 2: Try to get from sessionStorage (works in incognito)
      existingId = html.window.sessionStorage[_deviceIdKey];
      if (existingId != null && existingId.isNotEmpty) {
        print('Found existing device ID in sessionStorage: $existingId');
        // Store in localStorage for future sessions
        html.window.localStorage[_deviceIdKey] = existingId;
        return existingId;
      }
      
      // Strategy 3: Check if we have a stored fingerprint to regenerate the same ID
      final storedFingerprint = html.window.localStorage[_fingerprintKey];
      if (storedFingerprint != null) {
        final regeneratedId = _hashFingerprint(storedFingerprint);
        print('Regenerated device ID from stored fingerprint: $regeneratedId');
        
        // Store the regenerated ID
        html.window.localStorage[_deviceIdKey] = regeneratedId;
        html.window.sessionStorage[_deviceIdKey] = regeneratedId;
        
        return regeneratedId;
      }
      
      // Strategy 4: Generate completely new fingerprint and ID
      print('Generating new device fingerprint and ID...');
      final fingerprint = await _generateBrowserFingerprint();
      final newId = _hashFingerprint(fingerprint);
      
      // Store both the fingerprint and ID in multiple places
      html.window.localStorage[_deviceIdKey] = newId;
      html.window.localStorage[_fingerprintKey] = fingerprint;
      html.window.localStorage[_lastGeneratedKey] = DateTime.now().millisecondsSinceEpoch.toString();
      
      html.window.sessionStorage[_deviceIdKey] = newId;
      html.window.sessionStorage[_fingerprintKey] = fingerprint;
      
      print('Generated new device ID: $newId');
      return newId;
      
    } catch (e) {
      print('Error in device identification: $e');
      // Ultimate fallback
      final fallbackId = 'web_fallback_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
      html.window.localStorage[_deviceIdKey] = fallbackId;
      return fallbackId;
    }
  }
  
  /// Generates a comprehensive browser fingerprint
  static Future<String> _generateBrowserFingerprint() async {
    final fingerprint = <String, dynamic>{};
    
    try {
      // Screen properties (very stable)
      fingerprint['screen'] = {
        'width': html.window.screen?.width ?? 0,
        'height': html.window.screen?.height ?? 0,
        'colorDepth': html.window.screen?.colorDepth ?? 0,
        'pixelDepth': html.window.screen?.pixelDepth ?? 0,
      };
      
      // Browser properties
      fingerprint['navigator'] = {
        'userAgent': html.window.navigator.userAgent,
        'language': html.window.navigator.language,
        'languages': html.window.navigator.languages?.join(',') ?? '',
        'platform': html.window.navigator.platform,
        'cookieEnabled': html.window.navigator.cookieEnabled,
        'doNotTrack': html.window.navigator.doNotTrack,
        'hardwareConcurrency': html.window.navigator.hardwareConcurrency ?? 0,
        'maxTouchPoints': html.window.navigator.maxTouchPoints ?? 0,
        'vendor': html.window.navigator.vendor,
      };
      
      // Window properties
      fingerprint['window'] = {
        'innerWidth': html.window.innerWidth,
        'innerHeight': html.window.innerHeight,
        'outerWidth': html.window.outerWidth,
        'outerHeight': html.window.outerHeight,
        'devicePixelRatio': html.window.devicePixelRatio,
      };
      
      // Canvas fingerprinting (extremely reliable)
      fingerprint['canvas'] = await _getCanvasFingerprint();
      
      // WebGL fingerprinting
      fingerprint['webgl'] = await _getWebGLFingerprint();
      
      // Font fingerprinting
      fingerprint['fonts'] = await _getFontFingerprint();
      
      // Timezone and locale
      fingerprint['timezone'] = DateTime.now().timeZoneName;
      fingerprint['locale'] = html.window.navigator.language;
      
      // Performance characteristics
      fingerprint['performance'] = await _getPerformanceFingerprint();
      
    } catch (e) {
      print('Error generating fingerprint: $e');
      fingerprint['error'] = e.toString();
    }
    
    return json.encode(fingerprint);
  }
  
  /// Creates a hash from the fingerprint string
  static String _hashFingerprint(String fingerprint) {
    final bytes = utf8.encode(fingerprint);
    final digest = sha256.convert(bytes);
    return 'web_${digest.toString().substring(0, 16)}';
  }
  
  /// Generates a random string for fallback IDs
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }
  
  /// Canvas fingerprinting - very reliable
  static Future<String> _getCanvasFingerprint() async {
    try {
      final canvas = html.CanvasElement();
      final ctx = canvas.getContext('2d') as html.CanvasRenderingContext2D;
      
      // Draw text with specific properties
      ctx.font = '18pt Arial';
      ctx.fillStyle = 'rgb(102, 204, 0)';
      ctx.fillText('Browser fingerprint', 2, 2);
      
      // Add geometric shapes
      ctx.fillStyle = 'rgb(255, 0, 255)';
      ctx.beginPath();
      ctx.arc(50, 50, 20, 0, 2 * 3.14159);
      ctx.fill();
      
      ctx.strokeStyle = 'rgb(0, 0, 255)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(10, 10);
      ctx.lineTo(90, 90);
      ctx.stroke();
      
      // Add gradient
      final gradient = ctx.createLinearGradient(0, 0, 100, 100);
      gradient.addColorStop(0, 'rgba(255, 0, 0, 0.5)');
      gradient.addColorStop(1, 'rgba(0, 255, 0, 0.5)');
      ctx.fillStyle = gradient;
      ctx.fillRect(70, 70, 30, 30);
      
      return canvas.toDataUrl();
    } catch (e) {
      return 'canvas_error_${e.toString().hashCode}';
    }
  }
  
  /// WebGL fingerprinting
  static Future<String> _getWebGLFingerprint() async {
    try {
      final canvas = html.CanvasElement();
      final gl = canvas.getContext('webgl');
      
      if (gl == null) return 'webgl_not_supported';
      
      return 'webgl_supported';
    } catch (e) {
      return 'webgl_error_${e.toString().hashCode}';
    }
  }
  
  /// Font fingerprinting
  static Future<String> _getFontFingerprint() async {
    final testFonts = [
      'Arial', 'Verdana', 'Times New Roman', 'Courier New',
      'Georgia', 'Palatino', 'Garamond', 'Bookman', 'Comic Sans MS',
      'Trebuchet MS', 'Arial Black', 'Impact', 'Tahoma', 'Lucida Console'
    ];
    
    final availableFonts = <String>[];
    
    for (final font in testFonts) {
      if (await _isFontAvailable(font)) {
        availableFonts.add(font);
      }
    }
    
    return availableFonts.join(',');
  }
  
  /// Check if a font is available
  static Future<bool> _isFontAvailable(String font) async {
    try {
      const testString = 'mmmmmmmmmmlli';
      const baseFont = 'monospace';
      
      final canvas = html.CanvasElement();
      final ctx = canvas.getContext('2d') as html.CanvasRenderingContext2D;
      
      ctx.font = '72px $baseFont';
      final baseWidth = ctx.measureText(testString).width ?? 0;
      
      ctx.font = '72px $font, $baseFont';
      final fontWidth = ctx.measureText(testString).width ?? 0;
      
      return (baseWidth - fontWidth).abs() > 1;
    } catch (e) {
      return false;
    }
  }
  
  /// Performance fingerprint
  static Future<String> _getPerformanceFingerprint() async {
    try {
      html.window.performance;
      return 'perf_supported';
    } catch (e) {
      return 'perf_not_supported';
    }
  }
  
  /// Force refresh the device ID (useful for testing)
  static Future<String> refreshDeviceId() async {
    // Clear all stored data
    html.window.localStorage.remove(_deviceIdKey);
    html.window.localStorage.remove(_fingerprintKey);
    html.window.localStorage.remove(_lastGeneratedKey);
    html.window.sessionStorage.remove(_deviceIdKey);
    html.window.sessionStorage.remove(_fingerprintKey);
    
    // Generate new ID
    return await getDeviceId();
  }
  
  /// Get device ID without generating new one
  static String? getExistingDeviceId() {
    return html.window.localStorage[_deviceIdKey] ?? 
           html.window.sessionStorage[_deviceIdKey];
  }
}
