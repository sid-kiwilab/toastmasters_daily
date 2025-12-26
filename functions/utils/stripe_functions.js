const admin = require('firebase-admin');
const functions = require('firebase-functions');
const stripe = require('stripe')(functions.config().stripe?.secret_key || process.env.STRIPE_SECRET_KEY);
const { rateLimit } = require('./rate_limiter_functions');

const db = admin.firestore();

// Rate limit configuration for Stripe functions
const RATE_LIMITS = {
  create_checkout_session: { max_calls: 5, window_seconds: 60 }, // 5 per minute (payment operations)
  cancel_subscription: { max_calls: 10, window_seconds: 60 }, // 10 per minute
  resume_subscription: { max_calls: 10, window_seconds: 60 }, // 10 per minute
};

// Create Stripe checkout session
// Exported for pinger function to keep it warm
const create_checkout_session_handler = async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { price_id, user_id, email, base_url } = data;

  if (!price_id || !user_id || !email) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  // Use base_url from payload or fallback to default
  const base_url_final = base_url || 'https://your-app-url.com';

  try {
    // Get or create Stripe customer
    let customer_id;
    const user_doc = await db.collection('users').doc(user_id).get();
    const user_data = user_doc.data();

    if (user_data?.stripe_customer_id) {
      customer_id = user_data.stripe_customer_id;
    } else {
      // Create new Stripe customer
      const customer = await stripe.customers.create({
        email: email,
        metadata: {
          firebase_uid: user_id,
        },
      });
      customer_id = customer.id;

      // Save customer ID to Firestore
      await db.collection('users').doc(user_id).set({
        stripe_customer_id: customer_id,
      }, { merge: true });
    }

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customer_id,
      payment_method_types: ['card'],
      line_items: [
        {
          price: price_id,
          quantity: 1,
        },
      ],
      mode: 'subscription',
      success_url: `${base_url_final}/payment-success`,
      cancel_url: `${base_url_final}/payment-cancelled`,
      metadata: {
        firebase_uid: user_id,
      },
    });

    return { url: session.url };
  } catch (error) {
    console.error('Error creating checkout session:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create checkout session', error.message);
  }
};

// Export handler for pinger function
exports.create_checkout_session_handler = create_checkout_session_handler;

// Wrap with rate limiting
exports.create_checkout_session = functions.https.onCall(
  rateLimit(create_checkout_session_handler, {
    ...RATE_LIMITS.create_checkout_session,
    function_name: 'create_checkout_session'
  })
);

// Cancel subscription auto-renewal
const cancel_subscription_handler = async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const user_id = context.auth.uid;

  try {
    // Get user document to find Stripe customer ID
    const user_doc = await db.collection('users').doc(user_id).get();
    const user_data = user_doc.data();

    if (!user_data?.stripe_customer_id) {
      throw new functions.https.HttpsError('not-found', 'No Stripe customer found for this user');
    }

    const customer_id = user_data.stripe_customer_id;

    // Find active subscriptions for this customer
    const subscriptions = await stripe.subscriptions.list({
      customer: customer_id,
      status: 'active',
      limit: 10,
    });

    if (subscriptions.data.length === 0) {
      throw new functions.https.HttpsError('not-found', 'No active subscription found');
    }

    // Cancel the most recent active subscription at period end
    const subscription = subscriptions.data[0];
    const canceled_subscription = await stripe.subscriptions.update(subscription.id, {
      cancel_at_period_end: true,
    });

    console.log(`Subscription ${subscription.id} will be canceled at period end`);

    // Update Firestore immediately with cancellation info
    await db.collection('users').doc(user_id).set({
      subscription_cancel_at_period_end: true,
      subscription_current_period_end: admin.firestore.Timestamp.fromMillis(canceled_subscription.current_period_end * 1000),
    }, { merge: true });

    return { 
      success: true, 
      message: 'Subscription will be canceled at the end of the billing period',
      cancel_at_period_end: canceled_subscription.cancel_at_period_end,
      current_period_end: canceled_subscription.current_period_end,
    };
  } catch (error) {
    console.error('Error canceling subscription:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to cancel subscription', error.message);
  }
};

// Wrap with rate limiting
exports.cancel_subscription = functions.https.onCall(
  rateLimit(cancel_subscription_handler, {
    ...RATE_LIMITS.cancel_subscription,
    function_name: 'cancel_subscription'
  })
);

// Resume subscription auto-renewal
const resume_subscription_handler = async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const user_id = context.auth.uid;

  try {
    // Get user document to find Stripe customer ID
    const user_doc = await db.collection('users').doc(user_id).get();
    const user_data = user_doc.data();

    if (!user_data?.stripe_customer_id) {
      throw new functions.https.HttpsError('not-found', 'No Stripe customer found for this user');
    }

    const customer_id = user_data.stripe_customer_id;

    // Find active subscriptions for this customer
    const subscriptions = await stripe.subscriptions.list({
      customer: customer_id,
      status: 'active',
      limit: 10,
    });

    if (subscriptions.data.length === 0) {
      throw new functions.https.HttpsError('not-found', 'No active subscription found');
    }

    // Resume the most recent active subscription
    const subscription = subscriptions.data[0];
    const resumed_subscription = await stripe.subscriptions.update(subscription.id, {
      cancel_at_period_end: false,
    });

    console.log(`Subscription ${subscription.id} auto-renewal resumed`);

    // Update Firestore immediately to clear cancellation info
    await db.collection('users').doc(user_id).set({
      subscription_cancel_at_period_end: false,
      subscription_current_period_end: admin.firestore.Timestamp.fromMillis(resumed_subscription.current_period_end * 1000),
    }, { merge: true });

    return { 
      success: true, 
      message: 'Subscription auto-renewal resumed',
      cancel_at_period_end: resumed_subscription.cancel_at_period_end,
      current_period_end: resumed_subscription.current_period_end,
    };
  } catch (error) {
    console.error('Error resuming subscription:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to resume subscription', error.message);
  }
};

// Wrap with rate limiting
exports.resume_subscription = functions.https.onCall(
  rateLimit(resume_subscription_handler, {
    ...RATE_LIMITS.resume_subscription,
    function_name: 'resume_subscription'
  })
);

// Stripe webhook handler
exports.handle_stripe_webhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhook_secret = functions.config().stripe?.webhook_secret || process.env.STRIPE_WEBHOOK_SECRET;

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhook_secret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    switch (event.type) {
      case 'customer.subscription.created':
        await handle_subscription_created(event.data.object);
        break;

      case 'customer.subscription.updated':
        await handle_subscription_updated(event.data.object);
        break;

      case 'customer.subscription.deleted':
        await handle_subscription_deleted(event.data.object);
        break;

      case 'invoice.payment_failed':
        await handle_invoice_payment_failed(event.data.object);
        break;

      case 'invoice.payment_succeeded':
        await handle_invoice_payment_succeeded(event.data.object);
        break;

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (error) {
    console.error('Error processing webhook:', error);
    res.status(500).send(`Webhook Error: ${error.message}`);
  }
});

// Handle subscription created
async function handle_subscription_created(subscription) {
  try {
    const customer_id = subscription.customer;
    const firebase_uid = subscription.metadata?.firebase_uid;
    const status = subscription.status;
    const cancel_at_period_end = subscription.cancel_at_period_end;
    const current_period_end = subscription.current_period_end;

    // Only set to active if subscription status is actually 'active'
    // When subscription is first created, status is usually 'incomplete' until payment succeeds
    // We'll rely on invoice.payment_succeeded to set it to active
    if (status !== 'active') {
      console.log(`Subscription created with status '${status}', waiting for payment confirmation`);
      return;
    }

    if (!firebase_uid) {
      // Try to get firebase_uid from customer metadata
      const customer = await stripe.customers.retrieve(customer_id);
      const customer_firebase_uid = customer.metadata?.firebase_uid;
      
      if (!customer_firebase_uid) {
        console.error('No firebase_uid found in subscription or customer metadata');
        return;
      }
      
      await update_user_subscription_with_period(
        customer_firebase_uid, 
        'active', 
        cancel_at_period_end, 
        current_period_end
      );
    } else {
      await update_user_subscription_with_period(
        firebase_uid, 
        'active', 
        cancel_at_period_end, 
        current_period_end
      );
    }
  } catch (error) {
    console.error('Error handling subscription created:', error);
    throw error;
  }
}

// Handle subscription updated
async function handle_subscription_updated(subscription) {
  try {
    const customer_id = subscription.customer;
    const firebase_uid = subscription.metadata?.firebase_uid;
    const status = subscription.status;
    const cancel_at_period_end = subscription.cancel_at_period_end;
    const current_period_end = subscription.current_period_end;

    console.log(`Subscription updated: ${subscription.id}, status: ${status}, cancel_at_period_end: ${cancel_at_period_end}`);

    if (!firebase_uid) {
      // Try to get firebase_uid from customer metadata
      const customer = await stripe.customers.retrieve(customer_id);
      const customer_firebase_uid = customer.metadata?.firebase_uid;
      
      if (!customer_firebase_uid) {
        console.error('No firebase_uid found in subscription or customer metadata');
        return;
      }
      
      await update_user_subscription_with_period(
        customer_firebase_uid,
        status === 'active' ? 'active' : 'inactive',
        cancel_at_period_end,
        current_period_end
      );
    } else {
      await update_user_subscription_with_period(
        firebase_uid,
        status === 'active' ? 'active' : 'inactive',
        cancel_at_period_end,
        current_period_end
      );
    }
  } catch (error) {
    console.error('Error handling subscription updated:', error);
    throw error;
  }
}

// Handle subscription deleted
async function handle_subscription_deleted(subscription) {
  try {
    const customer_id = subscription.customer;
    const firebase_uid = subscription.metadata?.firebase_uid;
    const subscription_status = subscription.status;

    console.log(`Subscription deleted: ${subscription.id}, status: ${subscription_status}`);

    if (!firebase_uid) {
      // Try to get firebase_uid from customer metadata
      const customer = await stripe.customers.retrieve(customer_id);
      const customer_firebase_uid = customer.metadata?.firebase_uid;
      
      if (!customer_firebase_uid) {
        console.error('No firebase_uid found in subscription or customer metadata');
        return;
      }
      
      // Set to inactive and clear cancellation fields
      await db.collection('users').doc(customer_firebase_uid).set({
        subscription: 'inactive',
        subscription_cancel_at_period_end: admin.firestore.FieldValue.delete(),
        subscription_current_period_end: admin.firestore.FieldValue.delete(),
      }, { merge: true });
    } else {
      // Set to inactive and clear cancellation fields
      await db.collection('users').doc(firebase_uid).set({
        subscription: 'inactive',
        subscription_cancel_at_period_end: admin.firestore.FieldValue.delete(),
        subscription_current_period_end: admin.firestore.FieldValue.delete(),
      }, { merge: true });
    }
  } catch (error) {
    console.error('Error handling subscription deleted:', error);
    throw error;
  }
}

// Handle invoice payment failed
async function handle_invoice_payment_failed(invoice) {
  try {
    const customer_id = invoice.customer;
    const subscription_id = invoice.subscription;

    // Get customer to find firebase_uid
    const customer = await stripe.customers.retrieve(customer_id);
    const firebase_uid = customer.metadata?.firebase_uid;

    if (!firebase_uid) {
      console.error('No firebase_uid found in customer metadata');
      return;
    }

    // If there's a subscription, check its status
    if (subscription_id) {
      const subscription = await stripe.subscriptions.retrieve(subscription_id);
      await update_user_subscription(firebase_uid, subscription.status === 'active' ? 'active' : 'inactive');
    } else {
      // No subscription, set to inactive
      await update_user_subscription(firebase_uid, 'inactive');
    }
  } catch (error) {
    console.error('Error handling invoice payment failed:', error);
    throw error;
  }
}

// Handle invoice payment succeeded
async function handle_invoice_payment_succeeded(invoice) {
  try {
    const customer_id = invoice.customer;
    const subscription_id = invoice.subscription;

    console.log(`Invoice payment succeeded - invoice ID: ${invoice.id}, customer: ${customer_id}, subscription: ${subscription_id}`);

    // Get customer to find firebase_uid
    const customer = await stripe.customers.retrieve(customer_id);
    const firebase_uid = customer.metadata?.firebase_uid;

    if (!firebase_uid) {
      console.error('No firebase_uid found in customer metadata');
      return;
    }

    // If payment succeeded and there's a subscription, set it to active
    // Payment succeeded means the subscription should be active
    if (subscription_id) {
      // Retrieve the subscription to verify it exists and get its status
      const subscription = await stripe.subscriptions.retrieve(subscription_id);
      console.log(`Invoice payment succeeded for subscription ${subscription_id}, status: ${subscription.status}`);
      
      const cancel_at_period_end = subscription.cancel_at_period_end;
      const current_period_end = subscription.current_period_end;
      
      // If subscription is active, set to active
      // If subscription is trialing, also set to active (trial is active)
      // Otherwise, still set to active since payment succeeded (subscription might be transitioning)
      if (subscription.status === 'active' || subscription.status === 'trialing') {
        await update_user_subscription_with_period(
          firebase_uid, 
          'active', 
          cancel_at_period_end, 
          current_period_end
        );
      } else {
        // Payment succeeded but subscription not active yet - set to active anyway
        // This handles edge cases where subscription status hasn't updated yet
        console.log(`Payment succeeded but subscription status is '${subscription.status}', setting to active anyway`);
        await update_user_subscription_with_period(
          firebase_uid, 
          'active', 
          cancel_at_period_end, 
          current_period_end
        );
      }
    } else {
      // No subscription ID in invoice - this can happen for one-time payments
      // But for subscription invoices, we should still try to find the subscription
      // by looking up the customer's active subscriptions
      console.log('Invoice payment succeeded but no subscription ID in invoice, checking customer subscriptions...');
      
      try {
        // Get all subscriptions for this customer
        const subscriptions = await stripe.subscriptions.list({
          customer: customer_id,
          status: 'all',
          limit: 10,
        });
        
        // Find the most recent active or trialing subscription
        const active_subscription = subscriptions.data.find(
          sub => sub.status === 'active' || sub.status === 'trialing' || sub.status === 'incomplete'
        );
        
        if (active_subscription) {
          console.log(`Found subscription ${active_subscription.id} with status ${active_subscription.status}, setting to active`);
          await update_user_subscription_with_period(
            firebase_uid,
            'active',
            active_subscription.cancel_at_period_end,
            active_subscription.current_period_end
          );
        } else {
          console.log('No active subscription found for customer, skipping status update');
        }
      } catch (lookup_error) {
        console.error('Error looking up customer subscriptions:', lookup_error);
      }
    }
  } catch (error) {
    console.error('Error handling invoice payment succeeded:', error);
    throw error;
  }
}

// Helper function to update user subscription status
async function update_user_subscription(firebase_uid, status) {
  try {
    await db.collection('users').doc(firebase_uid).set({
      subscription: status,
    }, { merge: true });
    console.log(`Updated subscription status for user ${firebase_uid} to ${status}`);
  } catch (error) {
    console.error(`Error updating subscription status for user ${firebase_uid}:`, error);
    throw error;
  }
}

// Helper function to update user subscription status with period end info
async function update_user_subscription_with_period(firebase_uid, status, cancel_at_period_end, current_period_end) {
  try {
    const update_data = {
      subscription: status,
    };

    // Update cancellation status
    if (cancel_at_period_end !== undefined) {
      update_data.subscription_cancel_at_period_end = cancel_at_period_end;
    }

    // Update period end date
    if (current_period_end) {
      update_data.subscription_current_period_end = admin.firestore.Timestamp.fromMillis(current_period_end * 1000);
    }

    await db.collection('users').doc(firebase_uid).set(update_data, { merge: true });
    console.log(`Updated subscription status for user ${firebase_uid} to ${status}, cancel_at_period_end: ${cancel_at_period_end}, current_period_end: ${current_period_end}`);
  } catch (error) {
    console.error(`Error updating subscription status for user ${firebase_uid}:`, error);
    throw error;
  }
}

