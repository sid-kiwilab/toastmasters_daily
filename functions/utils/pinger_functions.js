const functions = require('firebase-functions');

// Array of URLs to ping
const URLS = [
  'https://us-central1-toastmasters-daily.cloudfunctions.net/create_checkout_session',
  // Add more URLs here as needed
];

/**
 * Simple health checker that pings multiple URLs every 5 minutes
 */
exports.ping_functions = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    try {
      // Ping all URLs concurrently
      const results = await Promise.all(
        URLS.map(async (url, index) => {
          try {
            const response = await fetch(url);
            
            return {
              url: url,
              status: response.status,
              ok: response.ok,
              success: true
            };
          } catch (error) {
            return {
              url: url,
              error: error.message,
              success: false
            };
          }
        })
      );
      
      // Only log errors
      results.forEach(result => {
        if (!result.success) {
          console.error(`❌ ${result.url} - Error: ${result.error}`);
        }
      });
      
      return { results };
      
    } catch (error) {
      console.error('❌ Health check failed:', error);
      return { error: error.message };
    }
  });

