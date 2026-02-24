const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { rateLimit } = require('./rate_limiter_functions');

// Rate limit configuration for speech functions
const RATE_LIMITS = {
  get_speech_upload_url: { max_calls: 20, window_seconds: 60 }, // 20 per minute
};

// Initialize S3 client for R2 (S3-compatible)
// These should be set as environment variables in Firebase Functions
// Use functions.config() with fallback to process.env
const db = admin.firestore();

const getR2Config = () => {
  try {
    const config = functions.config().r2 || {};
    return {
      accountId: config.account_id || process.env.R2_ACCOUNT_ID || '',
      accessKeyId: config.access_key_id || process.env.R2_ACCESS_KEY_ID || '',
      secretAccessKey: config.secret_access_key || process.env.R2_SECRET_ACCESS_KEY || '',
      bucketName: config.bucket_name || process.env.R2_BUCKET_NAME || '',
      publicUrl: config.public_url || process.env.R2_PUBLIC_URL || '',
    };
  } catch (error) {
    console.error('Error reading R2 config:', error);
    return {
      accountId: process.env.R2_ACCOUNT_ID || '',
      accessKeyId: process.env.R2_ACCESS_KEY_ID || '',
      secretAccessKey: process.env.R2_SECRET_ACCESS_KEY || '',
      bucketName: process.env.R2_BUCKET_NAME || '',
      publicUrl: process.env.R2_PUBLIC_URL || '',
    };
  }
};

// Lazy initialization - will be created when needed
let r2Client = null;
let r2Config = null;

const getR2Client = () => {
  if (!r2Client || !r2Config) {
    r2Config = getR2Config();
    
    // Validate all required config values including bucketName
    if (!r2Config.accountId || !r2Config.accessKeyId || !r2Config.secretAccessKey || !r2Config.bucketName) {
      console.error('R2 config missing:', {
        hasAccountId: !!r2Config.accountId,
        hasAccessKeyId: !!r2Config.accessKeyId,
        hasSecretAccessKey: !!r2Config.secretAccessKey,
        hasBucketName: !!r2Config.bucketName,
        bucketNameValue: r2Config.bucketName || 'EMPTY',
      });
      return null;
    }
    
    r2Client = new S3Client({
      region: 'auto',
      endpoint: `https://${r2Config.accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: r2Config.accessKeyId,
        secretAccessKey: r2Config.secretAccessKey,
      },
    });
  }
  return r2Client;
};

/**
 * Generates a presigned URL for uploading a speech video to R2
 * @param {Object} data - The request data object
 * @param {string} data.fileName - Original filename
 * @param {string} data.contentType - MIME type of the file (e.g., 'video/mp4')
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} Presigned URL for upload
 */
const get_speech_upload_url_handler = async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      return { success: false, error: 'Authentication required' };
    }

    // Get R2 client (lazy initialization)
    const client = getR2Client();
    if (!client || !r2Config) {
      const currentConfig = getR2Config();
      console.error('R2 configuration is missing:', {
        accountId: currentConfig.accountId ? '***' : 'MISSING',
        accessKeyId: currentConfig.accessKeyId ? '***' : 'MISSING',
        secretAccessKey: currentConfig.secretAccessKey ? '***' : 'MISSING',
        bucketName: currentConfig.bucketName || 'MISSING',
        rawConfig: JSON.stringify(functions.config().r2 || {}),
      });
      return { success: false, error: 'Server configuration error: R2 storage not configured. Please set R2 environment variables.' };
    }

    const bucketName = r2Config.bucketName;
    if (!bucketName) {
      console.error('Bucket name is empty even though client was created. Config:', {
        bucketName: r2Config.bucketName,
        rawConfig: JSON.stringify(functions.config().r2 || {}),
      });
      return { success: false, error: 'Server configuration error: R2 bucket name not configured' };
    }

    // Validate required fields
    if (!data.fileName || !data.contentType) {
      return { success: false, error: 'Missing required fields: fileName and contentType are required' };
    }

    // Validate file type (only video files allowed)
    const allowedTypes = ['video/mp4', 'video/webm', 'video/quicktime', 'video/x-msvideo'];
    if (!allowedTypes.includes(data.contentType.toLowerCase())) {
      return { success: false, error: 'Only video files are allowed' };
    }

    // Generate unique file path: speeches/{userId}/{timestamp}-{filename}
    const userId = context.auth.uid;
    const timestamp = Date.now();
    const sanitizedFileName = data.fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
    const filePath = `speeches/${userId}/${timestamp}-${sanitizedFileName}`;
    
    // Generate unique video ID
    const videoId = db.collection('users').doc(userId).collection('videos').doc().id;
    
    // Build public URL
    const publicUrl = r2Config.publicUrl 
      ? `${r2Config.publicUrl}/${filePath}`
      : `https://pub-${r2Config.accountId}.r2.dev/${filePath}`;

    // Generate presigned URL first (before creating document)
    // This way if URL generation fails, we don't create a stuck document
    const command = new PutObjectCommand({
      Bucket: bucketName,
      Key: filePath,
      ContentType: data.contentType,
    });
    
    const presignedUrl = await getSignedUrl(client, command, { expiresIn: 3600 });

    // Use transaction to atomically create document with ready status
    // Since URL generation succeeded, we can safely create the document
    await db.runTransaction(async (transaction) => {
      const videoRef = db.collection('users').doc(userId).collection('videos').doc(videoId);
      
      // Check if document already exists (shouldn't happen, but be safe)
      const existingDoc = await transaction.get(videoRef);
      if (existingDoc.exists) {
        throw new Error('Video document already exists');
      }
      
      // Create video document with ready status atomically
      const videoData = {
        status: 'ready_to_upload',
        fileName: data.fileName,
        contentType: data.contentType,
        filePath: filePath,
        publicUrl: publicUrl,
        uploadUrl: presignedUrl,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      transaction.set(videoRef, videoData);
    });

    return {
      success: true,
      uploadUrl: presignedUrl,
      filePath: filePath,
      videoId: videoId,
      publicUrl: publicUrl,
    };
  } catch (error) {
    console.error('Error generating speech upload URL:', error);
    // If transaction failed after URL generation, the document wasn't created
    // If transaction succeeded but something else failed, document exists with ready status
    // No cleanup needed - URL generation happens before document creation
    return { success: false, error: error.message || 'Failed to generate upload URL' };
  }
};

/**
 * Valid state transitions for video status
 */
const VALID_TRANSITIONS = {
  'getting_url': ['ready_to_upload', 'failed'],
  'ready_to_upload': ['uploading', 'failed'],
  'uploading': ['uploaded', 'failed'],
  'uploaded': ['processing', 'failed'],
  'processing': ['completed', 'failed'],
  'completed': [], // Terminal state
  'failed': [], // Terminal state
};

/**
 * Updates the status of a video upload atomically with state transition validation
 * @param {Object} data - The request data object
 * @param {string} data.videoId - Video document ID
 * @param {string} data.status - New status (uploading, uploaded, processing, etc.)
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} Success status
 */
const update_video_status_handler = async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      return { success: false, error: 'Authentication required' };
    }

    const userId = context.auth.uid;
    const { videoId, status } = data;

    // Validate required fields
    if (!videoId || !status) {
      return { success: false, error: 'Missing required fields: videoId and status are required' };
    }

    // Validate status
    const allowedStatuses = ['getting_url', 'ready_to_upload', 'uploading', 'uploaded', 'processing', 'completed', 'failed'];
    if (!allowedStatuses.includes(status)) {
      return { success: false, error: `Invalid status. Allowed: ${allowedStatuses.join(', ')}` };
    }

    // Use transaction to atomically check current state and update
    const result = await db.runTransaction(async (transaction) => {
      const videoRef = db.collection('users').doc(userId).collection('videos').doc(videoId);
      const videoDoc = await transaction.get(videoRef);

      if (!videoDoc.exists) {
        throw new Error('Video not found');
      }

      const currentData = videoDoc.data();
      const currentStatus = currentData?.status;

      // Validate state transition
      if (currentStatus && VALID_TRANSITIONS[currentStatus]) {
        if (!VALID_TRANSITIONS[currentStatus].includes(status)) {
          throw new Error(`Invalid state transition from ${currentStatus} to ${status}`);
        }
      }

      // Prevent overwriting terminal states (idempotency check)
      if (currentStatus === 'completed' || currentStatus === 'failed') {
        if (currentStatus !== status) {
          throw new Error(`Cannot change status from terminal state ${currentStatus} to ${status}`);
        }
        // Already in the desired terminal state, return success (idempotent)
        return { success: true, videoId, status: currentStatus, wasAlreadySet: true };
      }

      // Update status atomically
      transaction.update(videoRef, {
        status: status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, videoId, status, wasAlreadySet: false };
    });

    return result;
  } catch (error) {
    console.error('Error updating video status:', error);
    return { success: false, error: error.message || 'Failed to update video status' };
  }
};

/**
 * Marks a video upload as complete after successful upload
 * This is called after the client successfully uploads to R2
 * @param {Object} data - The request data object
 * @param {string} data.videoId - Video document ID
 * @param {Object} context - Firebase Functions context
 * @returns {Promise<Object>} Success status
 */
const complete_video_upload_handler = async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      return { success: false, error: 'Authentication required' };
    }

    const userId = context.auth.uid;
    const { videoId } = data;

    // Validate required fields
    if (!videoId) {
      return { success: false, error: 'Missing required field: videoId is required' };
    }

    // Use transaction to atomically update status
    const result = await db.runTransaction(async (transaction) => {
      const videoRef = db.collection('users').doc(userId).collection('videos').doc(videoId);
      const videoDoc = await transaction.get(videoRef);

      if (!videoDoc.exists) {
        throw new Error('Video not found');
      }

      const currentData = videoDoc.data();
      const currentStatus = currentData?.status;

      // Only allow transition from uploading to uploaded
      if (currentStatus !== 'uploading') {
        // If already uploaded or in a later state, return success (idempotent)
        if (currentStatus === 'uploaded' || currentStatus === 'processing' || currentStatus === 'completed') {
          return { success: true, videoId, status: currentStatus, wasAlreadySet: true };
        }
        throw new Error(`Invalid state transition: cannot mark upload complete from ${currentStatus}. Expected 'uploading'`);
      }

      // Update status atomically
      transaction.update(videoRef, {
        status: 'uploaded',
        uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, videoId, status: 'uploaded', wasAlreadySet: false };
    });

    return result;
  } catch (error) {
    console.error('Error completing video upload:', error);
    return { success: false, error: error.message || 'Failed to complete video upload' };
  }
};

// Wrap with rate limiting
module.exports = {
  get_speech_upload_url: functions.https.onCall(
    rateLimit(get_speech_upload_url_handler, {
      ...RATE_LIMITS.get_speech_upload_url,
      function_name: 'get_speech_upload_url'
    })
  ),
  update_video_status: functions.https.onCall(
    rateLimit(update_video_status_handler, {
      max_calls: 50,
      window_seconds: 60,
      function_name: 'update_video_status'
    })
  ),
  complete_video_upload: functions.https.onCall(
    rateLimit(complete_video_upload_handler, {
      max_calls: 20,
      window_seconds: 60,
      function_name: 'complete_video_upload'
    })
  ),
};

