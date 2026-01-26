const functions = require('firebase-functions');
const admin = require('firebase-admin');
const https = require('https');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// ============================================================
// STANDARDIZED ERROR CODE FRAMEWORK
// ============================================================

/**
 * Application-level error codes for consistent client handling.
 * Returned in error details for machine-readable parsing.
 *
 * Naming Convention: CATEGORY_SPECIFIC_CONDITION
 * Categories: AUTH, KYC, WALLET, TXN, RATE, SERVICE, CONFIG, SYSTEM
 */
const ERROR_CODES = Object.freeze({
  // Authentication & Authorization
  AUTH_UNAUTHENTICATED: 'AUTH_UNAUTHENTICATED',
  AUTH_PERMISSION_DENIED: 'AUTH_PERMISSION_DENIED',
  AUTH_SESSION_EXPIRED: 'AUTH_SESSION_EXPIRED',

  // KYC & Verification
  KYC_REQUIRED: 'KYC_REQUIRED',
  KYC_INCOMPLETE: 'KYC_INCOMPLETE',
  KYC_VERIFICATION_FAILED: 'KYC_VERIFICATION_FAILED',

  // Wallet Operations
  WALLET_NOT_FOUND: 'WALLET_NOT_FOUND',
  WALLET_INSUFFICIENT_FUNDS: 'WALLET_INSUFFICIENT_FUNDS',
  WALLET_LIMIT_EXCEEDED: 'WALLET_LIMIT_EXCEEDED',
  WALLET_SUSPENDED: 'WALLET_SUSPENDED',

  // Transaction Errors
  TXN_INVALID_STATE: 'TXN_INVALID_STATE',
  TXN_DUPLICATE_REQUEST: 'TXN_DUPLICATE_REQUEST',
  TXN_SELF_TRANSFER: 'TXN_SELF_TRANSFER',
  TXN_RECIPIENT_NOT_FOUND: 'TXN_RECIPIENT_NOT_FOUND',
  TXN_NOT_FOUND: 'TXN_NOT_FOUND',
  TXN_AMOUNT_INVALID: 'TXN_AMOUNT_INVALID',
  TXN_AMOUNT_TOO_SMALL: 'TXN_AMOUNT_TOO_SMALL',
  TXN_AMOUNT_TOO_LARGE: 'TXN_AMOUNT_TOO_LARGE',

  // Rate Limiting
  RATE_LIMIT_EXCEEDED: 'RATE_LIMIT_EXCEEDED',
  RATE_COOLDOWN_ACTIVE: 'RATE_COOLDOWN_ACTIVE',

  // External Services
  SERVICE_PAYSTACK_ERROR: 'SERVICE_PAYSTACK_ERROR',
  SERVICE_MOMO_ERROR: 'SERVICE_MOMO_ERROR',
  SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE',

  // Configuration
  CONFIG_MISSING: 'CONFIG_MISSING',
  CONFIG_INVALID: 'CONFIG_INVALID',

  // System Errors
  SYSTEM_INTERNAL_ERROR: 'SYSTEM_INTERNAL_ERROR',
  SYSTEM_VALIDATION_FAILED: 'SYSTEM_VALIDATION_FAILED',
});

/**
 * Maps application error codes to gRPC-style Cloud Function status codes.
 */
const ERROR_CODE_TO_HTTP = {
  AUTH_UNAUTHENTICATED: 'unauthenticated',
  AUTH_PERMISSION_DENIED: 'permission-denied',
  AUTH_SESSION_EXPIRED: 'unauthenticated',
  KYC_REQUIRED: 'failed-precondition',
  KYC_INCOMPLETE: 'failed-precondition',
  KYC_VERIFICATION_FAILED: 'failed-precondition',
  WALLET_NOT_FOUND: 'not-found',
  WALLET_INSUFFICIENT_FUNDS: 'failed-precondition',
  WALLET_LIMIT_EXCEEDED: 'failed-precondition',
  WALLET_SUSPENDED: 'failed-precondition',
  TXN_INVALID_STATE: 'failed-precondition',
  TXN_DUPLICATE_REQUEST: 'already-exists',
  TXN_SELF_TRANSFER: 'invalid-argument',
  TXN_RECIPIENT_NOT_FOUND: 'not-found',
  TXN_NOT_FOUND: 'not-found',
  TXN_AMOUNT_INVALID: 'invalid-argument',
  TXN_AMOUNT_TOO_SMALL: 'invalid-argument',
  TXN_AMOUNT_TOO_LARGE: 'invalid-argument',
  RATE_LIMIT_EXCEEDED: 'resource-exhausted',
  RATE_COOLDOWN_ACTIVE: 'resource-exhausted',
  SERVICE_PAYSTACK_ERROR: 'unavailable',
  SERVICE_MOMO_ERROR: 'unavailable',
  SERVICE_UNAVAILABLE: 'unavailable',
  CONFIG_MISSING: 'failed-precondition',
  CONFIG_INVALID: 'failed-precondition',
  SYSTEM_INTERNAL_ERROR: 'internal',
  SYSTEM_VALIDATION_FAILED: 'invalid-argument',
};

/**
 * User-friendly messages safe for direct UI display.
 */
const ERROR_MESSAGES = {
  AUTH_UNAUTHENTICATED: 'Please sign in to continue.',
  AUTH_PERMISSION_DENIED: 'You do not have permission to perform this action.',
  AUTH_SESSION_EXPIRED: 'Your session has expired. Please sign in again.',
  KYC_REQUIRED: 'Please complete identity verification to continue.',
  KYC_INCOMPLETE: 'Your verification is incomplete. Please finish all steps.',
  KYC_VERIFICATION_FAILED: 'Identity verification failed. Please try again.',
  WALLET_NOT_FOUND: 'Wallet not found. Please contact support.',
  WALLET_INSUFFICIENT_FUNDS: 'Insufficient balance for this transaction.',
  WALLET_LIMIT_EXCEEDED: 'Transaction exceeds your daily limit.',
  WALLET_SUSPENDED: 'This wallet is suspended. Please contact support.',
  TXN_INVALID_STATE: 'This transaction cannot be modified.',
  TXN_DUPLICATE_REQUEST: 'This request has already been processed.',
  TXN_SELF_TRANSFER: 'You cannot transfer to your own wallet.',
  TXN_RECIPIENT_NOT_FOUND: 'Recipient wallet not found. Please check the ID.',
  TXN_NOT_FOUND: 'Transaction not found.',
  TXN_AMOUNT_INVALID: 'Please enter a valid amount.',
  TXN_AMOUNT_TOO_SMALL: 'Amount is below the minimum allowed.',
  TXN_AMOUNT_TOO_LARGE: 'Amount exceeds the maximum allowed.',
  RATE_LIMIT_EXCEEDED: 'Too many requests. Please wait before trying again.',
  RATE_COOLDOWN_ACTIVE: 'Please wait before retrying this action.',
  SERVICE_PAYSTACK_ERROR: 'Payment service error. Please try again.',
  SERVICE_MOMO_ERROR: 'MoMo service error. Please try again.',
  SERVICE_UNAVAILABLE: 'Service temporarily unavailable. Please try again.',
  CONFIG_MISSING: 'Service is not configured. Contact support.',
  CONFIG_INVALID: 'Service configuration error. Contact support.',
  SYSTEM_INTERNAL_ERROR: 'Something went wrong. Please try again later.',
  SYSTEM_VALIDATION_FAILED: 'Invalid data provided.',
};

/**
 * Throws a standardized application error with consistent structure.
 *
 * @param {string} code - Error code from ERROR_CODES
 * @param {string} [customMessage] - Override default message (optional)
 * @param {Object} [details] - Additional context for debugging
 * @throws {functions.https.HttpsError}
 */
function throwAppError(code, customMessage = null, details = {}) {
  const httpCode = ERROR_CODE_TO_HTTP[code] || 'failed-precondition';
  const message = customMessage || ERROR_MESSAGES[code] || 'An error occurred.';

  console.error(JSON.stringify({
    level: 'ERROR',
    errorCode: code,
    message,
    details,
    timestamp: new Date().toISOString(),
  }));

  throw new functions.https.HttpsError(httpCode, message, {
    code,
    message,
    ...details,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Wraps external service errors with consistent formatting.
 * Use when catching errors from Paystack, MoMo, etc.
 *
 * @param {string} serviceName - 'paystack' or 'momo'
 * @param {Error} originalError - The caught error
 * @param {Object} [context] - Additional context
 * @throws {functions.https.HttpsError}
 */
function throwServiceError(serviceName, originalError, context = {}) {
  const codeKey = `SERVICE_${serviceName.toUpperCase()}_ERROR`;
  const code = ERROR_CODES[codeKey] || ERROR_CODES.SERVICE_UNAVAILABLE;

  console.error(JSON.stringify({
    level: 'ERROR',
    errorCode: code,
    service: serviceName,
    originalError: originalError.message || String(originalError),
    context,
    timestamp: new Date().toISOString(),
  }));

  throw new functions.https.HttpsError('unavailable',
    `${serviceName} service error. Please try again.`, {
      code,
      service: serviceName,
      retryable: true,
      ...context,
    }
  );
}

// ============================================================
// CONFIGURATION VALIDATION
// ============================================================

/**
 * Validates that a required config value is present.
 * Throws a clear HttpsError if missing, so callers get an actionable message
 * instead of cryptic auth/network failures.
 */
function requireConfig(value, name) {
  if (!value) {
    throwAppError(ERROR_CODES.CONFIG_MISSING, `Server configuration error: ${name} is not set. Contact support.`);
  }
  return value;
}

// ============================================================
// ENVIRONMENT CONFIGURATION ENFORCEMENT
// ============================================================

/**
 * Critical configs: Financial and security keys that MUST be set in production.
 * Functions depending on these will fail loudly at call time via requireConfig().
 * Missing critical configs are tracked at cold-start for fast runtime checks.
 */
const CRITICAL_CONFIGS = {
  'paystack.secret_key': functions.config().paystack?.secret_key,
  'qr.secret': functions.config().qr?.secret,
  'momo.collections_subscription_key': functions.config().momo?.collections_subscription_key,
  'momo.collections_api_user': functions.config().momo?.collections_api_user,
  'momo.collections_api_key': functions.config().momo?.collections_api_key,
  'momo.disbursements_subscription_key': functions.config().momo?.disbursements_subscription_key,
  'momo.disbursements_api_user': functions.config().momo?.disbursements_api_user,
  'momo.disbursements_api_key': functions.config().momo?.disbursements_api_key,
  'momo.webhook_secret': functions.config().momo?.webhook_secret,
};

/**
 * Service-to-config mapping: which configs each service needs.
 * Used by requireServiceReady() to validate all configs for a service at once.
 */
const SERVICE_CONFIGS = {
  paystack: ['paystack.secret_key'],
  qr: ['qr.secret'],
  momo_collections: ['momo.collections_subscription_key', 'momo.collections_api_user', 'momo.collections_api_key'],
  momo_disbursements: ['momo.disbursements_subscription_key', 'momo.disbursements_api_user', 'momo.disbursements_api_key'],
  momo_webhook: ['momo.webhook_secret'],
};

/** Set of config keys known to be missing at cold-start */
const MISSING_CRITICAL_CONFIGS = new Set();

// Validate all configs at cold-start and log appropriately
(function enforceEnvironmentConfig() {
  const missingCritical = [];

  for (const [key, value] of Object.entries(CRITICAL_CONFIGS)) {
    if (!value) {
      missingCritical.push(key);
      MISSING_CRITICAL_CONFIGS.add(key);
    }
  }

  if (missingCritical.length > 0) {
    console.error(
      `CRITICAL CONFIG MISSING (${missingCritical.length}): ${missingCritical.join(', ')}. ` +
      `Set via: firebase functions:config:set KEY="value". ` +
      `Functions depending on these keys will fail at call time.`
    );
  } else {
    console.log('All critical environment configs present.');
  }
})();

/**
 * Validates that all required configs for a service are present.
 * Uses the cold-start MISSING_CRITICAL_CONFIGS set for O(1) lookup.
 * Throws a clear HttpsError listing exactly which keys are missing.
 *
 * @param {string} serviceName - Service name from SERVICE_CONFIGS (e.g., 'paystack', 'momo_collections')
 * @throws {HttpsError} failed-precondition if any required config is missing
 */
function requireServiceReady(serviceName) {
  const requiredKeys = SERVICE_CONFIGS[serviceName];
  if (!requiredKeys) return; // Unknown service, skip check

  const missing = requiredKeys.filter(key => MISSING_CRITICAL_CONFIGS.has(key));
  if (missing.length > 0) {
    throwAppError(ERROR_CODES.CONFIG_MISSING, `Service unavailable: ${serviceName} is not configured. Contact support.`);
  }
}

// ============================================================
// PAYSTACK CONFIGURATION
// ============================================================

// Paystack configuration - set via: firebase functions:config:set paystack.secret_key="sk_live_xxx"
// REQUIRED: Must be configured. Functions will fail with clear errors if missing.
const PAYSTACK_SECRET_KEY = functions.config().paystack?.secret_key || '';
const PAYSTACK_BASE_URL = 'api.paystack.co';

// Helper function for Paystack API calls
function paystackRequest(method, path, data = null) {
  requireConfig(PAYSTACK_SECRET_KEY, 'paystack.secret_key');
  return new Promise((resolve, reject) => {
    const options = {
      hostname: PAYSTACK_BASE_URL,
      port: 443,
      path: path,
      method: method,
      headers: {
        'Authorization': `Bearer ${PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
    };

    const req = https.request(options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => responseData += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(responseData);
          resolve(json);
        } catch (e) {
          reject(new Error('Failed to parse Paystack response'));
        }
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// ============================================================
// EXCHANGE RATE CONFIGURATION
// ============================================================

const CURRENCIES = [
  'USD', 'NGN', 'ZAR', 'KES', 'GHS', 'EGP', 'TZS', 'UGX', 'RWF', 'ETB',
  'MAD', 'DZD', 'TND', 'XAF', 'XOF', 'ZWL', 'ZMW', 'BWP', 'NAD', 'MZN',
  'AOA', 'CDF', 'SDG', 'LYD', 'MUR', 'MWK', 'SLL', 'LRD', 'GMD', 'GNF',
  'BIF', 'ERN', 'DJF', 'SOS', 'SSP', 'LSL', 'SZL', 'MGA', 'SCR', 'KMF',
  'MRU', 'CVE', 'STN', 'GBP', 'EUR'
];

function fetchRates() {
  return new Promise((resolve, reject) => {
    const url = 'https://api.exchangerate.host/latest?base=USD';
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.success !== false && json.rates) {
            resolve(json.rates);
          } else {
            reject(new Error('API returned error'));
          }
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

// Scheduled function - runs daily at midnight UTC
exports.updateExchangeRatesDaily = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      console.log('Fetching exchange rates...');
      const allRates = await fetchRates();

      const rates = { 'USD': 1.0 };
      for (const currency of CURRENCIES) {
        if (allRates[currency]) {
          rates[currency] = allRates[currency];
        }
      }

      await db.collection('app_config').doc('exchange_rates').set({
        rates: rates,
        base: 'USD',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        source: 'exchangerate.host'
      });

      console.log(`Updated ${Object.keys(rates).length} exchange rates`);
      return null;
    } catch (error) {
      console.error('Error updating rates:', error);
      throw error;
    }
  });

// HTTP function - manual trigger
exports.updateExchangeRatesNow = functions.https.onRequest(async (req, res) => {
  try {
    const allRates = await fetchRates();

    const rates = { 'USD': 1.0 };
    for (const currency of CURRENCIES) {
      if (allRates[currency]) {
        rates[currency] = allRates[currency];
      }
    }

    await db.collection('app_config').doc('exchange_rates').set({
      rates: rates,
      base: 'USD',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'exchangerate.host'
    });

    res.json({ success: true, count: Object.keys(rates).length, rates });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================================
// PAYSTACK PAYMENT FUNCTIONS
// ============================================================

// Verify Paystack payment and credit wallet
exports.verifyPayment = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { reference } = data;
  if (!reference) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Payment reference is required.');
  }

  const userId = context.auth.uid;

  // Fail fast if Paystack is not configured
  requireServiceReady('paystack');

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  try {
    // Verify with Paystack
    const response = await paystackRequest('GET', `/transaction/verify/${reference}`);

    if (!response.status || response.data.status !== 'success') {
      return { success: false, error: 'Payment verification failed' };
    }

    const paymentData = response.data;
    const amountInKobo = paymentData.amount;
    const amount = amountInKobo / 100; // Convert from kobo to naira
    const currency = paymentData.currency;

    // Check if payment already processed (idempotency)
    const paymentRef = db.collection('payments').doc(reference);
    const paymentDoc = await paymentRef.get();

    if (paymentDoc.exists && paymentDoc.data().processed) {
      return { success: true, message: 'Payment already processed', alreadyProcessed: true };
    }

    // Get user's wallet
    const walletSnapshot = await db.collection('wallets')
      .where('userId', '==', userId)
      .limit(1)
      .get();

    if (walletSnapshot.empty) {
      throwAppError(ERROR_CODES.WALLET_NOT_FOUND);
    }

    const walletDoc = walletSnapshot.docs[0];
    const walletData = walletDoc.data();

    // Credit wallet using transaction
    await db.runTransaction(async (transaction) => {
      const freshWallet = await transaction.get(walletDoc.ref);
      const currentBalance = freshWallet.data().balance || 0;
      const newBalance = currentBalance + amount;

      // Update wallet balance
      transaction.update(walletDoc.ref, {
        balance: newBalance,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Record payment
      transaction.set(paymentRef, {
        userId: userId,
        walletId: walletDoc.id,
        reference: reference,
        amount: amount,
        currency: currency,
        type: 'deposit',
        status: 'success',
        processed: true,
        paystackData: paymentData,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Add to user's transactions
      const txRef = db.collection('users').doc(userId).collection('transactions').doc();
      transaction.set(txRef, {
        id: txRef.id,
        type: 'deposit',
        amount: amount,
        currency: currency,
        status: 'completed',
        reference: reference,
        description: 'Wallet top-up via Paystack',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await auditLog({
      userId, operation: 'verifyPayment', result: 'success',
      amount, currency,
      metadata: { reference },
      ipHash: hashIp(context),
    });

    return {
      success: true,
      amount: amount,
      currency: currency,
      newBalance: walletData.balance + amount,
    };

  } catch (error) {
    console.error('Payment verification error:', error);
    await auditLog({
      userId, operation: 'verifyPayment', result: 'failure',
      metadata: { reference },
      error: error.message,
      ipHash: hashIp(context),
    });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message);
  }
});

// Handle Paystack webhook events
exports.paystackWebhook = functions.https.onRequest(async (req, res) => {
  // Fail fast if Paystack secret key is not configured
  if (MISSING_CRITICAL_CONFIGS.has('paystack.secret_key')) {
    console.error('paystackWebhook: PAYSTACK_SECRET_KEY not configured, rejecting webhook');
    return res.status(503).send('Service not configured');
  }

  // Verify webhook signature
  const hash = crypto
    .createHmac('sha512', PAYSTACK_SECRET_KEY)
    .update(JSON.stringify(req.body))
    .digest('hex');

  if (hash !== req.headers['x-paystack-signature']) {
    console.error('Invalid webhook signature');
    return res.status(400).send('Invalid signature');
  }

  const event = req.body;
  console.log('Paystack webhook event:', event.event);

  try {
    switch (event.event) {
      case 'charge.success':
        await handleSuccessfulCharge(event.data);
        break;

      case 'transfer.success':
        await handleSuccessfulTransfer(event.data);
        break;

      case 'transfer.failed':
        await handleFailedTransfer(event.data);
        break;

      default:
        console.log('Unhandled event type:', event.event);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(500).send('Error processing webhook');
  }
});

async function handleSuccessfulCharge(data) {
  const reference = data.reference;
  const metadata = data.metadata || {};
  const userId = metadata.userId;

  if (!userId) {
    console.error('No userId in metadata for charge:', reference);
    return;
  }

  // Check if already processed
  const paymentRef = db.collection('payments').doc(reference);
  const paymentDoc = await paymentRef.get();

  if (paymentDoc.exists && paymentDoc.data().processed) {
    console.log('Payment already processed:', reference);
    return;
  }

  const amount = data.amount / 100;
  const currency = data.currency;

  // Get user's wallet
  const walletSnapshot = await db.collection('wallets')
    .where('userId', '==', userId)
    .limit(1)
    .get();

  if (walletSnapshot.empty) {
    console.error('Wallet not found for user:', userId);
    return;
  }

  const walletDoc = walletSnapshot.docs[0];

  // Credit wallet
  await db.runTransaction(async (transaction) => {
    const freshWallet = await transaction.get(walletDoc.ref);
    const currentBalance = freshWallet.data().balance || 0;
    const newBalance = currentBalance + amount;

    transaction.update(walletDoc.ref, {
      balance: newBalance,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.set(paymentRef, {
      userId: userId,
      walletId: walletDoc.id,
      reference: reference,
      amount: amount,
      currency: currency,
      type: 'deposit',
      channel: data.channel,
      status: 'success',
      processed: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const txRef = db.collection('users').doc(userId).collection('transactions').doc();
    transaction.set(txRef, {
      id: txRef.id,
      type: 'deposit',
      amount: amount,
      currency: currency,
      status: 'completed',
      reference: reference,
      description: `Deposit via ${data.channel}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  console.log('Successfully credited wallet for:', reference);
}

async function handleSuccessfulTransfer(data) {
  const reference = data.reference;

  await updateTransactionState(
    db.collection('withdrawals').doc(reference),
    TRANSACTION_STATES.COMPLETED,
    {
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      paystackTransferCode: data.transfer_code,
    }
  );

  // Update user's transaction
  const withdrawalDoc = await db.collection('withdrawals').doc(reference).get();
  if (withdrawalDoc.exists) {
    const userId = withdrawalDoc.data().userId;
    const txQuery = await db.collection('users').doc(userId)
      .collection('transactions')
      .where('reference', '==', reference)
      .limit(1)
      .get();

    if (!txQuery.empty) {
      await updateTransactionState(
        txQuery.docs[0].ref,
        TRANSACTION_STATES.COMPLETED,
        { completedAt: admin.firestore.FieldValue.serverTimestamp() }
      );
    }
  }

  console.log('Withdrawal completed:', reference);
}

async function handleFailedTransfer(data) {
  const reference = data.reference;

  // Get withdrawal details
  const withdrawalDoc = await db.collection('withdrawals').doc(reference).get();
  if (!withdrawalDoc.exists) {
    console.error('Withdrawal not found:', reference);
    return;
  }

  const withdrawalData = withdrawalDoc.data();
  const userId = withdrawalData.userId;
  const amount = withdrawalData.amount;

  // Refund to wallet
  const walletSnapshot = await db.collection('wallets')
    .where('userId', '==', userId)
    .limit(1)
    .get();

  if (!walletSnapshot.empty) {
    const walletDoc = walletSnapshot.docs[0];

    await db.runTransaction(async (transaction) => {
      const freshWallet = await transaction.get(walletDoc.ref);
      const currentBalance = freshWallet.data().balance || 0;

      transaction.update(walletDoc.ref, {
        balance: currentBalance + amount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(db.collection('withdrawals').doc(reference), {
        ...buildStateTransitionFields(withdrawalData.status, TRANSACTION_STATES.FAILED, reference),
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        failureReason: data.reason || 'Transfer failed',
        refunded: true,
      });

      const txQuery = await db.collection('users').doc(userId)
        .collection('transactions')
        .where('reference', '==', reference)
        .limit(1)
        .get();

      if (!txQuery.empty) {
        const txCurrentStatus = txQuery.docs[0].data().status || 'pending';
        transaction.update(txQuery.docs[0].ref, {
          ...buildStateTransitionFields(txCurrentStatus, TRANSACTION_STATES.FAILED, txQuery.docs[0].id),
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
  }

  console.log('Withdrawal failed and refunded:', reference);
}

// Initiate withdrawal to bank or mobile money
exports.initiateWithdrawal = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { amount, bankCode, accountNumber, accountName, type, mobileMoneyProvider, phoneNumber, idempotencyKey } = data;
  const userId = context.auth.uid;

  // Fail fast if Paystack is not configured
  requireServiceReady('paystack');

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Enforce persistent rate limiting (5 withdrawals per hour)
  await enforceRateLimit(userId, 'initiateWithdrawal');

  console.log("initiateWithdrawal called with:", JSON.stringify({ amount, bankCode, accountNumber, accountName, type, mobileMoneyProvider, phoneNumber }));
  // Validate amount
  if (!amount || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID);
  }

  // Minimum withdrawal amount (e.g., 100)
  if (amount < 100) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_TOO_SMALL, 'Minimum withdrawal is 100.');
  }

  return withIdempotency(idempotencyKey, 'initiateWithdrawal', userId, async () => {
  try {
    // Get user's wallet
    const walletSnapshot = await db.collection('wallets')
      .where('userId', '==', userId)
      .limit(1)
      .get();

    if (walletSnapshot.empty) {
      throwAppError(ERROR_CODES.WALLET_NOT_FOUND);
    }

    const walletDoc = walletSnapshot.docs[0];
    const walletData = walletDoc.data();

    // Check balance
    if (walletData.balance < amount) {
      throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS);
    }

    // Generate reference
    const reference = `WD_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // Create transfer recipient first
    let recipientData;
    if (type === 'mobile_money') {
      recipientData = {
        type: 'mobile_money',
        name: accountName,
        account_number: phoneNumber,
        bank_code: mobileMoneyProvider,
        currency: walletData.currency || 'NGN',
      };
    } else {
      recipientData = {
        type: 'nuban',
        name: accountName,
        account_number: accountNumber,
        bank_code: bankCode,
        currency: walletData.currency || 'NGN',
      };
    }

    // Create recipient
    const recipientResponse = await paystackRequest('POST', '/transferrecipient', recipientData);
    console.log("Paystack recipient response:", JSON.stringify(recipientResponse));

    if (!recipientResponse.status) {
      throwServiceError('paystack', new Error('Failed to create transfer recipient'));
    }

    const recipientCode = recipientResponse.data.recipient_code;

    // Debit wallet first
    await db.runTransaction(async (transaction) => {
      const freshWallet = await transaction.get(walletDoc.ref);
      const currentBalance = freshWallet.data().balance || 0;

      if (currentBalance < amount) {
        throw new Error('Insufficient balance');
      }

      transaction.update(walletDoc.ref, {
        balance: currentBalance - amount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Record withdrawal
      transaction.set(db.collection('withdrawals').doc(reference), {
        userId: userId,
        walletId: walletDoc.id,
        reference: reference,
        amount: amount,
        currency: walletData.currency || 'NGN',
        type: type || 'bank',
        bankCode: bankCode || null,
        mobileMoneyProvider: mobileMoneyProvider || null,
        accountNumber: accountNumber || phoneNumber || null,
        phoneNumber: phoneNumber || null,
        accountName: accountName,
        recipientCode: recipientCode,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Add to user's transactions
      const txRef = db.collection('users').doc(userId).collection('transactions').doc();
      transaction.set(txRef, {
        id: txRef.id,
        type: 'withdrawal',
        amount: amount,
        currency: walletData.currency || 'NGN',
        status: 'pending',
        reference: reference,
        description: `Withdrawal to ${type === 'mobile_money' ? 'Mobile Money' : 'Bank'} - ${accountName}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Initiate transfer
    const transferResponse = await paystackRequest('POST', '/transfer', {
      source: 'balance',
      amount: amount * 100, // Convert to kobo
      recipient: recipientCode,
      reference: reference,
      reason: `Wallet withdrawal - ${reference}`,
    });

    console.log("Paystack transfer response:", JSON.stringify(transferResponse));
    if (!transferResponse.status) {
      // Refund if transfer initiation fails
      await db.runTransaction(async (transaction) => {
        const freshWallet = await transaction.get(walletDoc.ref);
        const currentBalance = freshWallet.data().balance || 0;

        transaction.update(walletDoc.ref, {
          balance: currentBalance + amount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        transaction.update(db.collection('withdrawals').doc(reference), {
          ...buildStateTransitionFields(TRANSACTION_STATES.PENDING, TRANSACTION_STATES.FAILED, reference),
          failureReason: 'Transfer initiation failed',
          refunded: true,
        });
      });

      throwServiceError('paystack', new Error('Failed to initiate transfer'));
    }

    // Check if OTP is required
    const transferData = transferResponse.data;
    if (transferData.status === 'otp') {
      // Store transfer code for OTP verification
      await updateTransactionState(
        db.collection('withdrawals').doc(reference),
        TRANSACTION_STATES.PENDING_OTP,
        { transferCode: transferData.transfer_code }
      );

      return {
        success: false,
        requiresOtp: true,
        transferCode: transferData.transfer_code,
        reference: reference,
        message: 'OTP verification required',
      };
    }

    await auditLog({
      userId, operation: 'initiateWithdrawal', result: 'success',
      amount, currency: walletData.currency || 'NGN',
      metadata: { reference, type: type || 'bank' },
      ipHash: hashIp(context),
    });

    return {
      success: true,
      reference: reference,
      message: 'Withdrawal initiated successfully',
    };

  } catch (error) {
    console.error('Withdrawal error:', error);
    await auditLog({
      userId, operation: 'initiateWithdrawal', result: 'failure',
      amount,
      error: error.message,
      ipHash: hashIp(context),
    });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message);
  }
  });
});

// Finalize transfer with OTP
exports.finalizeTransfer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { transferCode, otp, idempotencyKey } = data;
  const userId = context.auth.uid;

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  if (!transferCode || !otp) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Transfer code and OTP are required.');
  }

  return withIdempotency(idempotencyKey, 'finalizeTransfer', userId, async () => {
  try {
    // Find withdrawal by transfer code
    const withdrawalQuery = await db.collection('withdrawals')
      .where('transferCode', '==', transferCode)
      .where('userId', '==', userId)
      .limit(1)
      .get();

    if (withdrawalQuery.empty) {
      throwAppError(ERROR_CODES.TXN_NOT_FOUND, 'Withdrawal not found.');
    }

    const withdrawalDoc = withdrawalQuery.docs[0];

    // Submit OTP to Paystack
    const otpResponse = await paystackRequest('POST', '/transfer/finalize_transfer', {
      transfer_code: transferCode,
      otp: otp,
    });

    console.log('OTP finalize response:', JSON.stringify(otpResponse));

    if (otpResponse.status) {
      // Update withdrawal status
      await updateTransactionState(
        withdrawalDoc.ref,
        TRANSACTION_STATES.PROCESSING,
        { otpVerifiedAt: admin.firestore.FieldValue.serverTimestamp() }
      );

      return {
        success: true,
        reference: withdrawalDoc.data().reference,
        message: 'Transfer finalized successfully',
      };
    } else {
      return {
        success: false,
        error: otpResponse.message || 'OTP verification failed',
      };
    }
  } catch (error) {
    console.error('Finalize transfer error:', error);
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message);
  }
  });
});

// Get list of banks
exports.getBanks = functions.https.onCall(async (data, context) => {
  try {
    const country = data.country || 'nigeria';
    const response = await paystackRequest('GET', `/bank?country=${country}`);
    console.log('Paystack response:', JSON.stringify(response));
    console.log('Paystack response:', JSON.stringify(response));
    if (!response.status) {
      throw new Error('Failed to fetch banks');
    }

    return {
      success: true,
      banks: response.data.map(bank => ({
        name: bank.name,
        code: bank.code,
        type: bank.type,
      })),
    };
  } catch (error) {
    console.error('Get banks error:', error);
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message);
  }
});

// Verify bank account
exports.verifyBankAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { accountNumber, bankCode } = data;

  if (!accountNumber || !bankCode) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Account number and bank code required.');
  }

  try {
    console.log('Calling Paystack with account:', accountNumber, 'bank:', bankCode);
    const response = await paystackRequest('GET', `/bank/resolve?account_number=${accountNumber}&bank_code=${bankCode}`);

    console.log('Paystack response:', JSON.stringify(response));
    if (!response.status) {
      return { success: false, error: 'Could not verify account' };
    }

    return {
      success: true,
      accountName: response.data.account_name,
      accountNumber: response.data.account_number,
      bankId: response.data.bank_id,
    };
  } catch (error) {
    console.error('Verify account error:', error);
    return { success: false, error: 'Account verification failed' };
  }
});

// ============================================================
// MOBILE MONEY CHARGE (For adding funds via Mobile Money)
// ============================================================
exports.chargeMobileMoney = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { email, amount, currency, provider, phoneNumber, idempotencyKey } = data;
  const userId = context.auth.uid;

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  if (!amount || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID);
  }
  if (!provider || !phoneNumber) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Provider and phone number are required.');
  }

  return withIdempotency(idempotencyKey, 'chargeMobileMoney', userId, async () => {
  try {
    const reference = `MOMO_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const chargeResponse = await paystackRequest('POST', '/charge', {
      email: email,
      amount: Math.round(amount * 100),
      currency: currency || 'GHS',
      mobile_money: {
        phone: phoneNumber,
        provider: provider,
      },
      reference: reference,
      metadata: {
        userId: userId,
        type: 'deposit',
      },
    });

    console.log('Mobile Money charge response:', JSON.stringify(chargeResponse));

    // Check if payment was immediately successful (common in test mode)
    if (chargeResponse.status && chargeResponse.data?.status === 'success') {
      // Update wallet balance immediately
      const walletSnapshot = await db.collection('wallets')
        .where('userId', '==', userId)
        .limit(1)
        .get();

      if (!walletSnapshot.empty) {
        const walletDoc = walletSnapshot.docs[0];
        const walletData = walletDoc.data();

        await db.runTransaction(async (transaction) => {
          transaction.update(walletDoc.ref, {
            balance: (walletData.balance || 0) + amount,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Record transaction
          const txRef = db.collection('users').doc(userId).collection('transactions').doc();
          transaction.set(txRef, {
            id: txRef.id,
            type: 'deposit',
            amount: amount,
            currency: currency || 'GHS',
            status: 'completed',
            reference: reference,
            description: 'Mobile Money deposit',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
      }

      return {
        success: true,
        reference: reference,
        message: 'Payment successful!',
        status: 'success',
        completed: true,
      };
    } else if (chargeResponse.status) {
      // Payment pending - user needs to approve on phone
      return {
        success: true,
        reference: reference,
        message: 'Payment initiated. Please approve on your phone.',
        status: chargeResponse.data?.status,
        completed: false,
      };
    } else {
      return {
        success: false,
        error: chargeResponse.message || 'Failed to initiate payment',
      };
    }
  } catch (error) {
    console.error('Mobile Money charge error:', error);
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message || 'Payment failed.');
  }
  });
});

// ============================================================
// VIRTUAL ACCOUNT (For Bank Transfer deposits)
// ============================================================
exports.getOrCreateVirtualAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { email, name } = data;
  const userId = context.auth.uid;

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  try {
    // Check if user already has a virtual account
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (userData?.virtualAccount) {
      return {
        success: true,
        bankName: userData.virtualAccount.bankName,
        accountNumber: userData.virtualAccount.accountNumber,
        accountName: userData.virtualAccount.accountName,
      };
    }

    // Get or create customer
    let customerId;
    const customerListResponse = await paystackRequest('GET', `/customer/${email}`);

    if (customerListResponse.status && customerListResponse.data) {
      customerId = customerListResponse.data.id;
    } else {
      const createCustomerResponse = await paystackRequest('POST', '/customer', {
        email: email,
        first_name: name.split(' ')[0],
        last_name: name.split(' ').slice(1).join(' ') || name.split(' ')[0],
        metadata: { userId: userId },
      });

      if (!createCustomerResponse.status) {
        throw new Error('Failed to create customer');
      }
      customerId = createCustomerResponse.data.id;
    }

    // Create Dedicated Virtual Account
    const dvaResponse = await paystackRequest('POST', '/dedicated_account', {
      customer: customerId,
      preferred_bank: 'wema-bank',
    });

    console.log('DVA response:', JSON.stringify(dvaResponse));

    if (dvaResponse.status && dvaResponse.data) {
      const virtualAccount = {
        bankName: dvaResponse.data.bank?.name || 'Wema Bank',
        accountNumber: dvaResponse.data.account_number,
        accountName: dvaResponse.data.account_name,
        bankId: dvaResponse.data.bank?.id,
        customerId: customerId,
      };

      await db.collection('users').doc(userId).update({
        virtualAccount: virtualAccount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        bankName: virtualAccount.bankName,
        accountNumber: virtualAccount.accountNumber,
        accountName: virtualAccount.accountName,
      };
    } else {
      // Return mock for development/test mode
      return {
        success: true,
        bankName: 'Test Bank (Development)',
        accountNumber: '0000000000',
        accountName: name,
        note: 'Virtual accounts are only available in live mode',
      };
    }
  } catch (error) {
    console.error('Virtual account error:', error);
    return {
      success: true,
      bankName: 'Test Bank (Development)',
      accountNumber: '0000000000',
      accountName: name || 'Test Account',
      note: 'Virtual accounts require live mode activation',
    };
  }
});

// ============================================================
// INITIALIZE TRANSACTION (For Card Payment via Browser)
// ============================================================
exports.initializeTransaction = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { email, amount, currency } = data;
  const userId = context.auth.uid;

  if (!amount || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID);
  }

  if (!email) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Email is required.');
  }

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  try {
    const reference = `TXN_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    const response = await paystackRequest('POST', '/transaction/initialize', {
      email: email,
      amount: Math.round(amount * 100), // Convert to smallest unit
      currency: currency || 'GHS',
      reference: reference,
      callback_url: 'https://qr-wallet-1993.web.app/payment-callback',
      metadata: {
        userId: userId,
        type: 'deposit',
      },
    });

    console.log('Initialize transaction response:', JSON.stringify(response));

    if (response.status && response.data) {
      return {
        success: true,
        authorizationUrl: response.data.authorization_url,
        reference: response.data.reference,
        accessCode: response.data.access_code,
      };
    } else {
      return {
        success: false,
        error: response.message || 'Failed to initialize transaction',
      };
    }
  } catch (error) {
    console.error('Initialize transaction error:', error);
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message || 'Transaction initialization failed.');
  }
});

// ============================================================
// INITIALIZE TRANSACTION (For Card Payment via Browser)
// ============================================================
exports.initializeTransaction = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { email, amount, currency } = data;
  const userId = context.auth.uid;

  if (!amount || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID);
  }

  if (!email) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Email is required.');
  }

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  try {
    const reference = 'TXN_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    
    const response = await paystackRequest('POST', '/transaction/initialize', {
      email: email,
      amount: Math.round(amount * 100),
      currency: currency || 'GHS',
      reference: reference,
      metadata: {
        userId: userId,
        type: 'deposit',
      },
    });

    console.log('Initialize transaction response:', JSON.stringify(response));

    if (response.status && response.data) {
      return {
        success: true,
        authorizationUrl: response.data.authorization_url,
        reference: response.data.reference,
        accessCode: response.data.access_code,
      };
    } else {
      return {
        success: false,
        error: response.message || 'Failed to initialize transaction',
      };
    }
  } catch (error) {
    console.error('Initialize transaction error:', error);
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message || 'Transaction initialization failed.');
  }
});

// ============================================================
// QR CODE SIGNING & VERIFICATION
// ============================================================

// Secret key for signing QR codes (set via: firebase functions:config:set qr.secret="your-secret-key")
// REQUIRED: Must be configured. QR signing will fail if missing.
const QR_SECRET_KEY = functions.config().qr?.secret || '';
const QR_EXPIRY_MS = 15 * 60 * 1000; // 15 minutes

// Helper: Generate HMAC signature
function generateQrSignature(payload) {
  requireConfig(QR_SECRET_KEY, 'qr.secret');
  return crypto.createHmac('sha256', QR_SECRET_KEY)
    .update(payload)
    .digest('hex');
}

// Rate limiting storage (in-memory, resets on cold start)
const rateLimitStore = {};
const failedLookupStore = {};

// Helper: Check rate limit
function checkRateLimit(key, maxRequests, windowMs) {
  const now = Date.now();
  if (!rateLimitStore[key]) {
    rateLimitStore[key] = { count: 1, resetTime: now + windowMs };
    return true;
  }
  
  if (now > rateLimitStore[key].resetTime) {
    rateLimitStore[key] = { count: 1, resetTime: now + windowMs };
    return true;
  }
  
  if (rateLimitStore[key].count >= maxRequests) {
    return false;
  }
  
  rateLimitStore[key].count++;
  return true;
}

// Helper: Check failed lookup limit
function checkFailedLookups(ip) {
  const now = Date.now();
  const windowMs = 5 * 60 * 1000; // 5 minutes
  const maxFailures = 10;
  
  if (!failedLookupStore[ip]) {
    failedLookupStore[ip] = { count: 0, resetTime: now + windowMs };
  }
  
  if (now > failedLookupStore[ip].resetTime) {
    failedLookupStore[ip] = { count: 0, resetTime: now + windowMs };
  }
  
  return failedLookupStore[ip].count < maxFailures;
}

function recordFailedLookup(ip) {
  if (!failedLookupStore[ip]) {
    failedLookupStore[ip] = { count: 0, resetTime: Date.now() + 5 * 60 * 1000 };
  }
  failedLookupStore[ip].count++;
}

// ============================================================
// PERSISTENT RATE LIMITING (Firestore-backed)
// ============================================================

/**
 * Rate limit configuration per operation.
 * windowMs: sliding window duration in milliseconds
 * maxRequests: maximum requests allowed in the window
 * message: user-facing error message when rate limited
 */
const RATE_LIMITS = {
  sendMoney:          { windowMs: 60 * 60 * 1000, maxRequests: 20, message: 'Too many transfers. Please wait before sending again.' },
  initiateWithdrawal: { windowMs: 60 * 60 * 1000, maxRequests: 5,  message: 'Too many withdrawal attempts. Please try again later.' },
  momoRequestToPay:   { windowMs: 60 * 60 * 1000, maxRequests: 10, message: 'Too many MoMo payment requests. Please try again later.' },
  momoTransfer:       { windowMs: 60 * 60 * 1000, maxRequests: 5,  message: 'Too many MoMo transfers. Please try again later.' },
  lookupWallet:       { windowMs: 5 * 60 * 1000,  maxRequests: 30, message: 'Too many wallet lookups. Please wait a few minutes.' },
};

/**
 * Persistent rate limit check using Firestore.
 * Uses a sliding window counter stored in the rate_limits collection.
 * Survives cold starts (unlike the in-memory rateLimitStore).
 *
 * @param {string} userId - The user ID to rate limit
 * @param {string} operation - The operation name (must exist in RATE_LIMITS)
 * @returns {Promise<boolean>} true if within limit, false if rate limited
 */
async function checkRateLimitPersistent(userId, operation) {
  const config = RATE_LIMITS[operation];
  if (!config) {
    console.warn(`No rate limit config for operation: ${operation}`);
    return true;
  }

  const docId = `${userId}_${operation}`;
  const rateLimitRef = db.collection('rate_limits').doc(docId);
  const now = Date.now();
  const windowStart = now - config.windowMs;

  try {
    const result = await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);

      if (!doc.exists) {
        transaction.set(rateLimitRef, {
          userId,
          operation,
          requests: [now],
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
      }

      const data = doc.data();
      const recentRequests = (data.requests || []).filter(ts => ts > windowStart);

      if (recentRequests.length >= config.maxRequests) {
        return false;
      }

      recentRequests.push(now);
      transaction.update(rateLimitRef, {
        requests: recentRequests,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return true;
    });

    return result;
  } catch (error) {
    console.error(`Rate limit check failed for ${userId}/${operation}:`, error);
    return true; // Fail open to avoid blocking legitimate users
  }
}

/**
 * Enforces rate limiting for a financial operation.
 * Throws resource-exhausted HttpsError if the user has exceeded the limit.
 *
 * @param {string} userId - The user ID to rate limit
 * @param {string} operation - The operation name (must exist in RATE_LIMITS)
 * @throws {HttpsError} resource-exhausted if rate limited
 */
async function enforceRateLimit(userId, operation) {
  const allowed = await checkRateLimitPersistent(userId, operation);
  if (!allowed) {
    const config = RATE_LIMITS[operation];
    throwAppError(ERROR_CODES.RATE_LIMIT_EXCEEDED, config?.message, { operation, userId });
  }
}

// ============================================================
// FINANCIAL AUDIT LOGGING
// ============================================================

/**
 * Hash the client IP from the request context for privacy-safe forensics.
 * @param {Object} context - Cloud Function onCall context
 * @returns {string} First 16 hex chars of SHA-256 hash
 */
function hashIp(context) {
  const ip = context.rawRequest?.headers?.['x-forwarded-for'] || 'unknown';
  return crypto.createHash('sha256').update(ip).digest('hex').substring(0, 16);
}

/**
 * Writes an immutable audit log entry to the audit_logs collection.
 * Creates a tamper-resistant record of all financial operations.
 * The audit_logs collection is Cloud Functions-only (client access blocked by Firestore rules).
 *
 * Never throws — audit logging must not block or fail the main operation.
 *
 * @param {Object} entry - Audit log entry
 * @param {string} entry.userId - The user who performed the operation
 * @param {string} entry.operation - Operation name (e.g., 'sendMoney', 'withdrawal')
 * @param {string} entry.result - 'success' or 'failure'
 * @param {number} [entry.amount] - Amount involved
 * @param {string} [entry.currency] - Currency code
 * @param {string} [entry.error] - Error message (for failures)
 * @param {Object} [entry.metadata] - Additional context (transactionId, reference, etc.)
 * @param {string} [entry.ipHash] - Hashed IP for forensics
 */
async function auditLog(entry) {
  try {
    await db.collection('audit_logs').add({
      ...entry,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      loggedAt: new Date().toISOString(),
    });
  } catch (error) {
    // Audit logging must never block the main operation
    console.error('AUDIT LOG WRITE FAILED:', error, 'Entry:', JSON.stringify(entry));
  }
}

// ============================================================
// KYC ENFORCEMENT (Server-Side)
// ============================================================

/**
 * Enforces that a user has completed KYC verification.
 * Must be called in ALL Cloud Functions that handle financial operations.
 *
 * Checks the canonical 'kycStatus' field on the user document.
 * Falls back to legacy 'kycCompleted' + 'kycVerified' for existing users,
 * and auto-migrates them to the new kycStatus field.
 *
 * @param {string} userId - The Firebase Auth UID
 * @throws {HttpsError} permission-denied with code KYC_REQUIRED if not verified
 */
async function enforceKyc(userId) {
  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'User account not found.');
  }

  const userData = userDoc.data();

  // Check canonical kycStatus field (authoritative, set by Cloud Functions only)
  if (userData.kycStatus === 'verified') {
    return;
  }

  // Backward compatibility: trust legacy fields if kycStatus not yet set
  // This covers existing users who completed KYC before this enforcement was added
  if (!userData.kycStatus && userData.kycCompleted === true && userData.kycVerified === true) {
    // Auto-migrate: set canonical kycStatus for this user
    await db.collection('users').doc(userId).update({ kycStatus: 'verified' });
    console.log(`Auto-migrated kycStatus to 'verified' for user: ${userId}`);
    return;
  }

  // KYC not verified — block the operation
  throwAppError(ERROR_CODES.KYC_REQUIRED);
}

// Set KYC status (called after successful Smile ID verification)
exports.updateKycStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;
  const { status } = data;

  // Only allow setting to specific valid statuses
  const validStatuses = ['pending', 'verified', 'rejected'];
  if (!validStatuses.includes(status)) {
    throwAppError(ERROR_CODES.KYC_VERIFICATION_FAILED, 'Invalid KYC status.');
  }

  // For 'verified', require that KYC documents have been approved in the subcollection
  if (status === 'verified') {
    const kycDoc = await db.collection('users').doc(userId)
      .collection('kyc').doc('documents').get();

    if (!kycDoc.exists) {
      throwAppError(ERROR_CODES.KYC_INCOMPLETE, 'No KYC documents found.');
    }

    const kycData = kycDoc.data();
    if (kycData.status !== 'approved' && kycData.status !== 'verified') {
      throwAppError(ERROR_CODES.KYC_INCOMPLETE, 'KYC documents have not been approved.');
    }
  }

  await db.collection('users').doc(userId).update({
    kycStatus: status,
    kycStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(status === 'verified' ? { kycCompleted: true, kycVerified: true } : {}),
  });

  console.log(`KYC status updated to '${status}' for user: ${userId}`);

  return {
    success: true,
    kycStatus: status,
  };
});

// ============================================================
// IDEMPOTENCY PROTECTION FOR FINANCIAL OPERATIONS
// ============================================================

/**
 * Idempotency guard for financial operations.
 * Prevents duplicate execution on client retries, webhook replays,
 * and network timeout re-sends.
 *
 * Uses a two-phase approach to avoid nested Firestore transactions:
 *   Phase 1: Atomically check/reserve the idempotency key (transaction)
 *   Phase 2: Execute the operation (may use its own transactions)
 *   Phase 3: Mark key as completed or failed
 *
 * @param {string} key - Client-provided idempotency key (min 16 chars)
 * @param {string} operation - Function name (for logging/grouping)
 * @param {string} userId - Authenticated user ID (ownership check)
 * @param {Function} executeOperation - Async function containing the business logic
 * @returns {Promise<any>} - Cached result (if replay) or fresh result
 */
async function withIdempotency(key, operation, userId, executeOperation) {
  if (!key || typeof key !== 'string' || key.length < 16) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Idempotency key required (min 16 characters).');
  }

  const idempotencyRef = db.collection('idempotency_keys').doc(key);

  // Phase 1: Atomically check and reserve the key
  const reservation = await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(idempotencyRef);

    if (existing.exists) {
      const data = existing.data();

      // Validate ownership — different user cannot reuse a key
      if (data.userId !== userId) {
        throwAppError(ERROR_CODES.AUTH_PERMISSION_DENIED, 'Idempotency key belongs to another user.');
      }

      // Already completed — return cached result
      if (data.status === 'completed') {
        return { alreadyCompleted: true, result: data.result };
      }

      // Previous attempt failed — allow retry
      if (data.status === 'failed') {
        transaction.update(idempotencyRef, {
          status: 'pending',
          retryAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { alreadyCompleted: false };
      }

      // Still pending from another request — reject to prevent races
      throwAppError(ERROR_CODES.TXN_DUPLICATE_REQUEST, 'Operation already in progress with this idempotency key.');
    }

    // Key does not exist — reserve it
    transaction.set(idempotencyRef, {
      key,
      operation,
      userId,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24h TTL
    });

    return { alreadyCompleted: false };
  });

  // Return cached result for idempotent replays
  if (reservation.alreadyCompleted) {
    console.log(`Idempotent replay: ${key} (operation: ${operation})`);
    return { ...reservation.result, _idempotent: true };
  }

  // Phase 2: Execute the actual operation
  try {
    const result = await executeOperation();

    // Phase 3a: Mark as completed with cached result
    await idempotencyRef.update({
      status: 'completed',
      result: result,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return result;
  } catch (error) {
    // Phase 3b: Mark as failed (allows retry with same key)
    await idempotencyRef.update({
      status: 'failed',
      error: error.message || 'Unknown error',
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch(updateErr => {
      console.error('Failed to update idempotency key status:', updateErr);
    });

    throw error;
  }
}

// Scheduled cleanup: remove expired idempotency keys every 6 hours
exports.cleanupIdempotencyKeys = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async () => {
    const now = new Date();
    const expired = await db.collection('idempotency_keys')
      .where('expiresAt', '<', now)
      .limit(500)
      .get();

    if (expired.empty) {
      console.log('No expired idempotency keys to clean up');
      return null;
    }

    const batch = db.batch();
    expired.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    console.log(`Cleaned ${expired.size} expired idempotency keys`);
    return null;
  });

// ============================================================
// TRANSACTION STATE MACHINE
// ============================================================

const TRANSACTION_STATES = {
  CREATED: 'created',
  PENDING: 'pending',
  PENDING_OTP: 'pending_otp',
  PROCESSING: 'processing',
  COMPLETED: 'completed',
  FAILED: 'failed',
  REFUNDED: 'refunded',
  CANCELLED: 'cancelled',
};

const VALID_TRANSITIONS = {
  'created': ['pending', 'completed', 'cancelled'],
  'pending': ['processing', 'pending_otp', 'completed', 'failed', 'cancelled'],
  'pending_otp': ['processing', 'failed', 'cancelled'],
  'processing': ['completed', 'failed'],
  'completed': ['refunded'],
  'failed': ['refunded', 'pending'],
  'refunded': [],
  'cancelled': [],
};

const TERMINAL_STATES = ['refunded', 'cancelled'];

/**
 * Normalize external status values to internal state machine states.
 * MoMo API uses UPPERCASE, Paystack uses 'success', etc.
 */
function normalizeStatus(status) {
  if (!status) return 'created';
  const map = {
    'SUCCESSFUL': 'completed',
    'SUCCESS': 'completed',
    'success': 'completed',
    'PENDING': 'pending',
    'FAILED': 'failed',
  };
  return map[status] || status.toLowerCase();
}

/**
 * Validate a state transition is allowed.
 * @param {string} currentState - Current (possibly unnormalized) state
 * @param {string} newState - Desired (possibly unnormalized) state
 * @param {string} transactionId - Document ID for logging
 * @throws {HttpsError} if the transition is invalid
 */
function validateStateTransition(currentState, newState, transactionId) {
  const from = normalizeStatus(currentState);
  const to = normalizeStatus(newState);

  if (TERMINAL_STATES.includes(from)) {
    throwAppError(ERROR_CODES.TXN_INVALID_STATE, `Transaction ${transactionId} is in terminal state: ${from}.`, { transactionId, from });
  }

  if (from === 'completed' && to !== 'refunded') {
    throwAppError(ERROR_CODES.TXN_INVALID_STATE, `Completed transaction ${transactionId} can only be refunded.`, { transactionId, from, to });
  }

  const allowed = VALID_TRANSITIONS[from] || [];
  if (!allowed.includes(to)) {
    throwAppError(ERROR_CODES.TXN_INVALID_STATE, `Invalid state transition: ${from} → ${to}.`, { transactionId, from, to });
  }

  console.log(`State transition: ${from} → ${to} for ${transactionId}`);
  return true;
}

/**
 * Build Firestore update fields for a validated state transition.
 * Use inside existing Firestore transactions (spreads into update object).
 *
 * @param {string} currentStatus - Current document status
 * @param {string} newStatus - Desired new status
 * @param {string} docId - Document ID for logging/validation
 * @returns {Object} Fields to spread into transaction.update()
 */
function buildStateTransitionFields(currentStatus, newStatus, docId) {
  const from = normalizeStatus(currentStatus);
  const to = normalizeStatus(newStatus);
  validateStateTransition(from, to, docId);

  return {
    status: to,
    previousStatus: from,
    statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    statusHistory: admin.firestore.FieldValue.arrayUnion({
      from: from,
      to: to,
      timestamp: new Date().toISOString(),
    }),
  };
}

/**
 * Atomically validate and update a document's transaction state.
 * Runs its own Firestore transaction — do NOT call from inside another transaction.
 * For in-transaction use, call buildStateTransitionFields() instead.
 *
 * @param {DocumentReference} docRef - Firestore document reference
 * @param {string} newState - Desired new state
 * @param {Object} additionalData - Extra fields to set alongside the state change
 */
async function updateTransactionState(docRef, newState, additionalData = {}) {
  const to = normalizeStatus(newState);

  return db.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);

    if (!doc.exists) {
      throwAppError(ERROR_CODES.TXN_NOT_FOUND, 'Transaction document not found.');
    }

    const from = normalizeStatus(doc.data().status);
    validateStateTransition(from, to, doc.id);

    transaction.update(docRef, {
      status: to,
      previousStatus: from,
      statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      statusHistory: admin.firestore.FieldValue.arrayUnion({
        from: from,
        to: to,
        timestamp: new Date().toISOString(),
      }),
      ...additionalData,
    });

    return { previousState: from, newState: to };
  });
}

// ============================================================
// QR CODE SIGNING & VERIFICATION
// ============================================================

// Sign QR payload for payment requests
exports.signQrPayload = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  // Enforce KYC verification before financial operation
  await enforceKyc(context.auth.uid);

  const { walletId, amount, note } = data;

  if (!walletId || typeof walletId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Invalid wallet ID.');
  }
  
  // Verify the wallet belongs to the user
  const walletDoc = await db.collection('wallets').doc(context.auth.uid).get();
  if (!walletDoc.exists || walletDoc.data().walletId !== walletId) {
    throwAppError(ERROR_CODES.AUTH_PERMISSION_DENIED, 'Wallet does not belong to user.');
  }
  
  const timestamp = Date.now();
  const payload = {
    walletId,
    amount: amount || 0,
    note: note || '',
    timestamp,
    userId: context.auth.uid
  };
  
  const payloadString = JSON.stringify(payload);
  const signature = generateQrSignature(payloadString);
  
  return {
    payload: payloadString,
    signature,
    expiresAt: timestamp + QR_EXPIRY_MS
  };
});

// Verify QR signature before processing payment
exports.verifyQrSignature = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }
  
  const { payload, signature } = data;
  
  if (!payload || !signature) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Missing payload or signature.');
  }
  
  // Verify signature
  const expectedSignature = generateQrSignature(payload);
  if (signature !== expectedSignature) {
    return { valid: false, reason: 'Invalid signature' };
  }
  
  // Parse and check expiry
  let parsedPayload;
  try {
    parsedPayload = JSON.parse(payload);
  } catch (e) {
    return { valid: false, reason: 'Invalid payload format' };
  }
  
  const now = Date.now();
  if (parsedPayload.timestamp && (now - parsedPayload.timestamp) > QR_EXPIRY_MS) {
    return { valid: false, reason: 'QR code expired' };
  }
  
  // Verify wallet exists
  const walletQuery = await db.collection('wallets')
    .where('walletId', '==', parsedPayload.walletId)
    .limit(1)
    .get();
  
  if (walletQuery.empty) {
    return { valid: false, reason: 'Wallet not found' };
  }
  
  const walletData = walletQuery.docs[0].data();
  const userDoc = await db.collection('users').doc(walletQuery.docs[0].id).get();
  
  return {
    valid: true,
    walletId: parsedPayload.walletId,
    amount: parsedPayload.amount,
    note: parsedPayload.note,
    recipientName: userDoc.exists ? userDoc.data().fullName : 'QR Wallet User',
    profilePhotoUrl: userDoc.exists ? userDoc.data().profilePhotoUrl : null
  };
});

// Lookup wallet with rate limiting
exports.lookupWallet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }
  
  const { walletId } = data;
  const userId = context.auth.uid;
  
  // Get IP for rate limiting (hashed for privacy)
  const ip = context.rawRequest?.headers?.['x-forwarded-for'] || 'unknown';
  const hashedIp = crypto.createHash('sha256').update(ip).digest('hex').substring(0, 16);
  
  // Fast in-memory IP rate limit (burst protection within single instance)
  if (!checkRateLimit(`ip:${hashedIp}`, 100, 60000)) {
    throwAppError(ERROR_CODES.RATE_LIMIT_EXCEEDED, 'Too many requests from this location.');
  }

  // Check failed lookup limit (in-memory, per IP)
  if (!checkFailedLookups(hashedIp)) {
    throwAppError(ERROR_CODES.RATE_COOLDOWN_ACTIVE, 'Too many failed attempts. Please wait 5 minutes.');
  }

  // Persistent rate limit (30 lookups per 5 minutes, survives cold starts)
  await enforceRateLimit(userId, 'lookupWallet');
  
  if (!walletId || typeof walletId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Invalid wallet ID.');
  }
  
  // Find wallet
  const walletQuery = await db.collection('wallets')
    .where('walletId', '==', walletId)
    .limit(1)
    .get();
  
  if (walletQuery.empty) {
    recordFailedLookup(hashedIp);
    return { found: false };
  }
  
  const walletDoc = walletQuery.docs[0];
  const walletData = walletDoc.data();
  
  // Get user info
  const userDoc = await db.collection('users').doc(walletDoc.id).get();
  const userData = userDoc.exists ? userDoc.data() : {};
  
  return {
    found: true,
    walletId: walletData.walletId,
    recipientName: userData.fullName || 'QR Wallet User',
    profilePhotoUrl: userData.profilePhotoUrl || null
  };
});


// ============================================================
// SMILE ID PHONE VERIFICATION
// ============================================================

const SMILE_ID_API_KEY = functions.config().smileid?.api_key || '';
const SMILE_ID_PARTNER_ID = functions.config().smileid?.partner_id || '8244';
const SMILE_ID_BASE_URL = 'testapi.smileidentity.com'; // Change to 'api.smileidentity.com' for production

// Helper: Generate Smile ID signature
function generateSmileIdSignature(timestamp) {
  const message = timestamp + SMILE_ID_PARTNER_ID + 'sid_request';
  return crypto.createHmac('sha256', SMILE_ID_API_KEY)
    .update(message)
    .digest('base64');
}

// Helper: Make Smile ID API request
function smileIdRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const timestamp = new Date().toISOString();
    const signature = generateSmileIdSignature(timestamp);

    const options = {
      hostname: SMILE_ID_BASE_URL,
      port: 443,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'smileid-partner-id': SMILE_ID_PARTNER_ID,
        'smileid-request-signature': signature,
        'smileid-timestamp': timestamp,
        'smileid-source-sdk': 'cloud_functions',
        'smileid-source-sdk-version': '1.0.0',
      },
    };

    const req = https.request(options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => responseData += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(responseData);
          resolve(json);
        } catch (e) {
          reject(new Error('Failed to parse Smile ID response: ' + responseData));
        }
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// Verify phone number belongs to ID holder
exports.verifyPhoneNumber = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { phoneNumber, country, firstName, lastName, idNumber } = data;

  // Validate required fields
  if (!phoneNumber || !country) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Phone number and country are required.');
  }

  // Check if country supports phone verification
  const supportedCountries = ['NG', 'GH', 'KE', 'ZA', 'TZ', 'UG'];
  if (!supportedCountries.includes(country.toUpperCase())) {
    return {
      success: false,
      supported: false,
      error: 'Phone verification not available for this country',
    };
  }

  try {
    console.log('Verifying phone:', phoneNumber, 'Country:', country);

    // Format phone number (remove country code prefix if present)
    let formattedPhone = phoneNumber.replace(/\s+/g, '');
    
    // Build match fields (optional - for matching against ID)
    const matchFields = {};
    if (firstName) matchFields.first_name = firstName;
    if (lastName) matchFields.last_name = lastName;
    if (idNumber) matchFields.id_number = idNumber;

    const requestBody = {
      country: country.toUpperCase(),
      phone_number: formattedPhone,
      partner_params: {
        user_id: context.auth.uid,
        job_id: `phone_${Date.now()}`,
        job_type: 7, // Phone verification job type
      },
    };

    // Add match fields if provided
    if (Object.keys(matchFields).length > 0) {
      requestBody.match_fields = matchFields;
    }

    console.log('Smile ID request:', JSON.stringify(requestBody));

    const response = await smileIdRequest('POST', '/v2/verify-phone-number', requestBody);

    console.log('Smile ID response:', JSON.stringify(response));

    if (response.error) {
      return {
        success: false,
        error: response.error,
      };
    }

    // Parse result
    const result = {
      success: true,
      verified: false,
      resultText: response.ResultText || response.result_text || 'Unknown',
      resultCode: response.ResultCode || response.result_code,
      phoneInfo: {},
    };

    // Check verification result
    if (response.ResultCode === '1020' || response.result_code === '1020') {
      result.verified = true;
      result.match = 'Exact Match';
    } else if (response.ResultCode === '1021' || response.result_code === '1021') {
      result.verified = true;
      result.match = 'Partial Match';
    } else if (response.ResultCode === '1022' || response.result_code === '1022') {
      result.verified = false;
      result.match = 'No Match';
    }

    // Extract phone info if available
    if (response.PhoneInfo || response.phone_info) {
      const phoneInfo = response.PhoneInfo || response.phone_info;
      result.phoneInfo = {
        carrier: phoneInfo.carrier || phoneInfo.Carrier,
        phoneType: phoneInfo.phone_type || phoneInfo.PhoneType,
        countryCode: phoneInfo.country_code || phoneInfo.CountryCode,
      };
    }

    // Store verification result
    await db.collection('users').doc(context.auth.uid).collection('verifications').add({
      type: 'phone',
      phoneNumber: formattedPhone,
      country: country.toUpperCase(),
      verified: result.verified,
      resultCode: result.resultCode,
      resultText: result.resultText,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return result;

  } catch (error) {
    console.error('Phone verification error:', error);
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message || 'Verification failed.');
  }
});

// Check if phone verification is supported for a country
exports.checkPhoneVerificationSupport = functions.https.onCall(async (data, context) => {
  const { country } = data;
  
  const supportedCountries = {
    'NG': { supported: true, operators: ['MTN', 'GLO', 'AIRTEL', '9MOBILE'] },
    'GH': { supported: true, operators: ['MTN', 'VODAFONE', 'AIRTELTIGO'] },
    'KE': { supported: true, operators: ['SAFARICOM', 'AIRTEL', 'TELKOM'] },
    'ZA': { supported: true, operators: ['VODACOM', 'MTN', 'CELL C', 'TELKOM'] },
    'TZ': { supported: true, operators: ['VODACOM', 'AIRTEL', 'TIGO', 'HALOTEL'] },
    'UG': { supported: true, operators: ['MTN', 'AIRTEL', 'AFRICELL'] },
  };

  const countryUpper = (country || '').toUpperCase();
  
  if (supportedCountries[countryUpper]) {
    return {
      supported: true,
      country: countryUpper,
      operators: supportedCountries[countryUpper].operators,
    };
  }

  return {
    supported: false,
    country: countryUpper,
    message: 'Phone verification not available for this country',
  };
});

// ============================================================
// SEND MONEY (Wallet to Wallet Transfer)
// ============================================================

// Helper: Generate secure transaction ID
function generateSecureTransactionId() {
  const timestamp = Date.now();
  const random = Math.floor(Math.random() * 10000000);
  return `TXN${timestamp}${random}`;
}

exports.sendMoney = functions.https.onCall(async (data, context) => {
  // 1. Check authentication
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const senderUid = context.auth.uid;

  // Enforce KYC verification before financial operation
  await enforceKyc(senderUid);

  // Enforce persistent rate limiting (20 sends per hour)
  await enforceRateLimit(senderUid, 'sendMoney');

  const { recipientWalletId, amount, note, idempotencyKey } = data;

  // 2. Validate inputs
  if (!recipientWalletId || typeof recipientWalletId !== 'string') {
    throwAppError(ERROR_CODES.TXN_RECIPIENT_NOT_FOUND, 'Invalid recipient wallet ID.');
  }

  if (typeof amount !== 'number' || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID, 'Amount must be positive.');
  }

  if (amount > 10000000) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_TOO_LARGE);
  }

  return withIdempotency(idempotencyKey, 'sendMoney', senderUid, async () => {
  try {
    // 3. Run atomic transaction
    const result = await db.runTransaction(async (transaction) => {
      // Get sender wallet
      const senderWalletRef = db.collection('wallets').doc(senderUid);
      const senderWallet = await transaction.get(senderWalletRef);

      if (!senderWallet.exists) {
        throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Sender wallet not found.');
      }

      const senderData = senderWallet.data();
      const senderBalance = senderData.balance || 0;

      // Calculate fee (1% with min 10, max 100)
      const fee = Math.min(Math.max(amount * 0.01, 10), 100);
      const totalDebit = amount + fee;

      // Check balance
      if (senderBalance < totalDebit) {
        throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS);
      }

      // Prevent self-transfer
      if (senderData.walletId === recipientWalletId) {
        throwAppError(ERROR_CODES.TXN_SELF_TRANSFER);
      }

      // Find recipient
      const recipientQuery = await db.collection('wallets')
        .where('walletId', '==', recipientWalletId)
        .limit(1)
        .get();

      if (recipientQuery.empty) {
        throwAppError(ERROR_CODES.TXN_RECIPIENT_NOT_FOUND);
      }

      const recipientDoc = recipientQuery.docs[0];
      const recipientUid = recipientDoc.id;
      const recipientRef = recipientDoc.ref;
      const recipientData = recipientDoc.data();

      // Get user names
      const senderUserDoc = await transaction.get(db.collection('users').doc(senderUid));
      const recipientUserDoc = await transaction.get(db.collection('users').doc(recipientUid));

      const senderName = senderUserDoc.exists ? senderUserDoc.data().fullName : 'Unknown';
      const recipientName = recipientUserDoc.exists ? recipientUserDoc.data().fullName : 'Unknown';

      // Generate transaction ID
      const txId = generateSecureTransactionId();
      const now = new Date();

      // Deduct from sender
      transaction.update(senderWalletRef, {
        balance: admin.firestore.FieldValue.increment(-totalDebit),
        dailySpent: admin.firestore.FieldValue.increment(totalDebit),
        monthlySpent: admin.firestore.FieldValue.increment(totalDebit),
        updatedAt: now.toISOString()
      });

      // Add to recipient
      transaction.update(recipientRef, {
        balance: admin.firestore.FieldValue.increment(amount),
        updatedAt: now.toISOString()
      });

      // ============================================
      // COLLECT FEE TO PLATFORM WALLET
      // ============================================
      const senderCurrency = senderData.currency || 'GHS';
      
      // Get exchange rates for USD conversion
      const ratesDoc = await db.collection('app_config').doc('exchange_rates').get();
      const rates = ratesDoc.exists ? ratesDoc.data().rates : {};
      const exchangeRate = rates[senderCurrency] || 1;
      const feeInUSD = fee / exchangeRate;
      
      // Update platform wallet USD balance
      const platformWalletRef = db.collection('wallets').doc('platform');
      transaction.update(platformWalletRef, {
        totalBalanceUSD: admin.firestore.FieldValue.increment(feeInUSD),
        totalTransactions: admin.firestore.FieldValue.increment(1),
        totalFeesCollected: admin.firestore.FieldValue.increment(1),
        updatedAt: now.toISOString()
      });
      
      // Update currency-specific balance
      const currencyBalanceRef = db.collection('wallets').doc('platform').collection('balances').doc(senderCurrency);
      transaction.set(currencyBalanceRef, {
        currency: senderCurrency,
        amount: admin.firestore.FieldValue.increment(fee),
        usdEquivalent: admin.firestore.FieldValue.increment(feeInUSD),
        txCount: admin.firestore.FieldValue.increment(1),
        lastTransactionAt: now.toISOString(),
        updatedAt: now.toISOString()
      }, { merge: true });
      
      // Record fee in history
      const feeRecordRef = db.collection('wallets').doc('platform').collection('fees').doc(txId);
      transaction.set(feeRecordRef, {
        transactionId: txId,
        originalAmount: fee,
        currency: senderCurrency,
        usdAmount: feeInUSD,
        exchangeRate: exchangeRate,
        senderUid: senderUid,
        senderName: senderName,
        transferAmount: amount,
        createdAt: now.toISOString()
      });

      // Transaction data
      const baseTxData = {
        id: txId,
        senderWalletId: senderData.walletId,
        receiverWalletId: recipientWalletId,
        senderName: senderName,
        receiverName: recipientName,
        amount: amount,
        fee: fee,
        currency: senderData.currency || 'GHS',
        senderCurrency: senderData.currency || 'GHS',
        receiverCurrency: recipientData.currency || 'GHS',
        note: note || '',
        status: 'completed',
        createdAt: now.toISOString(),
        completedAt: now.toISOString(),
        reference: `TXN-${now.getTime()}`,
        exchangeRate: null,
        convertedAmount: null,
        failureReason: null,
      };

      // Sender transaction record
      transaction.set(
        db.collection('users').doc(senderUid).collection('transactions').doc(txId),
        { ...baseTxData, type: 'send' }
      );

      // Recipient transaction record
      transaction.set(
        db.collection('users').doc(recipientUid).collection('transactions').doc(txId),
        { ...baseTxData, type: 'receive', fee: 0 }
      );

      return {
        transactionId: txId,
        amount: amount,
        fee: fee,
        recipientName: recipientName,
        newBalance: senderBalance - totalDebit
      };
    });

    console.log('sendMoney success:', result.transactionId);

    await auditLog({
      userId: senderUid, operation: 'sendMoney', result: 'success',
      amount, currency: result.currency || 'GHS',
      metadata: { transactionId: result.transactionId, recipientWalletId, fee: result.fee },
      ipHash: hashIp(context),
    });

    return { success: true, ...result };

  } catch (error) {
    console.error('sendMoney error:', error);
    await auditLog({
      userId: senderUid, operation: 'sendMoney', result: 'failure',
      amount,
      metadata: { recipientWalletId },
      error: error.message,
      ipHash: hashIp(context),
    });
    if (error.code) throw error;
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Transaction failed.');
  }
  });
});

// ============================================================
// MTN MOMO API CONFIGURATION
// ============================================================

// MTN MoMo configuration - set via: firebase functions:config:set momo.collections_subscription_key="xxx" etc.
// IMPORTANT: webhook_secret MUST be configured for production to verify callback authenticity
const MOMO_WEBHOOK_SECRET = functions.config().momo?.webhook_secret || '';

const MOMO_CONFIG = {
  collections: {
    subscriptionKey: functions.config().momo?.collections_subscription_key || '',
    apiUser: functions.config().momo?.collections_api_user || '',
    apiKey: functions.config().momo?.collections_api_key || '',
  },
  disbursements: {
    subscriptionKey: functions.config().momo?.disbursements_subscription_key || '',
    apiUser: functions.config().momo?.disbursements_api_user || '',
    apiKey: functions.config().momo?.disbursements_api_key || '',
  },
  baseUrl: functions.config().momo?.environment === 'production'
    ? 'proxy.momoapi.mtn.com'
    : 'sandbox.momodeveloper.mtn.com',
  environment: functions.config().momo?.environment || 'sandbox',
  callbackUrl: MOMO_WEBHOOK_SECRET
    ? `https://us-central1-qr-wallet-1993.cloudfunctions.net/momoWebhook?token=${MOMO_WEBHOOK_SECRET}`
    : 'https://us-central1-qr-wallet-1993.cloudfunctions.net/momoWebhook',
};

// Helper function to get MTN MoMo access token
async function getMomoAccessToken(product) {
  const config = product === 'collections' ? MOMO_CONFIG.collections : MOMO_CONFIG.disbursements;
  requireConfig(config.subscriptionKey, `momo.${product}_subscription_key`);
  requireConfig(config.apiUser, `momo.${product}_api_user`);
  requireConfig(config.apiKey, `momo.${product}_api_key`);
  const credentials = Buffer.from(`${config.apiUser}:${config.apiKey}`).toString('base64');

  return new Promise((resolve, reject) => {
    const options = {
      hostname: MOMO_CONFIG.baseUrl,
      port: 443,
      path: `/${product}/token/`,
      method: 'POST',
      headers: {
        'Authorization': `Basic ${credentials}`,
        'Ocp-Apim-Subscription-Key': config.subscriptionKey,
        'Content-Type': 'application/json',
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.access_token) {
            resolve(json.access_token);
          } else {
            reject(new Error('Failed to get access token: ' + data));
          }
        } catch (e) {
          reject(new Error('Failed to parse token response: ' + data));
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

// Helper function for MTN MoMo API requests
async function momoRequest(product, method, path, data, referenceId) {
  const config = product === 'collections' ? MOMO_CONFIG.collections : MOMO_CONFIG.disbursements;
  const accessToken = await getMomoAccessToken(product);

  return new Promise((resolve, reject) => {
    const options = {
      hostname: MOMO_CONFIG.baseUrl,
      port: 443,
      path: `/${product}${path}`,
      method: method,
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'X-Reference-Id': referenceId,
        'X-Target-Environment': MOMO_CONFIG.environment,
        'Ocp-Apim-Subscription-Key': config.subscriptionKey,
        'Content-Type': 'application/json',
      },
    };

    if (MOMO_CONFIG.environment !== 'sandbox') {
      options.headers['X-Callback-Url'] = MOMO_CONFIG.callbackUrl;
    }

    const req = https.request(options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => responseData += chunk);
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          data: responseData ? JSON.parse(responseData) : null,
        });
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// ============================================================
// MTN MOMO COLLECTIONS - REQUEST TO PAY (Add Money)
// ============================================================

exports.momoRequestToPay = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { amount, currency, phoneNumber, payerMessage, payeeNote, idempotencyKey } = data;
  const userId = context.auth.uid;

  // Fail fast if MoMo collections API is not configured
  requireServiceReady('momo_collections');

  if (!amount || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID);
  }
  if (!phoneNumber) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Phone number is required.');
  }

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Enforce persistent rate limiting (10 MoMo payments per hour)
  await enforceRateLimit(userId, 'momoRequestToPay');

  return withIdempotency(idempotencyKey, 'momoRequestToPay', userId, async () => {
  try {
    // Generate unique reference ID
    const referenceId = crypto.randomUUID();

    // Create request to pay
    const response = await momoRequest('collection', 'POST', '/v1_0/requesttopay', {
      amount: amount.toString(),
      currency: currency || 'EUR', // Sandbox only supports EUR
      externalId: referenceId,
      payer: {
        partyIdType: 'MSISDN',
        partyId: phoneNumber.replace('+', ''),
      },
      payerMessage: payerMessage || 'Add money to QR Wallet',
      payeeNote: payeeNote || 'Wallet deposit',
    }, referenceId);

    console.log('MoMo RequestToPay response:', response);

    if (response.statusCode === 202) {
      // Request accepted - store pending transaction
      await db.collection('momo_transactions').doc(referenceId).set({
        type: 'collection',
        userId: userId,
        amount: amount,
        currency: currency || 'EUR',
        phoneNumber: phoneNumber,
        status: TRANSACTION_STATES.PENDING,
        referenceId: referenceId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        statusHistory: [{ from: null, to: TRANSACTION_STATES.PENDING, timestamp: new Date().toISOString() }],
      });

      await auditLog({
        userId, operation: 'momoRequestToPay', result: 'success',
        amount, currency: currency || 'EUR',
        metadata: { referenceId, phoneNumber },
        ipHash: hashIp(context),
      });

      return {
        success: true,
        referenceId: referenceId,
        status: TRANSACTION_STATES.PENDING,
        message: 'Please approve the payment on your phone',
      };
    } else {
      throwServiceError('momo', new Error('Failed to initiate payment'), { responseData: response.data });
    }
  } catch (error) {
    console.error('MoMo RequestToPay error:', error);
    await auditLog({
      userId, operation: 'momoRequestToPay', result: 'failure',
      amount, currency: currency || 'EUR',
      error: error.message,
      ipHash: hashIp(context),
    });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message);
  }
  });
});

// ============================================================
// MTN MOMO - CHECK TRANSACTION STATUS
// ============================================================

exports.momoCheckStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { referenceId, type } = data;

  if (!referenceId) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Reference ID is required.');
  }

  try {
    const product = type === 'disbursement' ? 'disbursement' : 'collection';
    const path = type === 'disbursement' ? `/v1_0/transfer/${referenceId}` : `/v1_0/requesttopay/${referenceId}`;

    const response = await momoRequest(product, 'GET', path, null, referenceId);

    console.log('MoMo status check response:', response);

    if (response.statusCode === 200 && response.data) {
      const status = response.data.status;

      // Update transaction in Firestore
      const txRef = db.collection('momo_transactions').doc(referenceId);
      const txDoc = await txRef.get();

      if (txDoc.exists) {
        const txData = txDoc.data();

        // If status changed to SUCCESSFUL, credit/debit wallet
        // Use normalizeStatus() to handle both old ('SUCCESSFUL') and new ('completed') stored formats
        if (status === 'SUCCESSFUL' && normalizeStatus(txData.status) !== 'completed') {
          await db.runTransaction(async (transaction) => {
            // Get user's wallet
            const walletSnapshot = await db.collection('wallets')
              .where('userId', '==', txData.userId)
              .limit(1)
              .get();

            if (!walletSnapshot.empty) {
              const walletDoc = walletSnapshot.docs[0];
              const walletData = walletDoc.data();

              if (txData.type === 'collection') {
                // Add money - credit wallet
                transaction.update(walletDoc.ref, {
                  balance: (walletData.balance || 0) + txData.amount,
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                // Record transaction
                transaction.set(db.collection('users').doc(txData.userId).collection('transactions').doc(referenceId), {
                  id: referenceId,
                  type: 'deposit',
                  amount: txData.amount,
                  currency: txData.currency,
                  method: 'MTN MoMo',
                  phoneNumber: txData.phoneNumber,
                  status: 'completed',
                  createdAt: txData.createdAt,
                  completedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              } else {
                // Disbursement already debited wallet, just record completion
                transaction.set(db.collection('users').doc(txData.userId).collection('transactions').doc(referenceId), {
                  id: referenceId,
                  type: 'withdrawal',
                  amount: txData.amount,
                  currency: txData.currency,
                  method: 'MTN MoMo',
                  phoneNumber: txData.phoneNumber,
                  status: 'completed',
                  createdAt: txData.createdAt,
                  completedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              }
            }

            // Update momo transaction status with state machine validation
            transaction.update(txRef, {
              ...buildStateTransitionFields(txData.status, status, referenceId),
              providerStatus: status,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          });
        } else {
          // Just update status with state machine validation
          await updateTransactionState(txRef, status, {
            providerStatus: status,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      return {
        success: true,
        status: status,
        data: response.data,
      };
    } else {
      return {
        success: false,
        status: 'UNKNOWN',
        error: 'Failed to get status',
      };
    }
  } catch (error) {
    console.error('MoMo status check error:', error);
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message);
  }
});

// ============================================================
// MTN MOMO DISBURSEMENTS - TRANSFER (Withdraw)
// ============================================================

exports.momoTransfer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { amount, currency, phoneNumber, payerMessage, payeeNote, idempotencyKey } = data;
  const userId = context.auth.uid;

  // Fail fast if MoMo disbursements API is not configured
  requireServiceReady('momo_disbursements');

  if (!amount || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID);
  }
  if (!phoneNumber) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Phone number is required.');
  }

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Enforce persistent rate limiting (5 MoMo transfers per hour)
  await enforceRateLimit(userId, 'momoTransfer');

  return withIdempotency(idempotencyKey, 'momoTransfer', userId, async () => {
  try {
    // Check wallet balance
    const walletSnapshot = await db.collection('wallets')
      .where('userId', '==', userId)
      .limit(1)
      .get();

    if (walletSnapshot.empty) {
      throwAppError(ERROR_CODES.WALLET_NOT_FOUND);
    }

    const walletDoc = walletSnapshot.docs[0];
    const walletData = walletDoc.data();

    if ((walletData.balance || 0) < amount) {
      throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS);
    }

    // Generate unique reference ID
    const referenceId = crypto.randomUUID();

    // Debit wallet first
    await db.runTransaction(async (transaction) => {
      const freshWallet = await transaction.get(walletDoc.ref);
      const currentBalance = freshWallet.data().balance || 0;

      if (currentBalance < amount) {
        throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS);
      }

      transaction.update(walletDoc.ref, {
        balance: currentBalance - amount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Store pending withdrawal
      transaction.set(db.collection('momo_transactions').doc(referenceId), {
        type: 'disbursement',
        userId: userId,
        amount: amount,
        currency: currency || 'EUR',
        phoneNumber: phoneNumber,
        status: TRANSACTION_STATES.PENDING,
        referenceId: referenceId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        statusHistory: [{ from: null, to: TRANSACTION_STATES.PENDING, timestamp: new Date().toISOString() }],
      });
    });

    // Create transfer request
    const response = await momoRequest('disbursement', 'POST', '/v1_0/transfer', {
      amount: amount.toString(),
      currency: currency || 'EUR', // Sandbox only supports EUR
      externalId: referenceId,
      payee: {
        partyIdType: 'MSISDN',
        partyId: phoneNumber.replace('+', ''),
      },
      payerMessage: payerMessage || 'Withdrawal from QR Wallet',
      payeeNote: payeeNote || 'Wallet withdrawal',
    }, referenceId);

    console.log('MoMo Transfer response:', response);

    if (response.statusCode === 202) {
      await auditLog({
        userId, operation: 'momoTransfer', result: 'success',
        amount, currency: currency || 'EUR',
        metadata: { referenceId, phoneNumber },
        ipHash: hashIp(context),
      });

      return {
        success: true,
        referenceId: referenceId,
        status: 'PENDING',
        message: 'Withdrawal is being processed',
      };
    } else {
      // Refund wallet if transfer failed
      await db.runTransaction(async (transaction) => {
        const freshWallet = await transaction.get(walletDoc.ref);
        const currentBalance = freshWallet.data().balance || 0;

        transaction.update(walletDoc.ref, {
          balance: currentBalance + amount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        transaction.update(db.collection('momo_transactions').doc(referenceId), {
          ...buildStateTransitionFields(TRANSACTION_STATES.PENDING, TRANSACTION_STATES.FAILED, referenceId),
          providerStatus: 'FAILED',
          failureReason: JSON.stringify(response.data),
          refunded: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      throwServiceError('momo', new Error('Failed to initiate transfer'), { responseData: response.data });
    }
  } catch (error) {
    console.error('MoMo Transfer error:', error);
    await auditLog({
      userId, operation: 'momoTransfer', result: 'failure',
      amount, currency: currency || 'EUR',
      error: error.message,
      ipHash: hashIp(context),
    });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message);
  }
  });
});

// ============================================================
// MTN MOMO - GET BALANCE
// ============================================================

exports.momoGetBalance = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { product } = data; // 'collection' or 'disbursement'

  try {
    const response = await momoRequest(
      product || 'collection',
      'GET',
      '/v1_0/account/balance',
      null,
      crypto.randomUUID()
    );

    if (response.statusCode === 200) {
      return {
        success: true,
        balance: response.data,
      };
    } else {
      throwServiceError('momo', new Error('Failed to get balance'));
    }
  } catch (error) {
    console.error('MoMo balance error:', error);
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, error.message);
  }
});

// ============================================================
// MTN MOMO - WEBHOOK (Callback for async notifications)
// ============================================================

exports.momoWebhook = functions.https.onRequest(async (req, res) => {
  // ── LAYER 1: HTTP Method Restriction ──
  if (req.method !== 'POST') {
    console.warn('MoMo webhook: rejected non-POST request:', req.method);
    return res.status(405).send('Method Not Allowed');
  }

  // ── LAYER 2: Webhook Secret Token Verification ──
  // The token is appended to the callback URL registered with MoMo.
  // Only MoMo (which received the URL) should know the token.
  if (MOMO_WEBHOOK_SECRET) {
    const token = req.query.token;
    if (!token || token !== MOMO_WEBHOOK_SECRET) {
      console.error('MoMo webhook: invalid or missing webhook token');
      return res.status(403).send('Forbidden');
    }
  } else if (MOMO_CONFIG.environment === 'production') {
    // In production, a webhook secret MUST be configured
    console.error('MoMo webhook: CRITICAL - no webhook_secret configured in production');
    return res.status(503).send('Service misconfigured');
  }

  console.log('MoMo webhook received (authenticated):', JSON.stringify(req.body));

  try {
    const { externalId, status, financialTransactionId } = req.body;

    // ── LAYER 3: Request Body Validation ──
    if (!externalId || typeof externalId !== 'string' || !status) {
      console.error('MoMo webhook: missing or invalid required fields');
      return res.status(400).send('Bad Request');
    }

    // ── LAYER 4: Transaction Existence Verification ──
    // Only process callbacks for transactions WE initiated
    const txRef = db.collection('momo_transactions').doc(externalId);
    const txDoc = await txRef.get();

    if (!txDoc.exists) {
      console.error('MoMo webhook: unknown externalId (not initiated by us):', externalId);
      return res.status(404).send('Transaction not found');
    }

    const txData = txDoc.data();

    // ── LAYER 5: Cross-Verify Status via MoMo API ──
    // Never trust the callback body alone. Independently confirm the
    // transaction status by calling MoMo's GET status endpoint.
    let verifiedStatus = null;
    try {
      const product = txData.type === 'disbursement' ? 'disbursement' : 'collection';
      const statusPath = txData.type === 'disbursement'
        ? `/v1_0/transfer/${externalId}`
        : `/v1_0/requesttopay/${externalId}`;

      const apiResponse = await momoRequest(product, 'GET', statusPath, null, externalId);

      if (apiResponse.statusCode === 200 && apiResponse.data && apiResponse.data.status) {
        verifiedStatus = apiResponse.data.status;
        console.log(`MoMo webhook cross-verified: callback=${status}, api=${verifiedStatus}, ref=${externalId}`);

        if (verifiedStatus !== status) {
          console.warn(`MoMo webhook STATUS MISMATCH: callback=${status}, api=${verifiedStatus} for ref=${externalId}`);
          // Trust the API response, not the callback
        }
      } else {
        console.warn('MoMo webhook: cross-verification returned unexpected response:', apiResponse.statusCode);
      }
    } catch (verifyError) {
      console.error('MoMo webhook: cross-verification error:', verifyError.message);
    }

    // In production, reject if cross-verification failed
    if (!verifiedStatus && MOMO_CONFIG.environment === 'production') {
      console.error('MoMo webhook: rejecting callback — unable to cross-verify in production');
      return res.status(502).send('Unable to verify transaction status');
    }

    // Use verified status (from API) or fall back to callback status in sandbox
    const effectiveStatus = verifiedStatus || status;

    // ── Process the verified transaction status ──
    // Use normalizeStatus() to handle both old ('SUCCESSFUL') and new ('completed') stored formats
    if (effectiveStatus === 'SUCCESSFUL' && normalizeStatus(txData.status) !== 'completed') {
      await db.runTransaction(async (transaction) => {
        const walletSnapshot = await db.collection('wallets')
          .where('userId', '==', txData.userId)
          .limit(1)
          .get();

        if (!walletSnapshot.empty) {
          const walletDoc = walletSnapshot.docs[0];
          const walletData = walletDoc.data();

          if (txData.type === 'collection') {
            transaction.update(walletDoc.ref, {
              balance: (walletData.balance || 0) + txData.amount,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          transaction.set(db.collection('users').doc(txData.userId).collection('transactions').doc(externalId), {
            id: externalId,
            type: txData.type === 'collection' ? 'deposit' : 'withdrawal',
            amount: txData.amount,
            currency: txData.currency,
            method: 'MTN MoMo',
            phoneNumber: txData.phoneNumber,
            status: 'completed',
            financialTransactionId: financialTransactionId,
            createdAt: txData.createdAt,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        transaction.update(txRef, {
          ...buildStateTransitionFields(txData.status, effectiveStatus, externalId),
          providerStatus: effectiveStatus,
          financialTransactionId: financialTransactionId,
          callbackStatus: status,
          verifiedStatus: verifiedStatus,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } else if (effectiveStatus === 'FAILED') {
      // Refund if disbursement failed
      if (txData.type === 'disbursement') {
        await db.runTransaction(async (transaction) => {
          const walletSnapshot = await db.collection('wallets')
            .where('userId', '==', txData.userId)
            .limit(1)
            .get();

          if (!walletSnapshot.empty) {
            const walletDoc = walletSnapshot.docs[0];
            const walletData = walletDoc.data();

            transaction.update(walletDoc.ref, {
              balance: (walletData.balance || 0) + txData.amount,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          transaction.update(txRef, {
            ...buildStateTransitionFields(txData.status, effectiveStatus, externalId),
            providerStatus: effectiveStatus,
            refunded: true,
            callbackStatus: status,
            verifiedStatus: verifiedStatus,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
      } else {
        await updateTransactionState(txRef, effectiveStatus, {
          providerStatus: effectiveStatus,
          callbackStatus: status,
          verifiedStatus: verifiedStatus,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } else {
      // Status is PENDING or already processed — just log and acknowledge
      console.log(`MoMo webhook: no action needed for status=${effectiveStatus}, current=${txData.status}`);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('MoMo webhook error:', error);
    res.status(500).send('Error');
  }
});
