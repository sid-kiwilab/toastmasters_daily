const functions = require('firebase-functions');

// Pub/Sub function to keep checkout session creation warm
// Runs every 5 minutes to prevent cold starts
// Even if the call fails, it keeps the function instance alive
exports.ping_checkout_session_creation = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('Pinging checkout session creation to keep it warm...');
    
    try {
      // Import the handler function directly
      const stripeFunctions = require('./stripe_functions');
      
      // Create a dummy context that will fail auth check
      // This loads the function code but fails early, keeping it warm
      const dummyContext = {
        auth: null, // Will fail auth check immediately
      };
      
      // Call handler with invalid data - fails fast but loads the function
      try {
        await stripeFunctions.create_checkout_session_handler(
          {
            price_id: 'dummy',
            user_id: 'dummy',
            email: 'dummy@test.com',
            base_url: 'https://test.com',
          },
          dummyContext
        );
      } catch (error) {
        // Expected to fail at auth check - this is fine
        // The function code was loaded and executed, keeping it warm
        console.log('Ping completed (expected failure):', error.code || error.message);
      }
      
      console.log('Checkout session creation pinged - function kept warm');
      return null;
    } catch (error) {
      // Even if this fails, attempting to load the function helps keep it warm
      console.error('Error in ping function:', error);
      return null;
    }
  });
