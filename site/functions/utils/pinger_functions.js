const functions = require('firebase-functions');

const TOASTMASTERS_AGENT_URL = 'https://toastmasters-agent-864717492615.us-central1.run.app';

/**
 * Pings the Toastmasters chat agent Cloud Run service every 5 minutes to keep it warm.
 */
exports.ping_toastmasters_agent = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async () => {
    try {
      const res = await fetch(TOASTMASTERS_AGENT_URL + '/', { method: 'GET' });
      console.log('Toastmasters agent ping:', res.status);
    } catch (err) {
      console.warn('Toastmasters agent ping failed:', err.message);
    }
  });
