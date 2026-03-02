const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { rateLimit } = require('./rate_limiter_functions');

const RATE_LIMITS = {
  submit_eval: { max_calls: 20, window_seconds: 60 },
  delete_eval: { max_calls: 20, window_seconds: 60 },
};
const MAX_EVALUATEE_LEN = 100;
const MAX_CONTENT_LEN = 2000;
const MAX_SLUG_LEN = 40;

function slugEvaluatee(name) {
  const s = (name || '').trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '') || 'unknown';
  return s.length > MAX_SLUG_LEN ? s.slice(0, MAX_SLUG_LEN) : s;
}

const submit_eval_handler = async (data, context) => {
  try {
    const db = admin.firestore();
    if (!data.meeting_id || !data.device_id || data.evaluatee == null || data.content == null) {
      return { success: false, error: 'Missing required fields' };
    }
    const evaluatee = String(data.evaluatee).trim().slice(0, MAX_EVALUATEE_LEN);
    const content = String(data.content).trim().slice(0, MAX_CONTENT_LEN);
    if (!evaluatee || !content) {
      return { success: false, error: 'Evaluatee and content are required' };
    }
    const displayName = data.evaluator_display_name != null ? String(data.evaluator_display_name).trim().slice(0, 80) : '';

    const activeDoc = await db.collection('active_meetings').doc(data.meeting_id).get();
    if (!activeDoc.exists) return { success: false, error: 'Meeting not found' };
    const creator_id = activeDoc.data().creator_id;
    if (!creator_id) return { success: false, error: 'Meeting creator not found' };

    const slug = slugEvaluatee(evaluatee);
    const evalId = `eval_${data.device_id}_${slug}`;
    const ref = db.collection('users').doc(creator_id).collection('meetings').doc(data.meeting_id).collection('evals').doc(evalId);
    const existing = await ref.get();

    const payload = {
      evaluatee,
      evaluator_device_id: data.device_id,
      content,
      evaluator_display_name: displayName,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (existing.exists) {
      if (existing.data().evaluator_device_id !== data.device_id) {
        return { success: false, error: 'You can only edit your own evaluation' };
      }
      await ref.update(payload);
    } else {
      payload.created_at = admin.firestore.FieldValue.serverTimestamp();
      await ref.set(payload);
    }
    return { success: true };
  } catch (e) {
    console.error('submit_eval:', e);
    return { success: false, error: e.message || 'Failed to submit evaluation' };
  }
};

exports.submit_eval = functions.https.onCall(
  rateLimit(submit_eval_handler, { ...RATE_LIMITS.submit_eval, function_name: 'submit_eval' })
);

const delete_eval_handler = async (data, context) => {
  try {
    const db = admin.firestore();
    if (!data.meeting_id || !data.device_id || !data.eval_id) {
      return { success: false, error: 'Missing required fields' };
    }
    const activeDoc = await db.collection('active_meetings').doc(data.meeting_id).get();
    if (!activeDoc.exists) return { success: false, error: 'Meeting not found' };
    const creator_id = activeDoc.data().creator_id;
    if (!creator_id) return { success: false, error: 'Meeting creator not found' };
    const ref = db.collection('users').doc(creator_id).collection('meetings').doc(data.meeting_id).collection('evals').doc(data.eval_id);
    const doc = await ref.get();
    if (!doc.exists) return { success: false, error: 'Evaluation not found' };
    if (doc.data().evaluator_device_id !== data.device_id) {
      return { success: false, error: 'You can only delete your own evaluation' };
    }
    await ref.delete();
    return { success: true };
  } catch (e) {
    console.error('delete_eval:', e);
    return { success: false, error: e.message || 'Failed to delete evaluation' };
  }
};

exports.delete_eval = functions.https.onCall(
  rateLimit(delete_eval_handler, { ...RATE_LIMITS.delete_eval, function_name: 'delete_eval' })
);
