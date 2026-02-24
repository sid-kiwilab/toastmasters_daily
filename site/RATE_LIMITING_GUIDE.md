# Rate Limiting Implementation Guide

## Overview
Global rate limiting has been implemented for all Firebase Cloud Functions with configurable limits per function.

## How It Works

### Rate Limiter Middleware
- Located in `functions/utils/rate_limiter.js`
- Tracks calls per user/IP address
- Uses Firestore to store rate limit data
- Automatically cleans up old entries via cron job

### Rate Limit Configuration
Each function file has a `RATE_LIMITS` constant at the top:

```javascript
const RATE_LIMITS = {
  function_name: { maxCalls: 10, windowSeconds: 60 }, // 10 calls per 60 seconds
};
```

## Current Rate Limits

### Meeting Functions (`meeting_functions.js`)
- `create_meeting`: 10 calls/minute
- `delete_meeting`: 20 calls/minute

### Poll Functions (`poll_functions.js`)
- `submit_vote`: 60 calls/minute (voting can be frequent)

### Stripe Functions (`stripe_functions.js`)
- `create_checkout_session`: 5 calls/minute (payment operations)
- `cancel_subscription`: 10 calls/minute
- `resume_subscription`: 10 calls/minute

### Agenda Functions (`agenda_functions.js`)
- `upload_agenda`: 10 calls/minute (file uploads)

## Adjusting Rate Limits

To change a rate limit, edit the `RATE_LIMITS` constant in the respective function file:

```javascript
const RATE_LIMITS = {
  create_meeting: { maxCalls: 20, windowSeconds: 60 }, // Change to 20 per minute
};
```

## How Rate Limiting Works

1. **Identifier**: Uses user ID if authenticated, otherwise IP address
2. **Window**: Sliding window of X seconds (default: 60)
3. **Storage**: Rate limit data stored in `rate_limits` Firestore collection
4. **Cleanup**: Old entries cleaned up hourly via cron job

## Error Response

When rate limit is exceeded:
```json
{
  "code": "resource-exhausted",
  "message": "Rate limit exceeded. Maximum 10 calls per 60 seconds. Please try again in 45 seconds."
}
```

## Firestore Indexes

The following indexes have been added to `firestore.indexes.json`:

1. **meetings** collection: `created_at` DESC
2. **polls** collection: `created_at` ASC and DESC
3. **guests** collection: `device_id` ASC + `created_at` DESC (compound)
4. **club_codes** collection: `uid` ASC
5. **active_meetings** collection: `created_at` ASC

These indexes are required for efficient queries and will be automatically created when you deploy.

## Deployment

After making changes:
1. Deploy Firestore indexes: `firebase deploy --only firestore:indexes`
2. Deploy functions: `firebase deploy --only functions`

