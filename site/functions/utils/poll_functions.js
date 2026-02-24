const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { rateLimit } = require('./rate_limiter_functions');

// Rate limit configuration for poll functions
const RATE_LIMITS = {
  submit_vote: { max_calls: 10, window_seconds: 60 }, // 60 per minute (voting can be frequent)
};

/**
 * Submits a vote for a poll
 * @param {Object} data - The request data object
 * @param {string} data.meeting_id - Meeting ID
 * @param {string} data.poll_id - Poll ID
 * @param {string} data.option - Selected option
 * @param {string} data.device_id - Device ID to track votes
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} Success status
 */
const submit_vote_handler = async (data, context) => {
  try {
    const db = admin.firestore();
    
    // Validate required fields
    if (!data.meeting_id || !data.poll_id || !data.option || !data.device_id) {
      return { success: false, error: 'Missing required fields' };
    }

    // First get creator_id from active_meetings
    const activeMeetingRef = db.collection('active_meetings').doc(data.meeting_id);
    const activeMeetingDoc = await activeMeetingRef.get();
    
    if (!activeMeetingDoc.exists) {
      return { success: false, error: 'Meeting not found' };
    }
    
    const creator_id = activeMeetingDoc.data().creator_id;
    if (!creator_id) {
      return { success: false, error: 'Meeting creator not found' };
    }

    // Use transaction to ensure atomic vote submission
    await db.runTransaction(async (transaction) => {
      // Read the poll document from polls subcollection
      const pollRef = db.collection('users').doc(creator_id)
        .collection('meetings').doc(data.meeting_id)
        .collection('polls').doc(data.poll_id);
      
      const pollDoc = await transaction.get(pollRef);

      if (!pollDoc.exists) {
        throw new Error('Poll not found');
      }

      const poll = pollDoc.data();

      // Check if poll is active
      if (!poll.is_active) {
        throw new Error('Poll is not active');
      }

      // Validate option exists
      if (!poll.options.includes(data.option)) {
        throw new Error('Invalid option');
      }

      // Get current tallies and device votes
      const tallies = { ...poll.tallies };
      const deviceVotes = { ...(poll.device_votes || {}) };
      const previousVote = deviceVotes[data.device_id];
      let totalResponses = poll.total_responses || 0;

      // Handle vote change or new vote
      if (previousVote) {
        // User is changing their vote
        if (previousVote !== data.option) {
          // Decrement previous option
          if (tallies[previousVote] > 0) {
            tallies[previousVote] = (tallies[previousVote] || 0) - 1;
          }
          // Increment new option
          tallies[data.option] = (tallies[data.option] || 0) + 1;
        }
        // If same option, no change needed
      } else {
        // New vote
        tallies[data.option] = (tallies[data.option] || 0) + 1;
        totalResponses += 1;
      }

      // Update device vote
      deviceVotes[data.device_id] = data.option;

      // Update the poll document in polls subcollection
      transaction.update(pollRef, {
        tallies: tallies,
        device_votes: deviceVotes,
        total_responses: totalResponses
      });
    });

    return {
      success: true,
      message: 'Vote submitted successfully'
    };

  } catch (error) {
    console.error('Error submitting vote:', error);
    return { 
      success: false, 
      error: error.message || 'Failed to submit vote' 
    };
  }
};

// Wrap with rate limiting
exports.submit_vote = functions.https.onCall(
  rateLimit(submit_vote_handler, {
    ...RATE_LIMITS.submit_vote,
    function_name: 'submit_vote'
  })
);

