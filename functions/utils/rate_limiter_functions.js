const admin = require('firebase-admin');
const functions = require('firebase-functions');

const db = admin.firestore();

/**
 * Rate limiter middleware for Firebase Cloud Functions
 * @param {Function} handler - The function handler to wrap
 * @param {Object} options - Rate limit options
 * @param {number} options.max_calls - Maximum calls allowed per window
 * @param {number} options.window_seconds - Time window in seconds (default: 60)
 * @param {string} options.function_name - Name of the function (for logging)
 * @returns {Function} Wrapped function with rate limiting
 */
function rateLimit(handler, options) {
  const { max_calls, window_seconds = 60, function_name } = options;
  
  if (!max_calls || max_calls <= 0) {
    throw new Error('max_calls must be a positive number');
  }
  
  if (!function_name) {
    throw new Error('function_name is required for rate limiting');
  }
  
  return async (data, context) => {
    // Get identifier: user ID if authenticated, otherwise device_id from data
    let identifier;
    if (context.auth && context.auth.uid) {
      identifier = `user:${context.auth.uid}`;
    } else {
      // Use device_id from data parameter (for unauthenticated users)
      const device_id = data?.device_id || data?.deviceId;
      if (device_id) {
        identifier = `device:${device_id}`;
      } else {
        // Fallback: if no device_id provided and user not authenticated, can't rate limit
        // Log warning but allow the request (some functions may not need device_id)
        console.warn(`Rate limiter: No user_id or device_id provided for ${function_name}`);
        // Still try to rate limit with a generic identifier to prevent abuse
        identifier = `anonymous:unknown`;
      }
    }
    
    const rate_limit_key = `rate_limit:${function_name}:${identifier}`;
    const now = Date.now();
    const window_start = now - (window_seconds * 1000);
    
    try {
      // Get rate limit document
      const rate_limit_ref = db.collection('rate_limits').doc(rate_limit_key);
      const rate_limit_doc = await rate_limit_ref.get();
      
      let calls = [];
      
      if (rate_limit_doc.exists) {
        const doc_data = rate_limit_doc.data();
        calls = doc_data.calls || [];
        
        // Filter out calls outside the current window
        calls = calls.filter(timestamp => timestamp > window_start);
      }
      
      // Check if limit exceeded
      if (calls.length >= max_calls) {
        const oldest_call = Math.min(...calls);
        const reset_time = oldest_call + (window_seconds * 1000);
        const seconds_until_reset = Math.ceil((reset_time - now) / 1000);
        
        console.warn(`Rate limit exceeded for ${function_name} by ${identifier}. ${calls.length}/${max_calls} calls in last ${window_seconds}s`);
        
        throw new functions.https.HttpsError(
          'resource-exhausted',
          `Rate limit exceeded. Maximum ${max_calls} calls per ${window_seconds} seconds. Please try again in ${seconds_until_reset} seconds.`
        );
      }
      
      // Add current call timestamp
      calls.push(now);
      
      // Update rate limit document
      await rate_limit_ref.set({
        calls: calls,
        last_call: now,
        function_name: function_name,
        identifier: identifier,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      
      // Call the actual handler
      return await handler(data, context);
      
    } catch (error) {
      // If it's already an HttpsError, re-throw it
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      // Log unexpected errors but don't block the request
      console.error(`Rate limiter error for ${function_name}:`, error);
      
      // Continue with the handler if rate limiting fails
      return await handler(data, context);
    }
  };
}

/**
 * Cleanup old rate limit entries (run periodically via cron)
 */
exports.cleanup_rate_limits = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const db = admin.firestore();
    const one_hour_ago = Date.now() - (60 * 60 * 1000);
    
    try {
      const old_rate_limits = await db.collection('rate_limits')
        .where('last_call', '<', one_hour_ago)
        .limit(500)
        .get();
      
      if (old_rate_limits.empty) {
        console.log('No old rate limits to clean up');
        return null;
      }
      
      const batch = db.batch();
      old_rate_limits.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      console.log(`Cleaned up ${old_rate_limits.size} old rate limit entries`);
      
      return { cleaned: old_rate_limits.size };
    } catch (error) {
      console.error('Error cleaning up rate limits:', error);
      throw error;
    }
  });

module.exports = { rateLimit };

