const functions = require('firebase-functions');
const { defineSecret, defineString } = require('firebase-functions/params');

// ============================================================
// PARAMS (Phase 2.0.2 migration — non-critical configs)
// ============================================================
// Secrets — encrypted, stored in Firebase Secrets Manager
const AT_API_KEY                 = defineSecret('AT_API_KEY');
const SMILE_ID_API_KEY_PARAM     = defineSecret('SMILE_ID_API_KEY');
const ADMIN_EXCHANGE_RATE_SECRET = defineSecret('ADMIN_EXCHANGE_RATE_SECRET');

// Non-secret params (plaintext strings)
const AT_USERNAME                = defineString('AT_USERNAME', { default: 'sandbox' });
const AT_ENVIRONMENT             = defineString('AT_ENVIRONMENT', { default: 'sandbox' });
const SMILE_ID_PARTNER_ID_PARAM  = defineString('SMILE_ID_PARTNER_ID', { default: '8244' });
const SMILE_ID_ENVIRONMENT       = defineString('SMILE_ID_ENVIRONMENT', { default: 'sandbox' });
const APP_ENVIRONMENT            = defineString('APP_ENVIRONMENT', { default: 'sandbox' });
const PIN_SECRET_PARAM            = defineSecret('PIN_SECRET');
const QR_SECRET_PARAM             = defineSecret('QR_SECRET');
const PAYSTACK_SECRET_KEY_PARAM   = defineSecret('PAYSTACK_SECRET_KEY');

const MOMO_COLLECTIONS_SUBSCRIPTION_KEY_PARAM  = defineSecret('MOMO_COLLECTIONS_SUBSCRIPTION_KEY');
const MOMO_COLLECTIONS_API_USER_PARAM          = defineSecret('MOMO_COLLECTIONS_API_USER');
const MOMO_COLLECTIONS_API_KEY_PARAM           = defineSecret('MOMO_COLLECTIONS_API_KEY');
const MOMO_DISBURSEMENTS_SUBSCRIPTION_KEY_PARAM = defineSecret('MOMO_DISBURSEMENTS_SUBSCRIPTION_KEY');
const MOMO_DISBURSEMENTS_API_USER_PARAM        = defineSecret('MOMO_DISBURSEMENTS_API_USER');
const MOMO_DISBURSEMENTS_API_KEY_PARAM         = defineSecret('MOMO_DISBURSEMENTS_API_KEY');
const MOMO_WEBHOOK_SECRET_PARAM                = defineSecret('MOMO_WEBHOOK_SECRET_VAL');
const MOMO_ENVIRONMENT                         = defineString('MOMO_ENVIRONMENT', { default: 'sandbox' });
const RESEND_API_KEY_PARAM = defineSecret('RESEND_API_KEY');

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

  // Wallet Holds
  HOLD_NOT_FOUND: 'HOLD_NOT_FOUND',
  HOLD_INVALID_STATE: 'HOLD_INVALID_STATE',
  HOLD_CURRENCY_MISMATCH: 'HOLD_CURRENCY_MISMATCH',
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
  HOLD_NOT_FOUND: 'not-found',
  HOLD_INVALID_STATE: 'failed-precondition',
  HOLD_CURRENCY_MISMATCH: 'invalid-argument',
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
  HOLD_NOT_FOUND: 'Hold not found.',
  HOLD_INVALID_STATE: 'This hold cannot be modified in its current state.',
  HOLD_CURRENCY_MISMATCH: 'Currency does not match the wallet currency.',
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

  logError(`throwAppError: ${code}`, { errorCode: code, userMessage: message, details });

  throw new functions.https.HttpsError(httpCode, message, {
    code,
    message,
    ...details,
    timestamp: timestamps.isoNow(),
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

  logError(`throwServiceError: ${serviceName}`, { errorCode: code, service: serviceName, originalError: originalError.message || String(originalError), context });

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
// TIMING-SAFE COMPARISON HELPER
// ============================================================

/**
 * Performs timing-safe string comparison to prevent timing attacks.
 * Returns true if strings are equal, false otherwise.
 *
 * @param {string} a - First string (typically computed hash)
 * @param {string} b - Second string (typically provided hash)
 * @param {string} encoding - Encoding of strings ('hex', 'utf8', etc.)
 * @returns {boolean}
 */
function timingSafeCompare(a, b, encoding = 'hex') {
  try {
    if (!a || !b) return false;

    const bufA = Buffer.from(String(a), encoding);
    const bufB = Buffer.from(String(b), encoding);

    if (bufA.length !== bufB.length) {
      // Perform dummy comparison to maintain constant time
      crypto.timingSafeEqual(bufA, bufA);
      return false;
    }

    return crypto.timingSafeEqual(bufA, bufB);
  } catch (error) {
    return false;
  }
}

// ============================================================
// STRUCTURED LOGGING FRAMEWORK
// ============================================================

/**
 * Log severity levels aligned with Google Cloud Logging.
 * JSON output is automatically parsed by Cloud Logging.
 */
const LOG_LEVELS = {
  DEBUG: 'DEBUG', INFO: 'INFO', NOTICE: 'NOTICE',
  WARNING: 'WARNING', ERROR: 'ERROR', CRITICAL: 'CRITICAL',
};

/**
 * Core structured logging function.
 * Outputs JSON that Google Cloud Logging parses automatically.
 */
function logStructured(level, message, data = {}) {
  const entry = {
    severity: level,
    message,
    timestamp: new Date().toISOString(),
    ...data,
  };
  const output = JSON.stringify(entry);
  switch (level) {
    case LOG_LEVELS.ERROR:
    case LOG_LEVELS.CRITICAL:
      console.error(output);
      break;
    case LOG_LEVELS.WARNING:
      console.warn(output);
      break;
    default:
      console.log(output);
  }
}

function logInfo(message, data = {}) { logStructured(LOG_LEVELS.INFO, message, data); }
function logWarning(message, data = {}) { logStructured(LOG_LEVELS.WARNING, message, data); }
function logError(message, data = {}) { logStructured(LOG_LEVELS.ERROR, message, data); }

// ============================================================
// PII MASKING UTILITIES
// ============================================================

/**
 * Masks sensitive data for logging purposes.
 * Preserves enough information for debugging without exposing full PII.
 */
const maskPii = {
  /** Mask phone number: +233501234567 → +233****4567 */
  phone: (phone) => {
    if (!phone || typeof phone !== 'string') return '[no phone]';
    const cleaned = phone.replace(/\s/g, '');
    if (cleaned.length < 6) return '****';
    return cleaned.slice(0, 4) + '****' + cleaned.slice(-4);
  },

  /** Mask bank account: 1234567890 → ******7890 */
  account: (account) => {
    if (!account || typeof account !== 'string') return '[no account]';
    const cleaned = account.replace(/\s/g, '');
    if (cleaned.length < 4) return '****';
    return '******' + cleaned.slice(-4);
  },

  /** Mask name: John Doe → J*** D** */
  name: (name) => {
    if (!name || typeof name !== 'string') return '[no name]';
    return name.split(' ')
      .map(part => part.charAt(0) + '***')
      .join(' ');
  },

  /** Mask email: john.doe@example.com → j***@e***.com */
  email: (email) => {
    if (!email || typeof email !== 'string') return '[no email]';
    const [local, domain] = email.split('@');
    if (!domain) return '***@***';
    const domainParts = domain.split('.');
    const maskedLocal = local.charAt(0) + '***';
    const maskedDomain = domainParts[0].charAt(0) + '***.' + domainParts.slice(1).join('.');
    return `${maskedLocal}@${maskedDomain}`;
  },

  /** Mask ID number: GHA-123456789 → *****6789 */
  idNumber: (id) => {
    if (!id || typeof id !== 'string') return '[no id]';
    if (id.length < 4) return '****';
    return '*****' + id.slice(-4);
  },

  /**
   * Auto-mask known PII fields in a data object.
   * Recognizes common field names and applies appropriate masking.
   */
  object: (obj) => {
    if (!obj || typeof obj !== 'object') return obj;

    const masked = { ...obj };

    const fieldMasks = {
      phoneNumber: maskPii.phone,
      phone: maskPii.phone,
      phone_number: maskPii.phone,
      formattedPhone: maskPii.phone,
      accountNumber: maskPii.account,
      account_number: maskPii.account,
      bankAccount: maskPii.account,
      accountName: maskPii.name,
      account_name: maskPii.name,
      fullName: maskPii.name,
      full_name: maskPii.name,
      firstName: maskPii.name,
      first_name: maskPii.name,
      lastName: maskPii.name,
      last_name: maskPii.name,
      email: maskPii.email,
      idNumber: maskPii.idNumber,
      id_number: maskPii.idNumber,
      nin: maskPii.idNumber,
      bvn: maskPii.idNumber,
    };

    for (const [key, maskFn] of Object.entries(fieldMasks)) {
      if (key in masked && masked[key]) {
        masked[key] = maskFn(masked[key]);
      }
    }

    return masked;
  },
};

/**
 * Log a financial operation with required context.
 * Flagged for Cloud Logging filters: jsonPayload.financial=true
 * Automatically masks PII fields in data.
 */
function logFinancialOperation(operation, status, data = {}) {
  const maskedData = maskPii.object(data);
  logInfo(`Financial: ${operation} ${status}`, { operation, status, financial: true, ...maskedData });
}

/**
 * Log a security-relevant event.
 * Flagged for Cloud Logging alerts: jsonPayload.security=true
 */
function logSecurityEvent(event, severity, data = {}) {
  const level = severity === 'high' ? LOG_LEVELS.WARNING : LOG_LEVELS.NOTICE;
  logStructured(level, `Security: ${event}`, { event, security: true, severity, ...data });
}

// ============================================================
// TIMESTAMP STANDARDIZATION
// ============================================================

/**
 * TIMESTAMP RULES:
 *
 * 1. FIRESTORE DOCUMENTS: Use serverTimestamp() for all time fields.
 * 2. ARRAY ENTRIES (e.g. statusHistory): Use timestamps.firestoreNow()
 *    since FieldValue.serverTimestamp() is not supported inside arrays.
 * 3. LOGS: Use timestamps.isoNow() for ISO 8601 UTC strings.
 * 4. CALCULATIONS: Use Date.now() for millisecond arithmetic.
 * 5. TTL FIELDS: Use timestamps.expiresIn(ms) for Firestore Timestamps.
 * 6. NEVER: Trust client-provided timestamps for financial records.
 */
const timestamps = {
  /** Firestore server-managed timestamp for document fields */
  serverTimestamp: () => admin.firestore.FieldValue.serverTimestamp(),

  /** Firestore Timestamp from Cloud Function clock (for array entries) */
  firestoreNow: () => admin.firestore.Timestamp.now(),

  /** ISO 8601 UTC string for logs and non-persisted data */
  isoNow: () => new Date().toISOString(),

  /** Milliseconds since epoch for arithmetic */
  nowMs: () => Date.now(),

  /** Firestore Timestamp for TTL/expiry fields */
  expiresIn: (ms) => admin.firestore.Timestamp.fromDate(new Date(Date.now() + ms)),
};

// ============================================================
// DEFENSIVE SCHEMA VALIDATION GUARDS
// ============================================================

/**
 * VALIDATION RULES:
 * 1. requireString() — assert a value is a non-empty string.
 * 2. requireNumber() — assert a value is a finite, non-NaN number.
 * 3. requirePositiveNumber() — assert a value is a positive finite number.
 * 4. validateWalletDocument() — verify a wallet document has the expected shape
 *    before performing any balance arithmetic. Fails loudly if corrupted.
 * 5. safeAdd() / safeSubtract() — defensive balance arithmetic with overflow
 *    checks and NaN guards. Returns a plain number, never NaN/Infinity.
 */

/**
 * Assert value is a non-empty string.
 * @param {*} value
 * @param {string} fieldName - Name for error messages
 * @returns {string} The validated string
 */
function requireString(value, fieldName) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, `${fieldName} must be a non-empty string.`);
  }
  return value.trim();
}

/**
 * Assert value is a finite number (not NaN, not Infinity).
 * @param {*} value
 * @param {string} fieldName
 * @returns {number} The validated number
 */
function requireNumber(value, fieldName) {
  const num = Number(value);
  if (!Number.isFinite(num)) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, `${fieldName} must be a valid number.`);
  }
  return num;
}

/**
 * Assert value is a positive finite number (> 0).
 * @param {*} value
 * @param {string} fieldName
 * @returns {number}
 */
function requirePositiveNumber(value, fieldName) {
  const num = requireNumber(value, fieldName);
  if (num <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID, `${fieldName} must be greater than zero.`);
  }
  return num;
}

/**
 * Validate a wallet Firestore document has the required shape.
 * Call this after reading a wallet document and before any balance arithmetic.
 *
 * @param {Object} walletData - The wallet document data
 * @param {string} context - Description for error messages (e.g. 'sender wallet')
 * @returns {{ balance: number, currency: string }} Validated wallet fields
 */
function validateWalletDocument(walletData, context = 'wallet') {
  if (!walletData || typeof walletData !== 'object') {
    logError('Wallet document validation failed: missing data', { context });
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, `${context} data is missing or corrupt.`);
  }

  const balance = Number(walletData.balance);
  if (!Number.isFinite(balance) || balance < 0) {
    logError('Wallet document validation failed: invalid balance', {
      context,
      rawBalance: walletData.balance,
      parsedBalance: balance,
    });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, `${context} has an invalid balance. Contact support.`);
  }

  const currency = walletData.currency || 'GHS';
  if (typeof currency !== 'string') {
    logError('Wallet document validation failed: invalid currency', { context, currency });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, `${context} has an invalid currency. Contact support.`);
  }

  return { balance, currency };
}

/**
 * Safely add two numbers, guarding against NaN / Infinity / negative results.
 * Intended for balance credits.
 *
 * @param {number} base - Current balance
 * @param {number} addend - Amount to add
 * @param {string} context - Description for error messages
 * @returns {number} The result
 */
function safeAdd(base, addend, context = 'balance credit') {
  const result = Number(base) + Number(addend);
  if (!Number.isFinite(result) || result < 0) {
    logError('safeAdd produced invalid result', { base, addend, result, context });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, `Arithmetic error during ${context}. Contact support.`);
  }
  return result;
}

/**
 * Safely subtract, guarding against NaN / Infinity / negative results.
 * Intended for balance debits. Returns an error if result would be negative.
 *
 * @param {number} base - Current balance
 * @param {number} subtrahend - Amount to subtract
 * @param {string} context - Description for error messages
 * @returns {number} The result
 */
function safeSubtract(base, subtrahend, context = 'balance debit') {
  const result = Number(base) - Number(subtrahend);
  if (!Number.isFinite(result)) {
    logError('safeSubtract produced non-finite result', { base, subtrahend, result, context });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, `Arithmetic error during ${context}. Contact support.`);
  }
  if (result < 0) {
    throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS, `Insufficient funds for ${context}.`);
  }
  return result;
}

/**
 * Supported currencies whitelist.
 * Only these currencies are accepted for transactions.
 */
const VALID_CURRENCIES = new Set([
  'GHS', 'NGN', 'KES', 'ZAR', 'TZS', 'UGX', 'RWF',
  'USD', 'EUR', 'GBP',
  'XOF', 'XAF', 'EGP',
  'GNF', 'LRD', 'ZMW', 'ZWG', 'SZL', 'SSP', 'SLL', 'CDF',
]);

/**
 * Validate that a currency code is in the whitelist.
 * @param {string} currency - Currency code to validate
 * @param {string} defaultCurrency - Default if not provided
 * @returns {string} Validated currency code (uppercase)
 */
function validateCurrency(currency, defaultCurrency = 'GHS') {
  const code = (currency || defaultCurrency).toUpperCase().trim();
  if (!VALID_CURRENCIES.has(code)) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED,
      `Unsupported currency: ${code}. Supported: ${[...VALID_CURRENCIES].join(', ')}`);
  }
  return code;
}

/**
 * Validate and normalize a phone number to E.164 format.
 *
 * @param {string} phone - Phone number to validate
 * @param {string} defaultCountryCode - Default country code (e.g., '233' for Ghana)
 * @returns {string} Normalized E.164 phone number
 * @throws {HttpsError} If phone number is invalid
 */
function validatePhoneNumber(phone, defaultCountryCode = '233') {
  if (!phone || typeof phone !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Phone number is required');
  }

  // Remove whitespace and common separators
  let cleaned = phone.replace(/[\s\-\(\)\.]/g, '');

  // Normalize to international format
  if (cleaned.startsWith('+')) {
    // Already has country code
  } else if (cleaned.startsWith('00')) {
    cleaned = '+' + cleaned.slice(2);
  } else if (cleaned.startsWith('0')) {
    cleaned = '+' + defaultCountryCode + cleaned.slice(1);
  } else if (!cleaned.startsWith('+')) {
    cleaned = '+' + defaultCountryCode + cleaned;
  }

  // Validate E.164: + followed by 7-15 digits
  const e164Regex = /^\+[1-9]\d{6,14}$/;

  if (!e164Regex.test(cleaned)) {
    throwAppError(
      ERROR_CODES.SYSTEM_VALIDATION_FAILED,
      'Invalid phone number format. Use international format (e.g., +233501234567)'
    );
  }

  return cleaned;
}

// ============================================================
// REQUEST CORRELATION FRAMEWORK
// ============================================================

/**
 * Extracts or generates a correlation ID for request tracing.
 *
 * Priority:
 * 1. X-Request-ID header (from API gateway/load balancer)
 * 2. X-Correlation-ID header (from upstream service)
 * 3. Generate new ID if none provided
 *
 * @param {Object} context - Cloud Function context
 * @returns {string} Correlation ID
 */
function getCorrelationId(context) {
  const headers = context?.rawRequest?.headers || {};

  const existingId =
    headers['x-request-id'] ||
    headers['x-correlation-id'] ||
    headers['X-Request-ID'] ||
    headers['X-Correlation-ID'];

  if (existingId && typeof existingId === 'string') {
    return existingId;
  }

  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 10);
  return `corr_${timestamp}_${random}`;
}

/**
 * Creates a correlation context for logging and audit throughout a function call.
 *
 * @param {Object} context - Cloud Function context
 * @param {string} functionName - Name of the Cloud Function
 * @returns {Object} Correlation context with helper methods
 */
function createCorrelationContext(context, functionName) {
  const correlationId = getCorrelationId(context);
  const userId = context?.auth?.uid || 'anonymous';

  return {
    correlationId,
    functionName,
    userId,
    startTime: Date.now(),

    /** Fields for structured log entries */
    toLogContext() {
      return {
        correlationId: this.correlationId,
        functionName: this.functionName,
        userId: this.userId,
      };
    },

    /** Fields for audit log entries (includes duration) */
    toAuditContext() {
      return {
        correlationId: this.correlationId,
        functionName: this.functionName,
        durationMs: Date.now() - this.startTime,
      };
    },
  };
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
// ENVIRONMENT CONFIGURATION ENFORCEMENT (Phase 2.0.4 — params-based)
// ============================================================
//
// After the Phase 2.0.x migration, secrets come from Firebase Secrets Manager
// via defineSecret() params. Values are resolved at runtime (inside CF handlers)
// — not at module-load time. The old CRITICAL_CONFIGS map that read
// functions.config() at cold-start has been removed.
//
// Each CF that needs a secret is responsible for:
//   1. Declaring it via runWith({ secrets: [...] })
//   2. Accessing it via SECRET.value()  (or SECRET.value for our getter wrappers)
//   3. Optionally calling requireConfig(SECRET.value, 'name') for clear errors
//
// requireServiceReady() is preserved for user-facing "service unavailable"
// messages (e.g., "Mobile Money is coming soon"). It checks params at runtime.

/**
 * Validates that all required configs for a service are present at RUNTIME.
 * Reads secret values via the params API.
 *
 * @param {string} serviceName - Service name (e.g., 'paystack', 'momo_collections')
 * @throws {HttpsError} failed-precondition if any required config is missing
 */
function requireServiceReady(serviceName) {
  let allPresent = true;

  switch (serviceName) {
    case 'paystack':
      allPresent = !!PAYSTACK_SECRET_KEY.value;
      break;
    case 'qr':
      allPresent = !!QR_SECRET_KEY.value;
      break;
    case 'momo_collections':
      allPresent =
        !!MOMO_CONFIG.collections.subscriptionKey &&
        !!MOMO_CONFIG.collections.apiUser &&
        !!MOMO_CONFIG.collections.apiKey;
      break;
    case 'momo_disbursements':
      allPresent =
        !!MOMO_CONFIG.disbursements.subscriptionKey &&
        !!MOMO_CONFIG.disbursements.apiUser &&
        !!MOMO_CONFIG.disbursements.apiKey;
      break;
    case 'momo_webhook':
      allPresent = !!MOMO_WEBHOOK_SECRET.value;
      break;
    default:
      return; // Unknown service, skip check
  }

  if (!allPresent) {
    let userMessage;
    if (serviceName.startsWith('momo')) {
      userMessage = 'Mobile Money is coming soon! This feature is not yet available in your region.';
    } else {
      userMessage = 'Service temporarily unavailable. Please try again later or use a different payment method.';
    }
    throwAppError(ERROR_CODES.CONFIG_MISSING, userMessage);
  }
}

// ============================================================
// PAYSTACK CONFIGURATION
// ============================================================

// Paystack configuration - set via: firebase functions:config:set paystack.secret_key="sk_live_xxx"
// REQUIRED: Must be configured. Functions will fail with clear errors if missing.
// PAYSTACK_SECRET_KEY wrapper: defer .value() to runtime. Usage stays `PAYSTACK_SECRET_KEY.value` (no parens).
const PAYSTACK_SECRET_KEY = { get value() { return PAYSTACK_SECRET_KEY_PARAM.value() || ''; } };
const PAYSTACK_BASE_URL = 'api.paystack.co';

// Helper function for Paystack API calls
const HTTP_TIMEOUT_MS = 15000; // 15 seconds for all external API calls

function paystackRequest(method, path, data = null) {
  requireConfig(PAYSTACK_SECRET_KEY.value, 'paystack.secret_key');
  return new Promise((resolve, reject) => {
    const options = {
      hostname: PAYSTACK_BASE_URL,
      port: 443,
      path: path,
      method: method,
      headers: {
        'Authorization': `Bearer ${PAYSTACK_SECRET_KEY.value}`,
        'Content-Type': 'application/json',
      },
      timeout: HTTP_TIMEOUT_MS,
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

    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`Paystack request timed out after ${HTTP_TIMEOUT_MS}ms: ${method} ${path}`));
    });

    req.on('error', (error) => {
      if (error.code === 'ECONNRESET') {
        reject(new Error(`Paystack connection reset: ${method} ${path}`));
      } else {
        reject(error);
      }
    });

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// ============================================================
// EMAIL + SMS HELPERS (Phase 2b)
// ============================================================

/**
 * Helper: send email via Resend. If Resend fails, queue for retry.
 * Never throws — workflow should never be blocked by email delivery.
 *
 * @param {Object} params
 * @param {string} params.to
 * @param {string} params.toName
 * @param {string} params.subject
 * @param {string} params.htmlBody
 * @param {string} params.textBody
 * @param {string} [params.replyTo]
 * @param {string} [params.relatedTo]  e.g., "proposal:PLT-..."
 */
async function sendProposalEmail({ to, toName, subject, htmlBody, textBody, replyTo, relatedTo }) {
  const fromEmail = 'qrwallet@bongroups.co';
  const fromName = 'QR Wallet Admin';

  try {
    const { Resend } = require('resend');
    const resend = new Resend(RESEND_API_KEY_PARAM.value());

    await resend.emails.send({
      from: `${fromName} <${fromEmail}>`,
      to: [toName ? `${toName} <${to}>` : to],
      subject,
      html: htmlBody,
      text: textBody,
      replyTo: replyTo || 'noreply@bongroups.co',
    });

    logInfo('sendProposalEmail succeeded', { to, subject, relatedTo });
    return { queued: false, sent: true };
  } catch (error) {
    logWarning('sendProposalEmail failed, queueing for retry', { to, subject, error: error.message });
    try {
      await db.collection('email_queue').add({
        to,
        toName: toName || null,
        fromEmail,
        fromName,
        replyTo: replyTo || 'noreply@bongroups.co',
        subject,
        htmlBody,
        textBody,
        attemptCount: 1,
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        lastError: error.message,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        sentAt: null,
        relatedTo: relatedTo || null,
      });
    } catch (queueError) {
      logError('sendProposalEmail ALSO failed to queue', { error: queueError.message, original: error.message });
    }
    return { queued: true, sent: false };
  }
}

/**
 * Helper: send SMS via Africa's Talking. If AT fails, queue for retry.
 * Never throws.
 *
 * @param {Object} params
 * @param {string} params.phoneNumber  E.164 format (+233...)
 * @param {string} params.message      max 160 chars per single-part SMS
 * @param {string} [params.relatedTo]
 */
async function sendCustomerSms({ phoneNumber, message, relatedTo }) {
  try {
    const africastalking = require('africastalking')({
      apiKey: AT_API_KEY.value(),
      username: AT_USERNAME.value() || 'sandbox',
    });
    const sms = africastalking.SMS;

    await sms.send({
      to: [phoneNumber],
      message,
      from: AT_ENVIRONMENT.value() === 'production' ? 'QRWALLET' : undefined,
    });

    logInfo('sendCustomerSms succeeded', { phoneNumber, relatedTo });
    return { queued: false, sent: true };
  } catch (error) {
    logWarning('sendCustomerSms failed, queueing for retry', { phoneNumber, error: error.message });
    try {
      await db.collection('sms_queue').add({
        phoneNumber,
        message,
        attemptCount: 1,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        lastError: error.message,
        sentAt: null,
        relatedTo: relatedTo || null,
      });
    } catch (queueError) {
      logError('sendCustomerSms ALSO failed to queue', { error: queueError.message });
    }
    return { queued: true, sent: false };
  }
}

/**
 * Calculate tiered dispute fee based on disputed amount (in USD).
 * Refunded to filer if dispute is upheld. Kept by platform if rejected.
 *
 * Tiers: ≤$100: 1.5% | $100-$1k: 1% | $1k-$10k: 0.75% | >$10k: 0.5%
 */
function calculateDisputeFee(amountInUSD) {
  let rate;
  if (amountInUSD <= 100) rate = 0.015;
  else if (amountInUSD <= 1000) rate = 0.010;
  else if (amountInUSD <= 10000) rate = 0.0075;
  else rate = 0.005;
  return Math.round(amountInUSD * rate * 100) / 100;
}

// ============================================================
// EXCHANGE RATE CONFIGURATION
// ============================================================

const CURRENCIES = [
  'USD', 'NGN', 'ZAR', 'KES', 'GHS', 'EGP', 'TZS', 'UGX', 'RWF', 'ETB',
  'MAD', 'DZD', 'TND', 'XAF', 'XOF', 'ZWG', 'ZMW', 'BWP', 'NAD', 'MZN',
  'AOA', 'CDF', 'SDG', 'LYD', 'MUR', 'MWK', 'SLL', 'LRD', 'GMD', 'GNF',
  'BIF', 'ERN', 'DJF', 'SOS', 'SSP', 'LSL', 'SZL', 'MGA', 'SCR', 'KMF',
  'MRU', 'CVE', 'STN', 'GBP', 'EUR'
];

function fetchRates() {
  return new Promise((resolve, reject) => {
    const url = 'https://api.exchangerate.host/latest?base=USD';
    const req = https.get(url, { timeout: HTTP_TIMEOUT_MS }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.success !== false && json.rates) {
            resolve(json.rates);
          } else {
            reject(new Error('Exchange rate API returned error'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`Exchange rate request timed out after ${HTTP_TIMEOUT_MS}ms`));
    });
    req.on('error', reject);
  });
}

// Scheduled function - runs daily at midnight UTC
exports.updateExchangeRatesDaily = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      logInfo('Fetching exchange rates');
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

      logInfo('Updated exchange rates', { count: Object.keys(rates).length });
      return null;
    } catch (error) {
      logError('Error updating rates', { error: error.message });
      throw error;
    }
  });

// HTTP function - manual trigger (Admin-Only, Signature-Protected)
exports.updateExchangeRatesNow = functions
  .runWith({ secrets: [ADMIN_EXCHANGE_RATE_SECRET] })
  .https.onRequest(async (req, res) => {
  // Only allow POST requests
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  // Validate admin secret is configured
  const adminSecret = ADMIN_EXCHANGE_RATE_SECRET.value();
  if (!adminSecret) {
    logError('Exchange rate endpoint called but admin secret not configured');
    res.status(503).json({ error: 'Service not configured' });
    return;
  }

  const providedSignature = req.headers['x-admin-signature'];
  const providedTimestamp = req.headers['x-timestamp'];

  if (!providedSignature || !providedTimestamp) {
    logSecurityEvent('exchange_rate_unauthorized', 'high', {
      ip: req.ip,
      reason: 'Missing signature or timestamp',
    });
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  // Validate timestamp (within 5 minutes to prevent replay)
  const timestampMs = parseInt(providedTimestamp, 10);
  const now = Date.now();
  if (isNaN(timestampMs) || Math.abs(now - timestampMs) > 5 * 60 * 1000) {
    logSecurityEvent('exchange_rate_unauthorized', 'high', {
      ip: req.ip,
      reason: 'Invalid or expired timestamp',
    });
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  // Verify HMAC signature (timing-safe)
  const expectedSignature = crypto
    .createHmac('sha256', adminSecret)
    .update(providedTimestamp)
    .digest('hex');

  const sigBuffer = Buffer.from(providedSignature, 'hex');
  const expectedBuffer = Buffer.from(expectedSignature, 'hex');

  if (sigBuffer.length !== expectedBuffer.length ||
      !crypto.timingSafeEqual(sigBuffer, expectedBuffer)) {
    logSecurityEvent('exchange_rate_unauthorized', 'high', {
      ip: req.ip,
      reason: 'Invalid signature',
    });
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  // Authorized — proceed with rate update
  try {
    logInfo('Exchange rate update initiated', {
      initiator: 'admin',
      ip: req.ip,
    });

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

    logInfo('Exchange rates updated successfully', {
      currencyCount: Object.keys(rates).length,
    });

    // Don't leak actual rates in response
    res.json({
      success: true,
      message: 'Rates updated',
      count: Object.keys(rates).length,
    });
  } catch (error) {
    logError('Exchange rate update failed', { error: error.message });
    // Don't leak error details
    res.status(500).json({
      success: false,
      error: 'Rate update failed. Check server logs.',
    });
  }
});

// ============================================================
// PAYSTACK PAYMENT FUNCTIONS
// ============================================================

// Verify Paystack payment and credit wallet
exports.verifyPayment = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { reference, idempotencyKey } = data;
  if (!reference) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Payment reference is required.');
  }

  const userId = context.auth.uid;
  const correlation = createCorrelationContext(context, 'verifyPayment');

  // Fail fast if Paystack is not configured
  requireServiceReady('paystack');

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Check if account is blocked
  const payUserDoc = await db.collection('users').doc(userId).get();
  if (payUserDoc.exists && payUserDoc.data().accountBlocked === true) {
    throwAppError(ERROR_CODES.WALLET_SUSPENDED, 'Your account is blocked. Please unblock it from your profile to add money.');
  }

  // Enforce persistent rate limiting (30 verifications per hour)
  await enforceRateLimit(userId, 'verifyPayment');

  // Use reference as idempotency key if none provided (natural idempotency)
  const effectiveIdempotencyKey = idempotencyKey || `verifyPayment_${reference}`;

  return withIdempotency(effectiveIdempotencyKey, 'verifyPayment', userId, async () => {
  try {
    // Verify with Paystack
    const response = await paystackRequest('GET', `/transaction/verify/${reference}`);

    if (!response.status || response.data.status !== 'success') {
      return { success: false, error: 'Payment verification failed' };
    }

    const paymentData = response.data;
    const amountInKobo = paymentData.amount;
    const amount = amountInKobo; // Keep in minor units (pesewas/kobo) for consistency
    const currency = paymentData.currency;

    // Secondary idempotency: paymentRef check is performed INSIDE the transaction below
    // (H-01 fix) to prevent a race between verifyPayment and paystackWebhook.
    const paymentRef = db.collection('payments').doc(reference);

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
    validateWalletDocument(walletData, 'verifyPayment wallet');

    // Credit wallet using transaction
    // H-01: paymentRef read + processed check moved inside the transaction.
    // Firestore retries the transaction body on conflicting writes to any
    // document read inside it, so concurrent invocations of verifyPayment
    // and paystackWebhook for the same reference are serialized — only the
    // first crediting transaction commits; subsequent ones see
    // processed: true on retry and exit without re-crediting.
    const txnResult = await db.runTransaction(async (transaction) => {
      const freshPayment = await transaction.get(paymentRef);
      if (freshPayment.exists && freshPayment.data().processed) {
        return { alreadyProcessed: true };
      }

      const freshWallet = await transaction.get(walletDoc.ref);
      const freshData = freshWallet.data();
      validateWalletDocument(freshData, 'verifyPayment fresh wallet');
      const currentBalance = freshData.balance;
      const newBalance = safeAdd(currentBalance, amount, 'verifyPayment credit');

      // Update wallet balance
      transaction.update(walletDoc.ref, {
        balance: newBalance,
        availableBalance: newBalance - (freshData.heldBalance || 0),
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
        method: 'Bank Card',
        receiverWalletId: walletDoc.id,
        senderName: 'Bank Card',
        description: 'Wallet top-up via Paystack',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { alreadyProcessed: false, newBalance };
    });

    // H-01: if the transaction detected a prior processed payment, return early
    // with the same response shape as the pre-fix outside-transaction check.
    if (txnResult.alreadyProcessed) {
      return { success: true, message: 'Payment already processed', alreadyProcessed: true };
    }

    await auditLog({
      userId, operation: 'verifyPayment', result: 'success',
      amount, currency,
      metadata: { reference, ...correlation.toAuditContext() },
      ipHash: hashIp(context),
    });

    // Send push notification for deposit
    await sendPushNotification(userId, {
      title: 'Deposit Successful',
      body: `${currency} ${(amount/100).toFixed(2)} has been added to your wallet`,
      type: 'transaction',
      data: { action: 'deposit', amount: amount.toString(), reference },
    });

    // Run fraud detection
    await checkForFraud(userId, { type: 'deposit', amount, currency });

    return {
      success: true,
      amount: amount,
      currency: currency,
      newBalance: txnResult.newBalance,
      _correlationId: correlation.correlationId,
    };

  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Payment verification error', { error: error.message });
    await auditLog({
      userId, operation: 'verifyPayment', result: 'failure',
      metadata: { reference, ...correlation.toAuditContext() },
      error: error.message,
      ipHash: hashIp(context),
    });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Payment verification failed. Please try again.');
  }
  });
});

// Handle Paystack webhook events
exports.paystackWebhook = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM] })
  .https.onRequest(async (req, res) => {
  const webhookCorrelationId = req.headers['x-correlation-id'] ||
    `webhook_paystack_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  logSecurityEvent('paystack_webhook_received', 'low', { correlationId: webhookCorrelationId, event: req.body?.event });

  // Fail fast if Paystack secret key is not configured
  if (!PAYSTACK_SECRET_KEY.value) {
    logSecurityEvent('paystack_webhook_not_configured', 'high', { correlationId: webhookCorrelationId });
    return res.status(503).send('Service not configured');
  }

  // Verify webhook signature
  const hash = crypto
    .createHmac('sha512', PAYSTACK_SECRET_KEY.value)
    .update(JSON.stringify(req.body))
    .digest('hex');

  if (!timingSafeCompare(hash, req.headers['x-paystack-signature'], 'hex')) {
    logSecurityEvent('paystack_webhook_invalid_signature', 'high', {
      correlationId: webhookCorrelationId,
      ip: req.ip,
    });
    return res.status(400).send('Invalid signature');
  }

  const event = req.body;
  logInfo('Paystack webhook event', { event: event.event, correlationId: webhookCorrelationId });

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
        logInfo('Unhandled webhook event type', { event: event.event, correlationId: webhookCorrelationId });
    }

    res.status(200).send('OK');
  } catch (error) {
    logError('Webhook processing error', { error: error.message, correlationId: webhookCorrelationId });
    res.status(500).send('Error processing webhook');
  }
});

async function handleSuccessfulCharge(data) {
  const reference = data.reference;
  const metadata = data.metadata || {};
  const userId = metadata.userId;

  if (!userId) {
    logError('No userId in metadata for charge', { reference });
    return;
  }

  // Check if already processed — the actual check is inside the transaction below
  // (H-01 fix) to prevent a race between verifyPayment and paystackWebhook.
  const paymentRef = db.collection('payments').doc(reference);

  const receivedAmountKobo = data.amount;
  const currency = data.currency;

  // Cross-validate amount against stored expected amount
  const pendingTx = await db.collection('pending_transactions').doc(reference).get();
  if (pendingTx.exists) {
    const expectedAmountKobo = pendingTx.data().expectedAmountKobo;
    if (expectedAmountKobo && Math.abs(expectedAmountKobo - receivedAmountKobo) > 1) {
      logSecurityEvent('paystack_amount_mismatch', 'critical', {
        reference,
        expected: expectedAmountKobo,
        received: receivedAmountKobo,
        difference: receivedAmountKobo - expectedAmountKobo,
        userId,
      });

      // Flag for manual review — do NOT credit wallet
      await db.collection('flagged_transactions').doc(reference).set({
        reason: 'Amount mismatch between initialized and webhook amounts',
        expectedAmountKobo,
        receivedAmountKobo,
        userId,
        reference,
        webhookData: { amount: data.amount, currency: data.currency, status: data.status },
        flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logError('Payment amount mismatch — flagged, not credited', { reference, userId });
      return;
    }
  }

  const amount = receivedAmountKobo; // Keep in minor units for consistency

  // Get user's wallet
  const walletSnapshot = await db.collection('wallets')
    .where('userId', '==', userId)
    .limit(1)
    .get();

  if (walletSnapshot.empty) {
    logError('Wallet not found for user', { userId });
    return;
  }

  const walletDoc = walletSnapshot.docs[0];

  // Credit wallet
  // H-01: paymentRef read + processed check moved inside the transaction.
  // Firestore retries the transaction body on conflicting writes to any
  // document read inside it, so concurrent invocations of handleSuccessfulCharge
  // (e.g. Paystack webhook retries) and verifyPayment for the same reference
  // are serialized — only the first crediting transaction commits; subsequent
  // ones see processed: true on retry and exit without re-crediting.
  const alreadyProcessed = await db.runTransaction(async (transaction) => {
    const freshPayment = await transaction.get(paymentRef);
    if (freshPayment.exists && freshPayment.data().processed) {
      return true;
    }

    const freshWallet = await transaction.get(walletDoc.ref);
    const freshData = freshWallet.data();
    validateWalletDocument(freshData, 'handleSuccessfulCharge wallet');
    const currentBalance = freshData.balance;
    const newBalance = safeAdd(currentBalance, amount, 'handleSuccessfulCharge credit');

    transaction.update(walletDoc.ref, {
      balance: newBalance,
      availableBalance: newBalance - (freshData.heldBalance || 0),
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
      method: 'Bank Card',
      description: `Deposit via ${data.channel}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return false;
  });

  // H-01: if already processed, exit early (no push notification, no fraud check)
  if (alreadyProcessed) {
    logInfo('Payment already processed (detected inside transaction)', { reference });
    return;
  }

  // Send push notification for deposit via webhook
  await sendPushNotification(userId, {
    title: 'Deposit Successful',
    body: `${currency} ${(amount/100).toFixed(2)} has been added to your wallet via ${data.channel || 'card'}`,
    type: 'transaction',
    data: { action: 'deposit', amount: amount.toString(), reference },
  });

  logFinancialOperation('creditWallet', 'success', { reference });
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

  // Send push notification for withdrawal completed
  if (withdrawalDoc.exists) {
    const wdData = withdrawalDoc.data();
    await sendPushNotification(wdData.userId, {
      title: 'Withdrawal Completed',
      body: `Your withdrawal of ${wdData.currency || ''} ${wdData.amount?.toFixed(2) || '0.00'} has been completed`,
      type: 'transaction',
      data: { action: 'withdrawal_completed', reference },
    });
  }

  logFinancialOperation('withdrawal', 'completed', { reference });
}

async function handleFailedTransfer(data) {
  const reference = data.reference;

  // Get withdrawal details
  const withdrawalDoc = await db.collection('withdrawals').doc(reference).get();
  if (!withdrawalDoc.exists) {
    logError('Withdrawal not found', { reference });
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
      const freshData = freshWallet.data();
      validateWalletDocument(freshData, 'handleFailedTransfer refund wallet');
      const currentBalance = freshData.balance;
      const newBalance = safeAdd(currentBalance, amount, 'handleFailedTransfer refund');

      transaction.update(walletDoc.ref, {
        balance: newBalance,
        availableBalance: newBalance - (freshData.heldBalance || 0),
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

  // Send push notification for withdrawal failed
  await sendPushNotification(userId, {
    title: 'Withdrawal Failed',
    body: `Your withdrawal of ${withdrawalData.currency || ''} ${amount?.toFixed(2) || '0.00'} has failed. The amount has been refunded to your wallet.`,
    type: 'transaction',
    data: { action: 'withdrawal_failed', reference, reason: data.reason || 'Transfer failed' },
  });

  logFinancialOperation('withdrawal', 'failed_refunded', { reference });
}

// Initiate withdrawal to bank or mobile money
exports.initiateWithdrawal = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { amount, bankCode, accountNumber, accountName, type, mobileMoneyProvider, phoneNumber, idempotencyKey } = data;
  const userId = context.auth.uid;
  const correlation = createCorrelationContext(context, 'initiateWithdrawal');

  // Fail fast if Paystack is not configured
  requireServiceReady('paystack');

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Check if account is blocked
  const withdrawUserDoc = await db.collection('users').doc(userId).get();
  if (withdrawUserDoc.exists && withdrawUserDoc.data().accountBlocked === true) {
    throwAppError(ERROR_CODES.WALLET_SUSPENDED, 'Your account is blocked. Please unblock it from your profile to make withdrawals.');
  }

  // Enforce persistent rate limiting (5 withdrawals per hour)
  await enforceRateLimit(userId, 'initiateWithdrawal');

  // Validate phone number if mobile money withdrawal
  const validatedPhone = (type === 'mobile_money' && phoneNumber)
    ? validatePhoneNumber(phoneNumber)
    : phoneNumber;

  logFinancialOperation('initiateWithdrawal', 'initiated', { amount, bankCode, accountNumber, accountName, type, mobileMoneyProvider, phoneNumber: validatedPhone });
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
    const validated = validateWalletDocument(walletData, 'initiateWithdrawal wallet');

    // Check balance
    if (validated.balance < amount) {
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
        currency: validated.currency || 'NGN',
      };
    } else {
      recipientData = {
        type: 'nuban',
        name: accountName,
        account_number: accountNumber,
        bank_code: bankCode,
        currency: validated.currency || 'NGN',
      };
    }

    // Create recipient
    const recipientResponse = await paystackRequest('POST', '/transferrecipient', recipientData);
    logInfo('Paystack recipient response', { response: recipientResponse });

    if (!recipientResponse.status) {
      throwServiceError('paystack', new Error('Failed to create transfer recipient'));
    }

    const recipientCode = recipientResponse.data.recipient_code;

    // Debit wallet first
    await db.runTransaction(async (transaction) => {
      const freshWallet = await transaction.get(walletDoc.ref);
      const freshData = freshWallet.data();
      validateWalletDocument(freshData, 'initiateWithdrawal fresh wallet');
      const currentBalance = freshData.balance;
      const newBalance = safeSubtract(currentBalance, amount, 'initiateWithdrawal debit');

      transaction.update(walletDoc.ref, {
        balance: newBalance,
        availableBalance: newBalance - (freshData.heldBalance || 0),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Record withdrawal
      transaction.set(db.collection('withdrawals').doc(reference), {
        userId: userId,
        walletId: walletDoc.id,
        reference: reference,
        amount: amount,
        currency: validated.currency || 'NGN',
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
        type: 'withdraw',
        amount: amount,
        currency: walletData.currency || 'NGN',
        status: 'pending',
        reference: reference,
        method: type === 'mobile_money' ? 'Mobile Money' : 'Bank Transfer',
        description: `Withdrawal to ${type === 'mobile_money' ? 'Mobile Money' : 'Bank'} - ${accountName}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Initiate transfer
    const transferResponse = await paystackRequest('POST', '/transfer', {
      source: 'balance',
      amount: amount,// Convert to kobo
      recipient: recipientCode,
      reference: reference,
      reason: `Wallet withdrawal - ${reference}`,
    });

    logInfo('Paystack transfer response', { response: transferResponse });
    if (!transferResponse.status) {
      // Refund if transfer initiation fails
      await db.runTransaction(async (transaction) => {
        const freshWallet = await transaction.get(walletDoc.ref);
        const freshRefundData = freshWallet.data();
        validateWalletDocument(freshRefundData, 'initiateWithdrawal refund wallet');
        const newBalance = safeAdd(freshRefundData.balance, amount, 'initiateWithdrawal refund');

        transaction.update(walletDoc.ref, {
          balance: newBalance,
          availableBalance: newBalance - (freshRefundData.heldBalance || 0),
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
      metadata: { reference, type: type || 'bank', ...correlation.toAuditContext() },
      ipHash: hashIp(context),
    });

    // Send push notification for withdrawal initiated
    await sendPushNotification(userId, {
      title: 'Withdrawal Initiated',
      body: `Your withdrawal of ${validated.currency || 'NGN'} ${amount.toFixed(2)} is being processed`,
      type: 'transaction',
      data: { action: 'withdrawal_initiated', amount: amount.toString(), reference },
    });

    // Run fraud detection
    await checkForFraud(userId, { type: 'withdrawal', amount, currency: validated.currency });

    return {
      success: true,
      reference: reference,
      message: 'Withdrawal initiated successfully',
      _correlationId: correlation.correlationId,
    };

  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Withdrawal error', { error: error.message });
    await auditLog({
      userId, operation: 'initiateWithdrawal', result: 'failure',
      amount,
      metadata: { ...correlation.toAuditContext() },
      error: error.message,
      ipHash: hashIp(context),
    });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Withdrawal failed. Please try again.');
  }
  });
});

// Finalize transfer with OTP
exports.finalizeTransfer = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { transferCode, otp, idempotencyKey } = data;
  const userId = context.auth.uid;

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Check if account is blocked
  const blockCheckDoc = await db.collection('users').doc(context.auth.uid).get();
  if (blockCheckDoc.exists && blockCheckDoc.data().accountBlocked === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Your account is suspended. Withdrawal cannot be completed.');
  }

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

    logInfo('OTP finalize response', { response: otpResponse });

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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Finalize transfer error', { error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Transfer finalization failed. Please try again.');
  }
  });
});

// Get list of banks
exports.getBanks = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  try {
    const country = data.country || 'nigeria';
    const response = await paystackRequest('GET', `/bank?country=${country}`);
    logInfo('Paystack getBanks response', { status: response.status });
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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Get banks error', { error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Unable to retrieve bank list. Please try again.');
  }
});

// Verify bank account
exports.verifyBankAccount = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { accountNumber, bankCode } = data;

  if (!accountNumber || !bankCode) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Account number and bank code required.');
  }

  try {
    logInfo('Calling Paystack to verify account', { accountNumber: maskPii.account(accountNumber), bankCode });
    const response = await paystackRequest('GET', `/bank/resolve?account_number=${accountNumber}&bank_code=${bankCode}`);

    logInfo('Paystack verifyAccount response', { status: response.status });
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
    logError('Verify account error', { error: error.message });
    return { success: false, error: 'Account verification failed' };
  }
});

// ============================================================
// MOBILE MONEY CHARGE (For adding funds via Mobile Money)
// ============================================================
exports.chargeMobileMoney = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { email, amount, currency, provider, phoneNumber, idempotencyKey } = data;
  const userId = context.auth.uid;

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Check if account is blocked
  const userBlockDoc = await db.collection('users').doc(userId).get();
  if (userBlockDoc.exists && userBlockDoc.data().accountBlocked === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Your account is suspended. All transactions are disabled. Contact support.');
  }

  await enforceRateLimit(userId, 'chargeMobileMoney');

  if (!amount || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID);
  }
  if (!provider || !phoneNumber) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Provider and phone number are required.');
  }

  // Validate currency and phone number format
  const validatedCurrency = validateCurrency(currency, 'GHS');
  const validatedPhone = validatePhoneNumber(phoneNumber);

  return withIdempotency(idempotencyKey, 'chargeMobileMoney', userId, async () => {
  try {
    const reference = `MOMO_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const chargeResponse = await paystackRequest('POST', '/charge', {
      email: email,
      amount: amount,
      currency: validatedCurrency,
      mobile_money: {
        phone: validatedPhone,
        provider: provider,
      },
      reference: reference,
      metadata: {
        userId: userId,
        type: 'deposit',
      },
    });

    logFinancialOperation('chargeMobileMoney', 'response_received', { status: chargeResponse.status, dataStatus: chargeResponse.data?.status });

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
        validateWalletDocument(walletData, 'chargeMobileMoney wallet');

        // H-02: write to payments/{reference} inside the transaction so that
        // the later paystackWebhook (which fires for the same reference) sees
        // processed: true in its H-01 transaction check and exits without
        // re-crediting. Shape matches what handleSuccessfulCharge writes.
        const paymentRef = db.collection('payments').doc(reference);

        await db.runTransaction(async (transaction) => {
          // Read fresh wallet data inside transaction to prevent stale balance
          const freshWallet = await transaction.get(walletDoc.ref);
          const freshData = freshWallet.data();
          validateWalletDocument(freshData, 'chargeMobileMoney fresh wallet');
          const creditBalance = safeAdd(freshData.balance, amount, 'chargeMobileMoney credit');
          transaction.update(walletDoc.ref, {
            balance: creditBalance,
            availableBalance: creditBalance - (freshData.heldBalance || 0),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // H-02: record the canonical payment document so the late Paystack
          // webhook sees this reference as already processed.
          transaction.set(paymentRef, {
            userId: userId,
            walletId: walletDoc.id,
            reference: reference,
            amount: amount,
            currency: validatedCurrency,
            type: 'deposit',
            channel: 'mobile_money',
            status: 'success',
            processed: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Record transaction
          const txRef = db.collection('users').doc(userId).collection('transactions').doc();
          transaction.set(txRef, {
            id: txRef.id,
            type: 'deposit',
            amount: amount,
            currency: validatedCurrency,
            status: 'completed',
            reference: reference,
            method: 'Mobile Money',
            receiverWalletId: walletDoc.id,
            senderName: 'Mobile Money',
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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Mobile Money charge error', { error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Payment failed. Please try again.');
  }
  });
});

// ============================================================
// VIRTUAL ACCOUNT (For Bank Transfer deposits)
// ============================================================
exports.getOrCreateVirtualAccount = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
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

    logInfo('DVA response', { status: dvaResponse.status });

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
      logInfo('Virtual account creation returned non-success', {
        userId,
        dvaStatus: dvaResponse.status,
      });
      return {
        success: false,
        error: 'Virtual accounts are only available in live mode',
        code: 'VIRTUAL_ACCOUNT_UNAVAILABLE',
        message: 'Please use mobile money or card payment instead.',
      };
    }
  } catch (error) {
    logError('Virtual account error', { userId, error: error.message });
    return {
      success: false,
      error: 'Unable to create virtual account at this time',
      code: 'VIRTUAL_ACCOUNT_ERROR',
      message: 'Please try again later or use an alternative payment method.',
    };
  }
});

// ============================================================
// INITIALIZE TRANSACTION (For Card Payment via Browser)
// ============================================================
exports.initializeTransaction = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
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

  // Validate currency
  const validatedCurrency = validateCurrency(currency, 'GHS');

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Check if account is blocked
  const userBlockDoc = await db.collection('users').doc(userId).get();
  if (userBlockDoc.exists && userBlockDoc.data().accountBlocked === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Your account is suspended. All transactions are disabled. Contact support.');
  }

  await enforceRateLimit(userId, 'initializeTransaction');

  try {
    const reference = `TXN_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const response = await paystackRequest('POST', '/transaction/initialize', {
      email: email,
      amount: amount, // Convert to smallest unit
      currency: validatedCurrency,
      reference: reference,
      callback_url: 'https://qr-wallet-1993.web.app/payment-callback',
      metadata: {
        userId: userId,
        type: 'deposit',
      },
    });

    logInfo('Initialize transaction response', { status: response.status });

    if (response.status && response.data) {
      // Store pending transaction with expected amount for webhook cross-validation
      await db.collection('pending_transactions').doc(reference).set({
        userId,
        email,
        expectedAmount: amount,
        expectedAmountKobo: amount, 
        currency: validatedCurrency,
        reference,
        paystackReference: response.data.reference,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Initialize transaction error', { error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Transaction initialization failed. Please try again.');
  }
});

// ============================================================
// QR CODE SIGNING & VERIFICATION
// ============================================================

// Secret key for signing QR codes (set via: firebase functions:config:set qr.secret="your-secret-key")
// REQUIRED: Must be configured. QR signing will fail if missing.
// QR_SECRET_KEY wrapper: defer .value() to runtime. Usage stays `QR_SECRET_KEY.value` (no parens).
const QR_SECRET_KEY = { get value() { return QR_SECRET_PARAM.value() || ''; } };
// PIN_SECRET wrapper: defer .value() to runtime. Usage stays `PIN_SECRET.value` (no parens).
const PIN_SECRET = { get value() { return PIN_SECRET_PARAM.value() || ''; } };
const QR_EXPIRY_MS = 15 * 60 * 1000; // 15 minutes

// Helper: Generate HMAC signature
function generateQrSignature(payload) {
  requireConfig(QR_SECRET_KEY.value, 'qr.secret');
  return crypto.createHmac('sha256', QR_SECRET_KEY.value)
    .update(payload)
    .digest('hex');
}

// In-memory burst limiter — supplementary first-line defense per Cloud Function instance.
// NOTE: Resets on cold starts. All critical rate limiting uses Firestore-backed persistent
// limiter below. This only provides fast burst protection within a single instance.
const rateLimitStore = {};

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

// Persistent failed lookup tracking (Firestore-backed, survives cold starts)
const FAILED_LOOKUP_MAX = 10;
const FAILED_LOOKUP_WINDOW_MS = 5 * 60 * 1000; // 5 minutes

async function checkFailedLookups(hashedIp) {
  const docRef = db.collection('rate_limits').doc(`failed_lookup_${hashedIp}`);
  try {
    const doc = await docRef.get();
    if (!doc.exists) return true;
    const data = doc.data();
    const windowStart = Date.now() - FAILED_LOOKUP_WINDOW_MS;
    // Window expired — allow
    if (data.resetTime && data.resetTime.toMillis() < windowStart) return true;
    return (data.count || 0) < FAILED_LOOKUP_MAX;
  } catch (error) {
    logError('Failed lookup check error', { error: error.message });
    return true; // Fail open on error
  }
}

async function recordFailedLookup(hashedIp) {
  const docRef = db.collection('rate_limits').doc(`failed_lookup_${hashedIp}`);
  try {
    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);
      const now = Date.now();
      if (!doc.exists) {
        transaction.set(docRef, {
          count: 1,
          resetTime: admin.firestore.Timestamp.fromMillis(now + FAILED_LOOKUP_WINDOW_MS),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        const data = doc.data();
        const windowStart = now - FAILED_LOOKUP_WINDOW_MS;
        if (data.resetTime && data.resetTime.toMillis() < windowStart) {
          // Window expired, reset
          transaction.set(docRef, {
            count: 1,
            resetTime: admin.firestore.Timestamp.fromMillis(now + FAILED_LOOKUP_WINDOW_MS),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(docRef, {
            count: (data.count || 0) + 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    });
  } catch (error) {
    logError('Failed lookup record error', { error: error.message });
  }
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
  verifyPayment:      { windowMs: 60 * 60 * 1000, maxRequests: 30, message: 'Too many payment verifications. Please wait before trying again.' },
  sendMoney:          { windowMs: 60 * 60 * 1000, maxRequests: 20, message: 'Too many transfers. Please wait before sending again.' },
  initiateWithdrawal: { windowMs: 60 * 60 * 1000, maxRequests: 5,  message: 'Too many withdrawal attempts. Please try again later.' },
  momoRequestToPay:   { windowMs: 60 * 60 * 1000, maxRequests: 10, message: 'Too many MoMo payment requests. Please try again later.' },
  momoTransfer:       { windowMs: 60 * 60 * 1000, maxRequests: 5,  message: 'Too many MoMo transfers. Please try again later.' },
  lookupWallet:       { windowMs: 5 * 60 * 1000,  maxRequests: 30, message: 'Too many wallet lookups. Please wait a few minutes.' },
  exportUserData:     { windowMs: 24 * 60 * 60 * 1000, maxRequests: 2, message: 'Data export limit reached. You may export your data twice per day.' },
  changePin:          { windowMs: 60 * 60 * 1000, maxRequests: 5,  message: 'Too many PIN change attempts. Please try again later.' },
  resetPin:           { windowMs: 60 * 60 * 1000, maxRequests: 3,  message: 'Too many PIN reset attempts. Please try again later.' },
  finalizeTransfer:   { windowMs: 60 * 60 * 1000, maxRequests: 10, message: 'Too many OTP attempts. Please try again later.' },
  adminFinalizeTransfer: { windowMs: 60 * 60 * 1000, maxRequests: 10, message: 'Too many admin OTP attempts. Please try again later.' },
  adminInitiateTransfer: { windowMs: 60 * 60 * 1000, maxRequests: 5, message: 'Too many transfer initiations. Please try again later.' },
  adminProposeTransfer:       { windowMs: 60 * 60 * 1000, maxRequests: 10,  message: 'Too many proposals. Please try again later.' },
  adminApproveTransfer:       { windowMs: 60 * 60 * 1000, maxRequests: 20,  message: 'Too many approvals. Please try again later.' },
  adminRejectTransfer:        { windowMs: 60 * 60 * 1000, maxRequests: 20,  message: 'Too many rejections. Please try again later.' },
  adminCancelProposal:        { windowMs: 60 * 60 * 1000, maxRequests: 20,  message: 'Too many cancellations. Please try again later.' },
  adminEmergencyTransfer:     { windowMs: 60 * 60 * 1000, maxRequests: 3,   message: 'Too many emergency transfers. Please try again later.' },
  adminEditProposal:          { windowMs: 60 * 60 * 1000, maxRequests: 20,  message: 'Too many edit attempts. Please try again later.' },
  adminCloseProposal:         { windowMs: 60 * 60 * 1000, maxRequests: 20,  message: 'Too many close attempts. Please try again later.' },
  adminUploadProposalDocument: { windowMs: 60 * 60 * 1000, maxRequests: 30, message: 'Too many upload attempts. Please try again later.' },
  adminGetProposalDocumentUrl: { windowMs: 60 * 60 * 1000, maxRequests: 60, message: 'Too many document access attempts. Please try again later.' },
  previewTransfer:    { windowMs: 60 * 60 * 1000, maxRequests: 60, message: 'Too many preview requests. Please wait before trying again.' },
  getOrCreateVirtualAccount: { windowMs: 60 * 60 * 1000, maxRequests: 5, message: 'Too many virtual account requests. Please try again later.' },
  chargeMobileMoney:   { windowMs: 60 * 60 * 1000, maxRequests: 10, message: 'Too many mobile money charge attempts. Please try again later.' },
  initializeTransaction: { windowMs: 60 * 60 * 1000, maxRequests: 20, message: 'Too many payment initializations. Please try again later.' },
  checkSmileIdJobStatus: { windowMs: 60 * 1000, maxRequests: 30, message: 'Too many status check requests.' },
  userFileDispute:            { windowMs: 60 * 60 * 1000, maxRequests: 5,  message: 'Too many dispute filings. Please try again later.' },
  userRespondToDispute:       { windowMs: 60 * 60 * 1000, maxRequests: 10, message: 'Too many responses. Please try again later.' },
  userViewDispute:            { windowMs: 60 * 60 * 1000, maxRequests: 60, message: 'Too many view requests.' },
  userGetMyDisputes:          { windowMs: 60 * 60 * 1000, maxRequests: 60, message: 'Too many list requests.' },
  adminAssignDispute:         { windowMs: 60 * 60 * 1000, maxRequests: 20, message: 'Too many assignment attempts.' },
  adminSubmitInvestigation:   { windowMs: 60 * 60 * 1000, maxRequests: 20, message: 'Too many investigation submissions.' },
  adminSupervisorDecision:    { windowMs: 60 * 60 * 1000, maxRequests: 20, message: 'Too many supervisor decisions.' },
  adminManagerDecision:       { windowMs: 60 * 60 * 1000, maxRequests: 20, message: 'Too many manager decisions.' },
  adminListDisputes:          { windowMs: 60 * 60 * 1000, maxRequests: 60, message: 'Too many list requests.' },
  adminGetDisputeEvidenceUrl: { windowMs: 60 * 60 * 1000, maxRequests: 60, message: 'Too many document access attempts.' },
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
    logWarning('No rate limit config for operation', { operation });
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
    // H-07: Fail CLOSED (not open) on Firestore errors. If we can't verify
    // that a request is within rate limit, we reject it. An attacker who
    // can induce Firestore errors (or natural transient failures during
    // traffic spikes) would otherwise get unlimited request capacity for
    // rate-limited operations. Legitimate users see a temporary rate-limit
    // error they can retry — a much smaller cost than financial abuse.
    logError('Rate limit check failed — failing closed', { userId, operation, error: error.message });
    return false;
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
// IN-APP NOTIFICATION HELPER
// ============================================================
/**
 * Create an in-app notification for a user.
 * Writes to the users/{userId}/notifications subcollection.
 */
async function createNotification(userId, { title, body, type = 'security', data = null }) {
  try {
    const notifRef = db.collection('users').doc(userId).collection('notifications').doc();
    await notifRef.set({
      id: notifRef.id,
      title,
      body,
      type,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      data: data || null,
    });
  } catch (error) {
    // Notification creation must never block the main operation
    logError('Failed to create notification', { userId, title, error: error.message });
  }
}

/**
 * Send a push notification to a user via FCM.
 * Also creates an in-app notification in Firestore.
 * @param {string} userId - Target user ID
 * @param {Object} options - Notification options
 * @param {string} options.title - Notification title
 * @param {string} options.body - Notification body text
 * @param {string} [options.type='system'] - Notification type (transaction, security, system)
 * @param {Object} [options.data=null] - Additional data payload
 */
async function sendPushNotification(userId, { title, body, type = 'system', data = null }) {
  try {
    // 1. Create in-app notification in Firestore
    await createNotification(userId, { title, body, type, data });

    // 2. Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      logInfo('No FCM token for user, skipping push', { userId });
      return;
    }

    // 3. Send push notification via FCM
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: type,
        ...(data ? Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])) : {}),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'qr_wallet_transactions',
          priority: 'high',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);
    logInfo('Push notification sent', { userId, title });
  } catch (error) {
    // Push notification must never block the main operation
    if (error.code === 'messaging/registration-token-not-registered' ||
        error.code === 'messaging/invalid-registration-token') {
      // Token is invalid, remove it
      try {
        await db.collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      } catch (e) { /* ignore cleanup errors */ }
    }
    logError('Failed to send push notification', { userId, title, error: error.message });
  }
}

// ============================================================
// FRAUD DETECTION
// ============================================================

/**
 * Check a transaction for suspicious patterns and auto-flag if needed.
 * Called internally after successful transactions.
 * @param {string} userId - User who initiated the transaction
 * @param {Object} txData - Transaction data
 */
async function checkForFraud(userId, txData) {
  try {
    const alerts = [];
    const amount = txData.amount || 0;
    const currency = txData.currency || 'Unknown';
    const type = txData.type || 'unknown';

    // 1. Large transaction threshold (varies by currency)
    const largeThresholds = {
      NGN: 500000, GHS: 10000, KES: 200000, UGX: 5000000, ZAR: 20000,
      USD: 1000, GBP: 800, EUR: 900,
    };
    const threshold = largeThresholds[currency] || 10000;
    if (amount >= threshold) {
      alerts.push({
        rule: 'large_transaction',
        severity: 'medium',
        message: `Large ${type}: ${currency} ${amount.toFixed(2)} exceeds threshold of ${currency} ${threshold}`,
      });
    }

    // 2. Rapid transactions (3+ in last 5 minutes)
    const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
    const recentTxSnapshot = await db.collection('users').doc(userId)
      .collection('transactions')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(fiveMinAgo))
      .get();

    if (recentTxSnapshot.size >= 3) {
      alerts.push({
        rule: 'rapid_transactions',
        severity: 'high',
        message: `Rapid activity: ${recentTxSnapshot.size} transactions in last 5 minutes`,
      });
    }

    // 3. New account activity (account less than 24 hours old)
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      let accountAge = Infinity;

      if (userData.createdAt) {
        const createdDate = typeof userData.createdAt === 'string'
          ? new Date(userData.createdAt)
          : userData.createdAt.toDate ? userData.createdAt.toDate() : new Date(userData.createdAt);
        accountAge = (Date.now() - createdDate.getTime()) / (1000 * 60 * 60); // hours
      }

      if (accountAge < 24 && amount > (threshold * 0.5)) {
        alerts.push({
          rule: 'new_account_large_tx',
          severity: 'high',
          message: `New account (${Math.round(accountAge)}h old) with significant transaction: ${currency} ${amount.toFixed(2)}`,
        });
      }
    }

    // 4. Multiple failed transactions recently
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const failedTxSnapshot = await db.collection('users').doc(userId)
      .collection('transactions')
      .where('status', '==', 'failed')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(oneHourAgo))
      .get();

    if (failedTxSnapshot.size >= 3) {
      alerts.push({
        rule: 'multiple_failures',
        severity: 'medium',
        message: `${failedTxSnapshot.size} failed transactions in the last hour`,
      });
    }

    // If alerts found, create fraud alert records
    if (alerts.length > 0) {
      const highestSeverity = alerts.some(a => a.severity === 'high') ? 'high'
        : alerts.some(a => a.severity === 'medium') ? 'medium' : 'low';

      const alertId = `FRAUD-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;

      await db.collection('fraud_alerts').doc(alertId).set({
        id: alertId,
        userId,
        userEmail: userDoc.exists ? userDoc.data().email : 'unknown',
        userName: userDoc.exists ? userDoc.data().fullName : 'unknown',
        transactionId: txData.id || null,
        transactionType: type,
        amount,
        currency,
        severity: highestSeverity,
        alerts,
        status: 'open',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify admin via push notification if high severity
      if (highestSeverity === 'high') {
        // Get all admin users to notify
        const adminSnapshot = await db.collection('admin_users').get();
        const notifyPromises = adminSnapshot.docs.map(doc =>
          sendPushNotification(doc.id, {
            title: 'Fraud Alert',
            body: `High severity alert for ${userDoc.exists ? userDoc.data().fullName : userId}: ${alerts[0].message}`,
            type: 'security',
            data: { action: 'fraud_alert', alertId, severity: highestSeverity },
          }).catch(() => {}) // Don't fail if notification fails
        );
        await Promise.all(notifyPromises);
      }

      logStructured(LOG_LEVELS.WARNING, 'Fraud alert triggered', {
        alertId, userId, severity: highestSeverity, rules: alerts.map(a => a.rule),
      });
    }
  } catch (error) {
    // Fraud detection must never block the main operation
    logStructured(LOG_LEVELS.ERROR, 'Fraud detection error', { error: error.message, userId });
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
      timestamp: timestamps.serverTimestamp(),
      loggedAt: timestamps.serverTimestamp(),
    });
  } catch (error) {
    // Audit logging must never block the main operation
    logError('AUDIT LOG WRITE FAILED', { error: error.message, entry: JSON.stringify(entry) });
  }
}

// ============================================================
// KYC ENFORCEMENT (Server-Side)
// ============================================================

/**
 * Enforces that a user has completed KYC verification.
 * Must be called in ALL Cloud Functions that handle financial operations.
 *
 * Checks email verification via Firebase Auth, then checks the canonical
 * 'kycStatus' field on the user document. Legacy 'kycCompleted' fields
 * are NOT auto-migrated — users must re-verify through Smile ID.
 *
 * @param {string} userId - The Firebase Auth UID
 * @throws {HttpsError} permission-denied with code KYC_REQUIRED if not verified
 */
async function enforceKyc(userId) {
  // Check email verification via Firebase Auth
  try {
    const userRecord = await admin.auth().getUser(userId);
    if (!userRecord.emailVerified) {
      throwAppError(ERROR_CODES.KYC_REQUIRED,
        'Email verification required. Please verify your email before performing financial operations.');
    }
  } catch (error) {
    if (error.code === 'functions/failed-precondition' || error.code === 'functions/permission-denied') {
      throw error;
    }
    logError('Email verification check failed', { userId, error: error.message });
  }

  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'User account not found.');
  }

  const userData = userDoc.data();

  // Check canonical kycStatus field (authoritative)
  if (userData.kycStatus === 'verified') {
    return;
  }

 // KYC enforcement is now uniform across all countries.
  // Previously, users in non-SmileID countries were auto-verified once they
  // had a phone number on file. That bypass was removed because all countries
  // now go through the same KYC flow: SmileID document verification + selfie
  // (handled in the KYC screens) + phone OTP (handled at /phone-otp for
  // non-SmileID countries before KYC, or at /kyc-phone-verification for
  // SmileID countries after KYC). The kycStatus field is set to 'verified'
  // exclusively by the smileIdWebhook (or by checkSmileIdJobStatus) on a
  // successful SmileID verification — never auto-set based on country.

  // Legacy kycCompleted/kycVerified fields are no longer trusted for auto-migration.
  if (!userData.kycStatus && userData.kycCompleted === true) {
    logInfo('User has legacy KYC fields but no canonical kycStatus — re-verification required', { userId });
  }

  // KYC not verified — block the operation
  throwAppError(ERROR_CODES.KYC_REQUIRED);
}

// Set KYC status (called after successful Smile ID verification)
// NOTE: The client now sets kycStatus directly in Firestore for reliability.
// This function is retained for backward compatibility and admin use cases.
exports.updateKycStatus = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  // SECURITY: Restricted to admin only. Client KYC uses completeKycVerification.
  const caller = await verifyAdmin(context, 'admin');

  const userId = data.targetUserId || context.auth.uid;
  const { status } = data;

  // Only allow setting to specific valid statuses
  const validStatuses = ['pending', 'verified', 'rejected'];
  if (!validStatuses.includes(status)) {
    throwAppError(ERROR_CODES.KYC_VERIFICATION_FAILED, 'Invalid KYC status.');
  }

  // Note: We no longer require KYC documents to exist with 'approved' status.
  // The client has already verified the user via Smile ID before calling this.
  // This simplification eliminates race conditions and silent failures.

  await db.collection('users').doc(userId).update({
    kycStatus: status,
    kycStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(status === 'verified' ? { kycCompleted: true, kycVerified: true } : {}),
  });

  logInfo('KYC status updated', { status, userId });

  return {
    success: true,
    kycStatus: status,
  };
});

/**
 * Complete KYC verification after client successfully uploads KYC documents.
 *
 * This function is called by the Flutter client after KYC documents have been
 * uploaded to Firestore. It validates that documents exist and sets kycStatus
 * using the Admin SDK (which bypasses Firestore security rules).
 *
 * Security: Only the authenticated user can complete their own KYC.
 * The kycStatus field is protected by Firestore rules and can only be
 * written by Cloud Functions using Admin SDK.
 */
exports.completeKycVerification = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;
  logInfo('Completing KYC verification', { userId });

  // Check if user document exists
  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throwAppError(ERROR_CODES.USER_NOT_FOUND, 'User document not found.');
  }

  const userData = userDoc.data();

  // If already verified, return success (idempotent)
  if (userData.kycStatus === 'verified') {
    logInfo('User already KYC verified, no action needed', { userId });
    return {
      success: true,
      kycStatus: 'verified',
      message: 'Already verified',
    };
  }

  // If already pending_review, return current status (idempotent)
  if (userData.kycStatus === 'pending_review') {
    logInfo('User KYC already pending review', { userId });
    return {
      success: true,
      kycStatus: 'pending_review',
      message: 'Verification pending review',
    };
  }

  // Check if KYC documents exist
  const kycDocRef = userRef.collection('kyc').doc('documents');
  const kycDoc = await kycDocRef.get();

  if (!kycDoc.exists) {
    throwAppError(ERROR_CODES.KYC_INCOMPLETE, 'No KYC documents found. Please complete identity verification first.');
  }

  const kycData = kycDoc.data();

  // SmileID verified documents go to pending_review (webhook will finalize)
  // Non-SmileID documents also go to pending_review for manual review
  const isSmileIdVerified = kycData.smileIdVerified === true;
  const validStatuses = ['verified', 'approved', 'pending_review'];
  const isValidStatus = validStatuses.includes(kycData.status) || isSmileIdVerified;

  if (!isValidStatus) {
    logInfo('KYC documents not yet verified', { userId, status: kycData.status, smileIdVerified: kycData.smileIdVerified });
    throwAppError(ERROR_CODES.KYC_INCOMPLETE, 'KYC documents have not been verified yet.');
  }

  // Set kycStatus to pending_review — webhook or admin will promote to 'verified'
  await userRef.update({
    kycStatus: 'pending_review',
    kycStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    kycCompleted: true,
  });

  logInfo('KYC set to pending_review, awaiting webhook/admin verification', { userId });

  return {
    success: true,
    kycStatus: 'pending_review',
  };
});

/**
 * Create wallet for a user after verification is complete.
 * Idempotent — if wallet already exists, returns existing walletId.
 * Called automatically after KYC or phone verification.
 */
exports.createWalletForUser = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;

  try {
    // Check if wallet already exists
    const walletDoc = await db.collection('wallets').doc(userId).get();
    if (walletDoc.exists) {
      const existingWalletId = walletDoc.data().walletId;
      logInfo('Wallet already exists for user', { userId, walletId: existingWalletId });
      return { success: true, walletId: existingWalletId, message: 'Wallet already exists.' };
    }

    // Get user document for currency
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throwAppError(ERROR_CODES.USER_NOT_FOUND, 'User document not found.');
    }

    const userData = userDoc.data();

    // Generate unique wallet ID
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    const segment = () => Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
    const walletId = `QRW-${segment()}-${segment()}-${segment()}`;

    // Create wallet document
    // heldBalance and availableBalance support the wallet holds feature.
    // Invariant: availableBalance = balance - heldBalance.
    // All money-moving Cloud Functions check availableBalance (not balance)
    // when deciding if a user can spend. Holds increase heldBalance and
    // decrease availableBalance without changing balance, so the user
    // cannot double-spend money they've committed to a pending order.
    const walletData = {
      id: userId,
      userId: userId,
      walletId: walletId,
      currency: userData.currency || 'GHS',
      balance: 0,
      heldBalance: 0,
      availableBalance: 0,
      isActive: true,
      dailySpent: 0,
      monthlySpent: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.runTransaction(async (transaction) => {
      // Double-check wallet doesn't exist (race condition protection)
      const freshWalletDoc = await transaction.get(db.collection('wallets').doc(userId));
      if (freshWalletDoc.exists) {
        return; // Already created by another call
      }

      // Create wallet
      transaction.set(db.collection('wallets').doc(userId), walletData);

      // Update user document with walletId
      transaction.update(db.collection('users').doc(userId), {
        walletId: walletId,
        walletCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    logInfo('Wallet created for user', { userId, walletId });

    return { success: true, walletId: walletId };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Failed to create wallet', { userId, error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Failed to create wallet. Please try again.');
  }
});

/**
 * Mark user as KYC verified when SmileID returns "already enrolled" error.
 * This indicates the user was previously verified by SmileID, so we can
 * trust that verification and set kycStatus: 'verified' directly.
 *
 * Unlike updateKycStatus, this function doesn't require prior KYC document
 * approval because SmileID has already verified the user's identity.
 */
// ============================================================
// UPDATE WALLET CURRENCY
// ============================================================

exports.updateWalletCurrency = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;
  const { currency } = data;

  if (!currency || typeof currency !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Currency code is required.');
  }

  const validatedCurrency = validateCurrency(currency, null);

  const walletRef = db.collection('wallets').doc(userId);
  const walletDoc = await walletRef.get();

  if (!walletDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND);
  }

  await walletRef.update({
    currency: validatedCurrency,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, currency: validatedCurrency };
});

// C-02 — markUserAlreadyEnrolled removed.
// The previous callable set kycStatus: 'verified' and created a wallet
// for any authenticated caller based solely on a client-provided idType
// string. That allowed any authenticated user to bypass KYC entirely.
// No active Flutter screen called this function (the 'already_enrolled'
// flow in the app uses a pop signal and re-routes through the normal
// webhook-verified path). When database-lookup KYC is re-enabled and a
// legitimate "already enrolled" short-circuit is needed, implement a
// replacement that server-side verifies the claim via SmileID's
// /v1/job_status endpoint with smileUserId + smileJobId.

// ============================================================
// GDPR DATA EXPORT & DELETION
// ============================================================

/**
 * Export all user data (GDPR Article 20 — Data Portability).
 * Returns a JSON object containing all data associated with the user.
 */
exports.exportUserData = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;
  const correlationId = getCorrelationId(context);

  // Rate limit data exports (2 per day)
  await enforceRateLimit(userId, 'exportUserData');

  logInfo('User data export requested', { userId, correlationId });

  try {
    // Collect all user data from all collections
    const userDoc = await db.collection('users').doc(userId).get();
    const walletDoc = await db.collection('wallets').doc(userId).get();

    // Sub-collections
    const transactions = await db.collection('users').doc(userId)
      .collection('transactions').orderBy('createdAt', 'desc').limit(1000).get();
    const notifications = await db.collection('users').doc(userId)
      .collection('notifications').orderBy('createdAt', 'desc').limit(500).get();
    const linkedAccounts = await db.collection('users').doc(userId)
      .collection('linkedAccounts').get();
    const bankAccounts = await db.collection('users').doc(userId)
      .collection('bankAccounts').get();
    const cards = await db.collection('users').doc(userId)
      .collection('cards').get();

    // Withdrawals
    const withdrawals = await db.collection('withdrawals')
      .where('userId', '==', userId).limit(500).get();

    // MoMo transactions
    const momoTxns = await db.collection('momo_transactions')
      .where('userId', '==', userId).limit(500).get();

    // Audit logs
    const auditLogs = await db.collection('audit_logs')
      .where('userId', '==', userId).orderBy('timestamp', 'desc').limit(500).get();

    const exportData = {
      exportDate: new Date().toISOString(),
      userId,
      profile: userDoc.exists ? userDoc.data() : null,
      wallet: walletDoc.exists ? walletDoc.data() : null,
      transactions: transactions.docs.map(d => ({ id: d.id, ...d.data() })),
      notifications: notifications.docs.map(d => ({ id: d.id, ...d.data() })),
      linkedAccounts: linkedAccounts.docs.map(d => ({ id: d.id, ...d.data() })),
      bankAccounts: bankAccounts.docs.map(d => ({ id: d.id, ...d.data() })),
      cards: cards.docs.map(d => ({ id: d.id, ...d.data() })),
      withdrawals: withdrawals.docs.map(d => ({ id: d.id, ...d.data() })),
      momoTransactions: momoTxns.docs.map(d => ({ id: d.id, ...d.data() })),
      auditLogs: auditLogs.docs.map(d => ({ id: d.id, ...d.data() })),
    };

    await auditLog({
      userId, operation: 'exportUserData', result: 'success',
      metadata: { correlationId },
    });

    return { success: true, data: exportData };
  } catch (error) {
    logError('User data export failed', { userId, error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Data export failed. Please try again.');
  }
});

/**
 * Delete user account and all associated data (GDPR Article 17 — Right to Erasure).
 * Requires re-authentication confirmation.
 */
exports.deleteUserData = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;
  const { confirmDeletion } = data;

  if (confirmDeletion !== 'DELETE_MY_ACCOUNT') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED,
      'Must confirm deletion with confirmDeletion: "DELETE_MY_ACCOUNT"');
  }

  logSecurityEvent('user_data_deletion_requested', 'high', { userId });

  try {
    // Check for pending transactions
    const pendingWithdrawals = await db.collection('withdrawals')
      .where('userId', '==', userId)
      .where('status', '==', 'pending')
      .limit(1)
      .get();

    if (!pendingWithdrawals.empty) {
      throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED,
        'Cannot delete account with pending withdrawals. Please wait for them to complete.');
    }

    const pendingMomo = await db.collection('momo_transactions')
      .where('userId', '==', userId)
      .where('status', '==', 'pending')
      .limit(1)
      .get();

    if (!pendingMomo.empty) {
      throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED,
        'Cannot delete account with pending MoMo transactions. Please wait for them to complete.');
    }

    // Check wallet balance
    const walletDoc = await db.collection('wallets').doc(userId).get();
    if (walletDoc.exists && walletDoc.data().balance > 0) {
      throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED,
        'Cannot delete account with remaining balance. Please withdraw all funds first.');
    }

    // Delete user sub-collections
    const subCollections = ['transactions', 'notifications', 'linkedAccounts', 'bankAccounts', 'cards', 'kyc'];
    for (const subCol of subCollections) {
      const docs = await db.collection('users').doc(userId).collection(subCol).limit(500).get();
      const batch = db.batch();
      docs.forEach(doc => batch.delete(doc.ref));
      if (!docs.empty) await batch.commit();
    }

    // Delete user document
    await db.collection('users').doc(userId).delete();

    // Delete wallet
    if (walletDoc.exists) {
      await db.collection('wallets').doc(userId).delete();
    }

    // Anonymize audit logs (retain for compliance but remove PII)
    const auditLogs = await db.collection('audit_logs')
      .where('userId', '==', userId).limit(500).get();
    if (!auditLogs.empty) {
      const batch = db.batch();
      auditLogs.forEach(doc => {
        batch.update(doc.ref, {
          userId: 'DELETED_USER',
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
    }

    // Delete Firebase Auth account
    await admin.auth().deleteUser(userId);

    logSecurityEvent('user_data_deleted', 'high', { userId: 'DELETED_USER' });

    return { success: true, message: 'Account and all associated data have been deleted.' };
  } catch (error) {
    if (error.code && error.code.startsWith('functions/')) {
      throw error; // Re-throw our own errors
    }
    logError('User data deletion failed', { userId, error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Account deletion failed. Please contact support.');
  }
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
      createdAt: timestamps.serverTimestamp(),
      expiresAt: timestamps.expiresIn(24 * 60 * 60 * 1000), // 24h TTL
    });

    return { alreadyCompleted: false };
  });

  // Return cached result for idempotent replays
  if (reservation.alreadyCompleted) {
    logInfo('Idempotent replay', { key, operation });
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
      logError('Failed to update idempotency key status', { error: updateErr.message });
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
      logInfo('No expired idempotency keys to clean up');
      return null;
    }

    const batch = db.batch();
    expired.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    logInfo('Cleaned expired idempotency keys', { count: expired.size });
    return null;
  });

// Cleanup expired QR nonces (runs hourly)
exports.cleanupExpiredQrNonces = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const expiredNonces = await db.collection('qr_nonces')
      .where('expiresAt', '<', now)
      .limit(500)
      .get();

    if (expiredNonces.empty) {
      logInfo('No expired QR nonces to clean up');
      return null;
    }

    const batch = db.batch();
    expiredNonces.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    logInfo('Cleaned expired QR nonces', { count: expiredNonces.size });
    return null;
  });

// Reset daily spending counters at midnight UTC
exports.resetDailySpendingLimits = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('UTC')
  .onRun(async () => {
    const walletsSnapshot = await db.collection('wallets')
      .where('dailySpent', '>', 0)
      .limit(500)
      .get();

    if (walletsSnapshot.empty) {
      logInfo('No daily spending counters to reset');
      return null;
    }

    const batch = db.batch();
    walletsSnapshot.docs.forEach(doc => {
      batch.update(doc.ref, { dailySpent: 0 });
    });
    await batch.commit();

    logInfo('Reset daily spending counters', { count: walletsSnapshot.size });
    return null;
  });

// Reset monthly spending counters on 1st of each month
exports.resetMonthlySpendingLimits = functions.pubsub
  .schedule('0 0 1 * *')
  .timeZone('UTC')
  .onRun(async () => {
    const walletsSnapshot = await db.collection('wallets')
      .where('monthlySpent', '>', 0)
      .limit(500)
      .get();

    if (walletsSnapshot.empty) {
      logInfo('No monthly spending counters to reset');
      return null;
    }

    const batch = db.batch();
    walletsSnapshot.docs.forEach(doc => {
      batch.update(doc.ref, { monthlySpent: 0 });
    });
    await batch.commit();

    logInfo('Reset monthly spending counters', { count: walletsSnapshot.size });
    return null;
  });

/**
 * Data Retention TTL Cleanup — runs daily at 3:00 AM UTC.
 * Enforces retention policies to limit stored PII and reduce storage costs.
 *
 * Retention periods:
 *   - Notifications: 90 days
 *   - Rate limit entries: 24 hours
 *   - Pending transactions (resolved): 7 days
 *   - Flagged transactions (resolved): 180 days
 *   - Audit logs: 365 days (regulatory minimum)
 */
// ============================================================
// CLEANUP PENDING MOMO TRANSACTIONS
// ============================================================

exports.cleanupPendingMomoTransactions = functions.pubsub
  .schedule('every 6 hours')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);

      const pendingTx = await db.collection('momo_transactions')
        .where('status', '==', 'pending')
        .where('createdAt', '<', cutoff)
        .limit(50)
        .get();

      if (pendingTx.empty) {
        logInfo('No stale pending MoMo transactions found');
        return null;
      }

      logInfo('Found stale pending MoMo transactions', { count: pendingTx.size });

      for (const txDoc of pendingTx.docs) {
        const txData = txDoc.data();

        try {
          if (txData.type === 'disbursement' && txData.userId) {
            await db.runTransaction(async (transaction) => {
              const walletDoc = await transaction.get(db.collection('wallets').doc(txData.userId));
              if (walletDoc.exists) {
                const walletData = walletDoc.data();
               const newBalance = safeAdd(walletData.balance, txData.amount, 'momoCleanup refund');
                transaction.update(walletDoc.ref, {
                  balance: newBalance,
                  availableBalance: newBalance - (walletData.heldBalance || 0),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              }

              transaction.update(txDoc.ref, {
                status: 'failed',
                failureReason: 'Transaction timed out after 24 hours',
                refunded: true,
                refundedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            });

            await sendPushNotification(txData.userId, {
              title: 'MoMo Transaction Failed',
              body: 'Your MoMo withdrawal has timed out. The amount has been refunded to your wallet.',
              type: 'transaction',
              data: { action: 'momo_timeout', referenceId: txDoc.id },
            }).catch(() => {});
          } else {
            await txDoc.ref.update({
              status: 'failed',
              failureReason: 'Transaction timed out after 24 hours',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            if (txData.userId) {
              await sendPushNotification(txData.userId, {
                title: 'MoMo Deposit Failed',
                body: 'Your MoMo deposit has timed out. No charge was made. Please try again.',
                type: 'transaction',
                data: { action: 'momo_timeout', referenceId: txDoc.id },
              }).catch(() => {});
            }
          }
        } catch (innerError) {
          logError('Error processing stale MoMo transaction', { txId: txDoc.id, error: innerError.message });
        }
      }

      logInfo('Cleaned up stale MoMo transactions', { processed: pendingTx.size });
      return null;
    } catch (error) {
      logError('Error in cleanupPendingMomoTransactions', { error: error.message });
      return null;
    }
  });

exports.cleanupExpiredData = functions.pubsub
  .schedule('0 3 * * *')  // Daily at 3:00 AM UTC
  .timeZone('UTC')
  .onRun(async () => {
    const now = Date.now();
    const BATCH_LIMIT = 400; // Firestore batch limit is 500, keep margin

    const retentionPolicies = [
      {
        name: 'rate_limits',
        collection: 'rate_limits',
        field: 'updatedAt',
        maxAgeMs: 24 * 60 * 60 * 1000, // 24 hours
      },
      {
        name: 'pending_transactions',
        collection: 'pending_transactions',
        field: 'createdAt',
        maxAgeMs: 7 * 24 * 60 * 60 * 1000, // 7 days
      },
      {
        name: 'flagged_transactions',
        collection: 'flagged_transactions',
        field: 'flaggedAt',
        maxAgeMs: 180 * 24 * 60 * 60 * 1000, // 180 days
      },
      {
        name: 'audit_logs',
        collection: 'audit_logs',
        field: 'timestamp',
        // Q-06: 2-year retention. LEGAL NOTE: may be shorter than required by
        // financial regulators in target markets (Nigeria 10y, UK 6y, Ghana 5y).
        // Review with legal counsel before production launch and adjust here.
        maxAgeMs: 730 * 24 * 60 * 60 * 1000, // 730 days (2 years)
      },
    ];

    let totalDeleted = 0;

    for (const policy of retentionPolicies) {
      try {
        const cutoff = admin.firestore.Timestamp.fromMillis(now - policy.maxAgeMs);
        const snapshot = await db.collection(policy.collection)
          .where(policy.field, '<', cutoff)
          .limit(BATCH_LIMIT)
          .get();

        if (!snapshot.empty) {
          const batch = db.batch();
          snapshot.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
          totalDeleted += snapshot.size;
          logInfo(`TTL cleanup: ${policy.name}`, { deleted: snapshot.size, cutoffDays: Math.round(policy.maxAgeMs / (24 * 60 * 60 * 1000)) });
        }
      } catch (error) {
        logError(`TTL cleanup failed: ${policy.name}`, { error: error.message });
      }
    }

    // Clean up old notifications across all users (sub-collection cleanup)
    try {
      const notifCutoff = admin.firestore.Timestamp.fromMillis(now - 90 * 24 * 60 * 60 * 1000); // 90 days
      const usersSnapshot = await db.collection('users').select().limit(500).get();

      for (const userDoc of usersSnapshot.docs) {
        const oldNotifs = await db.collection('users').doc(userDoc.id)
          .collection('notifications')
          .where('createdAt', '<', notifCutoff)
          .limit(100)
          .get();

        if (!oldNotifs.empty) {
          const batch = db.batch();
          oldNotifs.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
          totalDeleted += oldNotifs.size;
        }
      }
      logInfo('TTL cleanup: notifications', { usersProcessed: usersSnapshot.size });
    } catch (error) {
      logError('TTL cleanup failed: notifications', { error: error.message });
    }

    logInfo('Data retention cleanup complete', { totalDeleted });
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

  logInfo('State transition', { from, to, transactionId });
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
      timestamp: timestamps.firestoreNow(),
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
        timestamp: timestamps.firestoreNow(),
      }),
      ...additionalData,
    });

    return { previousState: from, newState: to };
  });
}

// ============================================================
// QR CODE SIGNING & VERIFICATION
// ============================================================

// Sign QR payload for payment requests (with nonce for replay protection)
exports.signQrPayload = functions
  .runWith({ secrets: [QR_SECRET_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Check if account is blocked
  const userBlockDoc = await db.collection('users').doc(userId).get();
  if (userBlockDoc.exists && userBlockDoc.data().accountBlocked === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Your account is suspended.');
  }

  const { walletId, amount, note, items } = data;

  if (!walletId || typeof walletId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Invalid wallet ID.');
  }

  // Verify the wallet belongs to the user
  const walletDoc = await db.collection('wallets').doc(userId).get();
  if (!walletDoc.exists || walletDoc.data().walletId !== walletId) {
    throwAppError(ERROR_CODES.AUTH_PERMISSION_DENIED, 'Wallet does not belong to user.');
  }

  // Generate unique nonce for one-time use
  const nonce = crypto.randomUUID();
  const timestamp = Date.now();
  const expiresAt = timestamp + QR_EXPIRY_MS;

  const payload = {
    walletId,
    amount: amount || 0,
    note: note || '',
    items: Array.isArray(items) ? items.slice(0, 20) : [],
    nonce,
    timestamp,
    userId,
  };

  const payloadString = JSON.stringify(payload);
  const signature = generateQrSignature(payloadString);

  // Store nonce for one-time use verification
  await db.collection('qr_nonces').doc(nonce).set({
    nonce,
    walletId,
    amount: amount || 0,
    items: Array.isArray(items) ? items.slice(0, 20) : [],
    createdBy: userId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt),
    used: false,
  });

  logInfo('QR code generated', {
    userId,
    walletId,
    hasAmount: !!amount,
    nonce,
  });

  return {
    payload: payloadString,
    signature,
    expiresAt,
    nonce,
  };
});

// Verify QR signature before processing payment (with nonce replay protection)
exports.verifyQrSignature = functions
  .runWith({ secrets: [QR_SECRET_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { payload, signature } = data;
  const userId = context.auth.uid;
  const correlationId = getCorrelationId(context);

  if (!payload || !signature) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Missing payload or signature.');
  }

  // Verify signature (timing-safe)
  const expectedSignature = generateQrSignature(payload);
  if (!timingSafeCompare(signature, expectedSignature, 'hex')) {
    logSecurityEvent('qr_invalid_signature', 'medium', {
      correlationId,
      userId,
    });
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

  // Check nonce for one-time use (replay protection)
  const nonce = parsedPayload.nonce;
  if (!nonce) {
    // Legacy QR without nonce — reject
    logSecurityEvent('qr_missing_nonce', 'medium', {
      correlationId,
      userId,
      walletId: parsedPayload.walletId,
    });
    return { valid: false, reason: 'Invalid QR code format' };
  }

  // Atomic check-and-mark using Firestore transaction
  const nonceRef = db.collection('qr_nonces').doc(nonce);

  try {
    await db.runTransaction(async (transaction) => {
      const nonceDoc = await transaction.get(nonceRef);

      if (!nonceDoc.exists) {
        throw new Error('NONCE_NOT_FOUND');
      }

      const nonceData = nonceDoc.data();

      if (nonceData.used) {
        throw new Error('NONCE_ALREADY_USED');
      }

      // Mark as used atomically
      transaction.update(nonceRef, {
        used: true,
        usedBy: userId,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        usedCorrelationId: correlationId,
      });
    });
  } catch (error) {
    if (error.message === 'NONCE_ALREADY_USED') {
      logSecurityEvent('qr_replay_attempt', 'high', {
        correlationId,
        userId,
        nonce,
        walletId: parsedPayload.walletId,
      });
      return { valid: false, reason: 'This QR code has already been used' };
    }
    if (error.message === 'NONCE_NOT_FOUND') {
      logSecurityEvent('qr_unknown_nonce', 'medium', {
        correlationId,
        userId,
        nonce,
      });
      return { valid: false, reason: 'Invalid QR code' };
    }
    throw error;
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

  logInfo('QR code verified', {
    correlationId,
    userId,
    walletId: parsedPayload.walletId,
    nonce,
  });

  // Use legalName (title-cased, masked) for privacy
  const userData = userDoc.exists ? userDoc.data() : {};
  const verifiedDisplayName = userData.legalName
    ? titleCaseName(userData.legalName)
    : (userData.fullName || 'QR Wallet User');

  return {
    valid: true,
    walletId: parsedPayload.walletId,
    amount: parsedPayload.amount,
    note: parsedPayload.note,
    items: parsedPayload.items || [],
    recipientName: maskName(verifiedDisplayName),
    nonce,
  };
});

// ============================================================
// NAME HELPERS — Title-casing and masking for legal names
// ============================================================

/**
 * Title-case a name: "JOE LEO DOE" → "Joe Leo Doe"
 * Handles edge cases: empty strings, single names, hyphens, apostrophes
 */
function titleCaseName(name) {
  if (!name || typeof name !== 'string') return name;
  return name
    .trim()
    .toLowerCase()
    .replace(/(?:^|\s|[-'])\S/g, (char) => char.toUpperCase());
}

/**
 * Mask a name for privacy: "Joe Leo Doe" → "Joe D."
 * Shows first name + last name initial + period.
 * If only one name part, returns it as-is.
 * Falls back to 'QR Wallet User' if empty.
 */
function maskName(name) {
  if (!name || typeof name !== 'string' || !name.trim()) return 'QR Wallet User';
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0];
  const firstName = parts[0];
  const lastInitial = parts[parts.length - 1][0].toUpperCase();
  return `${firstName} ${lastInitial}.`;
}

// Lookup wallet with rate limiting
exports.lookupWallet = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
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

  // Check failed lookup limit (persistent, per IP)
  if (!(await checkFailedLookups(hashedIp))) {
    throwAppError(ERROR_CODES.RATE_COOLDOWN_ACTIVE, 'Too many failed attempts. Please wait 5 minutes.');
  }

  // Persistent rate limit (30 lookups per 5 minutes, survives cold starts)
  await enforceRateLimit(userId, 'lookupWallet');
  
  if (!walletId || typeof walletId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Invalid wallet ID.');
  }
  
// Find wallet
  console.log("Looking up walletId:", JSON.stringify(walletId), "length:", walletId.length);
  const walletQuery = await db.collection('wallets')
    .where('walletId', '==', walletId)
    .limit(1)
    .get();
  
  if (walletQuery.empty) {
    await recordFailedLookup(hashedIp);
    return { found: false };
  }
  
  const walletDoc = walletQuery.docs[0];
  const walletData = walletDoc.data();
  
  // Get user info — only retrieve the minimum fields needed for recipient confirmation
  const userDoc = await db.collection('users').doc(walletDoc.id).get();
  const userData = userDoc.exists ? userDoc.data() : {};

  // Use legalName (title-cased) if available, fall back to fullName
  const displayName = userData.legalName
    ? titleCaseName(userData.legalName)
    : (userData.fullName || 'QR Wallet User');

  // Return full verified name for sender confirmation + masked version for transaction history
  return {
    found: true,
    walletId: walletData.walletId,
    recipientName: displayName,
    maskedName: maskName(displayName),
    currency: walletData.currency || 'NGN',
  };
});


// ============================================================
// ACCOUNT BLOCKING
/**
 * Reset PIN (forgot PIN flow).
 * Requires recent re-authentication (auth_time within 5 minutes).
 * User must re-authenticate via email/password or phone OTP on the client,
 * then call this function with the new PIN hash.
 */
exports.resetPin = functions
  .runWith({ secrets: [PIN_SECRET_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;
  const { newPinHash, method } = data;

  // Validate new PIN hash (SHA-256 hex = 64 chars)
  if (!newPinHash || typeof newPinHash !== 'string' || newPinHash.length !== 64) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Invalid new PIN hash.');
  }

  // Validate method
  if (!method || !['email', 'phone'].includes(method)) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Invalid reset method.');
  }

  // Rate limit PIN resets (stricter than changes)
  await enforceRateLimit(userId, 'resetPin');

  // Verify recent re-authentication: auth_time must be within 5 minutes
  const authTime = context.auth.token.auth_time;
  const now = Math.floor(Date.now() / 1000);
  const fiveMinutes = 5 * 60;

  if (!authTime || (now - authTime) > fiveMinutes) {
    throwAppError(
      ERROR_CODES.SYSTEM_VALIDATION_FAILED,
      'Session expired. Please re-authenticate and try again.'
    );
  }

  // Get user document
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'User not found.');
  }

  const userData = userDoc.data();

  // User must have a PIN set to reset it
  if (!userData.pinHash) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'No PIN is set on this account.');
  }

  // Generate new per-user salt
  const newSalt = crypto.randomBytes(32).toString('hex');

  // Compute HMAC hash
  const serverHash = hashPinServer(newPinHash, newSalt);

  // Prevent setting the same PIN
  if (timingSafeCompare(userData.pinHash, serverHash)) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'New PIN must be different from your previous PIN.');
  }

  // Update PIN hash and salt
  await db.collection('users').doc(userId).update({
    pinHash: serverHash,
    pinSalt: newSalt,
    pinChangedAt: admin.firestore.FieldValue.serverTimestamp(),
    pinResetAt: admin.firestore.FieldValue.serverTimestamp(),
    pinResetMethod: method,
  });

  // Audit log
  await auditLog({
    userId,
    operation: 'resetPin',
    result: 'success',
    metadata: { method },
    ipHash: hashIp(context),
  });

  // Security notification
  await sendPushNotification(userId, {
    title: 'PIN Reset',
    body: 'Your transaction PIN has been reset. If you did not make this change, block your account immediately from your profile.',
    type: 'security',
    data: { action: 'pin_reset', method },
  }).catch(() => {});

  return { success: true, message: 'PIN reset successfully.' };
});

// ============================================================
/**
 * Block user's account - prevents all financial operations.
 * Requires PIN verification for security.
 * Sets blockedBy to 'user' so the user can unblock themselves.
 */
// ============================================================
// PIN HELPER FUNCTIONS
// ============================================================

function hashPinServer(clientHash, salt) {
  requireConfig(PIN_SECRET.value, 'pin.secret');
  return crypto.createHmac('sha256', salt + PIN_SECRET.value)
    .update(clientHash)
    .digest('hex');
}

function verifyPinServer(clientHash, storedHash, salt) {
  const expectedHash = hashPinServer(clientHash, salt);
  return timingSafeCompare(storedHash, expectedHash);
}

// ============================================================
// CHANGE PIN
// ============================================================

exports.changePin = functions
  .runWith({ secrets: [PIN_SECRET_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;
  const { currentPinHash, newPinHash } = data;

  if (!newPinHash || typeof newPinHash !== 'string' || newPinHash.length !== 64) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Invalid new PIN hash.');
  }

  await enforceRateLimit(userId, 'changePin');

  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'User not found.');
  }

  const userData = userDoc.data();

  if (userData.pinHash) {
    if (!currentPinHash || typeof currentPinHash !== 'string') {
      throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Current PIN is required.');
    }
    if (!verifyPinServer(currentPinHash, userData.pinHash, userData.pinSalt || '')) {
      throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Incorrect current PIN.');
    }
  }

  const newSalt = crypto.randomBytes(32).toString('hex');
  const serverHash = hashPinServer(newPinHash, newSalt);

  if (userData.pinHash && timingSafeCompare(userData.pinHash, serverHash)) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'New PIN must be different from current PIN.');
  }

  await db.collection('users').doc(userId).update({
    pinHash: serverHash,
    pinSalt: newSalt,
    pinChangedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await auditLog({
    userId,
    operation: 'changePin',
    result: 'success',
    metadata: { hadExistingPin: !!userData.pinHash },
    ipHash: hashIp(context),
  });

  await sendPushNotification(userId, {
    title: 'PIN Changed',
    body: 'Your transaction PIN has been changed. If you did not make this change, block your account immediately from your profile.',
    type: 'security',
    data: { action: 'pin_changed' },
  }).catch(() => {});

  return { success: true, message: 'PIN updated successfully.' };
});



exports.blockAccount = functions
  .runWith({ secrets: [PIN_SECRET_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }
  const userId = context.auth.uid;
  const { pinHash } = data;
  if (!pinHash || typeof pinHash !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'PIN is required to block account.');
  }
  // Verify PIN
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'User not found.');
  }
const userData = userDoc.data();
  if (!userData.pinHash) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'You must set a PIN before you can block your account.');
  }
  if (!verifyPinServer(pinHash, userData.pinHash, userData.pinSalt || '')) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Incorrect PIN.');
  }
  // Check if already blocked
  if (userData.accountBlocked === true) {
    return { success: true, message: 'Account is already blocked.' };
  }
  // Block account
  await db.collection('users').doc(userId).update({
    accountBlocked: true,
    accountBlockedAt: admin.firestore.FieldValue.serverTimestamp(),
    accountBlockedBy: 'user',
  });
  // Send push + in-app notification
  await sendPushNotification(userId, {
    title: 'Account Blocked',
    body: 'Your account has been blocked. All transactions are disabled. You can unblock your account from your profile at any time.',
    type: 'security',
    data: { action: 'account_blocked', blockedBy: 'user' },
  });
  await auditLog({
    userId,
    operation: 'blockAccount',
    result: 'success',
    metadata: { blockedBy: 'user' },
    ipHash: hashIp(context),
  });
  return { success: true, message: 'Account blocked successfully.' };
});

/**
 * Unblock user's account.
 * Requires PIN verification.
 * Only allows unblock if the account was blocked by the user (not admin).
 */
exports.unblockAccount = functions
  .runWith({ secrets: [PIN_SECRET_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }
  const userId = context.auth.uid;
  const { pinHash } = data;
  if (!pinHash || typeof pinHash !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'PIN is required to unblock account.');
  }
  // Get user data
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'User not found.');
  }
 const userData = userDoc.data();
  // Check if account is actually blocked
  if (userData.accountBlocked !== true) {
    return { success: true, message: 'Account is not blocked.' };
  }
  // Check if blocked by admin - user cannot unblock admin blocks
  if (userData.accountBlockedBy === 'admin') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED,
      'Your account was blocked by support. Please contact customer support to unblock your account.');
  }
  // Verify PIN - PIN must be set
  if (!userData.pinHash) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'You must set a PIN before you can unblock your account.');
  }
  if (!verifyPinServer(pinHash, userData.pinHash, userData.pinSalt || '')) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Incorrect PIN.');
  }
  // Unblock account
  await db.collection('users').doc(userId).update({
    accountBlocked: false,
    accountUnblockedAt: admin.firestore.FieldValue.serverTimestamp(),
    accountBlockedBy: admin.firestore.FieldValue.delete(),
  });
  // Send push + in-app notification
  await sendPushNotification(userId, {
    title: 'Account Unblocked',
    body: 'Your account has been unblocked. All transactions are now enabled.',
    type: 'security',
    data: { action: 'account_unblocked' },
  });
  await auditLog({
    userId,
    operation: 'unblockAccount',
    result: 'success',
    metadata: {},
    ipHash: hashIp(context),
  });
  return { success: true, message: 'Account unblocked successfully.' };
});

// ============================================================
// ADMIN SYSTEM — ROLE-BASED ACCESS CONTROL
// ============================================================

/**
 * Verifies that the calling user has admin privileges.
 * Checks Firebase Auth custom claims for role-based access.
 *
 * Unified 8-role hierarchy used by both platform admin (here) and
 * business wallet (verifyBusinessWalletAccess, updated in commit 11):
 *   viewer < auditor < support < admin < admin_supervisor < finance < admin_manager < super_admin
 *
 * The `finance` role handles money validation and co-signs platform
 * transfers with admin_manager. It is NOT in the holds approval workflow.
 *
 * @param {Object} context - Firebase callable context
 * @param {string} requiredRole - Minimum role required. Valid values:
 *   'viewer', 'auditor', 'support', 'admin', 'admin_supervisor',
 *   'finance', 'admin_manager', 'super_admin'
 * @returns {Object} - { uid, role } of the verified admin
 * @throws {HttpsError} permission-denied if not authorized
 */
async function verifyAdmin(context, requiredRole = 'support') {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }

  const uid = context.auth.uid;
  const claims = context.auth.token;
  const role = claims.role;

  if (!role) {
    throw new functions.https.HttpsError('permission-denied', 'You do not have admin privileges.');
  }

  const roleHierarchy = {
    viewer: 1,
    auditor: 2,
    support: 3,
    admin: 4,
    admin_supervisor: 5,
    finance: 6,
    admin_manager: 7,
    super_admin: 8,
  };
  const userLevel = roleHierarchy[role] || 0;
  const requiredLevel = roleHierarchy[requiredRole] || 0;

  if (userLevel < requiredLevel) {
    throw new functions.https.HttpsError(
      'permission-denied',
      `This action requires ${requiredRole} role. Your role: ${role}`
    );
  }

  return { uid, role };
}

/**
 * One-time setup to assign super_admin role to the initial admin user.
 * Hardcoded UID for security — can only be called once.
 */
exports.setupSuperAdmin = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  // L-05: Allowlist is stored in Firestore at admin_bootstrap_config/allowed_emails.
  // Managed via updateSuperAdminAllowlist CF (super_admin only). See commit 10.
  // H-03: This function is ONE-TIME-ONLY. After the initial super_admin exists
  // in admin_users, this function refuses all further calls. New super_admins
  // must be created via adminPromoteUser (which requires an existing super_admin
  // to authorize). To re-bootstrap after losing the initial super_admin account,
  // use the Firebase Admin SDK directly from a trusted shell.
  const allowlistDoc = await db.collection('admin_bootstrap_config').doc('allowed_emails').get();
  if (!allowlistDoc.exists) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Super admin allowlist not configured. Contact system administrator.'
    );
  }
  const APPROVED_SUPER_ADMIN_EMAILS = allowlistDoc.data().emails || [];
  if (APPROVED_SUPER_ADMIN_EMAILS.length === 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Super admin allowlist is empty. Cannot bootstrap.'
    );
  }

  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in to setup super admin.');
  }

  // H-03: One-time-only guard. If any super_admin already exists in admin_users,
  // refuse this call regardless of caller identity. Closes the auto-escalation
  // path that would otherwise grant super_admin to anyone with access to an
  // allowlisted email.
  const existingSuperAdmins = await db.collection('admin_users')
    .where('role', '==', 'super_admin')
    .limit(1)
    .get();

  if (!existingSuperAdmins.empty) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Super admin bootstrap is closed. Use adminPromoteUser (requires existing super_admin).'
    );
  }

  const callerUid = context.auth.uid;
  const userRecord = await admin.auth().getUser(callerUid);
  const callerEmail = (userRecord.email || '').toLowerCase();

  if (!APPROVED_SUPER_ADMIN_EMAILS.map(e => e.toLowerCase()).includes(callerEmail)) {
    throw new functions.https.HttpsError('permission-denied', 'Email not approved for super admin.');
  }

  // Already set up — idempotent return
  if (userRecord.customClaims && userRecord.customClaims.role === 'super_admin') {
    // Make sure backup record in admin_users exists
    await db.collection('admin_users').doc(callerEmail).set({
      email: callerEmail,
      uid: callerUid,
      role: 'super_admin',
      updatedAt: timestamps.serverTimestamp(),
    }, { merge: true });
    return { success: true, message: 'Super admin already configured.' };
  }

  // Set the custom claim
  await admin.auth().setCustomUserClaims(callerUid, { role: 'super_admin' });

  // Update Firestore user document (best-effort — don't fail if user doc doesn't exist)
  try {
    await db.collection('users').doc(callerUid).set({
      role: 'super_admin',
      roleUpdatedAt: timestamps.serverTimestamp(),
    }, { merge: true });
  } catch (e) {
    console.warn('Could not update user doc, continuing:', e.message);
  }

  // Backup record in admin_users keyed by email so it survives wallet account deletion
  await db.collection('admin_users').doc(callerEmail).set({
    email: callerEmail,
    uid: callerUid,
    role: 'super_admin',
    createdAt: timestamps.serverTimestamp(),
    updatedAt: timestamps.serverTimestamp(),
  }, { merge: true });

  await auditLog({
    userId: callerUid,
    operation: 'setupSuperAdmin',
    result: 'success',
    metadata: { targetUid: callerUid, email: callerEmail },
    ipHash: hashIp(context),
  });

  return { success: true, message: 'Super admin role assigned successfully.' };
});

/**
 * Promote a user to admin or support role.
 * Only super_admin can promote to admin; admin+ can promote to support.
 */
/**
 * Helper: resolve a target user identifier to a Firebase Auth UID.
 *
 * Accepts EITHER targetEmail (preferred for UX — humans know emails, not UIDs)
 * OR targetUid (for direct API/script callers, backward compatible).
 *
 * If both are provided, targetEmail wins (user-friendly path).
 * If neither is provided, throws invalid-argument.
 *
 * Throws not-found if the email doesn't match any user.
 *
 * @param {Object} data - the CF input data
 * @param {string} [data.targetEmail] - email to look up
 * @param {string} [data.targetUid] - UID to use directly
 * @returns {Promise<string>} the resolved UID
 */
async function resolveTargetUid(data) {
  const email = data.targetEmail ? String(data.targetEmail).trim().toLowerCase() : null;
  const uid = data.targetUid ? String(data.targetUid).trim() : null;

  if (email) {
    try {
      const user = await admin.auth().getUserByEmail(email);
      return user.uid;
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        throw new functions.https.HttpsError('not-found',
          `No user found with email ${email}.`);
      }
      throw new functions.https.HttpsError('internal',
        `Failed to look up user by email: ${e.message}`);
    }
  }

  if (uid) {
    return uid;
  }

  throw new functions.https.HttpsError('invalid-argument',
    'Either targetEmail or targetUid is required.');
}

exports.adminPromoteUser = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const { role: newRole } = data;

  if (!newRole) {
    throw new functions.https.HttpsError('invalid-argument', 'role is required.');
  }

  const targetUid = await resolveTargetUid(data);

  // Valid target roles. super_admin goes through the separate promoteSuperAdmin CF.
  const VALID_PROMOTE_ROLES = ['viewer', 'auditor', 'support', 'admin', 'admin_supervisor', 'finance', 'admin_manager'];
  if (!VALID_PROMOTE_ROLES.includes(newRole)) {
    throw new functions.https.HttpsError('invalid-argument',
      `Role must be one of: ${VALID_PROMOTE_ROLES.join(', ')}. For super_admin promotion, use promoteSuperAdmin.`);
  }

  // 8-role hierarchy — caller must be strictly above target level.
  const ROLE_HIERARCHY = {
    viewer: 1, auditor: 2, support: 3, admin: 4,
    admin_supervisor: 5, finance: 6, admin_manager: 7, super_admin: 8,
  };
  const targetLevel = ROLE_HIERARCHY[newRole];
  const requiredCallerLevel = targetLevel + 1;

  // Find the lowest caller role that satisfies the requirement (for verifyAdmin gate).
  const minimumCallerRole = Object.entries(ROLE_HIERARCHY)
    .find(([, level]) => level === requiredCallerLevel)?.[0];

  if (!minimumCallerRole) {
    // Target level 8 (super_admin) would require caller level 9, which does not exist.
    throw new functions.https.HttpsError('invalid-argument',
      'Cannot promote to this role. Use promoteSuperAdmin for super_admin.');
  }

  const caller = await verifyAdmin(context, minimumCallerRole);

  // D-09: Prevent self-modification
  if (targetUid === caller.uid) {
    throw new functions.https.HttpsError('permission-denied',
      'You cannot modify your own role. Ask another super_admin to change it.');
  }

  // Verify target user exists; capture their email for the admin_users doc.
  let targetUser;
  try {
    targetUser = await admin.auth().getUser(targetUid);
  } catch (e) {
    throw new functions.https.HttpsError('not-found', 'Target user not found.');
  }
  const targetEmail = (targetUser.email || '').toLowerCase();

  // Set the Firebase Auth custom claim.
  await admin.auth().setCustomUserClaims(targetUid, { role: newRole });

  // Update the users collection (merge to be safe if fields are missing).
  await db.collection('users').doc(targetUid).set({
    role: newRole,
    roleUpdatedAt: timestamps.serverTimestamp(),
    roleUpdatedBy: caller.uid,
  }, { merge: true });

  // Update the admin_users collection so the Current Admins UI reflects it.
  if (targetEmail) {
    await db.collection('admin_users').doc(targetEmail).set({
      email: targetEmail,
      uid: targetUid,
      role: newRole,
      updatedAt: timestamps.serverTimestamp(),
      updatedBy: caller.uid,
    }, { merge: true });
  }

  await auditLog({
    userId: caller.uid,
    operation: 'adminPromoteUser',
    result: 'success',
    metadata: { targetUid, targetEmail, newRole, callerRole: caller.role },
    ipHash: hashIp(context),
  });

  // Admin activity log.
  await db.collection('admin_activity').add({
    uid: caller.uid,
    email: (await admin.auth().getUser(caller.uid)).email || 'unknown',
    role: caller.role,
    action: 'promote_user',
    targetUid,
    targetEmail,
    details: `Promoted to ${newRole}`,
    ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: `User promoted to ${newRole}.` };
});

/**
 * Demote a user by removing their admin role.
 * Only super_admin can demote admins; admin+ can demote support.
 */
exports.adminDemoteUser = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const { newRole } = data;

  const targetUid = await resolveTargetUid(data);

  // Get target's current role and email
  let targetUser;
  try {
    targetUser = await admin.auth().getUser(targetUid);
  } catch (e) {
    throw new functions.https.HttpsError('not-found', 'Target user not found.');
  }
  const targetRole = targetUser.customClaims?.role;
  const targetEmail = (targetUser.email || '').toLowerCase();

  if (!targetRole) {
    throw new functions.https.HttpsError('not-found', 'User does not have an admin role.');
  }

  // 8-role hierarchy (matches verifyAdmin).
  const ROLE_HIERARCHY = {
    viewer: 1, auditor: 2, support: 3, admin: 4,
    admin_supervisor: 5, finance: 6, admin_manager: 7, super_admin: 8,
  };

  const targetLevel = ROLE_HIERARCHY[targetRole];
  if (!targetLevel) {
    throw new functions.https.HttpsError('failed-precondition',
      `Target has unrecognized role '${targetRole}'. Cannot determine authorization.`);
  }

  // If a downgrade (newRole provided), validate newRole is below current level.
  if (newRole !== undefined && newRole !== null) {
    const newLevel = ROLE_HIERARCHY[newRole];
    if (!newLevel) {
      throw new functions.https.HttpsError('invalid-argument',
        `Invalid newRole. Must be one of: ${Object.keys(ROLE_HIERARCHY).join(', ')}`);
    }
    if (newLevel >= targetLevel) {
      throw new functions.https.HttpsError('invalid-argument',
        `newRole '${newRole}' (level ${newLevel}) must be strictly below current role '${targetRole}' (level ${targetLevel}).`);
    }
  }

  // Caller must be strictly above target's current level.
  const requiredCallerLevel = targetLevel + 1;
  const minimumCallerRole = Object.entries(ROLE_HIERARCHY)
    .find(([, level]) => level === requiredCallerLevel)?.[0];

  if (!minimumCallerRole) {
    // Target is super_admin (level 8). Only another super_admin can demote.
    // (super_admin demotion was previously blocked entirely; now allowed for
    // another super_admin, blocked for self via D-09.)
    const caller = await verifyAdmin(context, 'super_admin');
    if (targetUid === caller.uid) {
      throw new functions.https.HttpsError('permission-denied',
        'You cannot modify your own role. Ask another super_admin to change it.');
    }
    return await performDemotion(targetUid, targetEmail, targetRole, newRole, caller, context);
  }

  const caller = await verifyAdmin(context, minimumCallerRole);

  // D-09: Prevent self-modification
  if (targetUid === caller.uid) {
    throw new functions.https.HttpsError('permission-denied',
      'You cannot modify your own role. Ask another super_admin to change it.');
  }

  return await performDemotion(targetUid, targetEmail, targetRole, newRole, caller, context);
});

/**
 * Internal helper for adminDemoteUser. Performs the actual claim update,
 * token revocation, and Firestore writes.
 *
 * Two modes:
 *   - Full demote (newRole null/undefined): clears all admin claims,
 *     deletes the admin_users doc.
 *   - Downgrade (newRole provided): sets {role: newRole}, updates
 *     the admin_users doc with the new role.
 *
 * Token revocation (admin.auth().revokeRefreshTokens) forces the
 * demoted user's ID token to refresh within seconds rather than up to
 * 1 hour (the default Firebase ID token cache).
 */
async function performDemotion(targetUid, targetEmail, previousRole, newRole, caller, context) {
  const isFullDemote = newRole === undefined || newRole === null;

  // Update the custom claim
  if (isFullDemote) {
    await admin.auth().setCustomUserClaims(targetUid, {});
  } else {
    await admin.auth().setCustomUserClaims(targetUid, { role: newRole });
  }

  // CRITICAL: revoke refresh tokens so the new claim activates immediately.
  // Without this, the demoted user's cached ID token retains the old role
  // for up to 1 hour after demotion.
  await admin.auth().revokeRefreshTokens(targetUid);

  // Update users collection
  if (isFullDemote) {
    await db.collection('users').doc(targetUid).update({
      role: admin.firestore.FieldValue.delete(),
      roleUpdatedAt: timestamps.serverTimestamp(),
      roleUpdatedBy: caller.uid,
    });
  } else {
    await db.collection('users').doc(targetUid).set({
      role: newRole,
      roleUpdatedAt: timestamps.serverTimestamp(),
      roleUpdatedBy: caller.uid,
    }, { merge: true });
  }

  // Update admin_users collection
  if (targetEmail) {
    if (isFullDemote) {
      // Remove from admin_users on full demote
      try {
        await db.collection('admin_users').doc(targetEmail).delete();
      } catch (e) {
        // Doc may not exist; non-fatal
        logWarning('admin_users doc not found for full demote', { targetEmail });
      }
    } else {
      // Update role on partial demote
      await db.collection('admin_users').doc(targetEmail).set({
        email: targetEmail,
        uid: targetUid,
        role: newRole,
        updatedAt: timestamps.serverTimestamp(),
        updatedBy: caller.uid,
      }, { merge: true });
    }
  }

  // Audit log
  await auditLog({
    userId: caller.uid,
    operation: 'adminDemoteUser',
    result: 'success',
    metadata: {
      targetUid,
      targetEmail,
      previousRole,
      newRole: isFullDemote ? null : newRole,
      isFullDemote,
      callerRole: caller.role,
    },
    ipHash: hashIp(context),
  });

  // Admin activity log
  await db.collection('admin_activity').add({
    uid: caller.uid,
    email: (await admin.auth().getUser(caller.uid)).email || 'unknown',
    role: caller.role,
    action: isFullDemote ? 'demote_user_full' : 'demote_user_downgrade',
    targetUid,
    targetEmail,
    details: isFullDemote
      ? `Removed all admin roles (was ${previousRole})`
      : `Downgraded from ${previousRole} to ${newRole}`,
    ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    message: isFullDemote
      ? `User demoted from ${previousRole} (all admin roles removed).`
      : `User downgraded from ${previousRole} to ${newRole}.`,
  };
}

/**
 * Promote a user to super_admin. Separate from adminPromoteUser because
 * super_admin is special and requires extra safeguards:
 *  - Only an existing super_admin can perform this
 *  - Target email must be on the Firestore allowlist
 *    (admin_bootstrap_config/allowed_emails)
 *  - Forces refresh token revocation so new claim activates within seconds
 *  - Intended to be invoked via a dedicated high-risk UI with confirmation
 *    (dashboard side shipped in master plan Commit 19)
 */
exports.promoteSuperAdmin = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const targetUid = await resolveTargetUid(data);

  // Only super_admin can promote another super_admin
  const caller = await verifyAdmin(context, 'super_admin');

  // D-09: Prevent self-modification (defense in depth — caller already is
  // super_admin per verifyAdmin check above, so this is mainly a clarity guard).
  if (targetUid === caller.uid) {
    throw new functions.https.HttpsError('permission-denied',
      'You cannot modify your own role.');
  }

  // Verify target user exists, get email
  let targetUser;
  try {
    targetUser = await admin.auth().getUser(targetUid);
  } catch (e) {
    throw new functions.https.HttpsError('not-found', 'Target user not found.');
  }
  const targetEmail = (targetUser.email || '').toLowerCase();
  if (!targetEmail) {
    throw new functions.https.HttpsError('failed-precondition',
      'Target user has no email address.');
  }

  // L-05: Check allowlist (Firestore-backed)
  const allowlistDoc = await db.collection('admin_bootstrap_config').doc('allowed_emails').get();
  if (!allowlistDoc.exists) {
    throw new functions.https.HttpsError('failed-precondition',
      'Super admin allowlist not configured.');
  }
  const allowedEmails = (allowlistDoc.data().emails || []).map(e => String(e).toLowerCase());
  if (!allowedEmails.includes(targetEmail)) {
    throw new functions.https.HttpsError('permission-denied',
      `Target email is not on the super_admin allowlist. Add it first via updateSuperAdminAllowlist.`);
  }

  // Set custom claim
  await admin.auth().setCustomUserClaims(targetUid, { role: 'super_admin' });

  // Revoke refresh tokens so new claim activates immediately
  await admin.auth().revokeRefreshTokens(targetUid);

  // Update users collection
  await db.collection('users').doc(targetUid).set({
    role: 'super_admin',
    roleUpdatedAt: timestamps.serverTimestamp(),
    roleUpdatedBy: caller.uid,
  }, { merge: true });

  // Update admin_users collection
  await db.collection('admin_users').doc(targetEmail).set({
    email: targetEmail,
    uid: targetUid,
    role: 'super_admin',
    updatedAt: timestamps.serverTimestamp(),
    updatedBy: caller.uid,
  }, { merge: true });

  // Audit log
  await auditLog({
    userId: caller.uid,
    operation: 'promoteSuperAdmin',
    result: 'success',
    metadata: { targetUid, targetEmail, callerRole: caller.role },
    ipHash: hashIp(context),
  });

  // Admin activity log
  await db.collection('admin_activity').add({
    uid: caller.uid,
    email: (await admin.auth().getUser(caller.uid)).email || 'unknown',
    role: caller.role,
    action: 'promote_super_admin',
    targetUid,
    targetEmail,
    details: `Promoted ${targetEmail} to super_admin`,
    ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: `User ${targetEmail} promoted to super_admin.` };
});

/**
 * ============================================================
 * STAFF ONBOARDING WORKFLOW (Commit 26a)
 * ============================================================
 *
 * Two-tier onboarding flow:
 *
 *   Direct path (admin_manager / super_admin):
 *     staffOnboardingDirect -> creates Firebase Auth user immediately
 *
 *   Approval path (admin_supervisor):
 *     staffOnboardingRequest -> creates pending request
 *     staffOnboardingApprove (admin_manager+) -> creates Auth user
 *     staffOnboardingReject (admin_manager+) -> closes request
 *
 * Auto-expiry:
 *     staffOnboardingExpireOld (scheduled, daily at 4 AM UTC)
 *     -> marks pending requests older than 5 days as 'expired'
 *
 * Setup-complete detection:
 *     onUserAuthVerified (auth trigger)
 *     -> when employee verifies email (sets password), updates the
 *        request to 'setup_complete' so it surfaces in the
 *        "Ready to Promote" list on the dashboard
 *
 * Firestore: staff_onboarding_requests/{requestId}
 *   {
 *     email, displayName, reason,
 *     requestedBy: {uid, email, role},
 *     requestedAt, dueBy (createdAt + 5 days),
 *     status: 'pending'|'approved'|'rejected'|'expired'|'setup_complete'|'promoted',
 *     decidedBy?, decidedAt?, decisionReason?,
 *     firebaseUid?,            // set on approval/direct
 *     passwordResetLink?,      // set on approval/direct (for manager to copy/email)
 *     setupCompletedAt?,       // set when employee verifies email
 *     promotedAt?, promotedRole?, promotedBy?  // set if/when promoted via existing CFs
 *   }
 *
 * Audit: every action also writes to audit_logs.
 *
 * Email sending: NOT YET WIRED. The password reset link is returned to the
 * dashboard so the manager can copy/email manually. Email infrastructure is
 * the next-session task.
 */

// Internal helper used by both Direct and Approve paths.
// Creates the Firebase Auth user and generates a password reset link.
async function _createStaffAccount(email, displayName) {
  // Check if email already exists
  try {
    const existing = await admin.auth().getUserByEmail(email);
    throw new functions.https.HttpsError('already-exists',
      `An account with email ${email} already exists (UID ${existing.uid}).`);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') {
      // Either it's already-exists (we re-throw) or another error
      if (e instanceof functions.https.HttpsError) throw e;
      throw new functions.https.HttpsError('internal',
        `Failed to check existing user: ${e.message}`);
    }
    // Not found = good, proceed to create
  }

  // Create Auth user. emailVerified=false; the password-reset link will
  // verify them implicitly when they set their password.
  const userRecord = await admin.auth().createUser({
    email,
    emailVerified: false,
    displayName: displayName || undefined,
    disabled: false,
  });

  // Generate a password reset link. Manager copies this and emails the staff.
  const passwordResetLink = await admin.auth().generatePasswordResetLink(email);

  return { uid: userRecord.uid, passwordResetLink };
}

/**
 * Supervisor: submit a request to onboard a new staff member.
 * Manager/super_admin will approve or reject.
 */
exports.staffOnboardingRequest = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_supervisor');

  const email = data.email ? String(data.email).trim().toLowerCase() : null;
  const displayName = data.displayName ? String(data.displayName).trim() : null;
  const reason = data.reason ? String(data.reason).trim() : null;

  if (!email || !email.includes('@') || email.length < 5) {
    throw new functions.https.HttpsError('invalid-argument',
      'Valid email is required.');
  }
  if (!reason || reason.length < 5) {
    throw new functions.https.HttpsError('invalid-argument',
      'Reason is required (at least 5 characters).');
  }

  // Rate limit: 5 requests per supervisor per day
  await checkRateLimitPersistent({
    uid: caller.uid,
    operation: 'staffOnboardingRequest',
    limit: 5,
    windowSeconds: 86400,
  });

  // Check for existing pending request for the same email
  const existing = await db.collection('staff_onboarding_requests')
    .where('email', '==', email)
    .where('status', '==', 'pending')
    .limit(1)
    .get();
  if (!existing.empty) {
    throw new functions.https.HttpsError('already-exists',
      `A pending request already exists for ${email}.`);
  }

  const callerRecord = await admin.auth().getUser(caller.uid);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const dueBy = admin.firestore.Timestamp.fromMillis(
    Date.now() + 5 * 24 * 60 * 60 * 1000  // 5 days
  );

  const docRef = await db.collection('staff_onboarding_requests').add({
    email,
    displayName: displayName || null,
    reason,
    requestedBy: {
      uid: caller.uid,
      email: callerRecord.email || null,
      role: caller.role,
    },
    requestedAt: now,
    dueBy,
    status: 'pending',
  });

  await auditLog({
    userId: caller.uid,
    operation: 'staffOnboardingRequest',
    result: 'success',
    metadata: { requestId: docRef.id, email, callerRole: caller.role },
    ipHash: hashIp(context),
  });

  return { success: true, requestId: docRef.id };
});

/**
 * Manager/super_admin: approve a pending onboarding request.
 * Creates the Firebase Auth user and returns the password reset link
 * (manager copies it to email to the new employee).
 */
exports.staffOnboardingApprove = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_manager');

  const requestId = data.requestId ? String(data.requestId).trim() : null;
  if (!requestId) {
    throw new functions.https.HttpsError('invalid-argument', 'requestId is required.');
  }

  const docRef = db.collection('staff_onboarding_requests').doc(requestId);
  const doc = await docRef.get();
  if (!doc.exists) {
    throw new functions.https.HttpsError('not-found', 'Request not found.');
  }
  const req = doc.data();
  if (req.status !== 'pending') {
    throw new functions.https.HttpsError('failed-precondition',
      `Request is ${req.status}, not pending. Cannot approve.`);
  }

  const { uid: newUid, passwordResetLink } = await _createStaffAccount(req.email, req.displayName);

  await docRef.update({
    status: 'approved',
    decidedBy: { uid: caller.uid, role: caller.role },
    decidedAt: admin.firestore.FieldValue.serverTimestamp(),
    firebaseUid: newUid,
    passwordResetLink,
  });

  await auditLog({
    userId: caller.uid,
    operation: 'staffOnboardingApprove',
    result: 'success',
    metadata: { requestId, email: req.email, newUid, callerRole: caller.role },
    ipHash: hashIp(context),
  });

  return {
    success: true,
    uid: newUid,
    email: req.email,
    passwordResetLink,
    message: 'Account created. Send the password setup link to the employee.',
  };
});

/**
 * Manager/super_admin: reject a pending onboarding request.
 */
exports.staffOnboardingReject = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_manager');

  const requestId = data.requestId ? String(data.requestId).trim() : null;
  const reason = data.reason ? String(data.reason).trim() : null;
  if (!requestId) {
    throw new functions.https.HttpsError('invalid-argument', 'requestId is required.');
  }
  if (!reason || reason.length < 5) {
    throw new functions.https.HttpsError('invalid-argument',
      'Rejection reason is required (at least 5 characters).');
  }

  const docRef = db.collection('staff_onboarding_requests').doc(requestId);
  const doc = await docRef.get();
  if (!doc.exists) {
    throw new functions.https.HttpsError('not-found', 'Request not found.');
  }
  const req = doc.data();
  if (req.status !== 'pending') {
    throw new functions.https.HttpsError('failed-precondition',
      `Request is ${req.status}, not pending.`);
  }

  await docRef.update({
    status: 'rejected',
    decidedBy: { uid: caller.uid, role: caller.role },
    decidedAt: admin.firestore.FieldValue.serverTimestamp(),
    decisionReason: reason,
  });

  await auditLog({
    userId: caller.uid,
    operation: 'staffOnboardingReject',
    result: 'success',
    metadata: { requestId, email: req.email, reason, callerRole: caller.role },
    ipHash: hashIp(context),
  });

  return { success: true, requestId };
});

/**
 * Manager/super_admin: directly onboard a staff member without approval queue.
 * Skips the supervisor request step entirely.
 */
exports.staffOnboardingDirect = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_manager');

  const email = data.email ? String(data.email).trim().toLowerCase() : null;
  const displayName = data.displayName ? String(data.displayName).trim() : null;

  if (!email || !email.includes('@') || email.length < 5) {
    throw new functions.https.HttpsError('invalid-argument',
      'Valid email is required.');
  }

  // Rate limit: 10 direct onboardings per caller per day
  await checkRateLimitPersistent({
    uid: caller.uid,
    operation: 'staffOnboardingDirect',
    limit: 10,
    windowSeconds: 86400,
  });

  const { uid: newUid, passwordResetLink } = await _createStaffAccount(email, displayName);

  const callerRecord = await admin.auth().getUser(caller.uid);
  const now = admin.firestore.FieldValue.serverTimestamp();

  // Record this direct onboarding in the same collection for unified history
  const docRef = await db.collection('staff_onboarding_requests').add({
    email,
    displayName: displayName || null,
    reason: 'Direct onboarding (no supervisor request)',
    requestedBy: {
      uid: caller.uid,
      email: callerRecord.email || null,
      role: caller.role,
    },
    requestedAt: now,
    decidedBy: { uid: caller.uid, role: caller.role },
    decidedAt: now,
    status: 'approved',
    firebaseUid: newUid,
    passwordResetLink,
  });

  await auditLog({
    userId: caller.uid,
    operation: 'staffOnboardingDirect',
    result: 'success',
    metadata: { requestId: docRef.id, email, newUid, callerRole: caller.role },
    ipHash: hashIp(context),
  });

  return {
    success: true,
    requestId: docRef.id,
    uid: newUid,
    email,
    passwordResetLink,
    message: 'Account created. Send the password setup link to the employee.',
  };
});

/**
 * Read-only: list onboarding requests by status.
 * supervisor sees only their own requests; admin_manager+ sees all.
 */
exports.staffOnboardingListPending = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_supervisor');

  const status = data.status ? String(data.status) : 'pending';
  const validStatuses = ['pending', 'approved', 'rejected', 'expired', 'setup_complete', 'promoted'];
  if (!validStatuses.includes(status)) {
    throw new functions.https.HttpsError('invalid-argument',
      `status must be one of: ${validStatuses.join(', ')}`);
  }

  let query = db.collection('staff_onboarding_requests')
    .where('status', '==', status);

  // Supervisors only see their own requests; admin_manager+ see all
  if (caller.role === 'admin_supervisor') {
    query = query.where('requestedBy.uid', '==', caller.uid);
  }

  const snap = await query.orderBy('requestedAt', 'desc').limit(50).get();
  const requests = snap.docs.map(d => {
    const data = d.data();
    return {
      id: d.id,
      email: data.email,
      displayName: data.displayName,
      reason: data.reason,
      requestedBy: data.requestedBy,
      requestedAt: data.requestedAt,
      status: data.status,
      decidedBy: data.decidedBy || null,
      decidedAt: data.decidedAt || null,
      decisionReason: data.decisionReason || null,
      firebaseUid: data.firebaseUid || null,
      // Only return passwordResetLink to the manager who decided (security)
      passwordResetLink:
        data.decidedBy && data.decidedBy.uid === caller.uid
          ? data.passwordResetLink || null
          : null,
      setupCompletedAt: data.setupCompletedAt || null,
    };
  });

  return { success: true, status, requests };
});

/**
 * Scheduled (daily): expire pending requests older than 5 days.
 */
exports.staffOnboardingExpireOld = functions.pubsub
  .schedule('0 4 * * *')  // Daily at 4:00 AM UTC
  .timeZone('UTC')
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 5 * 24 * 60 * 60 * 1000
    );

    const snap = await db.collection('staff_onboarding_requests')
      .where('status', '==', 'pending')
      .where('requestedAt', '<', cutoff)
      .limit(500)
      .get();

    if (snap.empty) {
      logInfo('staffOnboardingExpireOld: no pending requests to expire');
      return null;
    }

    const batch = db.batch();
    const now = admin.firestore.FieldValue.serverTimestamp();
    snap.docs.forEach(doc => {
      batch.update(doc.ref, {
        status: 'expired',
        decidedAt: now,
      });
    });
    await batch.commit();

    logInfo('staffOnboardingExpireOld: expired pending requests', { count: snap.size });
    return null;
  });

/**
 * Auth trigger: when a Firebase Auth user's record is updated AND emailVerified
 * becomes true, check if they have an approved staff onboarding request and
 * mark it as 'setup_complete'.
 *
 * Fires on every user metadata refresh, but the early return on already-marked
 * docs makes the work cheap.
 */
exports.onUserAuthVerified = functions.auth.user().onCreate(async (user) => {
  // onCreate fires once per user. We use the user's email to look up any
  // approved onboarding request that matches.
  if (!user.email) return null;

  const email = user.email.toLowerCase();
  const snap = await db.collection('staff_onboarding_requests')
    .where('email', '==', email)
    .where('status', '==', 'approved')
    .limit(1)
    .get();

  if (snap.empty) return null;

  const doc = snap.docs[0];
  // Only update if the firebaseUid matches (defensive: ensures we're updating
  // the right request, not a same-email coincidence)
  if (doc.data().firebaseUid !== user.uid) {
    logWarning('onUserAuthVerified: uid mismatch on staff onboarding request', {
      requestId: doc.id, expectedUid: doc.data().firebaseUid, actualUid: user.uid,
    });
    return null;
  }

  await doc.ref.update({
    status: 'setup_complete',
    setupCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logInfo('onUserAuthVerified: marked staff onboarding as setup_complete', {
    requestId: doc.id, uid: user.uid, email,
  });
  return null;
});

/**
 * Manage the super_admin bootstrap allowlist stored at
 * admin_bootstrap_config/allowed_emails in Firestore.
 *
 * Only callable by an existing super_admin. Accepts an action ('add' or
 * 'remove') and an email address. Updates the allowlist array atomically
 * inside a Firestore transaction.
 *
 * Guards:
 *  - Email format validation (basic regex)
 *  - Cannot remove your own email (prevents self-lockout)
 *  - Cannot reduce the list to empty (at least one email must remain)
 *  - Adding a duplicate is rejected with 'already-exists'
 *  - Removing a non-existent email is rejected with 'not-found'
 *
 * Ref: L-05
 */
exports.updateSuperAdminAllowlist = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'super_admin');

  const { action, email } = data;
  if (!['add', 'remove'].includes(action)) {
    throw new functions.https.HttpsError('invalid-argument', 'action must be "add" or "remove"');
  }
  if (!email || typeof email !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'email is required');
  }

  const normalizedEmail = email.trim().toLowerCase();

  // Basic email format validation
  const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!EMAIL_REGEX.test(normalizedEmail)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid email format');
  }

  // Get caller's email to prevent self-removal from the allowlist
  const callerRecord = await admin.auth().getUser(caller.uid);
  const callerEmail = (callerRecord.email || '').toLowerCase();

  const allowlistRef = db.collection('admin_bootstrap_config').doc('allowed_emails');

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(allowlistRef);
    if (!doc.exists) {
      throw new functions.https.HttpsError('failed-precondition',
        'Allowlist doc does not exist. Initial bootstrap required.');
    }

    const currentEmails = (doc.data().emails || []).map(e => String(e).toLowerCase());
    let newEmails;

    if (action === 'add') {
      if (currentEmails.includes(normalizedEmail)) {
        throw new functions.https.HttpsError('already-exists',
          `${normalizedEmail} is already in the allowlist.`);
      }
      newEmails = [...currentEmails, normalizedEmail];
    } else {
      // action === 'remove'
      if (normalizedEmail === callerEmail) {
        throw new functions.https.HttpsError('permission-denied',
          'You cannot remove your own email from the allowlist.');
      }
      if (!currentEmails.includes(normalizedEmail)) {
        throw new functions.https.HttpsError('not-found',
          `${normalizedEmail} is not in the allowlist.`);
      }
      newEmails = currentEmails.filter(e => e !== normalizedEmail);
      if (newEmails.length === 0) {
        throw new functions.https.HttpsError('failed-precondition',
          'Cannot reduce allowlist to empty. At least one email must remain.');
      }
    }

    transaction.update(allowlistRef, {
      emails: newEmails,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: caller.uid,
    });
  });

  // Audit log
  await auditLog({
    userId: caller.uid,
    operation: 'updateSuperAdminAllowlist',
    result: 'success',
    metadata: { action, email: normalizedEmail, callerEmail },
    ipHash: hashIp(context),
  });

  // Admin activity log
  await db.collection('admin_activity').add({
    uid: caller.uid,
    email: callerEmail,
    role: caller.role,
    action: 'allowlist_update',
    details: `${action} ${normalizedEmail}`,
    ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, action, email: normalizedEmail };
});

/**
 * Read the super_admin bootstrap allowlist.
 * Super_admin only — keeps the list of bootstrap emails confidential from
 * lower-level roles.
 *
 * Ref: L-05
 */
exports.adminGetAllowlist = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  await verifyAdmin(context, 'super_admin');

  const allowlistDoc = await db.collection('admin_bootstrap_config').doc('allowed_emails').get();
  if (!allowlistDoc.exists) {
    return { success: true, emails: [], note: 'Allowlist doc does not exist.' };
  }

  const data_ = allowlistDoc.data();
  return {
    success: true,
    emails: data_.emails || [],
    updatedAt: data_.updatedAt || null,
    updatedBy: data_.updatedBy || null,
  };
});

/**
 * Search for users by email, phone, or name.
 */
exports.adminSearchUser = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  await verifyAdmin(context, 'support');

  const { query, searchType = 'email' } = data;

  if (!query) {
    throw new functions.https.HttpsError('invalid-argument', 'Search query is required.');
  }

  let results = [];

  if (searchType === 'email') {
    try {
      const userRecord = await admin.auth().getUserByEmail(query);
      const userDoc = await db.collection('users').doc(userRecord.uid).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        results.push({
          uid: userRecord.uid,
          email: userRecord.email,
          fullName: userData.fullName || '',
          phoneNumber: userData.phoneNumber || '',
          kycStatus: userData.kycStatus || 'none',
          accountBlocked: userData.accountBlocked || false,
          createdAt: userData.createdAt,
        });
      }
    } catch (e) {
      // User not found — return empty results
    }
  } else if (searchType === 'phone') {
    const snapshot = await db.collection('users')
      .where('phoneNumber', '==', query)
      .limit(10)
      .get();

    for (const doc of snapshot.docs) {
      const userData = doc.data();
      results.push({
        uid: doc.id,
        email: userData.email || '',
        fullName: userData.fullName || '',
        phoneNumber: userData.phoneNumber || '',
        kycStatus: userData.kycStatus || 'none',
        accountBlocked: userData.accountBlocked || false,
        createdAt: userData.createdAt,
      });
    }
  } else if (searchType === 'name') {
    const snapshot = await db.collection('users')
      .where('fullName', '>=', query)
      .where('fullName', '<=', query + '\uf8ff')
      .limit(10)
      .get();

    for (const doc of snapshot.docs) {
      const userData = doc.data();
      results.push({
        uid: doc.id,
        email: userData.email || '',
        fullName: userData.fullName || '',
        phoneNumber: userData.phoneNumber || '',
        kycStatus: userData.kycStatus || 'none',
        accountBlocked: userData.accountBlocked || false,
        createdAt: userData.createdAt,
      });
    }
  }

  return { success: true, results };
});

/**
 * Get detailed user information including wallet and recent transactions.
 */
exports.adminGetUserDetails = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  await verifyAdmin(context, 'support');

  const { targetUid } = data;
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid is required.');
  }

  // Get user document
  const userDoc = await db.collection('users').doc(targetUid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found.');
  }
  const userData = userDoc.data();

  // Get wallet
  const walletSnapshot = await db.collection('wallets')
    .where('userId', '==', targetUid)
    .limit(1)
    .get();

  let wallet = null;
  if (!walletSnapshot.empty) {
    const walletData = walletSnapshot.docs[0].data();
    wallet = {
      id: walletSnapshot.docs[0].id,
      balance: walletData.balance || 0,
      currency: walletData.currency || 'GHS',
    };
  }

  // Get recent transactions
  const txSnapshot = await db.collection('users').doc(targetUid)
    .collection('transactions')
    .orderBy('createdAt', 'desc')
    .limit(20)
    .get();

  const transactions = txSnapshot.docs.map(doc => {
    const txData = doc.data();
    return {
      id: doc.id,
      type: txData.type || '',
      amount: txData.amount || 0,
      currency: txData.currency || '',
      status: txData.status || '',
      description: txData.description || '',
      createdAt: txData.createdAt,
    };
  });

  // Get KYC documents
  const kycSnapshot = await db.collection('users').doc(targetUid)
    .collection('kyc')
    .get();

  const kycDocuments = kycSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
  }));

  return {
    success: true,
    user: {
      uid: targetUid,
      email: userData.email || '',
      fullName: userData.fullName || '',
      phoneNumber: userData.phoneNumber || '',
      kycStatus: userData.kycStatus || 'none',
      accountBlocked: userData.accountBlocked || false,
      accountBlockedBy: userData.accountBlockedBy || null,
      role: userData.role || null,
      createdAt: userData.createdAt,
      lastLoginAt: userData.lastLoginAt || null,
      countryCode: userData.countryCode || '',
      currencyCode: userData.currencyCode || '',
      profileImageUrl: userData.profileImageUrl || null,
      emailVerified: userData.emailVerified || false,
      phoneVerified: userData.phoneVerified || false,
    },
    wallet,
    transactions,
    kycDocuments,
  };
});

/**
 * Admin block account — blocks a user's account with admin authority.
 */
exports.adminBlockAccount = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin');

  const { targetUid, reason } = data;
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid is required.');
  }

  const userDoc = await db.collection('users').doc(targetUid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found.');
  }

  await db.collection('users').doc(targetUid).update({
    accountBlocked: true,
    accountBlockedBy: 'admin',
    accountBlockedReason: reason || 'Blocked by admin',
    accountBlockedAt: timestamps.serverTimestamp(),
    accountBlockedByUid: caller.uid,
  });

  await sendPushNotification(targetUid, {
    title: 'Account Blocked',
    body: 'Your account has been blocked by an administrator. Please contact support.',
    type: 'security',
    data: { action: 'account_blocked_by_admin' },
  });

  await auditLog({
    userId: caller.uid,
    operation: 'adminBlockAccount',
    result: 'success',
    metadata: { targetUid, reason: reason || 'No reason provided', callerRole: caller.role },
    ipHash: hashIp(context),
  });

  // Log admin activity
  await db.collection('admin_activity').add({
    uid: caller.uid,
    email: (await admin.auth().getUser(caller.uid)).email || 'unknown',
    role: caller.role,
    action: 'block_account',
    targetUserId: targetUid,
    targetInfo: userDoc.data().fullName || 'Unknown',
    details: reason || 'No reason provided',
    ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: 'Account blocked successfully.' };
});

/**
 * Admin unblock account — unblocks a user's account.
 */
exports.adminUnblockAccount = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin');

  const { targetUid } = data;
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid is required.');
  }

  const userDoc = await db.collection('users').doc(targetUid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found.');
  }

  await db.collection('users').doc(targetUid).update({
    accountBlocked: false,
    accountBlockedBy: admin.firestore.FieldValue.delete(),
    accountBlockedReason: admin.firestore.FieldValue.delete(),
    accountBlockedAt: admin.firestore.FieldValue.delete(),
    accountBlockedByUid: admin.firestore.FieldValue.delete(),
  });

  await sendPushNotification(targetUid, {
    title: 'Account Unblocked',
    body: 'Your account has been unblocked. You can now use all features.',
    type: 'security',
    data: { action: 'account_unblocked_by_admin' },
  });

  await auditLog({
    userId: caller.uid,
    operation: 'adminUnblockAccount',
    result: 'success',
    metadata: { targetUid, callerRole: caller.role },
    ipHash: hashIp(context),
  });

  // Log admin activity
  await db.collection('admin_activity').add({
    uid: caller.uid,
    email: (await admin.auth().getUser(caller.uid)).email || 'unknown',
    role: caller.role,
    action: 'unblock_account',
    targetUserId: targetUid,
    targetInfo: userDoc.data().fullName || 'Unknown',
    details: 'Account unblocked',
    ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: 'Account unblocked successfully.' };
});

/**
 * Admin update user email.
 */
exports.adminUpdateUserEmail = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_supervisor');

  const { targetUid, newEmail } = data;
  if (!targetUid || !newEmail) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid and newEmail are required.');
  }

  // Update in Firebase Auth
  await admin.auth().updateUser(targetUid, { email: newEmail });

  // Update in Firestore
  await db.collection('users').doc(targetUid).update({
    email: newEmail,
    emailUpdatedAt: timestamps.serverTimestamp(),
    emailUpdatedBy: caller.uid,
  });

  await auditLog({
    userId: caller.uid,
    operation: 'adminUpdateUserEmail',
    result: 'success',
    metadata: { targetUid, newEmail, callerRole: caller.role },
    ipHash: hashIp(context),
  });

  // Log admin activity
  await db.collection('admin_activity').add({
    uid: caller.uid,
    email: (await admin.auth().getUser(caller.uid)).email || 'unknown',
    role: caller.role,
    action: 'update_email',
    targetUserId: targetUid,
    details: `Email changed to ${newEmail}`,
    ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: 'Email updated successfully.' };
});

/**
 * Admin send recovery OTP to a user's phone number.
 */
exports.adminSendRecoveryOTP = functions
  .runWith({ secrets: [AT_API_KEY], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin');

  const { targetUid } = data;
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid is required.');
  }

  const userDoc = await db.collection('users').doc(targetUid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found.');
  }

  const userData = userDoc.data();
  const phoneNumber = userData.phoneNumber;
  if (!phoneNumber) {
    throw new functions.https.HttpsError('failed-precondition', 'User has no phone number on file.');
  }

  // Generate 6-digit OTP
  const otp = crypto.randomInt(100000, 999999).toString();
  const otpHash = crypto.createHash('sha256').update(otp).digest('hex');
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

  // Store OTP in Firestore
  await db.collection('recovery_otps').doc(targetUid).set({
    otpHash,
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    createdAt: timestamps.serverTimestamp(),
    createdBy: caller.uid,
    attempts: 0,
    verified: false,
  });

  // Send SMS via Africa's Talking
  try {
    const atCredentials = {
      apiKey: AT_API_KEY.value(),
      username: AT_USERNAME.value() || 'sandbox',
    };
    const AfricasTalking = require('africastalking')(atCredentials);
    const sms = AfricasTalking.SMS;

    await sms.send({
      to: [phoneNumber],
      message: `Your QR Wallet recovery code is: ${otp}. It expires in 10 minutes. Do not share this code with anyone.`,
    });

    logStructured(LOG_LEVELS.INFO, 'Recovery OTP sent via SMS', {
      targetUid,
      phoneNumber: phoneNumber.substring(0, 4) + '****',
      callerUid: caller.uid,
    });
  } catch (smsError) {
    logStructured(LOG_LEVELS.ERROR, 'Failed to send recovery OTP via SMS', {
      error: smsError.message,
      targetUid,
    });
    // H-04: SMS is now the only delivery mechanism. If it fails, surface
    // the error to the admin so they can retry. Previously the OTP was
    // returned in the response as a fallback — removed for insider-risk
    // reasons.
    throw new functions.https.HttpsError(
      'unavailable',
      'Failed to send recovery OTP via SMS. Please retry. If the problem persists, check SMS provider configuration.'
    );
  }

  await auditLog({
    userId: caller.uid,
    operation: 'adminSendRecoveryOTP',
    result: 'success',
    metadata: { targetUid, callerRole: caller.role },
    ipHash: hashIp(context),
  });

  // Log admin activity
  const maskedPhone = phoneNumber.substring(0, 4) + '****' + phoneNumber.substring(phoneNumber.length - 2);
  await db.collection('admin_activity').add({
    uid: caller.uid,
    email: (await admin.auth().getUser(caller.uid)).email || 'unknown',
    role: caller.role,
    action: 'send_recovery_otp',
    targetUserId: targetUid,
    details: `OTP sent to ${maskedPhone}`,
    ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  // H-04: OTP is NEVER returned to the admin. It's delivered only via SMS
  // to the user's phone. If SMS delivery fails, the admin should re-trigger
  // the send (logs will show the SMS failure), not have OTP displayed to
  // them. Support staff with the OTP value can impersonate users — this
  // was a critical insider-risk hole.
 return {
    success: true,
    message: 'Recovery OTP sent to user\'s phone via SMS. User should share the code they receive.',
    phoneNumber: maskedPhone,
    expiresInMinutes: 10,
  };
});

/**
 * Admin verify recovery OTP.
 */
exports.adminVerifyRecoveryOTP = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin');

  const { targetUid, otp } = data;
  if (!targetUid || !otp) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid and otp are required.');
  }

  const otpDoc = await db.collection('recovery_otps').doc(targetUid).get();
  if (!otpDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'No OTP found for this user. Please generate a new one.');
  }

  const otpData = otpDoc.data();

  // Check expiry
  if (otpData.expiresAt.toDate() < new Date()) {
    await db.collection('recovery_otps').doc(targetUid).delete();
    throw new functions.https.HttpsError('deadline-exceeded', 'OTP has expired. Please generate a new one.');
  }

  // Check attempts
  if (otpData.attempts >= 3) {
    await db.collection('recovery_otps').doc(targetUid).delete();
    throw new functions.https.HttpsError('resource-exhausted', 'Too many attempts. Please generate a new OTP.');
  }

  // Verify OTP
  const otpHash = crypto.createHash('sha256').update(otp).digest('hex');

  // Timing-safe comparison
  const expected = Buffer.from(otpData.otpHash, 'hex');
  const received = Buffer.from(otpHash, 'hex');

  if (expected.length !== received.length || !crypto.timingSafeEqual(expected, received)) {
    await db.collection('recovery_otps').doc(targetUid).update({
      attempts: admin.firestore.FieldValue.increment(1),
    });
    throw new functions.https.HttpsError('invalid-argument', 'Invalid OTP.');
  }

  // Mark as verified
  await db.collection('recovery_otps').doc(targetUid).update({
    verified: true,
    verifiedAt: timestamps.serverTimestamp(),
    verifiedBy: caller.uid,
  });

  await auditLog({
    userId: caller.uid,
    operation: 'adminVerifyRecoveryOTP',
    result: 'success',
    metadata: { targetUid, callerRole: caller.role },
    ipHash: hashIp(context),
  });

  // Log admin activity
  await db.collection('admin_activity').add({
    uid: caller.uid,
    email: (await admin.auth().getUser(caller.uid)).email || 'unknown',
    role: caller.role,
    action: 'verify_recovery_otp',
    targetUserId: targetUid,
    details: 'OTP verified successfully',
    ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: 'OTP verified successfully.' };
});

/**
 * List all admin/support users.
 */
exports.adminListAdmins = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  await verifyAdmin(context, 'admin_manager');

  // Read from admin_users (the registry of admins), not users (the registry of
  // all signed-up wallet users). admin_users is keyed by email; each doc has
  // {uid, email, role, createdAt, updatedAt} as written by adminPromoteUser /
  // adminDemoteUser / promoteSuperAdmin.
  const snapshot = await db.collection('admin_users')
    .where('role', 'in', ['super_admin', 'admin_manager', 'finance', 'admin_supervisor', 'admin', 'support', 'auditor', 'viewer'])
    .get();

  const admins = snapshot.docs.map(doc => {
    const data = doc.data();
    return {
      uid: data.uid || '',
      email: data.email || doc.id,
      role: data.role || '',
      updatedAt: data.updatedAt || null,
    };
  });

  return { success: true, admins };
});

/**
 * Look up a user's current role by email or UID.
 *
 * Used by the admin dashboard to display the target user's CURRENT role
 * before promote/demote actions, so the operator can see what they're
 * changing FROM. Permissive on not-found (returns {exists: false} rather
 * than throwing) so a typing-in-progress UI can render gracefully.
 *
 * Auth: requires admin or above (anyone managing users needs this info).
 *
 * Input: { targetEmail?: string, targetUid?: string }
 * Output: {
 *   exists: boolean,
 *   uid?: string,
 *   email?: string,
 *   role: string | null,    // from Firebase Auth custom claims
 *   isAdmin: boolean,        // true if role is in the 8-role hierarchy
 * }
 *
 * Ref: bundle commit 23b
 */
exports.adminLookupUserRole = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  await verifyAdmin(context, 'admin');

  const email = data.targetEmail ? String(data.targetEmail).trim().toLowerCase() : null;
  const uid = data.targetUid ? String(data.targetUid).trim() : null;

  if (!email && !uid) {
    throw new functions.https.HttpsError('invalid-argument',
      'Either targetEmail or targetUid is required.');
  }

  let userRecord;
  try {
    if (email) {
      userRecord = await admin.auth().getUserByEmail(email);
    } else {
      userRecord = await admin.auth().getUser(uid);
    }
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      return { exists: false, role: null, isAdmin: false };
    }
    throw new functions.https.HttpsError('internal',
      `Lookup failed: ${e.message}`);
  }

  const role = userRecord.customClaims?.role || null;
  const VALID_ADMIN_ROLES = ['viewer', 'auditor', 'support', 'admin',
    'admin_supervisor', 'finance', 'admin_manager', 'super_admin'];
  const isAdmin = role !== null && VALID_ADMIN_ROLES.includes(role);

  return {
    exists: true,
    uid: userRecord.uid,
    email: userRecord.email || null,
    role,
    isAdmin,
  };
});

/**
 * Get platform stats for admin dashboard.
 */
exports.adminGetStats = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  await verifyAdmin(context, 'auditor');

  // Total users
  const usersSnapshot = await db.collection('users').count().get();
  const totalUsers = usersSnapshot.data().count;

  // Total wallets
  const walletsSnapshot = await db.collection('wallets').count().get();
  const totalWallets = walletsSnapshot.data().count;

  // Blocked accounts
  const blockedSnapshot = await db.collection('users')
    .where('accountBlocked', '==', true)
    .count()
    .get();
  const blockedAccounts = blockedSnapshot.data().count;

  // KYC completed
  const kycSnapshot = await db.collection('users')
    .where('kycStatus', '==', 'completed')
    .count()
    .get();
  const kycCompleted = kycSnapshot.data().count;

  // Recent transactions (last 24 hours)
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const recentTxSnapshot = await db.collection('transactions')
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(oneDayAgo))
    .count()
    .get();
  const recentTransactions = recentTxSnapshot.data().count;

  // Flagged transactions
  const flaggedSnapshot = await db.collection('flagged_transactions')
    .count()
    .get();
  const flaggedTransactions = flaggedSnapshot.data().count;

  return {
    success: true,
    stats: {
      totalUsers,
      totalWallets,
      blockedAccounts,
      kycCompleted,
      recentTransactions,
      flaggedTransactions,
    },
  };
});

/**
 * Admin: Export all users for CSV download.
 */
exports.adminExportUsers = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin');

  try {
    const usersSnapshot = await db.collection('users').orderBy('createdAt', 'desc').limit(5000).get();
    const walletsSnapshot = await db.collection('wallets').get();

    // Build wallet lookup
    const walletMap = {};
    walletsSnapshot.docs.forEach(doc => {
      if (doc.id !== 'platform') {
        walletMap[doc.id] = doc.data();
      }
    });

    const users = usersSnapshot.docs.map(doc => {
      const u = doc.data();
      const w = walletMap[doc.id] || {};
      return {
        uid: doc.id,
        fullName: u.fullName || '',
        email: u.email || '',
        phoneNumber: u.phoneNumber || '',
        country: u.country || '',
        currency: u.currency || '',
        walletId: w.walletId || '',
        balance: w.balance || 0,
        kycStatus: u.kycStatus || 'not_started',
        kycCompleted: u.kycCompleted || false,
        accountBlocked: u.accountBlocked || false,
        createdAt: u.createdAt || '',
      };
    });

    await auditLog({
      userId: caller.uid,
      operation: 'adminExportUsers',
      result: 'success',
      metadata: { count: users.length },
      ipHash: hashIp(context),
    });

    return { success: true, users };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Export failed: ${error.message}`);
  }
});

/**
 * Admin: Log a login or logout event.
 * Called by the dashboard when an admin signs in or out.
 */
exports.adminLogActivity = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  // Modernized from manual 3-role check to verifyAdmin helper in Commit 13.
  // Previously hardcoded ['support', 'admin', 'super_admin'] — which locked
  // out admin_manager, admin_supervisor, finance, auditor, viewer roles.
  // verifyAdmin(context, 'support') accepts any role at level 3 or higher.
  await verifyAdmin(context, 'support');

  const uid = context.auth.uid;
  const { action, metadata } = data;

  if (!action || !['login', 'logout'].includes(action)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid action.');
  }

  // Get IP address
  const ip = context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown';
  const userAgent = context.rawRequest?.headers?.['user-agent'] || 'unknown';

  // Get admin info
  let email = 'unknown';
  let role = 'unknown';
  try {
    const userRecord = await admin.auth().getUser(uid);
    email = userRecord.email || 'unknown';
    role = userRecord.customClaims?.role || 'unknown';
  } catch (e) {
    // Ignore - just log with uid
  }

  await db.collection('admin_activity').add({
    uid,
    email,
    role,
    action,
    ip,
    userAgent,
    metadata: metadata || {},
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

/**
 * Admin: Get activity logs with filtering.
 * Support can only see their own logs. Admin/super_admin can see all.
 */
exports.adminGetActivityLogs = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'auditor');

  const { limit: queryLimit, filterUid, filterAction } = data || {};
  const fetchLimit = Math.min(queryLimit || 50, 200);

  let query = db.collection('admin_activity').orderBy('timestamp', 'desc');

  // Support can only see their own activity
  if (caller.role === 'support') {
    query = query.where('uid', '==', caller.uid);
  } else if (filterUid) {
    query = query.where('uid', '==', filterUid);
  }

  query = query.limit(fetchLimit);

  const snapshot = await query.get();
  const logs = snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    timestamp: doc.data().timestamp?.toDate?.()?.toISOString() || null,
  }));

  return { success: true, logs };
});

/**
 * Admin: Get audit logs (admin and super_admin only).
 */
exports.adminGetAuditLogs = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'auditor');

  const { limit: queryLimit, filterUserId, filterOperation } = data || {};
  const fetchLimit = Math.min(queryLimit || 50, 200);

  let query = db.collection('audit_logs').orderBy('timestamp', 'desc');

  if (filterUserId) {
    query = query.where('userId', '==', filterUserId);
  }

  query = query.limit(fetchLimit);

  const snapshot = await query.get();
  const logs = snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    timestamp: doc.data().timestamp?.toDate?.()?.toISOString() || null,
  }));

  return { success: true, logs };
});

// ============================================================
// PLATFORM WALLET / REVENUE
// ============================================================

/**
 * Admin: Get platform wallet overview — total revenue, per-currency balances.
 */
exports.adminGetPlatformWallet = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'finance');

  try {
    // Get platform wallet document
    const platformDoc = await db.collection('wallets').doc('platform').get();
    if (!platformDoc.exists) {
      return { success: true, wallet: null, balances: [], message: 'Platform wallet not found.' };
    }

    const walletData = platformDoc.data();

    // Get per-currency balances
    const balancesSnapshot = await db.collection('wallets').doc('platform')
      .collection('balances')
      .orderBy('amount', 'desc')
      .get();

    const balances = balancesSnapshot.docs.map(doc => ({
      currency: doc.id,
      ...doc.data(),
      lastTransactionAt: doc.data().lastTransactionAt?.toDate?.()?.toISOString() || null,
      updatedAt: doc.data().updatedAt?.toDate?.()?.toISOString() || null,
    }));

    return {
      success: true,
      wallet: {
        totalBalanceUSD: walletData.totalBalanceUSD || 0,
        totalTransactions: walletData.totalTransactions || 0,
        totalFeesCollected: walletData.totalFeesCollected || 0,
        walletId: walletData.walletId,
        name: walletData.name,
        isActive: walletData.isActive,
        updatedAt: walletData.updatedAt?.toDate?.()?.toISOString() || null,
      },
      balances,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to get platform wallet: ${error.message}`);
  }
});

/**
 * Admin: Get platform transfer limits (perTransferUSD, dailyUSD).
 * Reads from app_config/platform_limits. Returns defaults if doc missing.
 *
 * Required by RevenuePage to display caps in the bank transfer form.
 *
 * Ref: D-08, L-35
 */
exports.adminGetPlatformLimits = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  await verifyAdmin(context, 'finance');
  const doc = await db.collection('app_config').doc('platform_limits').get();
  if (!doc.exists) {
    return { perTransferUSD: 50000, dailyUSD: 100000 };
  }
  const d = doc.data();
  return {
    perTransferUSD: d.perTransferUSD || 50000,
    dailyUSD: d.dailyUSD || 100000,
  };
});

/**
 * Admin: Get platform fee history with pagination.
 */
exports.adminGetFeeHistory = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'finance');

  const { limit: queryLimit, currency: filterCurrency } = data || {};
  const fetchLimit = Math.min(queryLimit || 50, 200);

  try {
    let query = db.collection('wallets').doc('platform')
      .collection('fees')
      .orderBy('createdAt', 'desc');

    if (filterCurrency) {
      query = query.where('currency', '==', filterCurrency);
    }

    query = query.limit(fetchLimit);

    const snapshot = await query.get();
    const fees = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
    }));

    return { success: true, fees };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to get fee history: ${error.message}`);
  }
});

/**
 * Admin: Get platform withdrawal history.
 */
exports.adminGetPlatformWithdrawals = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'finance');

  const { limit: queryLimit } = data || {};
  const fetchLimit = Math.min(queryLimit || 50, 200);

  try {
    const snapshot = await db.collection('wallets').doc('platform')
      .collection('withdrawals')
      .orderBy('createdAt', 'desc')
      .limit(fetchLimit)
      .get();

    const withdrawals = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
    }));

    return { success: true, withdrawals };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to get withdrawals: ${error.message}`);
  }
});

// ============================================================
// ADMIN BANK TRANSFERS
// ============================================================

/**
 * Admin: Get list of banks for a country (reuses Paystack API).
 */
exports.adminGetBanks = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  await verifyAdmin(context, 'admin');

  const country = data.country || 'nigeria';

  try {
    const response = await paystackRequest('GET', `/bank?country=${country}`);
    if (!response.status) {
      throw new functions.https.HttpsError('internal', 'Failed to fetch banks.');
    }

    return {
      success: true,
      banks: response.data.map(bank => ({
        name: bank.name,
        code: bank.code,
        type: bank.type,
        currency: bank.currency,
      })),
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to get banks: ${error.message}`);
  }
});

/**
 * Admin: Verify a bank account via Paystack.
 */
exports.adminVerifyBankAccount = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  await verifyAdmin(context, 'admin');

  const { accountNumber, bankCode } = data;
  if (!accountNumber || !bankCode) {
    throw new functions.https.HttpsError('invalid-argument', 'Account number and bank code are required.');
  }

  try {
    const response = await paystackRequest('GET', `/bank/resolve?account_number=${accountNumber}&bank_code=${bankCode}`);
    if (!response.status) {
      return { success: false, error: 'Could not verify account.' };
    }

    return {
      success: true,
      accountName: response.data.account_name,
      accountNumber: response.data.account_number,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Verification failed: ${error.message}`);
  }
});

/**
 * Admin: Initiate a real bank transfer from platform wallet via Paystack.
 * Only super_admin can initiate transfers.
 */
exports.adminInitiateTransfer = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'super_admin');

  const { amount, currency, bankCode, accountNumber, accountName, purpose, notes, idempotencyKey } = data;

  // D-07: Idempotency key required (prevents double-submit)
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument',
      'idempotencyKey is required (min 16 chars). Generate a UUID v4 client-side and pass it.');
  }

  // D-06: Rate limit
  const rateLimitOk = await checkRateLimitPersistent(caller.uid, 'adminInitiateTransfer');
  if (!rateLimitOk) {
    throw new functions.https.HttpsError('resource-exhausted',
      RATE_LIMITS.adminInitiateTransfer.message);
  }

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Valid amount is required.');
  }
  if (!currency) {
    throw new functions.https.HttpsError('invalid-argument', 'Currency is required.');
  }
  if (!bankCode || !accountNumber || !accountName) {
    throw new functions.https.HttpsError('invalid-argument', 'Bank details are required.');
  }
  if (!purpose) {
    throw new functions.https.HttpsError('invalid-argument', 'Purpose is required.');
  }

  // D-08: Amount caps. Read limits from Firestore (configurable without redeploy).
  const limitsDoc = await db.collection('app_config').doc('platform_limits').get();
  const DEFAULT_PER_TRANSFER_USD = 50000;
  const DEFAULT_DAILY_USD = 100000;
  const perTransferUSD = limitsDoc.exists ? (limitsDoc.data().perTransferUSD || DEFAULT_PER_TRANSFER_USD) : DEFAULT_PER_TRANSFER_USD;
  const dailyUSD = limitsDoc.exists ? (limitsDoc.data().dailyUSD || DEFAULT_DAILY_USD) : DEFAULT_DAILY_USD;

  // Compute USD equivalent NOW (before caps check). Reuses logic from later in function.
  const ratesDocForCaps = await db.collection('app_config').doc('exchange_rates').get();
  const ratesForCaps = ratesDocForCaps.exists ? ratesDocForCaps.data().rates : {};
  const exchangeRateForCaps = ratesForCaps[currency] || 1;
  const amountInUSDForCaps = amount / exchangeRateForCaps;

  // Per-transfer cap
  if (amountInUSDForCaps > perTransferUSD) {
    throw new functions.https.HttpsError('failed-precondition',
      `Transfer amount $${amountInUSDForCaps.toFixed(2)} USD exceeds per-transfer cap of $${perTransferUSD.toFixed(2)} USD. ` +
      `Adjust caps via app_config/platform_limits or split the transfer.`);
  }

  // Daily cap (per super_admin, rolling 24h window)
  const twentyFourHoursAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
  const recentWithdrawalsSnap = await db.collection('wallets').doc('platform')
    .collection('withdrawals')
    .where('withdrawnBy', '==', caller.uid)
    .where('createdAt', '>=', twentyFourHoursAgo)
    .get();
  const dailyTotalUSD = recentWithdrawalsSnap.docs.reduce((sum, doc) => {
    const d = doc.data();
    if (d.refunded === true) return sum;
    return sum + (d.usdEquivalent || 0);
  }, 0);

  if (dailyTotalUSD + amountInUSDForCaps > dailyUSD) {
    throw new functions.https.HttpsError('failed-precondition',
      `Transfer would exceed your daily cap. ` +
      `Used today: $${dailyTotalUSD.toFixed(2)} USD. ` +
      `Requested: $${amountInUSDForCaps.toFixed(2)} USD. ` +
      `Daily cap: $${dailyUSD.toFixed(2)} USD. ` +
      `Available headroom: $${(dailyUSD - dailyTotalUSD).toFixed(2)} USD.`);
  }

  // D-07: Wrap main body in idempotency to prevent double-submission
  return withIdempotency(idempotencyKey, 'adminInitiateTransfer', caller.uid, async () => {
  try {
    // Verify sufficient platform balance
    const balanceDoc = await db.collection('wallets').doc('platform')
      .collection('balances').doc(currency).get();

    if (!balanceDoc.exists) {
      throw new functions.https.HttpsError('failed-precondition', `No balance found for ${currency}.`);
    }

    const currentBalance = balanceDoc.data().amount || 0;
    if (currentBalance < amount) {
      throw new functions.https.HttpsError('failed-precondition',
        `Insufficient ${currency} balance. Available: ${currentBalance.toFixed(2)}, Requested: ${amount.toFixed(2)}`);
    }

    // Get exchange rate for USD equivalent
    const ratesDoc = await db.collection('app_config').doc('exchange_rates').get();
    const rates = ratesDoc.exists ? ratesDoc.data().rates : {};
    const exchangeRate = rates[currency] || 1;
    const amountInUSD = amount / exchangeRate;

    // Get caller email before transaction
    const callerEmail = (await admin.auth().getUser(caller.uid)).email || 'unknown';

    // Step 1: Create transfer recipient on Paystack
    const recipientResponse = await paystackRequest('POST', '/transferrecipient', {
      type: 'nuban',
      name: accountName,
      account_number: accountNumber,
      bank_code: bankCode,
      currency: currency,
    });

    if (!recipientResponse.status) {
      throw new functions.https.HttpsError('internal', 'Failed to create transfer recipient on Paystack.');
    }

    const recipientCode = recipientResponse.data.recipient_code;

    // Step 2: Deduct balance FIRST (atomic)
    const amountInSmallestUnit = Math.round(amount * 100);
    const reference = `PLT-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;

    const withdrawalRef = db.collection('wallets').doc('platform')
      .collection('withdrawals').doc(reference);

    await db.runTransaction(async (transaction) => {
      const freshBalance = await transaction.get(
        db.collection('wallets').doc('platform').collection('balances').doc(currency)
      );
      const freshAmount = freshBalance.data()?.amount || 0;

      if (freshAmount < amount) {
        throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance (concurrent update).');
      }

      transaction.update(
        db.collection('wallets').doc('platform').collection('balances').doc(currency),
        {
          amount: admin.firestore.FieldValue.increment(-amount),
          usdEquivalent: admin.firestore.FieldValue.increment(-amountInUSD),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }
      );

      transaction.update(db.collection('wallets').doc('platform'), {
        totalBalanceUSD: admin.firestore.FieldValue.increment(-amountInUSD),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(withdrawalRef, {
        id: reference,
        type: 'bank_transfer',
        amount,
        currency,
        usdEquivalent: amountInUSD,
        exchangeRate,
        purpose,
        notes: notes || null,
        bankCode,
        accountNumber,
        accountName,
        recipientCode,
        paystackReference: reference,
        status: 'pending',
        withdrawnBy: caller.uid,
        withdrawnByEmail: callerEmail,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Step 3: NOW initiate Paystack transfer (balance already deducted)
    let transferCode = null;
    let transferStatus = 'pending';
    try {
      const transferResponse = await paystackRequest('POST', '/transfer', {
        source: 'balance',
        amount: amountInSmallestUnit,
        recipient: recipientCode,
        reason: `Platform withdrawal: ${purpose}`,
        reference: reference,
      });

      if (transferResponse.status) {
        transferCode = transferResponse.data.transfer_code;
        transferStatus = transferResponse.data.status;
      }

      // Map Paystack response status -> our internal withdrawal status:
      //   'success' -> 'completed'    (Paystack finished the transfer, no OTP needed)
      //   'otp'     -> 'pending_otp'  (Paystack is holding, waiting for us to submit OTP)
      //   other     -> 'pending'      (queued / processing / unknown; check paystackStatus for detail)
      let internalStatus;
      if (transferStatus === 'success') {
        internalStatus = 'completed';
      } else if (transferStatus === 'otp') {
        internalStatus = 'pending_otp';
      } else {
        internalStatus = 'pending';
      }

      await withdrawalRef.update({
        transferCode: transferCode,
        paystackStatus: transferStatus,
        status: internalStatus,
      });
    } catch (transferError) {
      // Paystack failed — refund the platform balance
      logError('Paystack transfer failed, refunding platform balance', { error: transferError.message, reference });

      await db.runTransaction(async (transaction) => {
        transaction.update(
          db.collection('wallets').doc('platform').collection('balances').doc(currency),
          {
            amount: admin.firestore.FieldValue.increment(amount),
            usdEquivalent: admin.firestore.FieldValue.increment(amountInUSD),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }
        );
        transaction.update(db.collection('wallets').doc('platform'), {
          totalBalanceUSD: admin.firestore.FieldValue.increment(amountInUSD),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await withdrawalRef.update({
        status: 'failed',
        failureReason: transferError.message,
        refunded: true,
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      throw new functions.https.HttpsError('internal', `Paystack transfer failed: ${transferError.message}. Balance has been refunded.`);
    }

    // Audit log
    await auditLog({
      userId: caller.uid,
      operation: 'adminInitiateTransfer',
      result: 'success',
      amount,
      currency,
      metadata: { reference, purpose, bankCode, accountNumber, accountName, transferStatus },
      ipHash: hashIp(context),
    });

    // Admin activity log
    await db.collection('admin_activity').add({
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      action: 'bank_transfer',
      details: `Transferred ${currency} ${amount.toFixed(2)} ($${amountInUSD.toFixed(2)}) to ${accountName} at ${bankCode} for: ${purpose}`,
      ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      otpRequired: transferStatus === 'otp',
      transfer: {
        reference,
        transferCode,
        status: transferStatus,
        amount,
        currency,
        usdEquivalent: amountInUSD,
        accountName,
        purpose,
      },
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Transfer failed: ${error.message}`);
  }
  }); // end withIdempotency wrapper
});

/**
 * Admin: Propose a platform bank transfer (finance entry point for dual-sig).
 *
 * Creates a proposal doc in platform_transfer_proposals with status='proposed'.
 * Does NOT move money. Money movement happens when admin_manager approves
 * via adminApproveTransfer (which handles the Paystack flow in a future commit).
 *
 * Dual-signature flow:
 *   1. finance -> adminProposeTransfer (creates proposal)
 *   2. admin_manager -> adminApproveTransfer (approves + executes Paystack transfer)
 *   3. super_admin -> adminFinalizeTransfer (enters Paystack OTP if required)
 *
 * Security:
 *   - finance role or higher (verifyAdmin)
 *   - Rate limited (10 proposals/hour per caller)
 *   - Idempotency required
 *   - Finance daily cap check (financeDailyUSD from app_config/platform_limits)
 *   - Per-transfer cap (perTransferUSD from app_config/platform_limits)
 *
 * Ref: Phase 2a commit 2 (human-pair)
 */
exports.adminProposeTransfer = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'finance');

  // Check if caller is in blocked_finance_users (has overdue evidence)
  const blockedDoc = await db.collection('blocked_finance_users').doc(caller.uid).get();
  if (blockedDoc.exists) {
    const blockData = blockedDoc.data();
    throw new functions.https.HttpsError('failed-precondition',
      `You are blocked from new proposals due to overdue evidence. ` +
      `Close ${(blockData.openOverdueProposals || []).length} open proposals via the admin dashboard first.`);
  }

  const { amount, currency, bankCode, accountNumber, accountName, purpose, notes, idempotencyKey, priorityFlag } = data;

  // Idempotency key required
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument',
      'idempotencyKey is required (min 16 chars). Generate a UUID v4 client-side and pass it.');
  }

  // Rate limit
  const rateLimitOk = await checkRateLimitPersistent(caller.uid, 'adminProposeTransfer');
  if (!rateLimitOk) {
    throw new functions.https.HttpsError('resource-exhausted',
      RATE_LIMITS.adminProposeTransfer.message);
  }

  // Input validation
  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Valid amount is required.');
  }
  if (!currency) {
    throw new functions.https.HttpsError('invalid-argument', 'Currency is required.');
  }
  if (!bankCode || !accountNumber || !accountName) {
    throw new functions.https.HttpsError('invalid-argument', 'Bank details are required.');
  }
  if (!purpose || typeof purpose !== 'string' || purpose.length < 5) {
    throw new functions.https.HttpsError('invalid-argument', 'Purpose is required (min 5 chars).');
  }
  if (priorityFlag !== undefined && typeof priorityFlag !== 'boolean') {
    throw new functions.https.HttpsError('invalid-argument', 'priorityFlag must be a boolean if provided.');
  }

  // Read caps from app_config/platform_limits
  const limitsDoc = await db.collection('app_config').doc('platform_limits').get();
  const DEFAULT_PER_TRANSFER_USD = 50000;
  const DEFAULT_FINANCE_DAILY_USD = 100000;
  const perTransferUSD = limitsDoc.exists ? (limitsDoc.data().perTransferUSD || DEFAULT_PER_TRANSFER_USD) : DEFAULT_PER_TRANSFER_USD;
  const financeDailyUSD = limitsDoc.exists ? (limitsDoc.data().financeDailyUSD || DEFAULT_FINANCE_DAILY_USD) : DEFAULT_FINANCE_DAILY_USD;

  // Compute USD equivalent
  const ratesDoc = await db.collection('app_config').doc('exchange_rates').get();
  const rates = ratesDoc.exists ? ratesDoc.data().rates : {};
  const exchangeRate = rates[currency] || 1;
  const amountInUSD = amount / exchangeRate;

  // Per-transfer cap
  if (amountInUSD > perTransferUSD) {
    throw new functions.https.HttpsError('failed-precondition',
      `Transfer amount $${amountInUSD.toFixed(2)} USD exceeds per-transfer cap of $${perTransferUSD.toFixed(2)} USD.`);
  }

  // Finance daily cap (per finance user, rolling 24h, based on proposals created)
  const twentyFourHoursAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
  const recentProposalsSnap = await db.collection('platform_transfer_proposals')
    .where('proposedBy.uid', '==', caller.uid)
    .where('proposedAt', '>=', twentyFourHoursAgo)
    .get();

  const TERMINAL_NON_CONSUMING = new Set(['rejected', 'cancelled', 'expired']);
  const dailyTotalUSD = recentProposalsSnap.docs.reduce((sum, doc) => {
    const d = doc.data();
    if (TERMINAL_NON_CONSUMING.has(d.status)) return sum;
    return sum + (d.usdEquivalent || 0);
  }, 0);

  if (dailyTotalUSD + amountInUSD > financeDailyUSD) {
    throw new functions.https.HttpsError('resource-exhausted',
      `Transfer would exceed your daily proposal cap. ` +
      `Used today: $${dailyTotalUSD.toFixed(2)} USD. ` +
      `Requested: $${amountInUSD.toFixed(2)} USD. ` +
      `Daily cap: $${financeDailyUSD.toFixed(2)} USD. ` +
      `Available headroom: $${(financeDailyUSD - dailyTotalUSD).toFixed(2)} USD.`);
  }

  // Wrap main body in idempotency
  return withIdempotency(idempotencyKey, 'adminProposeTransfer', caller.uid, async () => {
    try {
      // Get caller identity
      const callerUser = await admin.auth().getUser(caller.uid);
      const callerEmail = callerUser.email || 'unknown';
      const callerDisplayName = callerUser.displayName || callerEmail;

      // Generate proposal ID
      const proposalId = `PLT-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
      const proposalRef = db.collection('platform_transfer_proposals').doc(proposalId);

      // expiresAt = now + 15 min
      const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 15 * 60 * 1000);

      // Write proposal doc
      await proposalRef.set({
        proposalId,
        status: 'proposed',

        // Money
        amount,
        currency,
        usdEquivalent: amountInUSD,
        exchangeRate,

        // Recipient
        bankCode,
        accountNumber,
        accountName,

        // Description
        purpose,
        notes: notes || null,
        priorityFlag: priorityFlag === true,

        // Stage: proposed
        proposedBy: {
          uid: caller.uid,
          email: callerEmail,
          role: caller.role,
          displayName: callerDisplayName,
        },
        proposedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
        idempotencyKey,

        // Future stages — null until transitions happen
        approvedBy: null,
        approvedAt: null,
        approvalIdempotencyKey: null,
        rejectedBy: null,
        rejectedAt: null,
        rejectionReason: null,
        cancelledBy: null,
        cancelledAt: null,
        cancelReason: null,
        recipientCode: null,
        transferCode: null,
        paystackStatus: null,
        otpFailedAttempts: null,
        otpExpiresAt: null,
        completedBy: null,
        completedAt: null,

        // Emergency flag (false for standard proposals)
        emergency: false,
        emergencyReason: null,
        emergencyInvokedBy: null,
      });

      // Audit log
      await auditLog({
        userId: caller.uid,
        operation: 'adminProposeTransfer',
        result: 'success',
        amount,
        currency,
        metadata: { proposalId, purpose, bankCode, accountNumber, accountName, usdEquivalent: amountInUSD },
        ipHash: hashIp(context),
      });

      // Admin activity log
      await db.collection('admin_activity').add({
        uid: caller.uid,
        email: callerEmail,
        role: caller.role,
        action: 'propose_transfer',
        details: `Proposed transfer ${proposalId}: ${currency} ${amount.toFixed(2)} ($${amountInUSD.toFixed(2)}) to ${accountName} at ${bankCode} for: ${purpose}`,
        ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify managers of new proposal
      const managersSnap = await db.collection('admin_users')
        .where('role', '==', 'admin_manager')
        .get();
      for (const mgr of managersSnap.docs) {
        await sendProposalEmail({
          to: mgr.id,
          toName: mgr.data().displayName || null,
          subject: `Approval needed — ${amount} ${currency} proposal from ${callerDisplayName}`,
          htmlBody: `<p>A new platform transfer proposal requires your review.</p>
<p><strong>Amount:</strong> ${amount} ${currency} (~ $${amountInUSD.toFixed(2)} USD)<br>
<strong>Recipient:</strong> ${accountName} — ${bankCode} — ${accountNumber}<br>
<strong>Purpose:</strong> ${purpose}<br>
<strong>Proposed by:</strong> ${callerDisplayName} &lt;${callerEmail}&gt;<br>
<strong>Auto-expires:</strong> 15 minutes from submission</p>
<p>Please log in to the admin dashboard to review and approve or reject.</p>
<p>— QR Wallet Admin</p>`,
          textBody: `New proposal ${proposalId}: ${amount} ${currency} to ${accountName}. Auto-expires in 15 minutes. Log in to review.`,
          relatedTo: `proposal:${proposalId}`,
        });
      }

      return {
        success: true,
        proposalId,
        status: 'proposed',
        expiresAt: expiresAt.toMillis(),
        amount,
        currency,
        usdEquivalent: amountInUSD,
      };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      logError('adminProposeTransfer failed', { uid: caller.uid, error: error.message });
      throw new functions.https.HttpsError('internal', `Proposal failed: ${error.message}`);
    }
  });
});

/**
 * Admin: Finalize or cancel a pending_otp platform transfer.
 *
 * Two actions:
 *   action='finalize': submit OTP to Paystack to complete the transfer
 *   action='cancel': abandon the transfer and refund the platform balance
 *
 * Q-05 decision: 3 wrong OTP attempts trigger auto-cancel + refund.
 *
 * Security:
 *   - super_admin only (verifyAdmin)
 *   - Rate limited (10 attempts/hour per admin)
 *   - Idempotency required
 *   - Failed attempt tracking on the withdrawal doc
 *
 * Ref: L-35, Q-05, D-06, D-07
 */
exports.adminFinalizeTransfer = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'super_admin');

  const { action, reference, transferCode, otp, idempotencyKey } = data;

  // Validate action
  if (!['finalize', 'cancel'].includes(action)) {
    throw new functions.https.HttpsError('invalid-argument',
      'action must be "finalize" or "cancel"');
  }

  // Validate reference
  if (!reference || typeof reference !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'reference is required');
  }

  // Validate idempotency key (D-07)
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument',
      'idempotencyKey is required (min 16 chars)');
  }

  // Action-specific validation
  if (action === 'finalize') {
    if (!transferCode || !otp) {
      throw new functions.https.HttpsError('invalid-argument',
        'transferCode and otp are required for finalize action');
    }
  }

  // D-06: Rate limit
  const allowed = await checkRateLimitPersistent(caller.uid, 'adminFinalizeTransfer');
  if (!allowed) {
    throw new functions.https.HttpsError('resource-exhausted',
      RATE_LIMITS.adminFinalizeTransfer.message);
  }

  return withIdempotency(idempotencyKey, 'adminFinalizeTransfer', caller.uid, async () => {
    const withdrawalRef = db.collection('wallets').doc('platform')
      .collection('withdrawals').doc(reference);

    const withdrawalDoc = await withdrawalRef.get();
    if (!withdrawalDoc.exists) {
      throw new functions.https.HttpsError('not-found',
        `Withdrawal ${reference} not found`);
    }

    const wd = withdrawalDoc.data();

    // Validate state — must be pending_otp
    if (wd.status !== 'pending_otp') {
      throw new functions.https.HttpsError('failed-precondition',
        `Withdrawal status is '${wd.status}', expected 'pending_otp'. ` +
        `Cannot ${action} a transfer that is not awaiting OTP confirmation.`);
    }

    // Get caller email for audit
    const callerEmail = (await admin.auth().getUser(caller.uid)).email || 'unknown';

    // ====== ACTION: CANCEL ======
    if (action === 'cancel') {
      return await cancelTransfer(
        withdrawalRef, wd, reference, caller, callerEmail, context,
        'manual_cancel'
      );
    }

    // ====== ACTION: FINALIZE ======

    // Submit OTP to Paystack
    let otpResponse;
    try {
      otpResponse = await paystackRequest('POST', '/transfer/finalize_transfer', {
        transfer_code: transferCode,
        otp: otp,
      });
      logInfo('Paystack adminFinalizeTransfer response', {
        reference, status: otpResponse.status
      });
    } catch (paystackError) {
      logError('Paystack adminFinalizeTransfer call failed', {
        reference,
        error: paystackError.message,
      });
      throw new functions.https.HttpsError('internal',
        `Paystack call failed: ${paystackError.message}`);
    }

    // OTP succeeded
    if (otpResponse.status === true) {
      await withdrawalRef.update({
        status: 'completed',
        otpVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        completedBy: caller.uid,
        completedByEmail: callerEmail,
        otpFailedAttempts: admin.firestore.FieldValue.delete(),
      });

      // Audit log
      await auditLog({
        userId: caller.uid,
        operation: 'adminFinalizeTransfer',
        result: 'success',
        amount: wd.amount,
        currency: wd.currency,
        metadata: { reference, action: 'finalize' },
        ipHash: hashIp(context),
      });

      // Admin activity log
      await db.collection('admin_activity').add({
        uid: caller.uid,
        email: callerEmail,
        role: caller.role,
        action: 'transfer_finalize',
        details: `Finalized transfer ${reference} via OTP`,
        ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        action: 'finalize',
        status: 'completed',
        reference,
        message: 'Transfer completed successfully.',
      };
    }

    // OTP FAILED — track attempts (Q-05: 3 strikes)
    const previousAttempts = wd.otpFailedAttempts || 0;
    const newAttempts = previousAttempts + 1;
    const MAX_ATTEMPTS = 3;

    await withdrawalRef.update({
      otpFailedAttempts: newAttempts,
      lastOtpAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Audit failed attempt
    await auditLog({
      userId: caller.uid,
      operation: 'adminFinalizeTransfer',
      result: 'failure',
      metadata: {
        reference,
        action: 'finalize',
        attempt: newAttempts,
        paystackMessage: otpResponse.message || 'OTP rejected',
      },
      ipHash: hashIp(context),
    });

    if (newAttempts >= MAX_ATTEMPTS) {
      // Auto-cancel and refund
      logWarning('adminFinalizeTransfer: max OTP attempts reached, auto-cancelling', {
        reference, attempts: newAttempts,
      });

      return await cancelTransfer(
        withdrawalRef, wd, reference, caller, callerEmail, context,
        'auto_cancelled_max_otp_attempts'
      );
    }

    // Still has attempts left — return failure with attempt count
    const remaining = MAX_ATTEMPTS - newAttempts;
    return {
      success: false,
      action: 'finalize',
      status: 'pending_otp',
      reference,
      attemptsUsed: newAttempts,
      attemptsRemaining: remaining,
      message: `OTP rejected. ${remaining} attempt${remaining === 1 ? '' : 's'} remaining before auto-cancel.`,
      paystackMessage: otpResponse.message || 'OTP verification failed',
    };
  });
});

/**
 * Internal helper for adminFinalizeTransfer cancellation path.
 * Refunds platform balance atomically and marks withdrawal as cancelled.
 *
 * @param {DocumentReference} withdrawalRef
 * @param {Object} wd - withdrawal data
 * @param {string} reference
 * @param {Object} caller - { uid, role }
 * @param {string} callerEmail
 * @param {Object} context - CF context for IP logging
 * @param {string} cancelReason - 'manual_cancel' or 'auto_cancelled_max_otp_attempts'
 */
async function cancelTransfer(withdrawalRef, wd, reference, caller, callerEmail, context, cancelReason) {
  // Atomic refund of platform balance
  await db.runTransaction(async (transaction) => {
    const balanceRef = db.collection('wallets').doc('platform')
      .collection('balances').doc(wd.currency);

    transaction.update(balanceRef, {
      amount: admin.firestore.FieldValue.increment(wd.amount),
      usdEquivalent: admin.firestore.FieldValue.increment(wd.usdEquivalent),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(db.collection('wallets').doc('platform'), {
      totalBalanceUSD: admin.firestore.FieldValue.increment(wd.usdEquivalent),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(withdrawalRef, {
      status: 'cancelled',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy: caller.uid,
      cancelledByEmail: callerEmail,
      cancelReason: cancelReason,
      refunded: true,
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // Audit log
  await auditLog({
    userId: caller.uid,
    operation: 'adminFinalizeTransfer',
    result: 'success',
    amount: wd.amount,
    currency: wd.currency,
    metadata: {
      reference,
      action: 'cancel',
      cancelReason,
    },
    ipHash: hashIp(context),
  });

  // Admin activity log
  await db.collection('admin_activity').add({
    uid: caller.uid,
    email: callerEmail,
    role: caller.role,
    action: 'transfer_cancel',
    details: `Cancelled transfer ${reference} (${cancelReason}). Refunded ${wd.currency} ${wd.amount.toFixed(2)} to platform balance.`,
    ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    action: 'cancel',
    status: 'cancelled',
    reference,
    refundedAmount: wd.amount,
    currency: wd.currency,
    reason: cancelReason,
    message: cancelReason === 'auto_cancelled_max_otp_attempts'
      ? 'Maximum OTP attempts reached. Transfer cancelled and balance refunded.'
      : 'Transfer cancelled and balance refunded.',
  };
}

// ============================================================
// DUAL-SIG PLATFORM TRANSFER PROPOSALS (Phase 2a)
// ============================================================

/**
 * Admin: Approve a pending platform transfer proposal.
 * Only admin_manager (level 7) and above can approve.
 * Updates proposal status from 'proposed' to 'approved'.
 * Does NOT execute Paystack transfer — that happens in a separate step.
 *
 * Ref: Phase 2a agent commit 2/6
 */
exports.adminApproveTransfer = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_manager');

  const { proposalId, idempotencyKey, approvalNote, checklistConfirmations } = data || {};

  // Input validation
  if (!proposalId || typeof proposalId !== 'string' || !proposalId.startsWith('PLT-')) {
    throw new functions.https.HttpsError('invalid-argument', 'proposalId is required and must start with "PLT-".');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey is required and must be at least 16 characters.');
  }
  if (!Array.isArray(checklistConfirmations) || checklistConfirmations.length !== 4) {
    throw new functions.https.HttpsError('invalid-argument',
      'checklistConfirmations is required — must be an array of exactly 4 confirmation objects.');
  }
  const REQUIRED_CHECKLIST_ITEMS = [
    'amount_verified',
    'recipient_verified',
    'purpose_approved',
    'funds_available',
  ];
  for (const required of REQUIRED_CHECKLIST_ITEMS) {
    const match = checklistConfirmations.find(c => c && c.item === required && c.confirmed === true);
    if (!match) {
      throw new functions.https.HttpsError('invalid-argument',
        `Missing checklist confirmation for '${required}'. All 4 items must be confirmed.`);
    }
  }

  // Rate limit
  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminApproveTransfer');
  if (!withinLimit) {
    throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminApproveTransfer.message);
  }

  try {
    const proposalRef = db.collection('platform_transfer_proposals').doc(proposalId);
    const proposalSnap = await proposalRef.get();

    if (!proposalSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Proposal ${proposalId} not found.`);
    }

    const proposal = proposalSnap.data();

    if (proposal.status !== 'proposed') {
      throw new functions.https.HttpsError('failed-precondition',
        `Proposal is not in 'proposed' state (current: ${proposal.status}). Cannot approve.`);
    }

    const now = Date.now();
    const expiresAtMs = proposal.expiresAt && proposal.expiresAt.toMillis ? proposal.expiresAt.toMillis() : 0;
    if (expiresAtMs <= now) {
      throw new functions.https.HttpsError('failed-precondition', 'Proposal has expired. Ask finance to re-submit.');
    }

    // Manager daily cap check
    const limitsDoc = await db.collection('app_config').doc('platform_limits').get();
    const managerDailyUSD = limitsDoc.exists ? (limitsDoc.data().managerDailyUSD || 100000) : 100000;

    const startOfTodayUTC = new Date();
    startOfTodayUTC.setUTCHours(0, 0, 0, 0);
    const startOfTodayTimestamp = admin.firestore.Timestamp.fromDate(startOfTodayUTC);

    const todayApprovalsSnap = await db.collection('platform_transfer_proposals')
      .where('approvedBy.uid', '==', caller.uid)
      .where('approvedAt', '>=', startOfTodayTimestamp)
      .get();

    const dailyApprovedUSD = todayApprovalsSnap.docs.reduce((sum, doc) => {
      return sum + (doc.data().usdEquivalent || 0);
    }, 0);

    if (dailyApprovedUSD + (proposal.usdEquivalent || 0) > managerDailyUSD) {
      const headroom = managerDailyUSD - dailyApprovedUSD;
      throw new functions.https.HttpsError('resource-exhausted',
        `Approval would exceed your daily cap. ` +
        `Approved today: $${dailyApprovedUSD.toFixed(2)} USD. ` +
        `This proposal: $${(proposal.usdEquivalent || 0).toFixed(2)} USD. ` +
        `Daily cap: $${managerDailyUSD.toFixed(2)} USD. ` +
        `Available headroom: $${headroom.toFixed(2)} USD.`);
    }

    // Get caller info
    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerEmail = callerRecord.email || 'unknown';
    const callerDisplayName = callerRecord.displayName || callerEmail;

    // Update in transaction (re-verify status inside)
    await db.runTransaction(async (transaction) => {
      const freshSnap = await transaction.get(proposalRef);
      if (!freshSnap.exists || freshSnap.data().status !== 'proposed') {
        throw new functions.https.HttpsError('failed-precondition',
          'Proposal was modified concurrently. Please refresh and try again.');
      }

      transaction.update(proposalRef, {
        status: 'approved',
        approvedBy: {
          uid: caller.uid,
          email: callerEmail,
          role: caller.role,
          displayName: callerDisplayName,
        },
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvalIdempotencyKey: idempotencyKey,
        approvalNote: approvalNote || null,
        checklistConfirmations: checklistConfirmations.map(c => ({
          item: c.item,
          confirmed: c.confirmed === true,
          confirmedBy: { uid: caller.uid, email: callerEmail, role: caller.role },
          confirmedAt: admin.firestore.Timestamp.now(),
        })),
      });
    });

    // ========================================================
    // Paystack execution (copied from adminInitiateTransfer)
    // ========================================================
    // Use the proposalId as the Paystack reference (same as the withdrawal doc ID).
    // adminFinalizeTransfer reads from wallets/platform/withdrawals/{reference} so
    // we must keep the withdrawal doc schema identical to adminInitiateTransfer.

    const amount = proposal.amount;
    const currency = proposal.currency;
    const bankCode = proposal.bankCode;
    const accountNumber = proposal.accountNumber;
    const accountName = proposal.accountName;
    const purpose = proposal.purpose;
    const notes = proposal.notes;
    const exchangeRate = proposal.exchangeRate;
    const amountInUSD = proposal.usdEquivalent;
    const reference = proposalId;

    // Verify sufficient platform balance
    const balanceDoc = await db.collection('wallets').doc('platform')
      .collection('balances').doc(currency).get();

    if (!balanceDoc.exists) {
      throw new functions.https.HttpsError('failed-precondition', `No balance found for ${currency}.`);
    }

    const currentBalance = balanceDoc.data().amount || 0;
    if (currentBalance < amount) {
      throw new functions.https.HttpsError('failed-precondition',
        `Insufficient ${currency} balance. Available: ${currentBalance.toFixed(2)}, Requested: ${amount.toFixed(2)}`);
    }

    // Step 1: Create transfer recipient on Paystack
    const recipientResponse = await paystackRequest('POST', '/transferrecipient', {
      type: 'nuban',
      name: accountName,
      account_number: accountNumber,
      bank_code: bankCode,
      currency: currency,
    });

    if (!recipientResponse.status) {
      throw new functions.https.HttpsError('internal', 'Failed to create transfer recipient on Paystack.');
    }

    const recipientCode = recipientResponse.data.recipient_code;

    // Step 2: Deduct balance FIRST (atomic) + write withdrawal doc
    const amountInSmallestUnit = Math.round(amount * 100);
    const withdrawalRef = db.collection('wallets').doc('platform')
      .collection('withdrawals').doc(reference);

    await db.runTransaction(async (transaction) => {
      const freshBalance = await transaction.get(
        db.collection('wallets').doc('platform').collection('balances').doc(currency)
      );
      const freshAmount = freshBalance.data()?.amount || 0;

      if (freshAmount < amount) {
        throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance (concurrent update).');
      }

      transaction.update(
        db.collection('wallets').doc('platform').collection('balances').doc(currency),
        {
          amount: admin.firestore.FieldValue.increment(-amount),
          usdEquivalent: admin.firestore.FieldValue.increment(-amountInUSD),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }
      );

      transaction.update(db.collection('wallets').doc('platform'), {
        totalBalanceUSD: admin.firestore.FieldValue.increment(-amountInUSD),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(withdrawalRef, {
        id: reference,
        type: 'bank_transfer',
        amount,
        currency,
        usdEquivalent: amountInUSD,
        exchangeRate,
        purpose,
        notes: notes || null,
        bankCode,
        accountNumber,
        accountName,
        recipientCode,
        paystackReference: reference,
        status: 'pending',
        withdrawnBy: caller.uid,
        withdrawnByEmail: callerEmail,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Step 3: Call Paystack /transfer (balance already deducted)
    let transferCode = null;
    let transferStatus = 'pending';
    let internalStatus = 'pending';

    try {
      const transferResponse = await paystackRequest('POST', '/transfer', {
        source: 'balance',
        amount: amountInSmallestUnit,
        recipient: recipientCode,
        reason: `Platform withdrawal: ${purpose}`,
        reference: reference,
      });

      if (transferResponse.status) {
        transferCode = transferResponse.data.transfer_code;
        transferStatus = transferResponse.data.status;
      }

      // Map Paystack status -> internal status
      if (transferStatus === 'success') {
        internalStatus = 'completed';
      } else if (transferStatus === 'otp') {
        internalStatus = 'pending_otp';
      } else {
        internalStatus = 'pending';
      }

      await withdrawalRef.update({
        transferCode: transferCode,
        paystackStatus: transferStatus,
        status: internalStatus,
      });
    } catch (transferError) {
      // Paystack failed — refund the platform balance atomically
      logError('Paystack transfer failed (adminApproveTransfer), refunding platform balance',
        { error: transferError.message, proposalId, reference });

      await db.runTransaction(async (transaction) => {
        transaction.update(
          db.collection('wallets').doc('platform').collection('balances').doc(currency),
          {
            amount: admin.firestore.FieldValue.increment(amount),
            usdEquivalent: admin.firestore.FieldValue.increment(amountInUSD),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }
        );
        transaction.update(db.collection('wallets').doc('platform'), {
          totalBalanceUSD: admin.firestore.FieldValue.increment(amountInUSD),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await withdrawalRef.update({
        status: 'failed',
        failureReason: transferError.message,
        refunded: true,
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Also mark proposal as failed
      await proposalRef.update({
        status: 'failed',
        failureReason: transferError.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      throw new functions.https.HttpsError('internal',
        `Paystack transfer failed: ${transferError.message}. Balance has been refunded. Proposal marked failed.`);
    }

    // Reflect Paystack result back onto the proposal doc
    const proposalStatusUpdate = {
      paystackStatus: transferStatus,
      transferCode: transferCode,
      recipientCode: recipientCode,
    };
    if (internalStatus === 'pending_otp') {
      proposalStatusUpdate.status = 'pending_otp';
      proposalStatusUpdate.otpExpiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 15 * 60 * 1000);
    } else if (internalStatus === 'completed') {
      proposalStatusUpdate.status = 'completed';
      proposalStatusUpdate.completedAt = admin.firestore.FieldValue.serverTimestamp();
      proposalStatusUpdate.completedBy = {
        uid: caller.uid,
        email: callerEmail,
        role: caller.role,
        displayName: callerDisplayName,
      };
    }
    await proposalRef.update(proposalStatusUpdate);

    // Audit log
    await db.collection('audit_logs').add({
      userId: caller.uid,
      operation: 'transfer_approved',
      result: 'success',
      amount: proposal.amount,
      currency: proposal.currency,
      metadata: {
        proposalId,
        approvedBy: caller.uid,
        paystackStatus: transferStatus,
        internalStatus: internalStatus,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Admin activity log
    await db.collection('admin_activity').add({
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      action: 'approve_proposal',
      details: `Approved proposal ${proposalId} for ${proposal.amount} ${proposal.currency} — Paystack: ${transferStatus}`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify super_admins if OTP is needed
    if (internalStatus === 'pending_otp') {
      const superAdminsSnap = await db.collection('admin_users')
        .where('role', '==', 'super_admin')
        .get();
      for (const sa of superAdminsSnap.docs) {
        await sendProposalEmail({
          to: sa.id,
          toName: sa.data().displayName || null,
          subject: `OTP needed — ${proposal.amount} ${proposal.currency} approved by ${callerDisplayName}`,
          htmlBody: `<p>A transfer has been approved and is awaiting your Paystack OTP entry.</p>
<p><strong>Proposal:</strong> ${proposalId}<br>
<strong>Amount:</strong> ${proposal.amount} ${proposal.currency}<br>
<strong>Recipient:</strong> ${proposal.accountName} — ${proposal.bankCode}<br>
<strong>Approved by:</strong> ${callerDisplayName}<br>
<strong>OTP expires:</strong> 15 minutes from now</p>
<p>Check your Paystack-registered phone for the OTP, then log in to enter it.</p>
<p>— QR Wallet Admin</p>`,
          textBody: `OTP needed for proposal ${proposalId}. Approved by ${callerDisplayName}. Check Paystack phone. OTP expires in 15 minutes.`,
          relatedTo: `proposal:${proposalId}`,
        });
      }
    }

    return {
      success: true,
      proposalId,
      status: proposalStatusUpdate.status || 'approved',
      otpRequired: internalStatus === 'pending_otp',
      transferCode: transferCode,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminApproveTransfer failed', { proposalId, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to approve proposal: ' + error.message);
  }
});

/**
 * Admin: Reject a pending platform transfer proposal.
 * Only admin_manager (level 7) and above can reject.
 * Updates proposal status from 'proposed' to 'rejected' (terminal state).
 *
 * Ref: Phase 2a agent commit 3/6
 */
exports.adminRejectTransfer = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_manager');

  const { proposalId, reason, idempotencyKey } = data || {};

  // Input validation
  if (!proposalId || typeof proposalId !== 'string' || !proposalId.startsWith('PLT-')) {
    throw new functions.https.HttpsError('invalid-argument', 'proposalId is required and must start with "PLT-".');
  }
  if (!reason || typeof reason !== 'string' || reason.trim().length < 5) {
    throw new functions.https.HttpsError('invalid-argument', 'reason is required and must be at least 5 characters.');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey is required and must be at least 16 characters.');
  }

  // Rate limit
  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminRejectTransfer');
  if (!withinLimit) {
    throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminRejectTransfer.message);
  }

  try {
    const proposalRef = db.collection('platform_transfer_proposals').doc(proposalId);
    const proposalSnap = await proposalRef.get();

    if (!proposalSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Proposal ${proposalId} not found.`);
    }

    if (proposalSnap.data().status !== 'proposed') {
      throw new functions.https.HttpsError('failed-precondition',
        `Proposal is not in 'proposed' state (current: ${proposalSnap.data().status}). Cannot reject.`);
    }

    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerEmail = callerRecord.email || 'unknown';
    const callerDisplayName = callerRecord.displayName || callerEmail;

    // Update in transaction (re-verify status inside)
    await db.runTransaction(async (transaction) => {
      const freshSnap = await transaction.get(proposalRef);
      if (!freshSnap.exists || freshSnap.data().status !== 'proposed') {
        throw new functions.https.HttpsError('failed-precondition',
          'Proposal was modified concurrently. Please refresh and try again.');
      }

      transaction.update(proposalRef, {
        status: 'rejected',
        rejectedBy: {
          uid: caller.uid,
          email: callerEmail,
          role: caller.role,
          displayName: callerDisplayName,
        },
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectionReason: reason.trim(),
      });
    });

    // Audit log
    await db.collection('audit_logs').add({
      userId: caller.uid,
      operation: 'transfer_rejected',
      result: 'success',
      metadata: { proposalId, reason: reason.trim(), rejectedBy: caller.uid },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Admin activity log
    await db.collection('admin_activity').add({
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      action: 'reject_proposal',
      details: `Rejected proposal ${proposalId}: ${reason.trim()}`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify proposer of rejection
    const proposalData = proposalSnap.data();
    await sendProposalEmail({
      to: proposalData.proposedBy.email,
      toName: proposalData.proposedBy.displayName || null,
      subject: `Your transfer proposal was rejected`,
      htmlBody: `<p>Your platform transfer proposal <strong>${proposalId}</strong> was rejected.</p>
<p><strong>Reviewer:</strong> ${callerDisplayName}<br>
<strong>Reason:</strong> ${reason.trim()}</p>
<p>You can submit a revised proposal through the admin dashboard.</p>
<p>— QR Wallet Admin</p>`,
      textBody: `Proposal ${proposalId} was rejected by ${callerDisplayName}. Reason: ${reason.trim()}`,
      relatedTo: `proposal:${proposalId}`,
    });

    return { success: true, proposalId, status: 'rejected' };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminRejectTransfer failed', { proposalId, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to reject proposal: ' + error.message);
  }
});

/**
 * Admin: Cancel a pending platform transfer proposal.
 * Finance (level 6) and above can call, but only the original proposer
 * or a super_admin can actually cancel.
 * Updates proposal status from 'proposed' to 'cancelled' (terminal state).
 *
 * Ref: Phase 2a agent commit 3/6
 */
exports.adminCancelProposal = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'finance');

  const { proposalId, idempotencyKey } = data || {};

  // Input validation
  if (!proposalId || typeof proposalId !== 'string' || !proposalId.startsWith('PLT-')) {
    throw new functions.https.HttpsError('invalid-argument', 'proposalId is required and must start with "PLT-".');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey is required and must be at least 16 characters.');
  }

  // Rate limit
  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminCancelProposal');
  if (!withinLimit) {
    throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminCancelProposal.message);
  }

  try {
    const proposalRef = db.collection('platform_transfer_proposals').doc(proposalId);
    const proposalSnap = await proposalRef.get();

    if (!proposalSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Proposal ${proposalId} not found.`);
    }

    const proposal = proposalSnap.data();

    if (proposal.status !== 'proposed') {
      throw new functions.https.HttpsError('failed-precondition',
        `Proposal is not in 'proposed' state (current: ${proposal.status}). Cannot cancel.`);
    }

    // Authorization: only the original proposer or a super_admin can cancel
    if (caller.uid !== proposal.proposedBy.uid && caller.role !== 'super_admin') {
      throw new functions.https.HttpsError('permission-denied',
        'Only the original proposer or a super_admin can cancel.');
    }

    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerEmail = callerRecord.email || 'unknown';
    const callerDisplayName = callerRecord.displayName || callerEmail;

    // Update in transaction (re-verify status inside)
    await db.runTransaction(async (transaction) => {
      const freshSnap = await transaction.get(proposalRef);
      if (!freshSnap.exists || freshSnap.data().status !== 'proposed') {
        throw new functions.https.HttpsError('failed-precondition',
          'Proposal was modified concurrently. Please refresh and try again.');
      }

      transaction.update(proposalRef, {
        status: 'cancelled',
        cancelledBy: {
          uid: caller.uid,
          email: callerEmail,
          role: caller.role,
          displayName: callerDisplayName,
        },
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: 'finance_cancel',
      });
    });

    // Audit log
    await db.collection('audit_logs').add({
      userId: caller.uid,
      operation: 'proposal_cancelled',
      result: 'success',
      metadata: { proposalId, cancelledBy: caller.uid },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Admin activity log
    await db.collection('admin_activity').add({
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      action: 'cancel_proposal',
      details: `Cancelled proposal ${proposalId}`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify managers FYI
    const managersSnap = await db.collection('admin_users')
      .where('role', '==', 'admin_manager')
      .get();
    for (const mgr of managersSnap.docs) {
      await sendProposalEmail({
        to: mgr.id,
        toName: mgr.data().displayName || null,
        subject: `FYI: Proposal ${proposalId} was cancelled by finance`,
        htmlBody: `<p>FYI: Finance user ${callerDisplayName} cancelled proposal ${proposalId} before approval.</p>
<p>No action required. This proposal is removed from the queue.</p>`,
        textBody: `FYI: Proposal ${proposalId} cancelled by ${callerDisplayName}.`,
        relatedTo: `proposal:${proposalId}`,
      });
    }

    return { success: true, proposalId, status: 'cancelled' };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminCancelProposal failed', { proposalId, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to cancel proposal: ' + error.message);
  }
});

/**
 * Admin: Emergency platform transfer — super_admin only.
 * Bypasses the propose → approve flow by creating a proposal directly
 * with emergency: true and status: 'proposed'. The human-pair commit
 * that modifies adminInitiateTransfer will detect emergency: true and
 * skip the approval step.
 *
 * Requires a detailed justification reason (min 50 chars).
 * Subject to a separate emergency daily cap.
 *
 * Ref: Phase 2a agent commit 4/6
 */

/**
 * Admin: Edit a pending platform transfer proposal.
 * Only the original proposer (finance) can edit. Only status: 'proposed' allowed.
 * Tracks full edit history with previous values.
 *
 * Ref: Phase 2b agent commit 5/10
 */
exports.adminEditProposal = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'finance');

  const { proposalId, fields, idempotencyKey } = data || {};

  // Input validation
  if (!proposalId || typeof proposalId !== 'string' || !proposalId.startsWith('PLT-')) {
    throw new functions.https.HttpsError('invalid-argument', 'proposalId is required and must start with "PLT-".');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey is required and must be at least 16 characters.');
  }
  if (!fields || typeof fields !== 'object' || Array.isArray(fields)) {
    throw new functions.https.HttpsError('invalid-argument', 'fields is required and must be an object.');
  }

  // Rate limit
  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminEditProposal');
  if (!withinLimit) {
    throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminEditProposal.message);
  }

  try {
    const proposalRef = db.collection('platform_transfer_proposals').doc(proposalId);
    const proposalSnap = await proposalRef.get();

    if (!proposalSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Proposal ${proposalId} not found.`);
    }

    const proposal = proposalSnap.data();

    if (proposal.status !== 'proposed') {
      throw new functions.https.HttpsError('failed-precondition',
        `Proposal is not in 'proposed' state (current: ${proposal.status}). Cannot edit.`);
    }

    // Only the original proposer can edit
    if (caller.uid !== proposal.proposedBy.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only the original proposer can edit this proposal.');
    }

    // Build change set — only include fields that actually changed
    const allowedFields = ['amount', 'bankCode', 'accountNumber', 'accountName', 'purpose', 'notes', 'priorityFlag'];
    const fieldsChanged = [];
    const previousValues = {};
    const updateData = {};

    for (const key of allowedFields) {
      if (fields[key] !== undefined && fields[key] !== proposal[key]) {
        fieldsChanged.push(key);
        previousValues[key] = proposal[key];
        updateData[key] = fields[key];
      }
    }

    if (fieldsChanged.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'No fields to change.');
    }

    // If amount changed, recompute usdEquivalent
    if (updateData.amount !== undefined) {
      const ratesDoc = await db.collection('app_config').doc('exchange_rates').get();
      const rates = ratesDoc.exists ? ratesDoc.data().rates || {} : {};
      const exchangeRate = rates[proposal.currency] || 1;
      updateData.usdEquivalent = updateData.amount / exchangeRate;
      updateData.exchangeRate = exchangeRate;
    }

    // Get caller info
    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerEmail = callerRecord.email || 'unknown';
    const callerDisplayName = callerRecord.displayName || callerEmail;

    let newEditHistoryLength = 0;

    // Update in transaction (re-verify status inside)
    await db.runTransaction(async (transaction) => {
      const freshSnap = await transaction.get(proposalRef);
      if (!freshSnap.exists || freshSnap.data().status !== 'proposed') {
        throw new functions.https.HttpsError('failed-precondition',
          'Proposal was modified concurrently. Please refresh and try again.');
      }

      transaction.update(proposalRef, {
        ...updateData,
        editHistory: admin.firestore.FieldValue.arrayUnion({
          editedBy: { uid: caller.uid, email: callerEmail, role: caller.role, displayName: callerDisplayName },
          editedAt: admin.firestore.Timestamp.now(),
          fieldsChanged,
          previousValues,
        }),
      });

      newEditHistoryLength = (freshSnap.data().editHistory || []).length + 1;
    });

    // Audit log
    await db.collection('audit_logs').add({
      userId: caller.uid,
      operation: 'proposal_edited',
      result: 'success',
      metadata: { proposalId, fieldsChanged, previousValues },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Admin activity log
    await db.collection('admin_activity').add({
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      action: 'edit_proposal',
      details: `Edited proposal ${proposalId}: changed ${fieldsChanged.join(', ')}`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, proposalId, editCount: newEditHistoryLength, fieldsChanged };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminEditProposal failed', { proposalId, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to edit proposal: ' + error.message);
  }
});

/**
 * Admin: Close a completed proposal after evidence is uploaded.
 * Finance user (proposer) or super_admin can close.
 * Unblocks finance user if they had overdue evidence.
 *
 * Ref: Phase 2b agent commit 8/10
 */
exports.adminCloseProposal = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'finance');

  const { proposalId, idempotencyKey } = data || {};

  if (!proposalId || typeof proposalId !== 'string' || !proposalId.startsWith('PLT-')) {
    throw new functions.https.HttpsError('invalid-argument', 'proposalId is required and must start with "PLT-".');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey is required and must be at least 16 characters.');
  }

  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminCloseProposal');
  if (!withinLimit) {
    throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminCloseProposal.message);
  }

  try {
    const proposalRef = db.collection('platform_transfer_proposals').doc(proposalId);
    const proposalSnap = await proposalRef.get();

    if (!proposalSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Proposal ${proposalId} not found.`);
    }

    const proposal = proposalSnap.data();
    const allowedStatuses = ['completed', 'evidence_pending', 'evidence_overdue'];
    if (!allowedStatuses.includes(proposal.status)) {
      throw new functions.https.HttpsError('failed-precondition',
        `Proposal status is '${proposal.status}'. Must be one of: ${allowedStatuses.join(', ')}.`);
    }

    if (caller.uid !== proposal.proposedBy.uid && caller.role !== 'super_admin') {
      throw new functions.https.HttpsError('permission-denied',
        'Only the original proposer or a super_admin can close this proposal.');
    }

    // Verify evidence is uploaded before allowing closure
    const docs = proposal.documents || {};
    if (!docs.receipt || !docs.receipt.path) {
      throw new functions.https.HttpsError('failed-precondition',
        'Receipt must be uploaded before closing. Use adminUploadProposalDocument with documentType="receipt".');
    }
    if (!Array.isArray(docs.evidence) || docs.evidence.length < 1) {
      throw new functions.https.HttpsError('failed-precondition',
        'At least 1 evidence file must be uploaded before closing. Use adminUploadProposalDocument with documentType="evidence".');
    }

    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerEmail = callerRecord.email || 'unknown';
    const callerDisplayName = callerRecord.displayName || callerEmail;

    await db.runTransaction(async (transaction) => {
      const freshSnap = await transaction.get(proposalRef);
      if (!freshSnap.exists || !allowedStatuses.includes(freshSnap.data().status)) {
        throw new functions.https.HttpsError('failed-precondition',
          'Proposal was modified concurrently. Please refresh and try again.');
      }

      transaction.update(proposalRef, {
        status: 'closed',
        closedAt: admin.firestore.FieldValue.serverTimestamp(),
        closedBy: {
          uid: caller.uid,
          email: callerEmail,
          role: caller.role,
          displayName: callerDisplayName,
        },
        evidenceUploadedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Finance unblock: check if proposer still has other overdue proposals
    const stillOverdue = await db.collection('platform_transfer_proposals')
      .where('proposedBy.uid', '==', proposal.proposedBy.uid)
      .where('status', '==', 'evidence_overdue')
      .limit(1)
      .get();
    if (stillOverdue.empty) {
      await db.collection('blocked_finance_users').doc(proposal.proposedBy.uid).delete();
    }

    await db.collection('audit_logs').add({
      userId: caller.uid,
      operation: 'proposal_closed',
      result: 'success',
      metadata: { proposalId },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    await db.collection('admin_activity').add({
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      action: 'close_proposal',
      details: `Closed proposal ${proposalId}`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, proposalId, status: 'closed' };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminCloseProposal failed', { proposalId, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to close proposal: ' + error.message);
  }
});

/**
 * Admin: Upload a document associated with a platform transfer proposal.
 * Files are sent as base64 in the payload, decoded in CF, written to Storage.
 *
 * documentType: 'invoice' | 'quote' | 'receipt' | 'evidence'
 *
 * Limits:
 *   - 10 MB per file
 *   - invoice + up to 4 quotes at proposal stage (status='proposed')
 *   - receipt + up to 4 evidence at post-completion (status in completed/evidence_pending/evidence_overdue)
 *   - Allowed types: application/pdf, image/jpeg, image/png
 *
 * Storage path: platform_transfer_proposals/{proposalId}/<...>
 *
 * Ref: Phase 2b commit 4 (human-pair)
 */
exports.adminUploadProposalDocument = functions
  .runWith({ memory: '512MB', enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'finance');

  const { proposalId, documentType, fileBase64, contentType, fileName, idempotencyKey } = data || {};

  // Input validation
  if (!proposalId || typeof proposalId !== 'string' || !proposalId.startsWith('PLT-')) {
    throw new functions.https.HttpsError('invalid-argument', 'proposalId is required and must start with "PLT-".');
  }
  const ALLOWED_TYPES = ['invoice', 'quote', 'receipt', 'evidence'];
  if (!ALLOWED_TYPES.includes(documentType)) {
    throw new functions.https.HttpsError('invalid-argument', `documentType must be one of: ${ALLOWED_TYPES.join(', ')}`);
  }
  if (!fileBase64 || typeof fileBase64 !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'fileBase64 is required (base64-encoded file).');
  }
  const ALLOWED_CONTENT = ['application/pdf', 'image/jpeg', 'image/png'];
  if (!ALLOWED_CONTENT.includes(contentType)) {
    throw new functions.https.HttpsError('invalid-argument', `contentType must be one of: ${ALLOWED_CONTENT.join(', ')}`);
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey is required and must be at least 16 characters.');
  }

  // Rate limit
  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminUploadProposalDocument');
  if (!withinLimit) {
    throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminUploadProposalDocument.message);
  }

  // Decode base64 and check size
  let fileBuffer;
  try {
    fileBuffer = Buffer.from(fileBase64, 'base64');
  } catch (err) {
    throw new functions.https.HttpsError('invalid-argument', 'fileBase64 could not be decoded.');
  }
  const MAX_SIZE = 10 * 1024 * 1024; // 10 MB
  if (fileBuffer.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Decoded file is empty.');
  }
  if (fileBuffer.length > MAX_SIZE) {
    throw new functions.https.HttpsError('invalid-argument', `File too large. Max ${MAX_SIZE / (1024 * 1024)} MB.`);
  }

  try {
    // Read proposal
    const proposalRef = db.collection('platform_transfer_proposals').doc(proposalId);
    const proposalSnap = await proposalRef.get();
    if (!proposalSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Proposal ${proposalId} not found.`);
    }
    const proposal = proposalSnap.data();

    // Authorization: caller must be the proposer (or super_admin)
    if (caller.uid !== proposal.proposedBy.uid && caller.role !== 'super_admin') {
      throw new functions.https.HttpsError('permission-denied',
        'Only the original proposer or a super_admin can upload documents.');
    }

    // State validation — which documents allowed at which stage
    const PROPOSAL_STAGE_STATUSES = ['proposed'];
    const EVIDENCE_STAGE_STATUSES = ['completed', 'evidence_pending', 'evidence_overdue'];
    if (['invoice', 'quote'].includes(documentType)) {
      if (!PROPOSAL_STAGE_STATUSES.includes(proposal.status)) {
        throw new functions.https.HttpsError('failed-precondition',
          `Cannot upload ${documentType} when proposal status is '${proposal.status}'. Only allowed in: ${PROPOSAL_STAGE_STATUSES.join(', ')}.`);
      }
    } else {
      // receipt or evidence
      if (!EVIDENCE_STAGE_STATUSES.includes(proposal.status)) {
        throw new functions.https.HttpsError('failed-precondition',
          `Cannot upload ${documentType} when proposal status is '${proposal.status}'. Only allowed in: ${EVIDENCE_STAGE_STATUSES.join(', ')}.`);
      }
    }

    // Quote/evidence array limits (max 4 each)
    const existingDocs = proposal.documents || {};
    const MAX_ARRAY_ITEMS = 4;
    if (documentType === 'quote') {
      const currentQuotes = Array.isArray(existingDocs.quotes) ? existingDocs.quotes : [];
      if (currentQuotes.length >= MAX_ARRAY_ITEMS) {
        throw new functions.https.HttpsError('failed-precondition',
          `Maximum ${MAX_ARRAY_ITEMS} quotes already uploaded for this proposal.`);
      }
    }
    if (documentType === 'evidence') {
      const currentEvidence = Array.isArray(existingDocs.evidence) ? existingDocs.evidence : [];
      if (currentEvidence.length >= MAX_ARRAY_ITEMS) {
        throw new functions.https.HttpsError('failed-precondition',
          `Maximum ${MAX_ARRAY_ITEMS} evidence files already uploaded for this proposal.`);
      }
    }

    // Determine extension from content type
    const EXT_MAP = {
      'application/pdf': 'pdf',
      'image/jpeg': 'jpg',
      'image/png': 'png',
    };
    const ext = EXT_MAP[contentType];

    // Build Storage path
    let storagePath;
    if (documentType === 'invoice' || documentType === 'receipt') {
      storagePath = `platform_transfer_proposals/${proposalId}/${documentType}.${ext}`;
    } else {
      // quote or evidence — indexed file
      const currentArray = documentType === 'quote'
        ? (Array.isArray(existingDocs.quotes) ? existingDocs.quotes : [])
        : (Array.isArray(existingDocs.evidence) ? existingDocs.evidence : []);
      const nextIndex = currentArray.length;
      const folder = documentType === 'quote' ? 'quotes' : 'evidence';
      storagePath = `platform_transfer_proposals/${proposalId}/${folder}/${nextIndex}.${ext}`;
    }

    // Upload to Firebase Storage
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    await file.save(fileBuffer, {
      contentType,
      metadata: {
        uploadedBy: caller.uid,
        proposalId,
        documentType,
        originalFileName: fileName || null,
      },
    });

    // Update proposal doc with the new document record
    const documentRecord = {
      path: storagePath,
      uploadedAt: admin.firestore.Timestamp.now(),
      sizeBytes: fileBuffer.length,
      contentType,
      uploadedBy: { uid: caller.uid, email: caller.email || null },
      originalFileName: fileName || null,
    };

    if (documentType === 'invoice' || documentType === 'receipt') {
      await proposalRef.update({
        [`documents.${documentType}`]: documentRecord,
      });
    } else {
      // quote or evidence — append to array
      const fieldName = documentType === 'quote' ? 'quotes' : 'evidence';
      await proposalRef.update({
        [`documents.${fieldName}`]: admin.firestore.FieldValue.arrayUnion(documentRecord),
      });
    }

    // Audit log
    await db.collection('audit_logs').add({
      userId: caller.uid,
      operation: 'proposal_document_uploaded',
      result: 'success',
      metadata: { proposalId, documentType, storagePath, sizeBytes: fileBuffer.length },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, proposalId, documentType, storagePath, sizeBytes: fileBuffer.length };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminUploadProposalDocument failed', { proposalId, documentType, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to upload document: ' + error.message);
  }
});

/**
 * Admin: Generate a short-lived signed URL for downloading a proposal document.
 * Auditor and above can access — compliance & review need visibility.
 *
 * URL valid for 5 minutes. Each access is audit-logged (compliance requirement).
 *
 * Ref: Phase 2b commit 4 (human-pair)
 */
exports.adminGetProposalDocumentUrl = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'auditor');

  const { proposalId, documentType, index } = data || {};

  if (!proposalId || typeof proposalId !== 'string' || !proposalId.startsWith('PLT-')) {
    throw new functions.https.HttpsError('invalid-argument', 'proposalId is required and must start with "PLT-".');
  }
  const ALLOWED_TYPES = ['invoice', 'quote', 'receipt', 'evidence'];
  if (!ALLOWED_TYPES.includes(documentType)) {
    throw new functions.https.HttpsError('invalid-argument', `documentType must be one of: ${ALLOWED_TYPES.join(', ')}`);
  }
  if (['quote', 'evidence'].includes(documentType)) {
    if (index === undefined || typeof index !== 'number' || index < 0 || index > 3) {
      throw new functions.https.HttpsError('invalid-argument', `index (0-3) is required for ${documentType}.`);
    }
  }

  // Rate limit
  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminGetProposalDocumentUrl');
  if (!withinLimit) {
    throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminGetProposalDocumentUrl.message);
  }

  try {
    // Read proposal to get the stored document path
    const proposalRef = db.collection('platform_transfer_proposals').doc(proposalId);
    const proposalSnap = await proposalRef.get();
    if (!proposalSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Proposal ${proposalId} not found.`);
    }
    const proposal = proposalSnap.data();
    const docs = proposal.documents || {};

    let docRecord;
    if (documentType === 'invoice' || documentType === 'receipt') {
      docRecord = docs[documentType];
    } else {
      const fieldName = documentType === 'quote' ? 'quotes' : 'evidence';
      const arr = Array.isArray(docs[fieldName]) ? docs[fieldName] : [];
      docRecord = arr[index];
    }

    if (!docRecord || !docRecord.path) {
      throw new functions.https.HttpsError('not-found',
        `No ${documentType} document found for this proposal${['quote', 'evidence'].includes(documentType) ? ` at index ${index}` : ''}.`);
    }

    // Generate signed URL (5-min expiry)
    const bucket = admin.storage().bucket();
    const file = bucket.file(docRecord.path);
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 5 * 60 * 1000,
    });

    // Audit log (compliance — record every document access)
    await db.collection('audit_logs').add({
      userId: caller.uid,
      operation: 'proposal_document_accessed',
      result: 'success',
      metadata: { proposalId, documentType, index: index || null, path: docRecord.path },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      url,
      expiresAt: Date.now() + 5 * 60 * 1000,
      contentType: docRecord.contentType,
      sizeBytes: docRecord.sizeBytes,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminGetProposalDocumentUrl failed', { proposalId, documentType, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to generate document URL: ' + error.message);
  }
});

exports.adminEmergencyTransfer = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'super_admin');

  const { amount, currency, bankCode, accountNumber, accountName, purpose, reason, notes, idempotencyKey } = data || {};

  // Input validation
  if (!amount || typeof amount !== 'number' || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'amount must be a positive number.');
  }
  if (!currency || typeof currency !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'currency is required.');
  }
  if (!bankCode || typeof bankCode !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'bankCode is required.');
  }
  if (!accountNumber || typeof accountNumber !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'accountNumber is required.');
  }
  if (!accountName || typeof accountName !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'accountName is required.');
  }
  if (!purpose || typeof purpose !== 'string' || purpose.trim().length < 5) {
    throw new functions.https.HttpsError('invalid-argument', 'purpose is required and must be at least 5 characters.');
  }
  if (!reason || typeof reason !== 'string' || reason.trim().length < 50) {
    throw new functions.https.HttpsError('invalid-argument', 'Emergency reason is required and must be at least 50 characters.');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey is required and must be at least 16 characters.');
  }

  // Rate limit (3/hour for emergency)
  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminEmergencyTransfer');
  if (!withinLimit) {
    throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminEmergencyTransfer.message);
  }

  try {
    // Compute USD equivalent
    const ratesDoc = await db.collection('app_config').doc('exchange_rates').get();
    const rates = ratesDoc.exists ? ratesDoc.data().rates || {} : {};
    const exchangeRate = rates[currency] || 1;
    const usdEquivalent = amount / exchangeRate;

    // Emergency daily cap check
    const limitsDoc = await db.collection('app_config').doc('platform_limits').get();
    const emergencyDailyUSD = limitsDoc.exists ? (limitsDoc.data().emergencyDailyUSD || 250000) : 250000;

    const startOfTodayUTC = new Date();
    startOfTodayUTC.setUTCHours(0, 0, 0, 0);
    const startOfTodayTimestamp = admin.firestore.Timestamp.fromDate(startOfTodayUTC);

    const todayEmergencySnap = await db.collection('platform_transfer_proposals')
      .where('emergencyInvokedBy.uid', '==', caller.uid)
      .where('proposedAt', '>=', startOfTodayTimestamp)
      .get();

    const dailyEmergencyUSD = todayEmergencySnap.docs.reduce((sum, doc) => {
      return sum + (doc.data().usdEquivalent || 0);
    }, 0);

    if (dailyEmergencyUSD + usdEquivalent > emergencyDailyUSD) {
      const headroom = emergencyDailyUSD - dailyEmergencyUSD;
      throw new functions.https.HttpsError('resource-exhausted',
        `Emergency transfer would exceed your daily emergency cap. ` +
        `Used today: $${dailyEmergencyUSD.toFixed(2)} USD. ` +
        `This transfer: $${usdEquivalent.toFixed(2)} USD. ` +
        `Daily emergency cap: $${emergencyDailyUSD.toFixed(2)} USD. ` +
        `Available headroom: $${headroom.toFixed(2)} USD.`);
    }

    // Generate proposal ID
    const proposalId = `PLT-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;

    // Get caller info
    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerEmail = callerRecord.email || 'unknown';
    const callerDisplayName = callerRecord.displayName || callerEmail;

    const callerIdentity = {
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      displayName: callerDisplayName,
    };

    // Write proposal doc
    await db.collection('platform_transfer_proposals').doc(proposalId).set({
      proposalId,
      status: 'proposed',
      amount,
      currency,
      usdEquivalent,
      exchangeRate,
      bankCode,
      accountNumber,
      accountName,
      purpose: purpose.trim(),
      notes: notes || null,
      priorityFlag: true,
      proposedBy: callerIdentity,
      proposedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 15 * 60 * 1000),
      idempotencyKey,
      emergency: true,
      emergencyReason: reason.trim(),
      emergencyInvokedBy: callerIdentity,
    });

    // Audit log
    await db.collection('audit_logs').add({
      userId: caller.uid,
      operation: 'transfer_emergency',
      result: 'success',
      amount,
      currency,
      metadata: { proposalId, emergency: true, reason: reason.trim() },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Admin activity log
    await db.collection('admin_activity').add({
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      action: 'transfer_emergency',
      details: `Emergency transfer proposal ${proposalId} for ${amount} ${currency}`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify admin_managers FYI
    const managersSnap = await db.collection('admin_users')
      .where('role', '==', 'admin_manager')
      .get();
    for (const mgr of managersSnap.docs) {
      await sendProposalEmail({
        to: mgr.id,
        toName: mgr.data().displayName || null,
        subject: `EMERGENCY transfer by super_admin — for your awareness`,
        htmlBody: `<p>Super_admin ${callerDisplayName} executed an emergency transfer without the standard approval flow.</p>
<p><strong>Proposal:</strong> ${proposalId}<br>
<strong>Amount:</strong> ${amount} ${currency}<br>
<strong>Recipient:</strong> ${accountName} — ${bankCode}<br>
<strong>Justification:</strong> ${reason.trim()}</p>
<p>This is for your awareness. No action required unless you have concerns.</p>`,
        textBody: `EMERGENCY transfer ${proposalId} by ${callerDisplayName}. Amount: ${amount} ${currency}. Reason: ${reason.trim()}`,
        relatedTo: `proposal:${proposalId}`,
      });
    }

    return { success: true, proposalId, status: 'proposed', emergency: true };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminEmergencyTransfer failed', { caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to create emergency transfer: ' + error.message);
  }
});

/**
 * Admin: List platform transfer proposals with optional filters and pagination.
 * Auditor (level 3) and above can call.
 * Finance role sees only their own proposals; admin_manager+ and auditor see all.
 *
 * Ref: Phase 2a agent commit 5/6
 */
exports.adminListTransferProposals = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'auditor');

  const { status: filterStatus, limit: requestedLimit, startAfter } = data || {};

  // Validate inputs
  const validStatuses = ['proposed', 'approved', 'rejected', 'cancelled', 'expired', 'completed', 'pending_otp'];
  if (filterStatus && !validStatuses.includes(filterStatus)) {
    throw new functions.https.HttpsError('invalid-argument',
      `Invalid status filter. Must be one of: ${validStatuses.join(', ')}`);
  }

  let limit = 50;
  if (requestedLimit && typeof requestedLimit === 'number') {
    limit = Math.min(Math.max(requestedLimit, 1), 200);
  }

  try {
    let query = db.collection('platform_transfer_proposals')
      .orderBy('proposedAt', 'desc')
      .limit(limit);

    if (filterStatus) {
      query = query.where('status', '==', filterStatus);
    }

    // Role-based filtering: finance (level 6 exactly) sees only own proposals
    const roleHierarchy = { viewer: 1, auditor: 2, support: 3, admin: 4, admin_supervisor: 5, finance: 6, admin_manager: 7, super_admin: 8 };
    const callerLevel = roleHierarchy[caller.role] || 0;
    if (caller.role === 'finance' && callerLevel === 6) {
      query = query.where('proposedBy.uid', '==', caller.uid);
    }

    // Pagination cursor
    if (startAfter && typeof startAfter === 'string') {
      const cursorDoc = await db.collection('platform_transfer_proposals').doc(startAfter).get();
      if (cursorDoc.exists) {
        query = query.startAfter(cursorDoc);
      }
    }

    const snapshot = await query.get();
    const proposals = snapshot.docs.map(doc => {
      const d = doc.data();
      const { idempotencyKey, approvalIdempotencyKey, ...safeData } = d;
      return safeData;
    });

    return {
      success: true,
      proposals,
      count: proposals.length,
      hasMore: proposals.length === limit,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminListTransferProposals failed', { caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to list proposals: ' + error.message);
  }
});

// ============================================================
// TRANSACTION MONITORING
// ============================================================

/**
 * Admin: Get all transactions across the platform using collectionGroup query.
 * Supports filtering by type, status, currency, and date range.
 */
exports.adminGetAllTransactions = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'auditor');

  const {
    limit: queryLimit,
    type: filterType,
    status: filterStatus,
    currency: filterCurrency,
    startDate,
    endDate,
  } = data || {};

  const fetchLimit = Math.min(queryLimit || 50, 200);

  try {
    let query = db.collectionGroup('transactions').orderBy('createdAt', 'desc');

    if (filterType) {
      query = query.where('type', '==', filterType);
    }

    if (filterStatus) {
      query = query.where('status', '==', filterStatus);
    }

    if (startDate) {
      query = query.where('createdAt', '>=', admin.firestore.Timestamp.fromDate(new Date(startDate)));
    }

    if (endDate) {
      query = query.where('createdAt', '<=', admin.firestore.Timestamp.fromDate(new Date(endDate)));
    }

    query = query.limit(fetchLimit);

    const snapshot = await query.get();
    const transactions = snapshot.docs.map(doc => {
      const data = doc.data();
      // Extract userId from the document path: users/{userId}/transactions/{txId}
      const pathParts = doc.ref.path.split('/');
      const userId = pathParts.length >= 2 ? pathParts[1] : null;

      return {
        id: doc.id,
        userId,
        type: data.type,
        amount: data.amount,
        fee: data.fee || 0,
        currency: data.currency || data.senderCurrency,
        senderCurrency: data.senderCurrency,
        receiverCurrency: data.receiverCurrency,
        status: data.status,
        method: data.method,
        senderName: data.senderName,
        receiverName: data.receiverName,
        senderWalletId: data.senderWalletId,
        receiverWalletId: data.receiverWalletId,
        note: data.note,
        phoneNumber: data.phoneNumber,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
        completedAt: data.completedAt?.toDate?.()?.toISOString() || null,
      };
    });

    return { success: true, transactions, count: transactions.length };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;

    // Check if index is needed
    if (error.code === 9 || error.message?.includes('index')) {
      throw new functions.https.HttpsError('failed-precondition',
        'A Firestore index is required. Check the Firebase Console logs for a link to create it.');
    }

    throw new functions.https.HttpsError('internal', `Failed to get transactions: ${error.message}`);
  }
});

/**
 * Admin: Get transaction volume statistics.
 */
exports.adminGetTransactionStats = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'auditor');

  const { days } = data || {};
  const lookbackDays = Math.min(days || 7, 90);
  const sinceDate = new Date(Date.now() - lookbackDays * 24 * 60 * 60 * 1000);

  try {
    const snapshot = await db.collectionGroup('transactions')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(sinceDate))
      .orderBy('createdAt', 'desc')
      .limit(1000)
      .get();

    let totalVolume = 0;
    let totalFees = 0;
    let sendCount = 0;
    let receiveCount = 0;
    let depositCount = 0;
    let withdrawCount = 0;
    let completedCount = 0;
    let failedCount = 0;
    let pendingCount = 0;
    const volumeByCurrency = {};
    const volumeByDay = {};

    snapshot.docs.forEach(doc => {
      const tx = doc.data();
      const amount = tx.amount || 0;
      const fee = tx.fee || 0;
      const currency = tx.currency || tx.senderCurrency || 'Unknown';
      const type = tx.type || 'unknown';
      const status = tx.status || 'unknown';

      totalVolume += amount;
      totalFees += fee;

      // Count by type
      if (type === 'send') sendCount++;
      else if (type === 'receive') receiveCount++;
      else if (type === 'deposit') depositCount++;
      else if (type === 'withdraw' || type === 'withdrawal') withdrawCount++;

      // Count by status
      if (status === 'completed') completedCount++;
      else if (status === 'failed') failedCount++;
      else if (status === 'pending') pendingCount++;

      // Volume by currency
      if (!volumeByCurrency[currency]) {
        volumeByCurrency[currency] = { amount: 0, count: 0, fees: 0 };
      }
      volumeByCurrency[currency].amount += amount;
      volumeByCurrency[currency].count += 1;
      volumeByCurrency[currency].fees += fee;

      // Volume by day
      if (tx.createdAt?.toDate) {
        const dayKey = tx.createdAt.toDate().toISOString().split('T')[0];
        if (!volumeByDay[dayKey]) {
          volumeByDay[dayKey] = { amount: 0, count: 0 };
        }
        volumeByDay[dayKey].amount += amount;
        volumeByDay[dayKey].count += 1;
      }
    });

    return {
      success: true,
      stats: {
        period: `${lookbackDays} days`,
        totalTransactions: snapshot.size,
        totalVolume,
        totalFees,
        byType: { send: sendCount, receive: receiveCount, deposit: depositCount, withdraw: withdrawCount },
        byStatus: { completed: completedCount, failed: failedCount, pending: pendingCount },
        volumeByCurrency,
        volumeByDay,
      },
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;

    if (error.code === 9 || error.message?.includes('index')) {
      throw new functions.https.HttpsError('failed-precondition',
        'A Firestore index is required. Check the Firebase Console logs for a link to create it.');
    }

    throw new functions.https.HttpsError('internal', `Failed to get transaction stats: ${error.message}`);
  }
});

/**
 * Admin: Flag a transaction for review.
 */
exports.adminFlagTransaction = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_supervisor');

  const { userId, transactionId, reason } = data;

  if (!userId || !transactionId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId and transactionId are required.');
  }

  if (!reason) {
    throw new functions.https.HttpsError('invalid-argument', 'Reason for flagging is required.');
  }

  try {
    // Get the transaction
    const txRef = db.collection('users').doc(userId).collection('transactions').doc(transactionId);
    const txDoc = await txRef.get();

    if (!txDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Transaction not found.');
    }

    const txData = txDoc.data();

    // Get caller email
    const callerEmail = (await admin.auth().getUser(caller.uid)).email || 'unknown';

    // Create flagged transaction record
    await db.collection('flagged_transactions').doc(transactionId).set({
      transactionId,
      userId,
      type: txData.type,
      amount: txData.amount,
      currency: txData.currency || txData.senderCurrency,
      status: txData.status,
      senderName: txData.senderName || null,
      receiverName: txData.receiverName || null,
      reason,
      flaggedBy: caller.uid,
      flaggedByEmail: callerEmail,
      flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
      resolved: false,
    });

    // Update original transaction
    await txRef.update({
      flagged: true,
      flaggedReason: reason,
      flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log activity
    await db.collection('admin_activity').add({
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      action: 'flag_transaction',
      targetUserId: userId,
      details: `Flagged transaction ${transactionId}: ${reason}`,
      ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    await auditLog({
      userId: caller.uid,
      operation: 'adminFlagTransaction',
      result: 'success',
      metadata: { transactionId, userId, reason },
      ipHash: hashIp(context),
    });

    return { success: true, message: 'Transaction flagged for review.' };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to flag transaction: ${error.message}`);
  }
});

/**
 * Admin: Get flagged transactions.
 */
exports.adminGetFlaggedTransactions = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'auditor');

  const { limit: queryLimit, resolved } = data || {};
  const fetchLimit = Math.min(queryLimit || 50, 200);

  try {
    let query = db.collection('flagged_transactions').orderBy('flaggedAt', 'desc');

    if (resolved !== undefined) {
      query = query.where('resolved', '==', resolved);
    }

    query = query.limit(fetchLimit);

    const snapshot = await query.get();
    const flagged = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      flaggedAt: doc.data().flaggedAt?.toDate?.()?.toISOString() || null,
    }));

    return { success: true, flagged };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to get flagged transactions: ${error.message}`);
  }
});

/**
 * Admin: Resolve a flagged transaction.
 */
exports.adminResolveFlaggedTransaction = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_supervisor');

  const { transactionId, resolution } = data;

  if (!transactionId || !resolution) {
    throw new functions.https.HttpsError('invalid-argument', 'transactionId and resolution are required.');
  }

  try {
    const flagRef = db.collection('flagged_transactions').doc(transactionId);
    const flagDoc = await flagRef.get();

    if (!flagDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Flagged transaction not found.');
    }

    const callerEmail = (await admin.auth().getUser(caller.uid)).email || 'unknown';

    await flagRef.update({
      resolved: true,
      resolution,
      resolvedBy: caller.uid,
      resolvedByEmail: callerEmail,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log activity
    await db.collection('admin_activity').add({
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      action: 'resolve_flagged_transaction',
      details: `Resolved flagged transaction ${transactionId}: ${resolution}`,
      ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, message: 'Flagged transaction resolved.' };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to resolve: ${error.message}`);
  }
});

/**
 * Admin: Get fraud alerts.
 */
exports.adminGetFraudAlerts = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'auditor');

  const { limit: queryLimit, status: filterStatus, severity: filterSeverity } = data || {};
  const fetchLimit = Math.min(queryLimit || 50, 200);

  try {
    let query = db.collection('fraud_alerts').orderBy('createdAt', 'desc');

    if (filterStatus) {
      query = query.where('status', '==', filterStatus);
    }

    query = query.limit(fetchLimit);

    const snapshot = await query.get();
    const alerts = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
    }));

    // Filter by severity client-side since Firestore can't do 2 where + orderBy without index
    const filtered = filterSeverity
      ? alerts.filter(a => a.severity === filterSeverity)
      : alerts;

    return { success: true, alerts: filtered };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to get fraud alerts: ${error.message}`);
  }
});

/**
 * Admin: Resolve a fraud alert.
 */
exports.adminResolveFraudAlert = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_supervisor');

  const { alertId, resolution, action } = data;
  if (!alertId || !resolution) {
    throw new functions.https.HttpsError('invalid-argument', 'alertId and resolution are required.');
  }

  try {
    const alertRef = db.collection('fraud_alerts').doc(alertId);
    const alertDoc = await alertRef.get();
    if (!alertDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Fraud alert not found.');
    }

    const alertData = alertDoc.data();

    const callerEmail = (await admin.auth().getUser(caller.uid)).email || 'unknown';

    await alertRef.update({
      status: 'resolved',
      resolution,
      resolvedAction: action || 'none',
      resolvedBy: caller.uid,
      resolvedByEmail: callerEmail,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // If action is 'block', block the user account
    if (action === 'block' && alertData.userId) {
      await db.collection('users').doc(alertData.userId).update({
        accountBlocked: true,
        accountBlockedAt: admin.firestore.FieldValue.serverTimestamp(),
        accountBlockedBy: 'admin',
        accountBlockReason: `Fraud alert: ${resolution}`,
      });

      await sendPushNotification(alertData.userId, {
        title: 'Account Blocked',
        body: 'Your account has been blocked for security review. Please contact support.',
        type: 'security',
        data: { action: 'account_blocked', blockedBy: 'admin' },
      });
    }

    // Log activity
    await db.collection('admin_activity').add({
      uid: caller.uid,
      email: callerEmail,
      role: caller.role,
      action: 'resolve_fraud_alert',
      targetUserId: alertData.userId,
      details: `Resolved fraud alert ${alertId}: ${resolution} (action: ${action || 'none'})`,
      ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, message: 'Fraud alert resolved.' };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to resolve alert: ${error.message}`);
  }
});

/**
 * Admin: Get fraud alert statistics.
 */
exports.adminGetFraudStats = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  await verifyAdmin(context, 'auditor');

  try {
    const openSnapshot = await db.collection('fraud_alerts').where('status', '==', 'open').count().get();
    const highSnapshot = await db.collection('fraud_alerts').where('status', '==', 'open').where('severity', '==', 'high').count().get();
    const totalSnapshot = await db.collection('fraud_alerts').count().get();
    const resolvedSnapshot = await db.collection('fraud_alerts').where('status', '==', 'resolved').count().get();

    return {
      success: true,
      stats: {
        open: openSnapshot.data().count,
        high: highSnapshot.data().count,
        total: totalSnapshot.data().count,
        resolved: resolvedSnapshot.data().count,
      },
    };
  } catch (error) {
    throw new functions.https.HttpsError('internal', `Failed to get fraud stats: ${error.message}`);
  }
});

// ============================================================
// SMILE ID PHONE VERIFICATION
// ============================================================

// Getter wrappers defer .value() to runtime (required by SDK 5.x params API).
// Note: usage sites read .value; NOT .value() — the getter evaluates on access.
const SMILE_ID_API_KEY = { get value() { return SMILE_ID_API_KEY_PARAM.value() || ''; } };
const SMILE_ID_PARTNER_ID = { get value() { return SMILE_ID_PARTNER_ID_PARAM.value() || '8244'; } };

/**
 * Smile ID API base URL — environment-aware.
 * Set via: firebase functions:config:set smileid.environment="production"
 * Fails secure: production deployment requires explicit config.
 */
function computeSmileIdBaseUrl() {
  const smileEnv = SMILE_ID_ENVIRONMENT.value();
  const appEnv = APP_ENVIRONMENT.value();

  if (smileEnv === 'production') {
    return 'api.smileidentity.com';
  } else if (smileEnv === 'sandbox' || smileEnv === 'test') {
    return 'testapi.smileidentity.com';
  } else {
    // No explicit smileid.environment set
    if (appEnv === 'production') {
      // FAIL SECURE: Don't allow production without explicit Smile ID config
      logError('CRITICAL: smileid.environment not set in production deployment');
      // Return production URL to avoid silent test-API usage in prod
      return 'api.smileidentity.com';
    }
    // Default to sandbox for development
    return 'testapi.smileidentity.com';
  }
}
const SMILE_ID_BASE_URL = { get value() { return computeSmileIdBaseUrl(); } };

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
      hostname: SMILE_ID_BASE_URL.value,
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
      timeout: HTTP_TIMEOUT_MS,
    };

    const req = https.request(options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => responseData += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(responseData);
          resolve(json);
        } catch (e) {
          reject(new Error('Failed to parse Smile ID response'));
        }
      });
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`Smile ID request timed out after ${HTTP_TIMEOUT_MS}ms: ${method} ${path}`));
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// Verify phone number belongs to ID holder
exports.verifyPhoneNumber = functions
  .runWith({ secrets: [SMILE_ID_API_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { phoneNumber, country, firstName, lastName, idNumber } = data;

  // Validate required fields
  if (!phoneNumber || !country) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Phone number and country are required.');
  }

  // Validate phone number format (E.164)
  // Country code mapping for validation context
  const countryDialCodes = { NG: '234', GH: '233', KE: '254', ZA: '27', TZ: '255', UG: '256' };
  const dialCode = countryDialCodes[country.toUpperCase()] || '233';
  validatePhoneNumber(phoneNumber, dialCode);

  // Validate Smile ID is properly configured
  if (!SMILE_ID_API_KEY || !SMILE_ID_PARTNER_ID) {
    logError('Smile ID configuration missing', {
      hasApiKey: !!SMILE_ID_API_KEY,
      hasPartnerId: !!SMILE_ID_PARTNER_ID,
    });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'KYC service not properly configured');
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
    logInfo('Verifying phone', { phoneNumber: maskPii.phone(phoneNumber), country });

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

    logInfo('Smile ID request', {
      country: requestBody.country,
      idType: requestBody.id_type,
      jobType: requestBody.sec_params?.job_type,
    });

    const response = await smileIdRequest('POST', '/v2/verify-phone-number', requestBody);

    logInfo('Smile ID response', { resultCode: response.ResultCode || response.result_code });

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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Phone verification error', { error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Verification failed. Please try again.');
  }
});

// Check if phone verification is supported for a country
exports.checkPhoneVerificationSupport = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

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

// ============================================================
// FEE CALCULATION (Tiered structure)
// ============================================================

/**
 * Calculate transaction fee using a tiered sliding scale.
 * Smaller amounts pay a higher percentage, larger amounts pay less.
 * This keeps daily small transactions affordable while generating
 * fair revenue on larger transfers.
 *
 * Same Country Tiers:
 *   0 - 500 major units:     1.5%   (min fee: 50 minor units / 0.50 major)
 *   501 - 5,000:             1.0%
 *   5,001 - 50,000:          0.75%
 *   50,001+:                 0.5%
 *
 * Cross Country Tiers:
 *   0 - 500 major units:     3.0%   (min fee: 100 minor units / 1.00 major)
 *   501 - 5,000:             2.0%
 *   5,001 - 50,000:          1.5%
 *   50,001+:                 1.0%
 *
 * @param {number} amount - Amount in minor units (e.g. 150000 = 1500.00 major)
 * @param {boolean} isCrossCountry - true if sender and recipient have different currencies
 * @returns {number} Fee in minor units (integer)
 */
function calculateFee(amount, isCrossCountry) {
  const majorAmount = amount / 100;
  let rate;

  if (isCrossCountry) {
    if (majorAmount <= 500) rate = 0.03;
    else if (majorAmount <= 5000) rate = 0.02;
    else if (majorAmount <= 50000) rate = 0.015;
    else rate = 0.01;
    return Math.round(Math.max(amount * rate, 100)); // min 100 minor units (1.00 major)
  } else {
    if (majorAmount <= 500) rate = 0.015;
    else if (majorAmount <= 5000) rate = 0.01;
    else if (majorAmount <= 50000) rate = 0.0075;
    else rate = 0.005;
    return Math.round(Math.max(amount * rate, 50)); // min 50 minor units (0.50 major)
  }
}

// ============================================================
// PREVIEW TRANSFER (Get exact fee before sending)
// ============================================================

exports.previewTransfer = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const senderUid = context.auth.uid;

  // Rate limit preview requests
  await enforceRateLimit(senderUid, 'previewTransfer');

  const { amount, recipientWalletId } = data;

  if (!amount || typeof amount !== 'number' || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID, 'Amount must be positive.');
  }

  if (!recipientWalletId || typeof recipientWalletId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Recipient wallet ID is required.');
  }

  try {
    // Get sender wallet
    const senderWalletDoc = await db.collection('wallets').doc(senderUid).get();

    if (!senderWalletDoc.exists) {
      throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Sender wallet not found.');
    }

    const senderData = senderWalletDoc.data();
    const senderBalance = Number(senderData.balance) || 0;
    const senderCurrency = senderData.currency || 'GHS';

    // Find recipient by walletId field
    const recipientQuery = await db.collection('wallets')
      .where('walletId', '==', recipientWalletId)
      .limit(1)
      .get();

    if (recipientQuery.empty) {
      throwAppError(ERROR_CODES.TXN_RECIPIENT_NOT_FOUND, 'Recipient not found.');
    }

    const recipientData = recipientQuery.docs[0].data();
    const recipientCurrency = recipientData.currency || 'GHS';

    // Calculate fee using tiered structure
    const isCrossCountry = senderCurrency !== recipientCurrency;
    const fee = calculateFee(amount, isCrossCountry);
    const totalDebit = amount + fee;
    const sufficient = senderBalance >= totalDebit;

    // Cross-currency conversion if needed
    let creditAmount = amount;
    let exchangeRate = null;

    if (isCrossCountry) {
      const ratesDoc = await db.collection('app_config').doc('exchange_rates').get();
      const rates = ratesDoc.exists ? ratesDoc.data().rates : {};

      const senderRate = rates[senderCurrency] || 1;
      const recipientRate = rates[recipientCurrency] || 1;

      // Convert: sender currency -> USD -> recipient currency
      exchangeRate = senderRate > 0 ? recipientRate / senderRate : 0;
      creditAmount = Math.round(amount * exchangeRate);
    }

    return {
      fee: fee,
      totalDebit: totalDebit,
      creditAmount: creditAmount,
      exchangeRate: exchangeRate,
      sufficient: sufficient,
      senderCurrency: senderCurrency,
      recipientCurrency: recipientCurrency,
      isCrossCountry: isCrossCountry,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Preview transfer error', { error: error.message, senderUid });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Could not preview transfer. Please try again.');
  }
});

exports.sendMoney = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  // 1. Check authentication
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const senderUid = context.auth.uid;
  const correlation = createCorrelationContext(context, 'sendMoney');

  // Enforce KYC verification before financial operation
  await enforceKyc(senderUid);

  // Enforce persistent rate limiting (20 sends per hour)
  await enforceRateLimit(senderUid, 'sendMoney');

  const { recipientWalletId, amount, note, items, idempotencyKey } = data;

  // 2. Validate inputs
  if (!recipientWalletId || typeof recipientWalletId !== 'string') {
    throwAppError(ERROR_CODES.TXN_RECIPIENT_NOT_FOUND, 'Invalid recipient wallet ID.');
  }

  if (typeof amount !== 'number' || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID, 'Amount must be positive.');
  }

  if (amount < 1) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_TOO_SMALL, 'Minimum transfer amount is 1.');
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
      const validatedSender = validateWalletDocument(senderData, 'sendMoney sender wallet');
      const senderBalance = validatedSender.balance;

      // Check if sender account is blocked
      const senderUserDoc = await transaction.get(db.collection('users').doc(senderUid));
      if (senderUserDoc.exists && senderUserDoc.data().accountBlocked === true) {
        throwAppError(ERROR_CODES.WALLET_SUSPENDED, 'Your account is blocked. Please unblock it from your profile to make transfers.');
      }

      // Fee is calculated after recipient lookup (needs recipient currency)
      let fee, totalDebit;

      // Balance check moved below after fee calculation

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
      validateWalletDocument(recipientData, 'sendMoney recipient wallet');

      // Calculate fee using tiered structure (needs recipient currency)
      const senderCurrency = senderData.currency || 'GHS';
      const recipientCurrency = recipientData.currency || 'GHS';
      const isCrossCountry = senderCurrency !== recipientCurrency;
      fee = calculateFee(amount, isCrossCountry);
      totalDebit = amount + fee;

      // Check balance with actual fee
      if (senderBalance < totalDebit) {
        throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS);
      }

      // Enforce daily/monthly spending limits
      const DAILY_LIMIT = 5000000;   // 50,000 major units in minor units
      const MONTHLY_LIMIT = 50000000; 
      const currentDailySpent = Number(senderData.dailySpent) || 0;
      const currentMonthlySpent = Number(senderData.monthlySpent) || 0;

      if (currentDailySpent + totalDebit > DAILY_LIMIT) {
        throwAppError(ERROR_CODES.TXN_AMOUNT_TOO_LARGE,
          `Daily spending limit of ${DAILY_LIMIT} exceeded. Current: ${currentDailySpent.toFixed(2)}, requested: ${totalDebit.toFixed(2)}`);
      }
      if (currentMonthlySpent + totalDebit > MONTHLY_LIMIT) {
        throwAppError(ERROR_CODES.TXN_AMOUNT_TOO_LARGE,
          `Monthly spending limit of ${MONTHLY_LIMIT} exceeded. Current: ${currentMonthlySpent.toFixed(2)}, requested: ${totalDebit.toFixed(2)}`);
      }

      // Fetch exchange rates (needed for currency conversion and fee collection)
      const ratesDoc = await db.collection('app_config').doc('exchange_rates').get();
      const rates = ratesDoc.exists ? ratesDoc.data().rates : {};

      // Get user names
      // senderUserDoc already fetched above for block check
      const recipientUserDoc = await transaction.get(db.collection('users').doc(recipientUid));

      // Use legalName (title-cased) if KYC verified, otherwise fullName
      const senderData_ = senderUserDoc.exists ? senderUserDoc.data() : {};
      const recipientData_ = recipientUserDoc.exists ? recipientUserDoc.data() : {};

      const senderDisplayName = senderData_.legalName
        ? titleCaseName(senderData_.legalName)
        : (senderData_.fullName || 'Unknown');
      const recipientDisplayName = recipientData_.legalName
        ? titleCaseName(recipientData_.legalName)
        : (recipientData_.fullName || 'Unknown');

      // Store MASKED names in transaction records for privacy
      const senderName = maskName(senderDisplayName);
      const recipientName = maskName(recipientDisplayName);

      // Check if recipient account is blocked
      if (recipientUserDoc.exists && recipientUserDoc.data().accountBlocked === true) {
        throwAppError(ERROR_CODES.WALLET_SUSPENDED, 'Recipient account is suspended. Transfer cannot be completed.');
      }

      // Generate transaction ID
      const txId = generateSecureTransactionId();
      const now = new Date();

      // Deduct from sender
      transaction.update(senderWalletRef, {
        balance: admin.firestore.FieldValue.increment(-totalDebit),
        availableBalance: admin.firestore.FieldValue.increment(-totalDebit),
        dailySpent: admin.firestore.FieldValue.increment(totalDebit),
        monthlySpent: admin.firestore.FieldValue.increment(totalDebit),
        updatedAt: timestamps.serverTimestamp()
      });

      // Convert amount if cross-country transfer
      let creditAmount = amount; // Default: same currency, no conversion
      let txExchangeRate = null;

      if (isCrossCountry) {
        const senderRate = rates[senderCurrency] || 1;
        const recipientRate = rates[recipientCurrency] || 1;
        txExchangeRate = senderRate > 0 ? recipientRate / senderRate : 0;
        creditAmount = Math.round(amount * txExchangeRate);
      }

      // Add converted amount to recipient
      transaction.update(recipientRef, {
        balance: admin.firestore.FieldValue.increment(creditAmount),
        availableBalance: admin.firestore.FieldValue.increment(creditAmount),
        updatedAt: timestamps.serverTimestamp()
      });

      // ============================================
      // COLLECT FEE TO PLATFORM WALLET
      // ============================================
      // senderCurrency already declared above
      // rates already fetched above for currency conversion
      const exchangeRate = rates[senderCurrency] || 1;
      const feeInUSD = fee / exchangeRate;
      
      // Update platform wallet USD balance
      const platformWalletRef = db.collection('wallets').doc('platform');
      transaction.update(platformWalletRef, {
        totalBalanceUSD: admin.firestore.FieldValue.increment(feeInUSD),
        totalTransactions: admin.firestore.FieldValue.increment(1),
        totalFeesCollected: admin.firestore.FieldValue.increment(1),
        updatedAt: timestamps.serverTimestamp()
      });
      
      // Update currency-specific balance
      const currencyBalanceRef = db.collection('wallets').doc('platform').collection('balances').doc(senderCurrency);
      transaction.set(currencyBalanceRef, {
        currency: senderCurrency,
        amount: admin.firestore.FieldValue.increment(fee),
        usdEquivalent: admin.firestore.FieldValue.increment(feeInUSD),
        txCount: admin.firestore.FieldValue.increment(1),
        lastTransactionAt: timestamps.serverTimestamp(),
        updatedAt: timestamps.serverTimestamp()
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
        createdAt: timestamps.serverTimestamp()
      });

      // Transaction data
      // Sanitize items: must be array of strings, max 20 items, max 100 chars each
      const sanitizedItems = Array.isArray(items)
        ? items.filter(i => typeof i === 'string').slice(0, 20).map(i => i.substring(0, 100))
        : [];

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
        items: sanitizedItems.length > 0 ? sanitizedItems : null,
        status: 'completed',
        createdAt: timestamps.serverTimestamp(),
        completedAt: timestamps.serverTimestamp(),
        reference: `TXN-${now.getTime()}`,
        exchangeRate: txExchangeRate,
        convertedAmount: isCrossCountry ? creditAmount : null,
        failureReason: null,
      };

      // Sender transaction record
      transaction.set(
        db.collection('users').doc(senderUid).collection('transactions').doc(txId),
        { ...baseTxData, type: 'send' }
      );

      // Recipient transaction record (amount in recipient's currency)
      transaction.set(
        db.collection('users').doc(recipientUid).collection('transactions').doc(txId),
        {
          ...baseTxData,
          type: 'receive',
          fee: 0,
          amount: creditAmount,
          currency: recipientCurrency,
        }
      );

      return {
        transactionId: txId,
        amount: amount,
        fee: fee,
        creditAmount: creditAmount,
        exchangeRate: txExchangeRate,
        recipientName: recipientName,
        senderName: senderName,
        recipientUid: recipientUid,
        senderCurrency: senderCurrency,
        recipientCurrency: recipientCurrency,
        newBalance: senderBalance - totalDebit
      };
    });

    logFinancialOperation('sendMoney', 'success', { transactionId: result.transactionId });

    await auditLog({
      userId: senderUid, operation: 'sendMoney', result: 'success',
      amount, currency: result.currency || 'GHS',
      metadata: { transactionId: result.transactionId, recipientWalletId, fee: result.fee, ...correlation.toAuditContext() },
      ipHash: hashIp(context),
    });

    // Send push notifications to both parties (using masked names for privacy)
    await Promise.all([
      sendPushNotification(senderUid, {
        title: 'Money Sent',
        body: `You sent ${result.senderCurrency || ''}${(amount / 100).toFixed(2)} to ${result.recipientName || 'a wallet'}`,
        type: 'transaction',
        data: { action: 'money_sent', amount: amount.toString(), transactionId: result.transactionId },
      }),
      sendPushNotification(result.recipientUid, {
        title: 'Money Received',
        body: `You received ${result.recipientCurrency || ''}${(amount / 100).toFixed(2)} from ${result.senderName || 'a wallet'}`,
        type: 'transaction',
        data: { action: 'money_received', amount: amount.toString(), transactionId: result.transactionId },
      }),
    ]);

    // Run fraud detection
    await checkForFraud(senderUid, { id: result.transactionId, type: 'send', amount, currency: result.senderCurrency });

    return { success: true, ...result, _correlationId: correlation.correlationId };

  } catch (error) {
    logError('sendMoney error', { error: error.message });
    await auditLog({
      userId: senderUid, operation: 'sendMoney', result: 'failure',
      amount,
      metadata: { recipientWalletId, ...correlation.toAuditContext() },
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
// MOMO_WEBHOOK_SECRET wrapper: defer .value() to runtime. Usage stays `MOMO_WEBHOOK_SECRET.value` (no parens).
const MOMO_WEBHOOK_SECRET = { get value() { return MOMO_WEBHOOK_SECRET_PARAM.value() || ''; } };

// MOMO_CONFIG with getters: defers secret resolution to runtime (required by params API).
// Usage at call sites stays identical: MOMO_CONFIG.collections.apiKey, MOMO_CONFIG.environment, etc.
const MOMO_CONFIG = {
  collections: {
    get subscriptionKey() { return MOMO_COLLECTIONS_SUBSCRIPTION_KEY_PARAM.value() || ''; },
    get apiUser()         { return MOMO_COLLECTIONS_API_USER_PARAM.value() || ''; },
    get apiKey()          { return MOMO_COLLECTIONS_API_KEY_PARAM.value() || ''; },
  },
  disbursements: {
    get subscriptionKey() { return MOMO_DISBURSEMENTS_SUBSCRIPTION_KEY_PARAM.value() || ''; },
    get apiUser()         { return MOMO_DISBURSEMENTS_API_USER_PARAM.value() || ''; },
    get apiKey()          { return MOMO_DISBURSEMENTS_API_KEY_PARAM.value() || ''; },
  },
  environment: (() => {
    const momoEnv = MOMO_ENVIRONMENT.value();
    const appEnv = APP_ENVIRONMENT.value();

    if (momoEnv) {
      // Prevent sandbox in production
      if (appEnv === 'production' && momoEnv === 'sandbox') {
        logError('CRITICAL: Cannot use MoMo sandbox in production');
        return 'production'; // Fail secure: use production
      }
      return momoEnv;
    }

    // No explicit momo.environment set
    if (appEnv === 'production') {
      logError('CRITICAL: momo.environment not set in production — defaulting to production');
      return 'production';
    }

    logWarning('MoMo environment not set, defaulting to sandbox for development');
    return 'sandbox';
  })(),
  callbackUrl: MOMO_WEBHOOK_SECRET
    ? `https://us-central1-qr-wallet-1993.cloudfunctions.net/momoWebhook?token=${MOMO_WEBHOOK_SECRET}`
    : 'https://us-central1-qr-wallet-1993.cloudfunctions.net/momoWebhook',
};

// Set baseUrl based on resolved environment
MOMO_CONFIG.baseUrl = MOMO_CONFIG.environment === 'production'
  ? 'proxy.momoapi.mtn.com'
  : 'sandbox.momodeveloper.mtn.com';

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
      path: `/${product === 'collections' ? 'collection' : 'disbursement'}/token/`,
      method: 'POST',
      headers: {
        'Authorization': `Basic ${credentials}`,
        'Ocp-Apim-Subscription-Key': config.subscriptionKey,
        'Content-Type': 'application/json',
      },
      timeout: HTTP_TIMEOUT_MS,
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
            reject(new Error('Failed to get MoMo access token'));
          }
        } catch (e) {
          reject(new Error('Failed to parse MoMo token response'));
        }
      });
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`MoMo token request timed out after ${HTTP_TIMEOUT_MS}ms`));
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
      path: `/${product === 'collections' ? 'collection' : 'disbursement'}${path}`,
      method: method,
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'X-Reference-Id': referenceId,
        'X-Target-Environment': MOMO_CONFIG.environment,
        'Ocp-Apim-Subscription-Key': config.subscriptionKey,
        'Content-Type': 'application/json',
      },
      timeout: HTTP_TIMEOUT_MS,
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

    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`MoMo API request timed out after ${HTTP_TIMEOUT_MS}ms: ${method} ${path}`));
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

exports.momoRequestToPay = functions
  .runWith({ secrets: [MOMO_COLLECTIONS_SUBSCRIPTION_KEY_PARAM, MOMO_COLLECTIONS_API_USER_PARAM, MOMO_COLLECTIONS_API_KEY_PARAM, MOMO_DISBURSEMENTS_SUBSCRIPTION_KEY_PARAM, MOMO_DISBURSEMENTS_API_USER_PARAM, MOMO_DISBURSEMENTS_API_KEY_PARAM, MOMO_WEBHOOK_SECRET_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { amount, currency, phoneNumber, payerMessage, payeeNote, idempotencyKey } = data;
  const userId = context.auth.uid;
  const correlation = createCorrelationContext(context, 'momoRequestToPay');

  // Fail fast if MoMo collections API is not configured
  requireServiceReady('momo_collections');

  if (!amount || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID);
  }
  if (!phoneNumber) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Phone number is required.');
  }

  // Validate currency and phone number format
  const validatedCurrency = validateCurrency(currency, 'EUR');
  const validatedPhone = validatePhoneNumber(phoneNumber);

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Check if account is blocked
  const userBlockDoc = await db.collection('users').doc(userId).get();
  if (userBlockDoc.exists && userBlockDoc.data().accountBlocked === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Your account is suspended. All transactions are disabled. Contact support.');
  }

  // Enforce persistent rate limiting (10 MoMo payments per hour)
  await enforceRateLimit(userId, 'momoRequestToPay');

  return withIdempotency(idempotencyKey, 'momoRequestToPay', userId, async () => {
  try {
    // Generate unique reference ID
    const referenceId = crypto.randomUUID();

    // Create request to pay
    const response = await momoRequest('collections', 'POST', '/v1_0/requesttopay', {
      amount: amount.toString(),
      currency: MOMO_CONFIG.environment === 'sandbox' ? 'EUR' : currency, // Sandbox=EUR, Production=actual currency
      externalId: referenceId,
      payer: {
        partyIdType: 'MSISDN',
        partyId: validatedPhone.replace('+', ''),
      },
      payerMessage: payerMessage || 'Add money to QR Wallet',
      payeeNote: payeeNote || 'Wallet deposit',
    }, referenceId);

    logFinancialOperation('momoRequestToPay', 'response_received', { statusCode: response.statusCode });

    if (response.statusCode === 202) {
      // Request accepted - store pending transaction
      await db.collection('momo_transactions').doc(referenceId).set({
        type: 'collection',
        userId: userId,
        amount: amount,
        currency: currency || 'EUR',
        phoneNumber: validatedPhone,
        status: TRANSACTION_STATES.PENDING,
        referenceId: referenceId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        statusHistory: [{ from: null, to: TRANSACTION_STATES.PENDING, timestamp: timestamps.firestoreNow() }],
      });

      await auditLog({
        userId, operation: 'momoRequestToPay', result: 'success',
        amount, currency: currency || 'EUR',
        metadata: { referenceId, phoneNumber: validatedPhone, ...correlation.toAuditContext() },
        ipHash: hashIp(context),
      });

      return {
        success: true,
        referenceId: referenceId,
        status: TRANSACTION_STATES.PENDING,
        message: 'Please approve the payment on your phone',
        _correlationId: correlation.correlationId,
      };
    } else {
      throwServiceError('momo', new Error('Failed to initiate payment'), { responseData: response.data });
    }
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('MoMo RequestToPay error', { error: error.message });
    await auditLog({
      userId, operation: 'momoRequestToPay', result: 'failure',
      amount, currency: currency || 'EUR',
      metadata: { ...correlation.toAuditContext() },
      error: error.message,
      ipHash: hashIp(context),
    });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Mobile money payment failed. Please try again.');
  }
  });
});

// ============================================================
// MTN MOMO - CHECK TRANSACTION STATUS
// ============================================================

exports.momoCheckStatus = functions
  .runWith({ secrets: [MOMO_COLLECTIONS_SUBSCRIPTION_KEY_PARAM, MOMO_COLLECTIONS_API_USER_PARAM, MOMO_COLLECTIONS_API_KEY_PARAM, MOMO_DISBURSEMENTS_SUBSCRIPTION_KEY_PARAM, MOMO_DISBURSEMENTS_API_USER_PARAM, MOMO_DISBURSEMENTS_API_KEY_PARAM, MOMO_WEBHOOK_SECRET_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;

  // KYC required — this function can credit wallets on SUCCESSFUL status
  await enforceKyc(userId);

  const { referenceId, type } = data;

  if (!referenceId) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Reference ID is required.');
  }

  try {
    const product = type === 'disbursement' ? 'disbursements' : 'collections';
    const path = type === 'disbursement' ? `/v1_0/transfer/${referenceId}` : `/v1_0/requesttopay/${referenceId}`;

    const response = await momoRequest(product, 'GET', path, null, referenceId);

    logInfo('MoMo status check response', { statusCode: response.statusCode, status: response.data?.status });

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
              validateWalletDocument(walletData, 'momoCheckStatus wallet');

              if (txData.type === 'collection') {
                // Add money - credit wallet
                const creditBalance = safeAdd(walletData.balance, txData.amount, 'momoCheckStatus credit');
                transaction.update(walletDoc.ref, {
                  balance: creditBalance,
                  availableBalance: creditBalance - (walletData.heldBalance || 0),
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
                  type: 'withdraw',
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

            transaction.update(txRef, {
              ...buildStateTransitionFields(txData.status, status, referenceId),
              providerStatus: status,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          });

          // Send push notification for completed MoMo transaction
          const checkNotifType = txData.type === 'collection' ? 'Deposit' : 'Withdrawal';
          await sendPushNotification(txData.userId, {
            title: `${checkNotifType} Successful`,
            body: `Your MTN MoMo ${checkNotifType.toLowerCase()} of ${txData.currency || ''} ${txData.amount?.toFixed(2) || '0.00'} has been completed`,
            type: 'transaction',
            data: { action: txData.type === 'collection' ? 'deposit' : 'withdrawal_completed', amount: txData.amount?.toString(), referenceId },
          });

          } else if (status === 'FAILED' || status === 'REJECTED') {
          // Update momo transaction status
          await updateTransactionState(txRef, status, {
            providerStatus: status,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Update user transaction to failed
          const userTxRef = db.collection('users').doc(txData.userId).collection('transactions').doc(referenceId);
          const userTxDoc = await userTxRef.get();
          if (userTxDoc.exists) {
            await userTxRef.update({
              status: 'failed',
              failedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          // Refund wallet for failed disbursements (money was already debited)
          if (txData.type === 'disbursement') {
            const walletSnapshot = await db.collection('wallets')
              .where('userId', '==', txData.userId)
              .limit(1)
              .get();

            if (!walletSnapshot.empty) {
              const walletDoc = walletSnapshot.docs[0];
              const walletData = walletDoc.data();
              const refundBalance = safeAdd(walletData.balance, txData.amount, 'momoCheckStatus refund');
              await walletDoc.ref.update({
                balance: refundBalance,
                availableBalance: refundBalance - (walletData.heldBalance || 0),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              logInfo('Refunded wallet for failed MoMo disbursement', {
                userId: txData.userId,
                amount: txData.amount,
                referenceId,
              });
            }
          }
        } else {
          // Other statuses (PENDING etc) - just update momo transaction
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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('MoMo status check error', { error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Unable to check transaction status. Please try again.');
  }
});

// ============================================================
// MTN MOMO DISBURSEMENTS - TRANSFER (Withdraw)
// ============================================================

exports.momoTransfer = functions
  .runWith({ secrets: [MOMO_COLLECTIONS_SUBSCRIPTION_KEY_PARAM, MOMO_COLLECTIONS_API_USER_PARAM, MOMO_COLLECTIONS_API_KEY_PARAM, MOMO_DISBURSEMENTS_SUBSCRIPTION_KEY_PARAM, MOMO_DISBURSEMENTS_API_USER_PARAM, MOMO_DISBURSEMENTS_API_KEY_PARAM, MOMO_WEBHOOK_SECRET_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { amount, currency, phoneNumber, payerMessage, payeeNote, idempotencyKey } = data;
  const userId = context.auth.uid;
  const correlation = createCorrelationContext(context, 'momoTransfer');

  // Fail fast if MoMo disbursements API is not configured
  requireServiceReady('momo_disbursements');

  if (!amount || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID);
  }
  if (!phoneNumber) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Phone number is required.');
  }

  // Validate currency and phone number format
  const validatedCurrency = validateCurrency(currency, 'EUR');
  const validatedPhone = validatePhoneNumber(phoneNumber);

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  // Check if account is blocked
  const userBlockDoc = await db.collection('users').doc(userId).get();
  if (userBlockDoc.exists && userBlockDoc.data().accountBlocked === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Your account is suspended. All transactions are disabled. Contact support.');
  }

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
    const validated = validateWalletDocument(walletData, 'momoTransfer wallet');

    if (validated.balance < amount) {
      throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS);
    }

    // Generate unique reference ID
    const referenceId = crypto.randomUUID();

    // Debit wallet first
    await db.runTransaction(async (transaction) => {
      const freshWallet = await transaction.get(walletDoc.ref);
      const freshData = freshWallet.data();
      validateWalletDocument(freshData, 'momoTransfer fresh wallet');
      const newBalance = safeSubtract(freshData.balance, amount, 'momoTransfer debit');

      transaction.update(walletDoc.ref, {
        balance: newBalance,
        availableBalance: newBalance - (freshData.heldBalance || 0),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Store pending withdrawal
      transaction.set(db.collection('momo_transactions').doc(referenceId), {
        type: 'disbursement',
        userId: userId,
        amount: amount,
        currency: currency || 'EUR',
        phoneNumber: validatedPhone,
        status: TRANSACTION_STATES.PENDING,
        referenceId: referenceId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        statusHistory: [{ from: null, to: TRANSACTION_STATES.PENDING, timestamp: timestamps.firestoreNow() }],
      });

      // Store pending withdrawal
      transaction.set(db.collection('momo_transactions').doc(referenceId), {
        type: 'disbursement',
        userId: userId,
        amount: amount,
        currency: currency || 'EUR',
        phoneNumber: validatedPhone,
        status: TRANSACTION_STATES.PENDING,
        referenceId: referenceId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        statusHistory: [{ from: null, to: TRANSACTION_STATES.PENDING, timestamp: timestamps.firestoreNow() }],
      });

      // Record in user's transactions subcollection for UI display
      transaction.set(db.collection('users').doc(userId).collection('transactions').doc(referenceId), {
        id: referenceId,
        type: 'withdraw',
        amount: amount,
        currency: currency || 'EUR',
        method: 'MTN MoMo',
        phoneNumber: validatedPhone,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    });

    // Create transfer request
    const response = await momoRequest('disbursements', 'POST', '/v1_0/transfer', {
      amount: amount.toString(),
      currency: MOMO_CONFIG.environment === 'sandbox' ? 'EUR' : currency, // Sandbox=EUR, Production=actual currency
      externalId: referenceId,
      payee: {
        partyIdType: 'MSISDN',
        partyId: validatedPhone.replace('+', ''),
      },
      payerMessage: payerMessage || 'Withdrawal from QR Wallet',
      payeeNote: payeeNote || 'Wallet withdrawal',
    }, referenceId);

    logFinancialOperation('momoTransfer', 'response_received', { statusCode: response.statusCode });

    if (response.statusCode === 202) {
      await auditLog({
        userId, operation: 'momoTransfer', result: 'success',
        amount, currency: currency || 'EUR',
        metadata: { referenceId, phoneNumber: validatedPhone, ...correlation.toAuditContext() },
        ipHash: hashIp(context),
      });

     // Send push notification for MoMo withdrawal
      await sendPushNotification(userId, {
        title: 'Withdrawal Initiated',
        body: `Your MTN MoMo withdrawal of ${currency || 'EUR'} ${amount.toFixed(2)} is being processed`,
        type: 'transaction',
        data: { action: 'withdrawal_initiated', amount: amount.toString(), referenceId },
      });

      return {
        success: true,
        referenceId: referenceId,
        status: 'PENDING',
        message: 'Withdrawal is being processed',
        _correlationId: correlation.correlationId,
      };
    } else {
      // Refund wallet if transfer failed
      await db.runTransaction(async (transaction) => {
        const freshWallet = await transaction.get(walletDoc.ref);
        const freshRefundData = freshWallet.data();
        validateWalletDocument(freshRefundData, 'momoTransfer refund wallet');
       const refundBalance = safeAdd(freshRefundData.balance, amount, 'momoTransfer refund');

        transaction.update(walletDoc.ref, {
          balance: refundBalance,
          availableBalance: refundBalance - (freshRefundData.heldBalance || 0),
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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('MoMo Transfer error', { error: error.message });
    await auditLog({
      userId, operation: 'momoTransfer', result: 'failure',
      amount, currency: currency || 'EUR',
      metadata: { ...correlation.toAuditContext() },
      error: error.message,
      ipHash: hashIp(context),
    });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Mobile money transfer failed. Please try again.');
  }
  });
});

// ============================================================
// MTN MOMO - GET BALANCE
// ============================================================

exports.momoGetBalance = functions
  .runWith({ secrets: [MOMO_COLLECTIONS_SUBSCRIPTION_KEY_PARAM, MOMO_COLLECTIONS_API_USER_PARAM, MOMO_COLLECTIONS_API_KEY_PARAM, MOMO_DISBURSEMENTS_SUBSCRIPTION_KEY_PARAM, MOMO_DISBURSEMENTS_API_USER_PARAM, MOMO_DISBURSEMENTS_API_KEY_PARAM, MOMO_WEBHOOK_SECRET_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  // Restricted to admin — exposes platform MoMo balance
  await verifyAdmin(context, 'finance');

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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('MoMo balance error', { error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Unable to retrieve balance. Please try again.');
  }
});

// ============================================================
// MTN MOMO - WEBHOOK (Callback for async notifications)
// ============================================================

exports.momoWebhook = functions
  .runWith({ secrets: [MOMO_COLLECTIONS_SUBSCRIPTION_KEY_PARAM, MOMO_COLLECTIONS_API_USER_PARAM, MOMO_COLLECTIONS_API_KEY_PARAM, MOMO_DISBURSEMENTS_SUBSCRIPTION_KEY_PARAM, MOMO_DISBURSEMENTS_API_USER_PARAM, MOMO_DISBURSEMENTS_API_KEY_PARAM, MOMO_WEBHOOK_SECRET_PARAM] })
  .https.onRequest(async (req, res) => {
  const webhookCorrelationId = req.headers['x-correlation-id'] ||
    `webhook_momo_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  logSecurityEvent('momo_webhook_received', 'low', { correlationId: webhookCorrelationId, externalId: req.body?.externalId, status: req.body?.status });

  // ── LAYER 1: HTTP Method Restriction ──
  if (req.method !== 'POST') {
    logSecurityEvent('momo_webhook_method_rejected', 'medium', { method: req.method, correlationId: webhookCorrelationId });
    return res.status(405).send('Method Not Allowed');
  }

  // ── LAYER 2: Webhook Secret Token Verification ──
  // The token is appended to the callback URL registered with MoMo.
  // Only MoMo (which received the URL) should know the token.
  if (MOMO_WEBHOOK_SECRET) {
    const token = req.query.token;
    if (!token || !timingSafeCompare(token, MOMO_WEBHOOK_SECRET, 'utf8')) {
      logSecurityEvent('momo_webhook_invalid_token', 'high', {
        correlationId: webhookCorrelationId,
        ip: req.ip,
        hasToken: !!token,
      });
      return res.status(403).send('Forbidden');
    }
  } else if (MOMO_CONFIG.environment === 'production') {
    // In production, a webhook secret MUST be configured
    logSecurityEvent('momo_webhook_no_secret_production', 'high', { correlationId: webhookCorrelationId });
    return res.status(503).send('Service misconfigured');
  }

  logInfo('MoMo webhook received (authenticated)', { externalId: req.body?.externalId, status: req.body?.status, correlationId: webhookCorrelationId });

  try {
    const { externalId, status, financialTransactionId } = req.body;

    // ── LAYER 3: Request Body Validation ──
    if (!externalId || typeof externalId !== 'string' || !status) {
      logSecurityEvent('momo_webhook_invalid_fields', 'medium', { correlationId: webhookCorrelationId });
      return res.status(400).send('Bad Request');
    }

    // ── LAYER 4: Transaction Existence Verification ──
    // Only process callbacks for transactions WE initiated
    const txRef = db.collection('momo_transactions').doc(externalId);
    const txDoc = await txRef.get();

    if (!txDoc.exists) {
      logSecurityEvent('momo_webhook_unknown_transaction', 'high', { externalId, correlationId: webhookCorrelationId });
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
        logInfo('MoMo webhook cross-verified', { callbackStatus: status, apiStatus: verifiedStatus, ref: externalId, correlationId: webhookCorrelationId });

        if (verifiedStatus !== status) {
          logSecurityEvent('momo_webhook_status_mismatch', 'high', { callbackStatus: status, apiStatus: verifiedStatus, ref: externalId, correlationId: webhookCorrelationId });
          // Trust the API response, not the callback
        }
      } else {
        logWarning('MoMo webhook: cross-verification returned unexpected response', { statusCode: apiResponse.statusCode, correlationId: webhookCorrelationId });
      }
    } catch (verifyError) {
      logError('MoMo webhook: cross-verification error', { error: verifyError.message, correlationId: webhookCorrelationId });
    }

    // In production, reject if cross-verification failed
    if (!verifiedStatus && MOMO_CONFIG.environment === 'production') {
      logSecurityEvent('momo_webhook_verification_failure', 'high', { correlationId: webhookCorrelationId });
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
          validateWalletDocument(walletData, 'momoWebhook SUCCESSFUL wallet');

          if (txData.type === 'collection') {
            const creditBalance = safeAdd(walletData.balance, txData.amount, 'momoWebhook collection credit');
            transaction.update(walletDoc.ref, {
              balance: creditBalance,
              availableBalance: creditBalance - (walletData.heldBalance || 0),
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

      // Send push notification for completed MoMo transaction
      const momoNotifType = txData.type === 'collection' ? 'Deposit' : 'Withdrawal';
      await sendPushNotification(txData.userId, {
        title: `${momoNotifType} Successful`,
        body: `Your MTN MoMo ${momoNotifType.toLowerCase()} of ${txData.currency || ''} ${txData.amount?.toFixed(2) || '0.00'} has been completed`,
        type: 'transaction',
        data: { action: momoNotifType === 'Deposit' ? 'deposit' : 'withdrawal_completed', amount: txData.amount?.toString(), referenceId: externalId },
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
            validateWalletDocument(walletData, 'momoWebhook FAILED refund wallet');
            const refundBalance = safeAdd(walletData.balance, txData.amount, 'momoWebhook disbursement refund');

            transaction.update(walletDoc.ref, {
              balance: refundBalance,
              availableBalance: refundBalance - (walletData.heldBalance || 0),
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
      logInfo('MoMo webhook: no action needed', { effectiveStatus, currentStatus: txData.status, correlationId: webhookCorrelationId });
    }

    res.status(200).send('OK');
  } catch (error) {
    logError('MoMo webhook error', { error: error.message, correlationId: webhookCorrelationId });
    res.status(500).send('Error');
  }
  
});

// ============================================================
// SMILE ID WEBHOOK — Receives verification results from Smile ID
// ============================================================
exports.smileIdWebhook = functions
  .runWith({ secrets: [SMILE_ID_API_KEY_PARAM] })
  .https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    // ============================================================
    // C-01 — Verify SmileID webhook signature BEFORE any DB write.
    //
    // SmileID signs callbacks by placing `timestamp` and `signature`
    // in the POST body (not headers). The signature is:
    //   HMAC-SHA256(API_KEY, timestamp + partner_id + "sid_request")
    // encoded as base64 — same recipe as outbound requests; see
    // generateSmileIdSignature() above.
    //
    // An unsigned, mis-signed, or stale callback cannot mutate user
    // state. Valid callbacks fall through to the existing processing.
    // ============================================================
    const receivedSignature = req.body?.signature;
    const receivedTimestamp = req.body?.timestamp;

    if (!receivedSignature || !receivedTimestamp) {
      logError('SmileID webhook rejected: missing signature or timestamp', {
        hasSignature: !!receivedSignature,
        hasTimestamp: !!receivedTimestamp,
        ip: req.ip,
        userAgent: req.get('user-agent'),
      });
      res.status(403).send('Forbidden');
      return;
    }

    if (!SMILE_ID_API_KEY) {
      logError('SmileID webhook rejected: SMILE_ID_API_KEY not configured — refusing to process callbacks unauthenticated');
      res.status(500).send('Server misconfigured');
      return;
    }

    // Replay protection: reject timestamps outside ±10 minutes of server time.
    const receivedMs = Date.parse(receivedTimestamp);
    if (Number.isNaN(receivedMs)) {
      logError('SmileID webhook rejected: unparseable timestamp', {
        receivedTimestamp,
        ip: req.ip,
      });
      res.status(403).send('Forbidden');
      return;
    }
    const TEN_MINUTES_MS = 10 * 60 * 1000;
    const skewMs = Date.now() - receivedMs;
    if (Math.abs(skewMs) > TEN_MINUTES_MS) {
      logError('SmileID webhook rejected: timestamp outside replay window', {
        receivedTimestamp,
        skewMs,
        ip: req.ip,
      });
      res.status(403).send('Forbidden');
      return;
    }

    // Generate expected signature using the existing outbound recipe,
    // then timing-safe compare with the received one.
    const expectedSignature = generateSmileIdSignature(receivedTimestamp);
    const receivedSigStr = String(receivedSignature);
    let signatureValid = false;
    if (expectedSignature.length === receivedSigStr.length) {
      signatureValid = crypto.timingSafeEqual(
        Buffer.from(expectedSignature, 'utf8'),
        Buffer.from(receivedSigStr, 'utf8')
      );
    }
    if (!signatureValid) {
      logError('SmileID webhook rejected: signature mismatch', {
        receivedTimestamp,
        ip: req.ip,
        userAgent: req.get('user-agent'),
      });
      res.status(403).send('Forbidden');
      return;
    }

    // Signature verified — safe to process payload below.
    const data = req.body;

    // SmileID sends PascalCase field names with user_id/job_id nested inside PartnerParams.
    // Fall back to snake_case variants so the webhook also works with test payloads.
    const partnerParams = data.PartnerParams || data.partner_params || {};
    const jobId = partnerParams.job_id || data.job_id;
    const userId = partnerParams.user_id || data.partner_params?.user_id;
    const jobType = partnerParams.job_type || data.job_type;
    const resultCode = data.ResultCode || data.result_code;
    const resultText = data.ResultText || data.result_text;
    const smileJobId = data.SmileJobID || data.smile_job_id;
    const partnerId = data.partner_id || null;
    const actions = data.Actions || data.actions || {};

    logInfo('Smile ID webhook received', {
      jobId,
      userId,
      jobType,
      resultCode,
      smileJobId,
    });

    if (!userId || !jobId) {
      logError('Smile ID webhook: missing userId or jobId', { data });
      res.status(400).send('Missing required fields');
      return;
    }

    // ============================================================
    // B-02 — Reverse-lookup Firebase UID from SmileID user_id.
    //
    // SmileID's PartnerParams.user_id is NOT the Firebase Auth UID.
    // The app generates it via SmileIDService.generateUserId() as
    // `user_${millisecondsSinceEpoch}` and stores it on the user
    // doc as the `smileUserId` field. We need the Firebase UID to
    // update the correct user document.
    // ============================================================
    const userQuerySnap = await admin.firestore()
      .collection('users')
      .where('smileUserId', '==', userId)
      .limit(1)
      .get();

    if (userQuerySnap.empty) {
      logInfo('Smile ID webhook: no user found for smileUserId — orphan or test callback', {
        smileUserId: userId,
        jobId,
        smileJobId,
      });
      res.status(200).send('OK');
      return;
    }

    const firebaseUid = userQuerySnap.docs[0].id;
    logInfo('Smile ID webhook: resolved Firebase UID from smileUserId', {
      smileUserId: userId,
      firebaseUid,
      jobId,
    });

    // Extract face-matching and liveness results.
    // SmileID sends action names with underscores and PascalCase values.
    const livenessResult = actions.Liveness_Check || actions.Liveness || 'Not Available';
    const selfieCheck = actions.Selfie_Check || 'Not Available';
    const selfieToIdCompare = actions.Selfie_To_ID_Card_Compare || 'Not Available';
    const documentCheck = actions.Document_Verification || 'Not Available';
    const humanReview = actions.Human_Review_Compare || 'Not Available';
    const antiSpoofing = actions.Anti_Spoofing || 'Not Available';
    const verifyIdNumber = actions.Verify_ID_Number || 'Not Available';
    const confidenceValue = data.ConfidenceValue || data.confidence_value || null;

    // Determine if face matching passed.
    // SmileID uses values like "Passed", "Failed", "Not Applicable", "Not Done", "Completed".
    const isPass = (v) => v === 'Pass' || v === 'Passed' || v === 'Completed';
    const isPassOrNa = (v) => isPass(v) || v === 'Not Applicable';
    const livenessPass = isPassOrNa(livenessResult);
    const selfiePass = isPass(selfieCheck) || isPass(selfieToIdCompare);
    const humanReviewPass = isPass(humanReview);
    const documentPass = isPassOrNa(documentCheck);
    const faceMatchPassed = livenessPass && (selfiePass || humanReviewPass);

    // Extract legal name from ID document results if available
    let legalName = null;
    const idInfo = data.id_info || data.result || {};
    const fullName = idInfo.FullName || idInfo.full_name;
    const firstName = idInfo.FirstName || idInfo.first_name || idInfo.given_names;
    const lastName = idInfo.LastName || idInfo.last_name || idInfo.surname;

    if (fullName) {
      legalName = fullName;
    } else if (firstName || lastName) {
      legalName = [firstName, lastName].filter(Boolean).join(' ');
    }

    // Store full result in Firestore (always, regardless of pass/fail)
    await admin.firestore()
      .collection('users')
      .doc(firebaseUid)
      .collection('kyc')
      .doc('smile_id_results')
      .set({
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        [`jobs.${jobId}`]: {
          jobId,
          smileJobId,
          partnerId,
          resultCode,
          resultText,
          jobType: jobType || null,
          actions,
          confidence: confidenceValue,
          livenessScore: livenessResult,
          documentCheck,
          humanReview,
          selfieMatch: selfieCheck,
          antifraud: antiSpoofing,
          faceMatchPassed,
          legalName,
          fullResult: data,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }, { merge: true });

    // Verification passed: face match + valid result code.
    // 0220/0120 = document/enhanced-doc verification success.
    // 1012 = Biometric KYC success (Selfie matched ID + ID verified).
    // 0810 = SmartSelfie enrollment success.
    const validResultCode =
      resultCode === '0220' ||
      resultCode === '0120' ||
      resultCode === '1012' ||
      resultCode === '0810';

    // Definitive failure codes — set kycStatus to 'failed' so the waiting
    // screen can show a failure dialog instead of spinning forever.
    const definitiveFailureCodes = ['1016', '1022', '1013', '1014'];
    if (!validResultCode && definitiveFailureCodes.includes(String(resultCode))) {
      try {
        await admin.firestore()
          .collection('users')
          .doc(firebaseUid)
          .update({
            kycStatus: 'failed',
            kycStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            kycFailureReason: resultText || 'Verification failed',
            kycFailureCode: resultCode,
          });
      } catch (e) {
        logError('Failed to set kycStatus=failed', { error: e.message, userId });
      }
      logInfo('Smile ID webhook: definitive failure recorded', {
        userId,
        jobId,
        resultCode,
        resultText,
      });
      res.status(200).send('OK');
      return;
    }

    if (validResultCode && faceMatchPassed) {
      // Full pass — set kycStatus to 'verified', create wallet
      const userRef = admin.firestore().collection('users').doc(firebaseUid);
      const userDoc = await userRef.get();
      const userData = userDoc.exists ? userDoc.data() : {};

      const updateData = {
        kycStatus: 'verified',
        kycVerified: true,
        isVerified: true,
        kycCompleted: true,
        kycStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'kycDetails.smileIdConfirmed': true,
        'kycDetails.smileIdResultCode': resultCode,
        'kycDetails.smileIdJobId': smileJobId,
        'kycDetails.faceMatchPassed': true,
        'kycDetails.verifiedAt': admin.firestore.FieldValue.serverTimestamp(),
      };

      // Store legal name if extracted (title-cased)
      if (legalName) {
        updateData.legalName = titleCaseName(legalName);
      }

      await userRef.update(updateData);

      // Create wallet if it doesn't exist
      const walletDoc = await admin.firestore().collection('wallets').doc(firebaseUid).get();
      if (!walletDoc.exists) {
        const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
        const segment = () => Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
        const walletId = `QRW-${segment()}-${segment()}-${segment()}`;

       await admin.firestore().collection('wallets').doc(firebaseUid).set({
          id: firebaseUid,
          userId: firebaseUid,
          walletId: walletId,
          currency: userData.currency || 'GHS',
          balance: 0,
          heldBalance: 0,
          availableBalance: 0,
          isActive: true,
          dailySpent: 0,
          monthlySpent: 0,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await userRef.update({
          walletId: walletId,
          walletCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logInfo('Wallet created via SmileID webhook', { userId, walletId });
      }

      logInfo('Smile ID webhook: user VERIFIED (face match passed)', { userId, resultCode, faceMatchPassed });
    } else if (validResultCode && !faceMatchPassed) {
      // Document verified but face match failed — mark as failed
      await admin.firestore()
        .collection('users')
        .doc(firebaseUid)
        .update({
          kycStatus: 'failed',
          kycStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          'kycDetails.smileIdResultCode': resultCode,
          'kycDetails.smileIdJobId': smileJobId,
          'kycDetails.faceMatchPassed': false,
          'kycDetails.failureReason': 'Face matching failed',
          'kycDetails.failedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
      logInfo('Smile ID webhook: FAILED (face match failed)', { userId, resultCode, actions });
    } else {
      // Non-passing result code
      await admin.firestore()
        .collection('users')
        .doc(firebaseUid)
        .update({
          kycStatus: 'failed',
          kycStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          'kycDetails.smileIdResultCode': resultCode,
          'kycDetails.smileIdJobId': smileJobId,
          'kycDetails.failureReason': resultText || 'Verification not passed',
          'kycDetails.failedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
      logInfo('Smile ID webhook: FAILED (result code not passing)', { userId, resultCode, resultText });
    }

    res.status(200).send('OK');
  } catch (error) {
    logError('Smile ID webhook error', { error: error.message });
    res.status(500).send('Error');
  }
});

// ============================================================
// SmileID Job Status Polling
// ============================================================
exports.checkSmileIdJobStatus = functions
  .runWith({ secrets: [SMILE_ID_API_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;
  const { smileUserId, smileJobId } = data;

  if (!smileUserId || !smileJobId) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'smileUserId and smileJobId are required');
  }

  logInfo('Checking SmileID job status', { userId, smileUserId, smileJobId });

  // Check current kycStatus - only poll if pending_review
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throwAppError(ERROR_CODES.USER_NOT_FOUND);
  }

  const userData = userDoc.data();
  if (userData.kycStatus === 'verified') {
    return { success: true, status: 'verified', message: 'Already verified' };
  }
  if (userData.kycStatus === 'failed') {
    return { success: true, status: 'failed', message: 'Already failed' };
  }

  // Generate SmileID signature
  const partnerId = process.env.SMILE_PARTNER_ID || '8244';
  const apiKey = process.env.SMILE_API_KEY;

  if (!apiKey) {
    logInfo('SMILE_API_KEY not configured');
    throw new functions.https.HttpsError('internal', 'SmileID API key not configured');
  }

  const timestamp = new Date().toISOString();

  // SmileID signature: hash of timestamp + partnerID + "sid_request" with API key
  const hmac = crypto.createHmac('sha256', apiKey);
  hmac.update(timestamp + partnerId + 'sid_request');
  const signature = hmac.digest('base64');

  // Determine API URL based on environment
  const useSandbox = process.env.SMILE_USE_SANDBOX !== 'false';
  const apiUrl = useSandbox
    ? 'https://testapi.smileidentity.com/v1/job_status'
    : 'https://api.smileidentity.com/v1/job_status';

  try {
    const fetch = (await import('node-fetch')).default;
    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        timestamp: timestamp,
        signature: signature,
        user_id: smileUserId,
        job_id: smileJobId,
        partner_id: partnerId,
        image_links: false,
        history: false,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logInfo('SmileID job_status API error', { status: response.status, error: errorText });
      throw new functions.https.HttpsError('internal', 'SmileID API error: ' + response.status);
    }

    const result = await response.json();
    logInfo('SmileID job status result', {
      userId,
      smileJobId,
      jobComplete: result.job_complete,
      jobSuccess: result.job_success,
      resultCode: result.result?.ResultCode,
      resultText: result.result?.ResultText,
    });

    // Job not yet complete
    if (!result.job_complete) {
      return { success: true, status: 'pending', message: 'Job still processing' };
    }

    // Job complete — check result
    const resultCode = result.result?.ResultCode || '';
    const resultText = result.result?.ResultText || '';
    const actions = result.result?.Actions || {};

    // Extract personal info if available
    const fullName = result.result?.FullName || result.result?.full_name || null;
    const dob = result.result?.DOB || result.result?.dob || null;
    const idNumber = result.result?.IDNumber || result.result?.id_number || null;

    // Check if verification passed
    const selfieCheck = actions.Selfie_Check || actions.selfie_check || '';
    const livenessCheck = actions.Liveness_Check || actions.liveness_check || '';
    const docCheck = actions.Document_Verification || actions.document_verification || '';

    const isApproved = resultCode === '0810' ||
                       (selfieCheck.toLowerCase() === 'passed' &&
                        (docCheck.toLowerCase() === 'passed' || docCheck === ''));

    if (isApproved) {
      // APPROVED — update user and create wallet
      logInfo('SmileID verification APPROVED', { userId, resultCode });

      // Build legal name from available data
      let legalName = fullName;
      if (!legalName) {
        const firstName = result.result?.FirstName || result.result?.first_name || '';
        const lastName = result.result?.LastName || result.result?.last_name || '';
        if (firstName || lastName) {
          legalName = `${firstName} ${lastName}`.trim();
        }
      }

      // Update user document
      const updateData = {
        kycStatus: 'verified',
        kycStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        kycCompleted: true,
        kycVerified: true,
        isVerified: true,
      };

      if (legalName) updateData.legalName = titleCaseName(legalName);
      if (dob) updateData.dateOfBirth = dob;
      if (idNumber) updateData.idNumber = idNumber;

      await db.collection('users').doc(userId).update(updateData);

      // Update KYC documents subcollection
      await db.collection('users').doc(userId).collection('kyc').doc('documents').set({
        status: 'verified',
        smileIdVerified: true,
        resultCode: resultCode,
        resultText: resultText,
        actions: actions,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        verificationMethod: 'smile_id_job_status_poll',
      }, { merge: true });

      // Create wallet if not exists
      const walletDoc = await db.collection('wallets').doc(userId).get();
      if (!walletDoc.exists) {
        const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; const segment = () => Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join(''); const walletId = `QRW-${segment()}-${segment()}-${segment()}`;
       await db.collection('wallets').doc(userId).set({
          id: userId,
          userId: userId,
          walletId: walletId,
          currency: userData.currency || 'GHS',
          balance: 0,
          heldBalance: 0,
          availableBalance: 0,
          isActive: true,
          dailySpent: 0,
          monthlySpent: 0,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await db.collection('users').doc(userId).update({
          walletId: walletId,
          walletCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logInfo('Wallet created via job status poll', { userId, walletId });
      }

      return { success: true, status: 'verified', resultCode, message: 'Verification approved' };

    } else {
      // REJECTED
      logInfo('SmileID verification REJECTED', { userId, resultCode, resultText });

      await db.collection('users').doc(userId).update({
        kycStatus: 'failed',
        kycStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        kycFailureReason: resultText || 'Verification failed',
      });

      await db.collection('users').doc(userId).collection('kyc').doc('documents').set({
        status: 'failed',
        smileIdVerified: false,
        resultCode: resultCode,
        resultText: resultText,
        actions: actions,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        verificationMethod: 'smile_id_job_status_poll',
      }, { merge: true });

      return { success: true, status: 'failed', resultCode, resultText, message: 'Verification failed' };
    }

  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logInfo('Error checking SmileID job status', { error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to check job status');
  }
});

// ============================================================
// SMILE ID BIOMETRIC KYC — SERVER-SIDE SUBMISSION
// Used when SmartSelfie enrollment is done on-device and we need
// to submit ID number verification against government database
// ============================================================
exports.submitBiometricKycVerification = functions
  .runWith({ secrets: [SMILE_ID_API_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  // Lazy requires — keeps all changes localized to this function
  const SmileIdentityCore = require('smile-identity-core');
  const SmileWebApi = SmileIdentityCore.WebApi;
  const SmileImageType = SmileIdentityCore.IMAGE_TYPE;
  const SmileJobType = SmileIdentityCore.JOB_TYPE;
  const fs = require('fs');
  const os = require('os');
  const path = require('path');

  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;
  const {
    smileUserId,
    country,
    idType,
    idNumber,
    selfieStoragePath,
    livenessStoragePaths,
    firstName,
    lastName,
    dob,
  } = data;

  // Validate required inputs
  if (!smileUserId || !country || !idType || !idNumber) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'smileUserId, country, idType, and idNumber are required');
  }
  if (!selfieStoragePath) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'selfieStoragePath is required');
  }
  if (!Array.isArray(livenessStoragePaths) || livenessStoragePaths.length === 0) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'livenessStoragePaths must be a non-empty array');
  }

  if (!SMILE_ID_API_KEY || !SMILE_ID_PARTNER_ID) {
    logError('SmileID configuration missing for biometric KYC submission');
    throw new functions.https.HttpsError('internal', 'SmileID API key not configured');
  }

  logInfo('Submitting Biometric KYC verification', {
    userId,
    smileUserId,
    country,
    idType,
    livenessCount: livenessStoragePaths.length,
  });

  const jobId = `job_${SMILE_ID_PARTNER_ID}_${crypto.randomUUID()}`;
  const callbackUrl = 'https://us-central1-qr-wallet-1993.cloudfunctions.net/smileIdWebhook';
  const sidServer = SMILE_ID_BASE_URL.value.includes('testapi') ? 0 : 1;

  // Track temp files for cleanup in finally block
  const tempFiles = [];

  try {
    const bucket = admin.storage().bucket();

    // Download selfie from Firebase Storage to /tmp
    const selfieTempPath = path.join(os.tmpdir(), `${jobId}_selfie.jpg`);
    await bucket.file(selfieStoragePath).download({ destination: selfieTempPath });
    tempFiles.push(selfieTempPath);
    logInfo('Selfie downloaded from Storage', { selfieStoragePath });

    // Download all liveness images and base64-encode them
    // (library zips files for type 0/1 only; type 6 must be base64 in info.json)
    const livenessBase64Images = [];
    for (let i = 0; i < livenessStoragePaths.length; i++) {
      const livenessTempPath = path.join(os.tmpdir(), `${jobId}_liveness_${i}.jpg`);
      await bucket.file(livenessStoragePaths[i]).download({ destination: livenessTempPath });
      tempFiles.push(livenessTempPath);
      const base64Image = fs.readFileSync(livenessTempPath).toString('base64');
      livenessBase64Images.push(base64Image);
    }
    logInfo('Liveness images downloaded and encoded', { count: livenessBase64Images.length });

    // Build image_details array for SmileID
    // Selfie: file path (library will read and zip it)
    // Liveness: base64 string (library will embed in info.json)
    const imageDetails = [
      {
        image_type_id: SmileImageType.SELFIE_IMAGE_FILE,
        image: selfieTempPath,
      },
      ...livenessBase64Images.map((base64) => ({
        image_type_id: SmileImageType.LIVENESS_IMAGE_BASE64,
        image: base64,
      })),
    ];

    // partner_params: identifies the job to SmileID and our webhook
    const partnerParams = {
      user_id: smileUserId,
      job_id: jobId,
      job_type: SmileJobType.BIOMETRIC_KYC,
    };

    // id_info: tells SmileID which government database to query
    // entered: 'true' means we're providing ID details for verification
    const idInfo = {
      country: country,
      id_type: idType,
      id_number: idNumber,
      first_name: firstName || '',
      last_name: lastName || '',
      dob: dob || '',
      entered: 'true',
    };

    // Submit via SmileID library — handles signature, ZIP, info.json, prep upload, S3 upload
    const webApi = new SmileWebApi(
      SMILE_ID_PARTNER_ID,
      callbackUrl,
      SMILE_ID_API_KEY,
      sidServer
    );

    const submitResult = await webApi.submit_job(partnerParams, imageDetails, idInfo, {});
    logInfo('SmileID submit_job completed', {
      success: submitResult.success,
      smileJobId: submitResult.smile_job_id,
    });

    // Save job info to user document so verification_pending_screen can poll
    await db.collection('users').doc(userId).update({
      smileUserId: smileUserId,
      smileJobId: jobId,
      kycStatus: 'pending_review',
    });

    // Save job details in kyc subcollection for audit trail
    await db.collection('users').doc(userId).collection('kyc').doc('pending_job').set({
      jobId: jobId,
      smileUserId: smileUserId,
      smileServerJobId: submitResult.smile_job_id || null,
      country: country,
      idType: idType,
      idNumber: idNumber,
      selfieStoragePath: selfieStoragePath,
      livenessStoragePaths: livenessStoragePaths,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'submitted',
    });

    return {
      success: true,
      jobId: jobId,
      smileJobId: submitResult.smile_job_id || null,
      message: 'Biometric KYC verification submitted to SmileID. Awaiting webhook result.',
    };
  } catch (error) {
    logError('Error submitting biometric KYC', {
      userId,
      error: error.message,
      stack: error.stack,
    });
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', 'Failed to submit verification: ' + error.message);
  } finally {
    // Cleanup temp files in /tmp (Firebase Storage copies remain for audit)
    for (const tempFile of tempFiles) {
      try {
        if (fs.existsSync(tempFile)) {
          fs.unlinkSync(tempFile);
        }
      } catch (cleanupError) {
        logInfo('Failed to cleanup temp file', { tempFile, error: cleanupError.message });
      }
    }
  }
});

// ============================================================
// WALLET HOLDS — CREATE HOLD
// ============================================================

/**
 * Creates a hold on a wallet, reserving funds for a future commitment.
 * The held amount is deducted from availableBalance but NOT from balance.
 * Primary use case: Shop Afrik pay-on-delivery orders.
 *
 * Auth: Caller must be the wallet owner OR have the 'walletHoldsWrite' custom claim.
 */
exports.createHold = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const callerId = context.auth.uid;
  const callerClaims = context.auth.token || {};

  const { walletId, amount, currency, reason, referenceId, referenceType, expiresAtSeconds, metadata } = data;

  // ── Input validation ──
  if (!walletId || typeof walletId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'walletId is required.');
  }
  if (!amount || typeof amount !== 'number' || amount <= 0 || !Number.isInteger(amount)) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID, 'amount must be a positive integer (minor units).');
  }
  if (!currency || typeof currency !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'currency is required.');
  }
  if (!reason || typeof reason !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'reason is required.');
  }
  if (!referenceId || typeof referenceId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'referenceId is required.');
  }
  if (!referenceType || typeof referenceType !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'referenceType is required.');
  }

  // ── Authorization: wallet owner or service with walletHoldsWrite claim ──
  const isOwner = callerId === walletId;
  const hasHoldsClaim = callerClaims.walletHoldsWrite === true;
  if (!isOwner && !hasHoldsClaim) {
    throwAppError(ERROR_CODES.AUTH_PERMISSION_DENIED, 'You are not authorized to create holds on this wallet.');
  }

  // ── Determine expiration ──
  const defaultExpiry = {
    shop_afrik_order: 14 * 24 * 60 * 60,  // 14 days
    withdrawal: 60 * 60,                    // 1 hour
    escrow: 30 * 24 * 60 * 60,             // 30 days
  };
  const expirySeconds = expiresAtSeconds || defaultExpiry[reason] || 14 * 24 * 60 * 60;
  const expiresAt = new Date(Date.now() + expirySeconds * 1000);

  // ── Generate hold ID ──
  const holdId = crypto.randomUUID();

  // ── Atomic transaction ──
  await db.runTransaction(async (transaction) => {
    const walletRef = db.collection('wallets').doc(walletId);
    const walletDoc = await transaction.get(walletRef);

    if (!walletDoc.exists) {
      throwAppError(ERROR_CODES.WALLET_NOT_FOUND);
    }

    const walletData = walletDoc.data();

    // Validate wallet is active
    if (walletData.accountBlocked === true || walletData.isActive === false) {
      throwAppError(ERROR_CODES.WALLET_SUSPENDED, 'Cannot create hold on a blocked or inactive wallet.');
    }

    // Validate currency match
    if (walletData.currency !== currency.toUpperCase()) {
      throwAppError(ERROR_CODES.HOLD_CURRENCY_MISMATCH, `Wallet currency is ${walletData.currency}, but hold currency is ${currency}.`);
    }

    // Validate sufficient available balance
    const currentAvailable = walletData.availableBalance ?? (walletData.balance - (walletData.heldBalance || 0));
    if (currentAvailable < amount) {
      throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS, `Available balance is ${currentAvailable}, but hold requires ${amount}.`);
    }

    // Write hold document
    const holdRef = db.collection('wallet_holds').doc(holdId);
    transaction.set(holdRef, {
      walletId: walletId,
      amount: amount,
      currency: currency.toUpperCase(),
      reason: reason,
      referenceId: referenceId,
      referenceType: referenceType,
      createdBy: callerId,
      createdByService: hasHoldsClaim ? (callerClaims.serviceName || 'external_service') : 'qr_wallet_user',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      status: 'active',
      releasedAt: null,
      releasedReason: null,
      convertedTransactionId: null,
      metadata: metadata || {},
    });

    // Update wallet: increase heldBalance, decrease availableBalance
    transaction.update(walletRef, {
      heldBalance: admin.firestore.FieldValue.increment(amount),
      availableBalance: admin.firestore.FieldValue.increment(-amount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // ── Audit log (outside transaction for performance) ──
  await auditLog({
    action: 'create_hold',
    userId: walletId,
    performedBy: callerId,
    details: {
      holdId,
      amount,
      currency,
      reason,
      referenceId,
      referenceType,
      expiresAt: expiresAt.toISOString(),
    },
  });

  logInfo('Hold created', { holdId, walletId, amount, reason, referenceId });

  return {
    success: true,
    holdId: holdId,
    expiresAt: expiresAt.toISOString(),
  };
});

// ============================================================
// WALLET HOLDS — RELEASE HOLD
// ============================================================

/**
 * Releases an active hold, restoring the held amount to the wallet's
 * availableBalance. Called when an order is cancelled or a hold is no
 * longer needed.
 *
 * Idempotent: if the hold is already released or converted, returns
 * success without error (no double-release).
 *
 * Auth: Caller must be the wallet owner, the service that created the
 * hold (matched by createdByService), or a super_admin.
 */
exports.releaseHold = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const callerId = context.auth.uid;
  const callerClaims = context.auth.token || {};

  const { holdId, reason } = data;

  // ── Input validation ──
  if (!holdId || typeof holdId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'holdId is required.');
  }
  if (!reason || typeof reason !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'reason is required.');
  }

  let holdWalletId = null;
  let holdAmount = 0;

  // ── Atomic transaction ──
  await db.runTransaction(async (transaction) => {
    const holdRef = db.collection('wallet_holds').doc(holdId);
    const holdDoc = await transaction.get(holdRef);

    if (!holdDoc.exists) {
      throwAppError(ERROR_CODES.HOLD_NOT_FOUND);
    }

    const holdData = holdDoc.data();

    // ── Idempotency: if already released or converted, return silently ──
    if (holdData.status === 'released' || holdData.status === 'expired') {
      logInfo('releaseHold: hold already released/expired, no-op', { holdId, status: holdData.status });
      return;
    }
    if (holdData.status === 'converted') {
      logInfo('releaseHold: hold already converted, no-op', { holdId });
      return;
    }
    if (holdData.status !== 'active') {
      throwAppError(ERROR_CODES.HOLD_INVALID_STATE, `Hold status is '${holdData.status}', expected 'active'.`);
    }

    // ── Authorization ──
    // D-02: Use verifyAdmin helper for consistency with the 8-role hierarchy.
    // Emergency executor path: super_admin or admin_manager can manually
    // release a hold when the creating service (e.g., a partner app) is
    // unable to do so automatically. Disputes and investigations run
    // through the separate approval workflow — not this direct path.
    const isOwner = callerId === holdData.walletId;
    const isCreatingService = callerClaims.walletHoldsWrite === true;
    let isAuthorizedAdmin = false;
    if (!isOwner && !isCreatingService) {
      try {
        await verifyAdmin(context, 'admin_manager');
        isAuthorizedAdmin = true;
      } catch (e) {
        // Not admin_manager or above; fall through to denial
      }
    }
    if (!isOwner && !isCreatingService && !isAuthorizedAdmin) {
      throwAppError(ERROR_CODES.AUTH_PERMISSION_DENIED, 'You are not authorized to release this hold.');
    }

    holdWalletId = holdData.walletId;
    holdAmount = holdData.amount;

    // ── Read wallet ──
    const walletRef = db.collection('wallets').doc(holdData.walletId);
    const walletDoc = await transaction.get(walletRef);

    if (!walletDoc.exists) {
      throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Wallet for this hold no longer exists.');
    }

    // ── Update wallet: decrease heldBalance, increase availableBalance ──
    transaction.update(walletRef, {
      heldBalance: admin.firestore.FieldValue.increment(-holdAmount),
      availableBalance: admin.firestore.FieldValue.increment(holdAmount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ── Update hold status ──
    transaction.update(holdRef, {
      status: 'released',
      releasedAt: admin.firestore.FieldValue.serverTimestamp(),
      releasedReason: reason,
    });
  });

  // ── Audit log (outside transaction) ──
  if (holdWalletId && holdAmount > 0) {
    await auditLog({
      action: 'release_hold',
      userId: holdWalletId,
      performedBy: callerId,
      details: {
        holdId,
        amount: holdAmount,
        reason,
      },
    });

    // ── FCM notification to wallet owner ──
    try {
      const userDoc = await db.collection('users').doc(holdWalletId).get();
      if (userDoc.exists) {
        const fcmToken = userDoc.data().fcmToken;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: 'Hold Released',
              body: `Your hold of ${holdAmount} has been released and is available again.`,
            },
            data: {
              type: 'hold_released',
              holdId: holdId,
            },
          });
        }
      }
    } catch (fcmError) {
      logError('Failed to send hold release notification', { holdId, error: fcmError.message });
    }
  }

  logInfo('Hold released', { holdId, walletId: holdWalletId, amount: holdAmount, reason });

  return { success: true };
});

// ============================================================
// WALLET HOLDS — GET HOLD STATUS
// ============================================================

/**
 * Returns the current status and details of a specific hold.
 * Read-only — no mutations.
 *
 * Auth: Caller must be the wallet owner, the creating service, or an admin.
 */
exports.getHoldStatus = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const callerId = context.auth.uid;
  const callerClaims = context.auth.token || {};

  const { holdId } = data;

  if (!holdId || typeof holdId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'holdId is required.');
  }

  const holdDoc = await db.collection('wallet_holds').doc(holdId).get();

  if (!holdDoc.exists) {
    throwAppError(ERROR_CODES.HOLD_NOT_FOUND);
  }

  const holdData = holdDoc.data();

  // Authorization: wallet owner, creating service, or any admin (support+)
  // D-02: Use verifyAdmin for 8-role hierarchy compliance.
  // Widened from 'super_admin || support' to 'support+' (any admin level)
  // for read-only visibility — consistent with other read endpoints.
  const isOwner = callerId === holdData.walletId;
  const isService = callerClaims.walletHoldsWrite === true;
  let isAuthorizedAdmin = false;
  if (!isOwner && !isService) {
    try {
      await verifyAdmin(context, 'support');
      isAuthorizedAdmin = true;
    } catch (e) {
      // Not an admin; fall through to denial
    }
  }
  if (!isOwner && !isService && !isAuthorizedAdmin) {
    throwAppError(ERROR_CODES.AUTH_PERMISSION_DENIED, 'You are not authorized to view this hold.');
  }

  return {
    holdId: holdDoc.id,
    walletId: holdData.walletId,
    amount: holdData.amount,
    currency: holdData.currency,
    status: holdData.status,
    reason: holdData.reason,
    referenceId: holdData.referenceId,
    referenceType: holdData.referenceType,
    createdAt: holdData.createdAt ? holdData.createdAt.toDate().toISOString() : null,
    expiresAt: holdData.expiresAt ? holdData.expiresAt.toDate().toISOString() : null,
    releasedAt: holdData.releasedAt ? holdData.releasedAt.toDate().toISOString() : null,
    releasedReason: holdData.releasedReason,
    convertedTransactionId: holdData.convertedTransactionId,
  };
});

// ============================================================
// WALLET HOLDS — LIST HOLDS FOR WALLET
// ============================================================

/**
 * Returns a list of holds for a specific wallet, optionally filtered by status.
 * Read-only — no mutations.
 *
 * Auth: Caller must be the wallet owner.
 */
exports.listHoldsForWallet = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const callerId = context.auth.uid;

  const { walletId, status, limit } = data;

  if (!walletId || typeof walletId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'walletId is required.');
  }

  // Only the wallet owner can list their holds
  if (callerId !== walletId) {
    throwAppError(ERROR_CODES.AUTH_PERMISSION_DENIED, 'You can only view holds on your own wallet.');
  }

  const queryLimit = Math.min(Math.max(limit || 20, 1), 100);

  let query = db.collection('wallet_holds')
    .where('walletId', '==', walletId)
    .orderBy('createdAt', 'desc')
    .limit(queryLimit);

  if (status && typeof status === 'string') {
    query = db.collection('wallet_holds')
      .where('walletId', '==', walletId)
      .where('status', '==', status)
      .orderBy('createdAt', 'desc')
      .limit(queryLimit);
  }

  const snapshot = await query.get();

  const holds = snapshot.docs.map(doc => {
    const d = doc.data();
    return {
      holdId: doc.id,
      amount: d.amount,
      currency: d.currency,
      status: d.status,
      reason: d.reason,
      referenceId: d.referenceId,
      referenceType: d.referenceType,
      createdAt: d.createdAt ? d.createdAt.toDate().toISOString() : null,
      expiresAt: d.expiresAt ? d.expiresAt.toDate().toISOString() : null,
      releasedAt: d.releasedAt ? d.releasedAt.toDate().toISOString() : null,
      releasedReason: d.releasedReason,
    };
  });

  return { holds, count: holds.length };
});


// ============================================================
// WALLET HOLDS — CONVERT HOLD TO TRANSFER
// ============================================================

/**
 * Converts an active hold into a real money transfer in a single atomic
 * operation. The held amount is deducted from the sender's balance (and
 * heldBalance), and the net amount (after fee) is credited to the
 * recipient's wallet.
 *
 * This is essentially sendMoney but starting from held funds instead of
 * available balance. No intermediate state where money is "half-moved."
 *
 * Auth: Caller must be the service that created the hold (walletHoldsWrite
 * claim) or a super_admin. The wallet owner CANNOT convert their own hold.
 */
exports.convertHoldToTransfer = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const callerId = context.auth.uid;
  const callerClaims = context.auth.token || {};

  const { holdId, recipientWalletId, note, metadata } = data;

  // ── Input validation ──
  if (!holdId || typeof holdId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'holdId is required.');
  }
  if (!recipientWalletId || typeof recipientWalletId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'recipientWalletId is required.');
  }

  // ── Authorization: creating service or admin_manager+ (emergency path) ──
  // D-02: Use verifyAdmin for 8-role hierarchy compliance.
  // Emergency executor path: super_admin or admin_manager can manually
  // convert a hold when the creating service is unable to do so.
  // Owner cannot convert their own hold (prevents self-payment abuse).
  const isService = callerClaims.walletHoldsWrite === true;
  let isAuthorizedAdmin = false;
  if (!isService) {
    try {
      await verifyAdmin(context, 'admin_manager');
      isAuthorizedAdmin = true;
    } catch (e) {
      // Not admin_manager or above; fall through to denial
    }
  }
  if (!isService && !isAuthorizedAdmin) {
    throwAppError(ERROR_CODES.AUTH_PERMISSION_DENIED, 'Only the creating service or an admin_manager+ can convert a hold.');
  }

  // ── Fetch exchange rates (outside transaction, read-only) ──
  const ratesDoc = await db.collection('app_config').doc('exchange_rates').get();
  const rates = ratesDoc.exists ? ratesDoc.data().rates : {};

  // ── Generate transaction ID ──
  const txId = generateSecureTransactionId();
  const now = new Date();

  // ── Atomic transaction ──
  const result = await db.runTransaction(async (transaction) => {
    // 1. Read hold
    const holdRef = db.collection('wallet_holds').doc(holdId);
    const holdDoc = await transaction.get(holdRef);

    if (!holdDoc.exists) {
      throwAppError(ERROR_CODES.HOLD_NOT_FOUND);
    }

    const holdData = holdDoc.data();

    // 2. Validate hold is active
    if (holdData.status !== 'active') {
      throwAppError(ERROR_CODES.HOLD_INVALID_STATE, `Hold status is '${holdData.status}', expected 'active'.`);
    }

    // 3. Read sender wallet
    const senderWalletRef = db.collection('wallets').doc(holdData.walletId);
    const senderWallet = await transaction.get(senderWalletRef);

    if (!senderWallet.exists) {
      throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Sender wallet not found.');
    }

    const senderData = senderWallet.data();
    validateWalletDocument(senderData, 'convertHoldToTransfer sender wallet');

    // 4. Find recipient wallet by walletId string (e.g. QRW-XXXX-XXXX-XXXX)
    const recipientQuery = await transaction.get(
      db.collection('wallets').where('walletId', '==', recipientWalletId)
    );

    // Firestore transactions don't support .where().get() directly in all SDK versions.
    // Fall back to reading outside transaction if needed.
    let recipientDoc, recipientUid, recipientRef, recipientData;

    if (recipientQuery && !recipientQuery.empty) {
      recipientDoc = recipientQuery.docs[0];
      recipientUid = recipientDoc.id;
      recipientRef = recipientDoc.ref;
      recipientData = recipientDoc.data();
    } else {
      throwAppError(ERROR_CODES.TXN_RECIPIENT_NOT_FOUND, 'Recipient wallet not found.');
    }

    validateWalletDocument(recipientData, 'convertHoldToTransfer recipient wallet');

    // 5. Check recipient is not blocked
    const recipientUserDoc = await transaction.get(db.collection('users').doc(recipientUid));
    if (recipientUserDoc.exists && recipientUserDoc.data().accountBlocked === true) {
      throwAppError(ERROR_CODES.WALLET_SUSPENDED, 'Recipient account is suspended.');
    }

    // 6. Calculate fee
    const senderCurrency = senderData.currency || 'GHS';
    const recipientCurrency = recipientData.currency || 'GHS';
    const isCrossCountry = senderCurrency !== recipientCurrency;
    const fee = calculateFee(holdData.amount, isCrossCountry);

    // 7. Validate hold covers the fee
    if (holdData.amount < fee) {
      throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS, `Hold amount (${holdData.amount}) does not cover the fee (${fee}).`);
    }

    const transferAmount = holdData.amount - fee;

    // 8. Currency conversion if cross-country
    let creditAmount = transferAmount;
    let txExchangeRate = null;

    if (isCrossCountry) {
      const senderRate = rates[senderCurrency] || 1;
      const recipientRate = rates[recipientCurrency] || 1;
      txExchangeRate = senderRate > 0 ? recipientRate / senderRate : 0;
      creditAmount = Math.round(transferAmount * txExchangeRate);
    }

    // 9. Update sender wallet:
    //    - balance decreases by hold amount (total goes down)
    //    - heldBalance decreases by hold amount (hold consumed)
    //    - availableBalance unchanged (money was already excluded from available)
    transaction.update(senderWalletRef, {
      balance: admin.firestore.FieldValue.increment(-holdData.amount),
      heldBalance: admin.firestore.FieldValue.increment(-holdData.amount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 10. Update recipient wallet
    transaction.update(recipientRef, {
      balance: admin.firestore.FieldValue.increment(creditAmount),
      availableBalance: admin.firestore.FieldValue.increment(creditAmount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 11. Collect platform fee
    const exchangeRate = rates[senderCurrency] || 1;
    const feeInUSD = fee / exchangeRate;

    const platformWalletRef = db.collection('wallets').doc('platform');
    transaction.update(platformWalletRef, {
      totalBalanceUSD: admin.firestore.FieldValue.increment(feeInUSD),
      totalTransactions: admin.firestore.FieldValue.increment(1),
      totalFeesCollected: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const currencyBalanceRef = db.collection('wallets').doc('platform').collection('balances').doc(senderCurrency);
    transaction.set(currencyBalanceRef, {
      currency: senderCurrency,
      amount: admin.firestore.FieldValue.increment(fee),
      usdEquivalent: admin.firestore.FieldValue.increment(feeInUSD),
      txCount: admin.firestore.FieldValue.increment(1),
      lastTransactionAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const feeRecordRef = db.collection('wallets').doc('platform').collection('fees').doc(txId);
    transaction.set(feeRecordRef, {
      transactionId: txId,
      originalAmount: fee,
      currency: senderCurrency,
      usdAmount: feeInUSD,
      exchangeRate: exchangeRate,
      senderUid: holdData.walletId,
      transferAmount: holdData.amount,
      holdId: holdId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 12. Record transaction documents
    // Get display names (masked for privacy)
    const senderUserDoc = await transaction.get(db.collection('users').doc(holdData.walletId));
    const senderDisplayName = senderUserDoc.exists ? (senderUserDoc.data().displayName || senderUserDoc.data().legalName || 'User') : 'User';
    const recipientDisplayName = recipientUserDoc.exists ? (recipientUserDoc.data().displayName || recipientUserDoc.data().legalName || 'Merchant') : 'Merchant';

    const baseTxData = {
      id: txId,
      senderWalletId: senderData.walletId,
      receiverWalletId: recipientWalletId,
      senderName: senderDisplayName,
      receiverName: recipientDisplayName,
      amount: holdData.amount,
      fee: fee,
      currency: senderCurrency,
      senderCurrency: senderCurrency,
      receiverCurrency: recipientCurrency,
      note: note || `Hold conversion: ${holdData.reason} - ${holdData.referenceId}`,
      items: null,
      status: 'completed',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      reference: `TXN-${now.getTime()}`,
      exchangeRate: txExchangeRate,
      convertedAmount: isCrossCountry ? creditAmount : null,
      failureReason: null,
      holdId: holdId,
      holdReason: holdData.reason,
      holdReferenceId: holdData.referenceId,
    };

    // Sender transaction record
    transaction.set(
      db.collection('users').doc(holdData.walletId).collection('transactions').doc(txId),
      { ...baseTxData, type: 'send' }
    );

    // Recipient transaction record
    transaction.set(
      db.collection('users').doc(recipientUid).collection('transactions').doc(txId),
      {
        ...baseTxData,
        type: 'receive',
        fee: 0,
        amount: creditAmount,
        currency: recipientCurrency,
      }
    );

    // 13. Update hold status
    transaction.update(holdRef, {
      status: 'converted',
      releasedAt: admin.firestore.FieldValue.serverTimestamp(),
      releasedReason: 'delivered',
      convertedTransactionId: txId,
    });

    return {
      transactionId: txId,
      holdId: holdId,
      senderWalletId: holdData.walletId,
      recipientWalletId: recipientWalletId,
      amount: holdData.amount,
      fee: fee,
      transferAmount: transferAmount,
      creditAmount: creditAmount,
      exchangeRate: txExchangeRate,
      senderCurrency: senderCurrency,
      recipientCurrency: recipientCurrency,
      senderUid: holdData.walletId,
      recipientUid: recipientUid,
      senderName: senderDisplayName,
      recipientName: recipientDisplayName,
    };
  });

  // ── Post-transaction: audit, notifications, fraud check ──
  logFinancialOperation('convertHoldToTransfer', 'success', { transactionId: result.transactionId, holdId });

  await auditLog({
    action: 'convert_hold_to_transfer',
    userId: result.senderUid,
    performedBy: callerId,
    details: {
      holdId,
      transactionId: result.transactionId,
      amount: result.amount,
      fee: result.fee,
      transferAmount: result.transferAmount,
      creditAmount: result.creditAmount,
      recipientWalletId,
    },
  });

  // FCM notifications
  await Promise.all([
    sendPushNotification(result.senderUid, {
      title: 'Payment Completed',
      body: `Your held funds of ${result.senderCurrency}${(result.amount / 100).toFixed(2)} have been transferred to ${result.recipientName}.`,
      type: 'transaction',
      data: { action: 'hold_converted', holdId, transactionId: result.transactionId },
    }),
    sendPushNotification(result.recipientUid, {
      title: 'Payment Received',
      body: `You received ${result.recipientCurrency}${(result.creditAmount / 100).toFixed(2)} from ${result.senderName}.`,
      type: 'transaction',
      data: { action: 'hold_payment_received', transactionId: result.transactionId },
    }),
  ]);

  // Fraud detection
  await checkForFraud(result.senderUid, {
    id: result.transactionId,
    type: 'send',
    amount: result.amount,
    currency: result.senderCurrency,
  });

  return {
    success: true,
    transactionId: result.transactionId,
    transferAmount: result.transferAmount,
    fee: result.fee,
    creditAmount: result.creditAmount,
  };
});

// ============================================================
// WALLET HOLDS — EXPIRE OLD HOLDS (SCHEDULED)
// ============================================================

/**
 * Runs every hour. Finds active holds past their expiresAt deadline
 * and releases them automatically, restoring funds to availableBalance.
 *
 * Safety net: if Shop Afrik crashes or a merchant abandons an order,
 * buyer funds aren't frozen forever.
 */
exports.expireOldHolds = functions.pubsub
  .schedule('every 1 hours')
  .timeZone('UTC')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    // Query active holds that have passed their expiration
    const expiredQuery = await db.collection('wallet_holds')
      .where('status', '==', 'active')
      .where('expiresAt', '<=', now)
      .limit(500)
      .get();

    if (expiredQuery.empty) {
      logInfo('expireOldHolds: no expired holds found');
      return null;
    }

    logInfo('expireOldHolds: processing expired holds', { count: expiredQuery.size });

    let processed = 0;
    let failed = 0;

    for (const holdDoc of expiredQuery.docs) {
      const holdData = holdDoc.data();

      try {
        await db.runTransaction(async (transaction) => {
          // Re-read hold inside transaction to avoid races
          const freshHold = await transaction.get(holdDoc.ref);
          const freshData = freshHold.data();

          // Skip if already resolved (another process got here first)
          if (freshData.status !== 'active') {
            logInfo('expireOldHolds: hold already resolved, skipping', {
              holdId: holdDoc.id,
              status: freshData.status,
            });
            return;
          }

          // Read wallet
          const walletRef = db.collection('wallets').doc(freshData.walletId);
          const walletDoc2 = await transaction.get(walletRef);

          if (!walletDoc2.exists) {
            logError('expireOldHolds: wallet not found for hold', {
              holdId: holdDoc.id,
              walletId: freshData.walletId,
            });
            return;
          }

          // Release: decrease heldBalance, increase availableBalance
          transaction.update(walletRef, {
            heldBalance: admin.firestore.FieldValue.increment(-freshData.amount),
            availableBalance: admin.firestore.FieldValue.increment(freshData.amount),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Update hold status
          transaction.update(holdDoc.ref, {
            status: 'expired',
            releasedAt: admin.firestore.FieldValue.serverTimestamp(),
            releasedReason: 'expired',
          });
        });

        processed++;

        // Send FCM notification
        try {
          const userDoc = await db.collection('users').doc(holdData.walletId).get();
          if (userDoc.exists) {
            const fcmToken = userDoc.data().fcmToken;
            if (fcmToken) {
              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: 'Hold Expired',
                  body: `Your hold of ${holdData.currency}${(holdData.amount / 100).toFixed(2)} for ${holdData.referenceId} has expired. The funds are available again.`,
                },
                data: {
                  type: 'hold_expired',
                  holdId: holdDoc.id,
                },
              });
            }
          }
        } catch (fcmError) {
          logError('expireOldHolds: FCM notification failed', {
            holdId: holdDoc.id,
            error: fcmError.message,
          });
        }

        // Audit log
        await auditLog({
          action: 'expire_hold',
          userId: holdData.walletId,
          performedBy: 'system',
          details: {
            holdId: holdDoc.id,
            amount: holdData.amount,
            currency: holdData.currency,
            reason: holdData.reason,
            referenceId: holdData.referenceId,
          },
        });

      } catch (error) {
        failed++;
        logError('expireOldHolds: failed to expire hold', {
          holdId: holdDoc.id,
          error: error.message,
        });
      }
    }

    logInfo('expireOldHolds: completed', { processed, failed, total: expiredQuery.size });
    return null;
  });

  // ============================================================
// BUSINESS WALLETS — ROLE VERIFICATION HELPER
// ============================================================

/**
 * Verifies the caller has a sufficient role on a business wallet.
 * Business wallet roles use the same 8-role naming as the platform admin
 * hierarchy (Q-03 decision — unified naming across both systems).
 *
 * Hierarchy: viewer(1) < auditor(2) < support(3) < admin(4)
 *          < admin_supervisor(5) < finance(6) < admin_manager(7) < super_admin(8)
 *
 * Existing businessWallets/{id}.ownerUsers role assignments (viewer, admin,
 * admin_supervisor, admin_manager, super_admin) continue to work: role NAMES
 * retain their relative positions in the expanded hierarchy. New roles
 * (auditor, support, finance) become available for assignment via the
 * business wallet admin UI.
 *
 * @param {string} callerId - The caller's uid
 * @param {Object} businessWalletData - The businessWallets/{id} document data
 * @param {string} requiredRole - Minimum role required
 * @returns {{ uid: string, role: string }} Caller info
 */
function verifyBusinessWalletAccess(callerId, businessWalletData, requiredRole = 'viewer') {
  const ownerUsers = businessWalletData.ownerUsers || {};
  const callerRole = ownerUsers[callerId];

  if (!callerRole) {
    throwAppError(ERROR_CODES.AUTH_PERMISSION_DENIED, 'You are not authorized to access this business wallet.');
  }

  const roleHierarchy = {
    viewer: 1,
    auditor: 2,
    support: 3,
    admin: 4,
    admin_supervisor: 5,
    finance: 6,
    admin_manager: 7,
    super_admin: 8,
  };

  const callerLevel = roleHierarchy[callerRole] || 0;
  const requiredLevel = roleHierarchy[requiredRole] || 0;

  if (callerLevel < requiredLevel) {
    throwAppError(
      ERROR_CODES.AUTH_PERMISSION_DENIED,
      `This action requires '${requiredRole}' role on this business wallet. Your role: '${callerRole}'.`
    );
  }

  return { uid: callerId, role: callerRole };
}

// ============================================================
// BUSINESS WALLETS — CREATE BUSINESS WALLET
// ============================================================

/**
 * One-time setup for a new business wallet. Creates:
 * 1. businessWallets/{id} — metadata + ownerUsers map
 * 2. wallets/{id} — standard wallet doc (balance 0) so sendMoney works
 * 3. users/{id} — backing user doc with isBusinessWallet:true so lookupWallet works
 *
 * Auth: QR Wallet super_admin only (not business wallet role — this is a platform-level action).
 */
exports.createBusinessWallet = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  // Only QR Wallet super_admin can create business wallets
  const caller = await verifyAdmin(context, 'super_admin');

  const { name, country, currency, ownerEmail, logoUrl } = data;

  // ── Input validation ──
  if (!name || typeof name !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Business name is required.');
  }
  if (!country || typeof country !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Country is required.');
  }
  if (!currency || typeof currency !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Currency is required.');
  }
  if (!ownerEmail || typeof ownerEmail !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Owner email is required.');
  }

  // ── Look up the owner user by email ──
  let ownerUid;
  try {
    const ownerUser = await admin.auth().getUserByEmail(ownerEmail);
    ownerUid = ownerUser.uid;
  } catch (error) {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, `No user found with email: ${ownerEmail}. They must have a QR Wallet account first.`);
  }

  // ── Generate wallet ID ──
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  const segment = () => Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
  const walletId = `QRW-BIZ-${segment()}-${segment()}`;

  // ── Generate a unique business wallet document ID ──
  const businessId = `biz_${crypto.randomUUID().replace(/-/g, '').substring(0, 16)}`;

  await db.runTransaction(async (transaction) => {
    // Check business wallet doesn't already exist with this name
    // (outside transaction — just a safety check, not atomic)
    const existingQuery = await db.collection('businessWallets')
      .where('name', '==', name)
      .limit(1)
      .get();

    if (!existingQuery.empty) {
      throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, `A business wallet named '${name}' already exists.`);
    }

    // 1. Create businessWallets/{id} document
    const businessWalletRef = db.collection('businessWallets').doc(businessId);
    transaction.set(businessWalletRef, {
      name: name,
      logoUrl: logoUrl || null,
      walletId: walletId,
      country: country.toUpperCase(),
      currency: currency.toUpperCase(),
      isActive: true,
      ownerUsers: {
        [ownerUid]: 'super_admin',
      },
      allowedBankAccounts: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: caller.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Create backing wallets/{id} document (standard wallet so sendMoney works)
    const walletRef = db.collection('wallets').doc(businessId);
    transaction.set(walletRef, {
      id: businessId,
      userId: businessId,
      walletId: walletId,
      currency: currency.toUpperCase(),
      balance: 0,
      heldBalance: 0,
      availableBalance: 0,
      isActive: true,
      isBusinessWallet: true,
      dailySpent: 0,
      monthlySpent: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 3. Create backing users/{id} document (so lookupWallet and sendMoney find the "user")
    const userRef = db.collection('users').doc(businessId);
    transaction.set(userRef, {
      displayName: name,
      legalName: name,
      email: `${businessId}@business.qrwallet.internal`,
      country: country.toUpperCase(),
      currency: currency.toUpperCase(),
      isBusinessWallet: true,
      kycStatus: 'verified',
      phoneVerified: true,
      emailVerified: true,
      walletId: walletId,
      walletCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // ── Audit log ──
  await auditLog({
    action: 'create_business_wallet',
    userId: businessId,
    performedBy: caller.uid,
    details: {
      businessId,
      name,
      walletId,
      country,
      currency,
      ownerEmail,
      ownerUid,
    },
  });

  logInfo('Business wallet created', { businessId, name, walletId, country, currency });

  return {
    success: true,
    businessId: businessId,
    walletId: walletId,
    name: name,
    currency: currency.toUpperCase(),
    country: country.toUpperCase(),
  };
});

// ============================================================
// BUSINESS WALLETS — GET OVERVIEW
// ============================================================

/**
 * Returns balance, currency, and summary stats for a business wallet.
 * Auth: Any role in ownerUsers.
 */
exports.businessWalletGetOverview = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { businessId } = data;
  if (!businessId || typeof businessId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'businessId is required.');
  }

  // Verify access
  const bizDoc = await db.collection('businessWallets').doc(businessId).get();
  if (!bizDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Business wallet not found.');
  }
  verifyBusinessWalletAccess(context.auth.uid, bizDoc.data(), 'viewer');

  // Get backing wallet
  const walletDoc = await db.collection('wallets').doc(businessId).get();
  if (!walletDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Backing wallet not found.');
  }
  const walletData = walletDoc.data();
  const bizData = bizDoc.data();

  // Get transaction stats
  const txSnapshot = await db.collection('users').doc(businessId)
    .collection('transactions')
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get();

  const lastTransaction = txSnapshot.empty ? null : txSnapshot.docs[0].data();

  // Count transactions (approximate — use aggregation for accuracy at scale)
  const receivedQuery = await db.collection('users').doc(businessId)
    .collection('transactions')
    .where('type', '==', 'receive')
    .count()
    .get();

  const sentQuery = await db.collection('users').doc(businessId)
    .collection('transactions')
    .where('type', '==', 'send')
    .count()
    .get();

  return {
    businessId: businessId,
    name: bizData.name,
    walletId: bizData.walletId,
    currency: bizData.currency,
    country: bizData.country,
    isActive: bizData.isActive,
    balance: walletData.balance,
    heldBalance: walletData.heldBalance,
    availableBalance: walletData.availableBalance,
    totalReceived: receivedQuery.data().count,
    totalSent: sentQuery.data().count,
    lastTransactionAt: lastTransaction?.createdAt ? lastTransaction.createdAt.toDate().toISOString() : null,
  };
});

// ============================================================
// BUSINESS WALLETS — GET TRANSACTIONS
// ============================================================

/**
 * Returns paginated transactions for a business wallet.
 * Auth: Any role in ownerUsers.
 */
exports.businessWalletGetTransactions = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { businessId, limit: queryLimit, startAfter, type } = data;

  if (!businessId || typeof businessId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'businessId is required.');
  }

  // Verify access
  const bizDoc = await db.collection('businessWallets').doc(businessId).get();
  if (!bizDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Business wallet not found.');
  }
  verifyBusinessWalletAccess(context.auth.uid, bizDoc.data(), 'viewer');

  const pageSize = Math.min(Math.max(queryLimit || 20, 1), 100);

  let query = db.collection('users').doc(businessId)
    .collection('transactions')
    .orderBy('createdAt', 'desc')
    .limit(pageSize);

  // Filter by type if provided
  if (type && typeof type === 'string') {
    query = db.collection('users').doc(businessId)
      .collection('transactions')
      .where('type', '==', type)
      .orderBy('createdAt', 'desc')
      .limit(pageSize);
  }

  // Pagination cursor
  if (startAfter) {
    const cursorDoc = await db.collection('users').doc(businessId)
      .collection('transactions').doc(startAfter).get();
    if (cursorDoc.exists) {
      query = query.startAfter(cursorDoc);
    }
  }

  const snapshot = await query.get();

  const transactions = snapshot.docs.map(doc => {
    const d = doc.data();
    return {
      id: doc.id,
      type: d.type,
      amount: d.amount,
      fee: d.fee || 0,
      currency: d.currency,
      senderName: d.senderName,
      receiverName: d.receiverName,
      senderWalletId: d.senderWalletId,
      receiverWalletId: d.receiverWalletId,
      note: d.note,
      status: d.status,
      createdAt: d.createdAt ? d.createdAt.toDate().toISOString() : null,
      holdId: d.holdId || null,
      sourceApp: d.sourceApp || null,
    };
  });

  return {
    transactions,
    count: transactions.length,
    hasMore: transactions.length >= pageSize,
    lastId: transactions.length > 0 ? transactions[transactions.length - 1].id : null,
  };
});

// ============================================================
// BUSINESS WALLETS — GET COUNTRY BREAKDOWN
// ============================================================

/**
 * Aggregates business wallet transactions by currency.
 * Since currency ≈ country in v1, this gives a country breakdown.
 * Auth: Any role in ownerUsers.
 */
exports.businessWalletGetCountryBreakdown = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { businessId } = data;
  if (!businessId || typeof businessId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'businessId is required.');
  }

  // Verify access
  const bizDoc = await db.collection('businessWallets').doc(businessId).get();
  if (!bizDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Business wallet not found.');
  }
  verifyBusinessWalletAccess(context.auth.uid, bizDoc.data(), 'viewer');

  // Fetch all received transactions (payments from buyers)
  const receivedSnapshot = await db.collection('users').doc(businessId)
    .collection('transactions')
    .where('type', '==', 'receive')
    .get();

  // Aggregate by sender currency
  const breakdown = {};
  receivedSnapshot.forEach(doc => {
    const d = doc.data();
    const currency = d.senderCurrency || d.currency || 'UNKNOWN';
    if (!breakdown[currency]) {
      breakdown[currency] = { currency, totalAmount: 0, transactionCount: 0 };
    }
    breakdown[currency].totalAmount += d.amount || 0;
    breakdown[currency].transactionCount += 1;
  });

  return {
    breakdown: Object.values(breakdown),
    totalCurrencies: Object.keys(breakdown).length,
  };
});

// ============================================================
// BUSINESS WALLETS — WITHDRAW
// ============================================================

/**
 * Initiates a Paystack bank transfer from the business wallet.
 * Auth: super_admin on the business wallet only.
 */
exports.businessWalletWithdraw = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY_PARAM], enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { businessId, amount, bankCode, accountNumber, accountName, reason } = data;

  if (!businessId || typeof businessId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'businessId is required.');
  }
  if (!amount || typeof amount !== 'number' || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID, 'amount must be a positive number.');
  }
  if (!bankCode || typeof bankCode !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'bankCode is required.');
  }
  if (!accountNumber || typeof accountNumber !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'accountNumber is required.');
  }

  // Verify business wallet access — super_admin only for withdrawals
  const bizDoc = await db.collection('businessWallets').doc(businessId).get();
  if (!bizDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Business wallet not found.');
  }
  const caller = verifyBusinessWalletAccess(context.auth.uid, bizDoc.data(), 'super_admin');

  // Check wallet balance
  const walletDoc = await db.collection('wallets').doc(businessId).get();
  if (!walletDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Backing wallet not found.');
  }
  const walletData = walletDoc.data();
  const available = walletData.availableBalance ?? (walletData.balance - (walletData.heldBalance || 0));

  if (available < amount) {
    throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS, `Available balance is ${available}, but withdrawal requires ${amount}.`);
  }

  // Create Paystack transfer recipient
  const paystackSecretKey = PAYSTACK_SECRET_KEY.value;
  if (!paystackSecretKey) {
    throwAppError(ERROR_CODES.CONFIG_MISSING, 'Paystack is not configured.');
  }

  const axios = require('axios');
  const reference = `BIZ-WD-${Date.now()}-${crypto.randomUUID().substring(0, 8)}`;

  try {
    // Step 1: Create transfer recipient
    const recipientResponse = await axios.post(
      'https://api.paystack.co/transferrecipient',
      {
        type: 'nuban',
        name: accountName || bizDoc.data().name,
        account_number: accountNumber,
        bank_code: bankCode,
        currency: walletData.currency,
      },
      { headers: { Authorization: `Bearer ${paystackSecretKey}` } }
    );

    if (!recipientResponse.data.status) {
      throwAppError(ERROR_CODES.SERVICE_PAYSTACK_ERROR, 'Failed to create transfer recipient.');
    }

    const recipientCode = recipientResponse.data.data.recipient_code;

    // Step 2: Debit wallet atomically
    await db.runTransaction(async (transaction) => {
      const freshWallet = await transaction.get(walletDoc.ref);
      const freshData = freshWallet.data();
      const freshAvailable = freshData.availableBalance ?? (freshData.balance - (freshData.heldBalance || 0));

      if (freshAvailable < amount) {
        throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS, 'Balance changed. Please try again.');
      }

      const newBalance = freshData.balance - amount;
      transaction.update(walletDoc.ref, {
        balance: newBalance,
        availableBalance: newBalance - (freshData.heldBalance || 0),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Record withdrawal
      transaction.set(db.collection('withdrawals').doc(reference), {
        userId: businessId,
        businessId: businessId,
        amount: amount,
        currency: walletData.currency,
        bankCode: bankCode,
        accountNumber: accountNumber,
        accountName: accountName || bizDoc.data().name,
        recipientCode: recipientCode,
        reference: reference,
        status: 'pending',
        reason: reason || 'Business wallet withdrawal',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: caller.uid,
      });
    });

    // Step 3: Initiate Paystack transfer
    const transferResponse = await axios.post(
      'https://api.paystack.co/transfer',
      {
        source: 'balance',
        amount: amount,
        recipient: recipientCode,
        reason: reason || `${bizDoc.data().name} withdrawal`,
        reference: reference,
      },
      { headers: { Authorization: `Bearer ${paystackSecretKey}` } }
    );

    // Update withdrawal status
    if (transferResponse.data.status) {
      await db.collection('withdrawals').doc(reference).update({
        status: 'processing',
        paystackTransferCode: transferResponse.data.data.transfer_code,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await auditLog({
      action: 'business_wallet_withdraw',
      userId: businessId,
      performedBy: caller.uid,
      details: { businessId, amount, bankCode, accountNumber, reference },
    });

    logInfo('Business wallet withdrawal initiated', { businessId, amount, reference });

    return {
      success: true,
      reference: reference,
      amount: amount,
      status: 'processing',
    };

  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Business wallet withdrawal failed', { businessId, error: error.message });
    throwAppError(ERROR_CODES.SERVICE_PAYSTACK_ERROR, 'Withdrawal failed: ' + error.message);
  }
});

// ============================================================
// BUSINESS WALLETS — REFUND TRANSACTION
// ============================================================

/**
 * Refunds a buyer from the business wallet. Debits the business wallet
 * and credits the buyer's personal wallet. Follows the refund escalation
 * rules defined in the integration spec.
 *
 * Auth: admin+ on the business wallet (with escalation rules enforced).
 * Idempotent: calling twice with the same refundId is a no-op.
 */
exports.businessWalletRefundTransaction = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const { businessId, originalTransactionId, buyerWalletId, amount, reason, refundId } = data;

  // ── Input validation ──
  if (!businessId || typeof businessId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'businessId is required.');
  }
  if (!originalTransactionId || typeof originalTransactionId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'originalTransactionId is required.');
  }
  if (!buyerWalletId || typeof buyerWalletId !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'buyerWalletId is required.');
  }
  if (!amount || typeof amount !== 'number' || amount <= 0) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID, 'Refund amount must be positive.');
  }
  if (!reason || typeof reason !== 'string') {
    throwAppError(ERROR_CODES.SYSTEM_VALIDATION_FAILED, 'Refund reason is required.');
  }

  // ── Verify business wallet access — admin+ required ──
  const bizDoc = await db.collection('businessWallets').doc(businessId).get();
  if (!bizDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'Business wallet not found.');
  }
  const caller = verifyBusinessWalletAccess(context.auth.uid, bizDoc.data(), 'admin');

  // ── Idempotency check ──
  if (refundId) {
    const existingRefund = await db.collection('users').doc(businessId)
      .collection('transactions').doc(refundId).get();
    if (existingRefund.exists) {
      logInfo('Refund already processed, returning existing result', { refundId });
      return { success: true, refundId: refundId, message: 'Refund already processed.' };
    }
  }

  // ── Verify original transaction exists ──
  const originalTx = await db.collection('users').doc(businessId)
    .collection('transactions').doc(originalTransactionId).get();
  if (!originalTx.exists) {
    throwAppError(ERROR_CODES.TXN_NOT_FOUND, 'Original transaction not found in business wallet.');
  }
  const originalTxData = originalTx.data();

  // Verify refund amount doesn't exceed original
  if (amount > originalTxData.amount) {
    throwAppError(ERROR_CODES.TXN_AMOUNT_INVALID, `Refund amount (${amount}) exceeds original transaction amount (${originalTxData.amount}).`);
  }

  // ── Find buyer wallet ──
  const buyerQuery = await db.collection('wallets')
    .where('walletId', '==', buyerWalletId)
    .limit(1)
    .get();

  if (buyerQuery.empty) {
    throwAppError(ERROR_CODES.TXN_RECIPIENT_NOT_FOUND, 'Buyer wallet not found.');
  }

  const buyerDoc = buyerQuery.docs[0];
  const buyerUid = buyerDoc.id;

  const txId = refundId || `REFUND-${Date.now()}-${crypto.randomUUID().substring(0, 8)}`;

  // ── Atomic refund transaction ──
  await db.runTransaction(async (transaction) => {
    // Read business wallet
    const bizWalletRef = db.collection('wallets').doc(businessId);
    const bizWallet = await transaction.get(bizWalletRef);
    const bizWalletData = bizWallet.data();

    // Check business wallet has enough balance
    const bizAvailable = bizWalletData.availableBalance ?? (bizWalletData.balance - (bizWalletData.heldBalance || 0));
    if (bizAvailable < amount) {
      throwAppError(ERROR_CODES.WALLET_INSUFFICIENT_FUNDS, `Business wallet available balance (${bizAvailable}) is less than refund amount (${amount}).`);
    }

    // Read buyer wallet
    const buyerWalletRef = db.collection('wallets').doc(buyerUid);
    const buyerWallet = await transaction.get(buyerWalletRef);
    const buyerWalletData = buyerWallet.data();

    // Debit business wallet
    const newBizBalance = bizWalletData.balance - amount;
    transaction.update(bizWalletRef, {
      balance: newBizBalance,
      availableBalance: newBizBalance - (bizWalletData.heldBalance || 0),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Credit buyer wallet
    const newBuyerBalance = buyerWalletData.balance + amount;
    transaction.update(buyerWalletRef, {
      balance: newBuyerBalance,
      availableBalance: newBuyerBalance - (buyerWalletData.heldBalance || 0),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Record refund on business wallet side
    transaction.set(
      db.collection('users').doc(businessId).collection('transactions').doc(txId),
      {
        id: txId,
        type: 'send',
        amount: amount,
        fee: 0,
        currency: bizWalletData.currency,
        senderWalletId: bizDoc.data().walletId,
        receiverWalletId: buyerWalletId,
        senderName: bizDoc.data().name,
        receiverName: 'Buyer',
        note: `Refund: ${reason}`,
        status: 'completed',
        isRefund: true,
        originalTransactionId: originalTransactionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        reference: `REFUND-${Date.now()}`,
      }
    );

    // Record refund on buyer side
    transaction.set(
      db.collection('users').doc(buyerUid).collection('transactions').doc(txId),
      {
        id: txId,
        type: 'receive',
        amount: amount,
        fee: 0,
        currency: buyerWalletData.currency,
        senderWalletId: bizDoc.data().walletId,
        receiverWalletId: buyerWalletId,
        senderName: bizDoc.data().name,
        receiverName: 'Buyer',
        note: `Refund from ${bizDoc.data().name}: ${reason}`,
        status: 'completed',
        isRefund: true,
        originalTransactionId: originalTransactionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        reference: `REFUND-${Date.now()}`,
      }
    );
  });

  // ── Audit log ──
  await auditLog({
    action: 'business_wallet_refund',
    userId: businessId,
    performedBy: caller.uid,
    details: {
      businessId,
      refundId: txId,
      originalTransactionId,
      buyerWalletId,
      buyerUid,
      amount,
      reason,
      callerRole: caller.role,
    },
  });

  // ── Notify buyer ──
  try {
    await sendPushNotification(buyerUid, {
      title: 'Refund Received',
      body: `You received a refund of ${bizDoc.data().currency}${(amount / 100).toFixed(2)} from ${bizDoc.data().name}.`,
      type: 'transaction',
      data: { action: 'refund_received', refundId: txId },
    });
  } catch (fcmError) {
    logError('Failed to send refund notification', { txId, error: fcmError.message });
  }

  logInfo('Business wallet refund processed', { businessId, txId, amount, buyerUid });

  return {
    success: true,
    refundId: txId,
    amount: amount,
  };
});

// ============================================================
// SCHEDULED: PLATFORM TRANSFER PROPOSAL AUTO-EXPIRY (Phase 2a)
// ============================================================

/**
 * Scheduled: Auto-expire proposals that have passed their expiresAt window.
 * Runs every 1 minute. Transitions status from 'proposed' to 'expired'.
 *
 * Ref: Phase 2a agent commit 6/6
 */
exports.autoExpireProposals = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('UTC')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    const expiredSnap = await db.collection('platform_transfer_proposals')
      .where('status', '==', 'proposed')
      .where('expiresAt', '<', now)
      .limit(100)
      .get();

    if (expiredSnap.empty) {
      return null;
    }

    let expiredCount = 0;
    const batch = db.batch();

    for (const doc of expiredSnap.docs) {
      try {
        batch.update(doc.ref, {
          status: 'expired',
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelReason: 'expired',
        });
        expiredCount++;
      } catch (error) {
        logError('autoExpireProposals: failed to process proposal', {
          proposalId: doc.id,
          error: error.message,
        });
      }
    }

    if (expiredCount > 0) {
      await batch.commit();

      // Write audit log entries for each expiration
      const auditBatch = db.batch();
      for (const doc of expiredSnap.docs) {
        const auditRef = db.collection('audit_logs').doc();
        auditBatch.set(auditRef, {
          userId: 'system',
          operation: 'proposal_expired',
          result: 'success',
          metadata: { proposalId: doc.id, amount: doc.data().amount, currency: doc.data().currency },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await auditBatch.commit();
    }

    logInfo('autoExpireProposals completed', { expiredCount });
    return null;
  });

/**
 * Scheduled: Auto-cancel proposals stuck in pending_otp past their otpExpiresAt.
 * Runs every 1 minute. Transitions status from 'pending_otp' to 'cancelled'.
 *
 * NOTE: This commit only handles the doc-state update. It does NOT do Paystack
 * balance refunds — those happen in the human-pair commit that modifies
 * adminFinalizeTransfer.
 *
 * Ref: Phase 2a agent commit 6/6
 */
exports.autoExpireOtpTransfers = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('UTC')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    const expiredOtpSnap = await db.collection('platform_transfer_proposals')
      .where('status', '==', 'pending_otp')
      .where('otpExpiresAt', '<', now)
      .limit(100)
      .get();

    if (expiredOtpSnap.empty) {
      return null;
    }

    let cancelledCount = 0;

    for (const doc of expiredOtpSnap.docs) {
      try {
        await doc.ref.update({
          status: 'cancelled',
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelReason: 'auto_cancelled_otp_timeout',
        });

        // TODO(Phase 2a human-pair commit 7): refund platform balance here.
        // For now, balance remains deducted. Manual reconciliation required.

        // Audit log
        await db.collection('audit_logs').add({
          userId: 'system',
          operation: 'otp_transfer_expired',
          result: 'success',
          metadata: { proposalId: doc.id, reason: 'auto_cancelled_otp_timeout' },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        cancelledCount++;
      } catch (error) {
        logError('autoExpireOtpTransfers: failed to process proposal', {
          proposalId: doc.id,
          error: error.message,
        });
      }
    }

    logInfo('autoExpireOtpTransfers completed', { cancelledCount });
    return null;
  });

// ============================================================
// EMAIL + SMS QUEUE PROCESSORS (Phase 2b)
// ============================================================

/**
 * Scheduled: Retry emails that failed to send.
 * Runs every 5 minutes. After 3 attempts spanning ~1 hour, marks failed_permanently.
 */
exports.processEmailQueue = functions
  .runWith({ secrets: [RESEND_API_KEY_PARAM] })
  .pubsub
  .schedule('every 5 minutes')
  .timeZone('UTC')
  .onRun(async (context) => {
    const fifteenMinAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 15 * 60 * 1000);

    const snap = await db.collection('email_queue')
      .where('status', '==', 'pending')
      .where('attemptCount', '<', 3)
      .limit(50)
      .get();

    let attempted = 0;
    let succeeded = 0;
    let failedPermanently = 0;

    for (const doc of snap.docs) {
      const d = doc.data();
      const lastAttempt = d.lastAttemptAt;
      if (lastAttempt && lastAttempt.toMillis() > fifteenMinAgo.toMillis()) {
        continue;
      }

      attempted++;
      try {
        const { Resend } = require('resend');
        const resend = new Resend(RESEND_API_KEY_PARAM.value());

        await resend.emails.send({
          from: `${d.fromName} <${d.fromEmail}>`,
          to: [d.toName ? `${d.toName} <${d.to}>` : d.to],
          subject: d.subject,
          html: d.htmlBody,
          text: d.textBody,
          replyTo: d.replyTo,
        });

        await doc.ref.update({
          status: 'sent',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        succeeded++;
      } catch (error) {
        const newAttemptCount = (d.attemptCount || 0) + 1;
        const update = {
          attemptCount: newAttemptCount,
          lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
          lastError: error.message,
        };
        if (newAttemptCount >= 3) {
          update.status = 'failed_permanently';
          failedPermanently++;
        }
        await doc.ref.update(update);
      }
    }

    logInfo('processEmailQueue completed', { attempted, succeeded, failedPermanently });
    return null;
  });

/**
 * Scheduled: Retry SMS messages that failed to send.
 * Runs every 5 minutes. After 3 attempts, marks failed_permanently.
 */
exports.processSmsQueue = functions
  .runWith({ secrets: [AT_API_KEY] })
  .pubsub
  .schedule('every 5 minutes')
  .timeZone('UTC')
  .onRun(async (context) => {
    const fifteenMinAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 15 * 60 * 1000);

    const snap = await db.collection('sms_queue')
      .where('status', '==', 'pending')
      .where('attemptCount', '<', 3)
      .limit(50)
      .get();

    let attempted = 0, succeeded = 0, failedPermanently = 0;

    for (const doc of snap.docs) {
      const d = doc.data();
      if (d.lastAttemptAt && d.lastAttemptAt.toMillis() > fifteenMinAgo.toMillis()) continue;

      attempted++;
      try {
        const africastalking = require('africastalking')({
          apiKey: AT_API_KEY.value(),
          username: AT_USERNAME.value() || 'sandbox',
        });
        await africastalking.SMS.send({ to: [d.phoneNumber], message: d.message });

        await doc.ref.update({
          status: 'sent',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        succeeded++;
      } catch (error) {
        const newCount = (d.attemptCount || 0) + 1;
        const update = {
          attemptCount: newCount,
          lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
          lastError: error.message,
        };
        if (newCount >= 3) {
          update.status = 'failed_permanently';
          failedPermanently++;
        }
        await doc.ref.update(update);
      }
    }

    logInfo('processSmsQueue completed', { attempted, succeeded, failedPermanently });
    return null;
  });

// ============================================================
// EVIDENCE LIFECYCLE SCHEDULERS (Phase 2b)
// ============================================================

/**
 * Scheduled: Mark completed proposals as evidence_overdue after 7 days
 * without evidence upload.
 * Runs every 60 minutes.
 *
 * Ref: Phase 2b agent commit 8/10
 */
exports.markEvidenceOverdueScheduled = functions.pubsub
  .schedule('every 60 minutes')
  .timeZone('UTC')
  .onRun(async (context) => {
    const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const snap = await db.collection('platform_transfer_proposals')
      .where('status', '==', 'completed')
      .where('completedAt', '<', sevenDaysAgo)
      .limit(100)
      .get();

    let overdueCount = 0;

    for (const doc of snap.docs) {
      const d = doc.data();
      if (d.evidenceUploadedAt) continue;

      try {
        await doc.ref.update({
          status: 'evidence_overdue',
          evidenceOverdueAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Email proposer about overdue evidence
        await sendProposalEmail({
          to: d.proposedBy.email,
          toName: d.proposedBy.displayName || null,
          subject: `Evidence overdue for completed transfer ${doc.id}`,
          htmlBody: `<p>The receipt and evidence for your completed transfer <strong>${doc.id}</strong> are overdue.</p>
<p>Please upload them through the admin dashboard within 14 days to avoid being blocked from new proposals.</p>`,
          textBody: `Evidence overdue for transfer ${doc.id}. Upload within 14 days or be blocked.`,
          relatedTo: `proposal:${doc.id}`,
        });

        await db.collection('audit_logs').add({
          userId: 'system',
          operation: 'proposal_evidence_overdue',
          result: 'success',
          metadata: { proposalId: doc.id },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        overdueCount++;
      } catch (error) {
        logError('markEvidenceOverdueScheduled: failed to process proposal', {
          proposalId: doc.id,
          error: error.message,
        });
      }
    }

    logInfo('markEvidenceOverdueScheduled completed', { overdueCount });
    return null;
  });

/**
 * Scheduled: Block finance users with proposals overdue for 21+ days.
 * Runs every 60 minutes.
 *
 * Ref: Phase 2b agent commit 8/10
 */
exports.markFinanceBlockedScheduled = functions.pubsub
  .schedule('every 60 minutes')
  .timeZone('UTC')
  .onRun(async (context) => {
    const twentyOneDaysAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 21 * 24 * 60 * 60 * 1000);

    const snap = await db.collection('platform_transfer_proposals')
      .where('status', '==', 'evidence_overdue')
      .where('completedAt', '<', twentyOneDaysAgo)
      .limit(100)
      .get();

    let blockedCount = 0;

    for (const doc of snap.docs) {
      const proposal = doc.data();
      if (proposal.financeBlockedAt) continue;

      try {
        await doc.ref.update({
          financeBlockedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const blockedRef = db.collection('blocked_finance_users').doc(proposal.proposedBy.uid);
        const blockedDoc = await blockedRef.get();
        if (blockedDoc.exists) {
          await blockedRef.update({
            openOverdueProposals: admin.firestore.FieldValue.arrayUnion(proposal.proposalId),
          });
        } else {
          await blockedRef.set({
            uid: proposal.proposedBy.uid,
            email: proposal.proposedBy.email,
            blockedAt: admin.firestore.FieldValue.serverTimestamp(),
            reason: 'overdue_evidence',
            openOverdueProposals: [proposal.proposalId],
          });
        }

        // Email proposer about being blocked
        await sendProposalEmail({
          to: proposal.proposedBy.email,
          toName: proposal.proposedBy.displayName || null,
          subject: `You are blocked from new proposals — upload evidence`,
          htmlBody: `<p>You have overdue evidence on transfer ${proposal.proposalId}.</p>
<p>You are now blocked from submitting new proposals until you close the overdue ones via the admin dashboard.</p>`,
          textBody: `Blocked from new proposals. Close overdue proposal ${proposal.proposalId} to unblock.`,
          relatedTo: `proposal:${proposal.proposalId}`,
        });

        await db.collection('audit_logs').add({
          userId: 'system',
          operation: 'finance_user_blocked',
          result: 'success',
          metadata: { proposalId: doc.id, blockedUid: proposal.proposedBy.uid },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        blockedCount++;
      } catch (error) {
        logError('markFinanceBlockedScheduled: failed to process proposal', {
          proposalId: doc.id,
          error: error.message,
        });
      }
    }

    logInfo('markFinanceBlockedScheduled completed', { blockedCount });
    return null;
  });

// ============================================================
// COLD ARCHIVE (Phase 2b)
// ============================================================

/**
 * Scheduled: Archive old documents (2+ years) to GCS bucket.
 * Runs 1st of every month at 00:00 UTC.
 * Targets: audit_logs, admin_activity, platform_transfer_proposals (terminal only).
 *
 * Ref: Phase 2b agent commit 10/10
 */
exports.coldArchiveScheduled = functions.pubsub
  .schedule('0 0 1 * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    const ARCHIVE_BUCKET = 'qr-wallet-1993-archive';
    const TWO_YEARS_MS = 730 * 24 * 60 * 60 * 1000;
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - TWO_YEARS_MS);

    let bucket;
    try {
      bucket = admin.storage().bucket(ARCHIVE_BUCKET);
      await bucket.getMetadata();
    } catch (err) {
      logWarning('coldArchiveScheduled: archive bucket does not exist yet — skipping this run', { bucket: ARCHIVE_BUCKET });
      return null;
    }

    const collections = [
      { name: 'audit_logs', timestampField: 'timestamp', filter: null },
      { name: 'admin_activity', timestampField: 'timestamp', filter: null },
      {
        name: 'platform_transfer_proposals',
        timestampField: 'proposedAt',
        filter: { field: 'status', op: 'in', values: ['closed', 'rejected', 'cancelled', 'expired'] },
      },
    ];

    const archivedCounts = {};

    for (const col of collections) {
      archivedCounts[col.name] = 0;

      try {
        let query = db.collection(col.name)
          .where(col.timestampField, '<', cutoff)
          .limit(500);

        if (col.filter) {
          query = query.where(col.filter.field, col.filter.op, col.filter.values);
        }

        const snap = await query.get();

        for (const doc of snap.docs) {
          try {
            const payload = JSON.stringify(doc.data());
            const filePath = `${col.name}/${doc.id}.json`;
            const file = bucket.file(filePath);

            await file.save(payload, { contentType: 'application/json' });

            const [metadata] = await file.getMetadata();
            if (metadata && metadata.size > 0) {
              await doc.ref.delete();
              archivedCounts[col.name]++;
            } else {
              logWarning('coldArchiveScheduled: GCS write succeeded but metadata empty', { filePath });
            }
          } catch (docError) {
            logError('coldArchiveScheduled: failed to archive doc', {
              collection: col.name,
              docId: doc.id,
              error: docError.message,
            });
          }
        }
      } catch (colError) {
        logError('coldArchiveScheduled: failed to process collection', {
          collection: col.name,
          error: colError.message,
        });
      }
    }

    logInfo('coldArchiveScheduled completed', { archivedCounts });
    return null;
  });

/**
 * Admin: Restore a document from cold archive.
 * Super_admin only. Reads from GCS and writes back to Firestore with a restore marker.
 *
 * Ref: Phase 2b agent commit 10/10
 */
exports.adminRestoreFromArchive = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'super_admin');

  const { collection, docId } = data || {};
  const ARCHIVE_BUCKET = 'qr-wallet-1993-archive';
  const ALLOWED_COLLECTIONS = ['audit_logs', 'admin_activity', 'platform_transfer_proposals'];

  if (!collection || !ALLOWED_COLLECTIONS.includes(collection)) {
    throw new functions.https.HttpsError('invalid-argument',
      `collection must be one of: ${ALLOWED_COLLECTIONS.join(', ')}`);
  }
  if (!docId || typeof docId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'docId is required.');
  }

  try {
    const bucket = admin.storage().bucket(ARCHIVE_BUCKET);
    const file = bucket.file(`${collection}/${docId}.json`);
    const [contents] = await file.download();
    const originalData = JSON.parse(contents.toString('utf8'));

    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerEmail = callerRecord.email || 'unknown';

    await db.collection(collection).doc(docId).set({
      ...originalData,
      restoredFromArchive: true,
      restoredAt: admin.firestore.FieldValue.serverTimestamp(),
      restoredBy: { uid: caller.uid, email: callerEmail },
    });

    await db.collection('audit_logs').add({
      userId: caller.uid,
      operation: 'archive_restored',
      result: 'success',
      metadata: { collection, docId },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, collection, docId, restored: true };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminRestoreFromArchive failed', { collection, docId, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to restore from archive: ' + error.message);
  }
});

// ============================================================
// DISPUTE RESOLUTION SYSTEM (Phase 2d)
// ============================================================

/**
 * Stub for opportunistic hold placement. Returns 0 (no hold).
 * Human-pair commit 7 replaces this with real implementation that moves
 * funds from recipient's availableBalance to heldBalance.
 */
async function placeOpportunisticHoldStub({ recipientUid, currency, requestedAmount, disputeId }) {
  logInfo('placeOpportunisticHoldStub called (no-op)', { recipientUid, currency, requestedAmount, disputeId });
  return 0;
}

/**
 * User: File a dispute against a transaction.
 * Validates 7-day window, max 3 active disputes, computes tiered fee.
 * Places opportunistic hold on recipient's wallet (stub for now).
 */
exports.userFileDispute = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }
  const callerUid = context.auth.uid;

  const { originalTransactionId, disputedAmount, issueType, description, idempotencyKey } = data || {};

  // Input validation
  const VALID_ISSUE_TYPES = ['money_sent_not_received', 'service_not_delivered', 'item_not_delivered', 'other'];
  if (!originalTransactionId || typeof originalTransactionId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'originalTransactionId is required.');
  }
  if (!issueType || !VALID_ISSUE_TYPES.includes(issueType)) {
    throw new functions.https.HttpsError('invalid-argument', `issueType must be one of: ${VALID_ISSUE_TYPES.join(', ')}`);
  }
  if (!description || typeof description !== 'string' || description.trim().length < 10) {
    throw new functions.https.HttpsError('invalid-argument', 'description must be at least 10 characters.');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey must be at least 16 characters.');
  }
  if (!disputedAmount || typeof disputedAmount !== 'number' || disputedAmount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'disputedAmount must be a positive number.');
  }

  // Rate limit
  const withinLimit = await checkRateLimitPersistent(callerUid, 'userFileDispute');
  if (!withinLimit) {
    throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.userFileDispute.message);
  }

  try {
    // Look up original transaction (user's subcollection)
    const txDoc = await db.collection('users').doc(callerUid)
      .collection('transactions').doc(originalTransactionId).get();
    if (!txDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Transaction not found.');
    }
    const tx = txDoc.data();

    // Verify caller is sender
    if (tx.senderWalletId !== callerUid && tx.senderWalletId !== tx.senderWalletId) {
      // Check by looking up caller's wallet
      const callerWalletDoc = await db.collection('wallets').doc(callerUid).get();
      const callerWalletId = callerWalletDoc.exists ? callerWalletDoc.data().walletId : null;
      if (tx.senderWalletId !== callerWalletId && tx.senderWalletId !== callerUid) {
        throw new functions.https.HttpsError('permission-denied', 'You can only dispute transactions you sent.');
      }
    }

    // 7-day window check
    const txCreatedAt = tx.createdAt && tx.createdAt.toMillis ? tx.createdAt.toMillis() : Date.parse(tx.createdAt);
    const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;
    if (Date.now() - txCreatedAt > SEVEN_DAYS_MS) {
      throw new functions.https.HttpsError('failed-precondition',
        'Dispute filing window expired. Disputes must be filed within 7 days of the transaction.');
    }

    // Disputed amount check
    const originalAmount = tx.amount || 0;
    if (disputedAmount > originalAmount) {
      throw new functions.https.HttpsError('invalid-argument',
        `Disputed amount (${disputedAmount}) cannot exceed transaction amount (${originalAmount}).`);
    }

    // Max 3 active disputes
    const activeDisputesSnap = await db.collection('disputes')
      .where('filedBy.uid', '==', callerUid)
      .where('status', 'not-in', ['resolved', 'closed_stuck'])
      .limit(4)
      .get();
    if (activeDisputesSnap.size >= 3) {
      throw new functions.https.HttpsError('resource-exhausted',
        'You already have 3 active disputes. Please wait for existing disputes to resolve.');
    }

    // Compute fee
    const ratesDoc = await db.collection('app_config').doc('exchange_rates').get();
    const rates = ratesDoc.exists ? ratesDoc.data().rates || {} : {};
    const txCurrency = tx.currency || 'NGN';
    const exchangeRate = rates[txCurrency] || 1;
    const usdEquivalent = disputedAmount / exchangeRate;
    const fee = calculateDisputeFee(usdEquivalent);

    // Check caller wallet for fee deduction
    const callerWallet = await db.collection('wallets').doc(callerUid).get();
    let feeDeductedFrom = 'recovery';
    const feeInMinorUnits = Math.round(fee * exchangeRate * 100);
    if (callerWallet.exists) {
      const walletData = callerWallet.data();
      const available = walletData.availableBalance || walletData.balance || 0;
      if (available >= feeInMinorUnits && feeInMinorUnits > 0) {
        await db.collection('wallets').doc(callerUid).update({
          balance: admin.firestore.FieldValue.increment(-feeInMinorUnits),
          availableBalance: admin.firestore.FieldValue.increment(-feeInMinorUnits),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        feeDeductedFrom = 'wallet_at_filing';
      }
    }

    // Generate dispute ID
    const disputeId = `DSP-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;

    // Get caller info
    const callerRecord = await admin.auth().getUser(callerUid);
    const callerEmail = callerRecord.email || 'unknown';
    const callerDisplayName = callerRecord.displayName || callerEmail;
    const callerUserDoc = await db.collection('users').doc(callerUid).get();
    const callerPhone = callerUserDoc.exists ? callerUserDoc.data().phoneNumber || '' : '';

    // Get recipient info
    const recipientUid = tx.receiverWalletId || '';
    let recipientEmail = '', recipientDisplayName = '', recipientPhone = '';
    if (recipientUid) {
      try {
        const recipientUserDoc = await db.collection('users').doc(recipientUid).get();
        if (recipientUserDoc.exists) {
          const rd = recipientUserDoc.data();
          recipientEmail = rd.email || '';
          recipientDisplayName = rd.fullName || rd.legalName || '';
          recipientPhone = rd.phoneNumber || '';
        }
      } catch (e) { /* recipient lookup failure non-blocking */ }
    }

    // Place opportunistic hold (stub returns 0)
    const holdAmount = await placeOpportunisticHoldStub({
      recipientUid,
      currency: txCurrency,
      requestedAmount: disputedAmount,
      disputeId,
    });

    const THREE_DAYS_MS = 3 * 24 * 60 * 60 * 1000;

    // Write dispute doc
    await db.collection('disputes').doc(disputeId).set({
      disputeId,
      status: 'filed',
      originalTransactionId,
      disputedAmount,
      disputedCurrency: txCurrency,
      usdEquivalent,
      filedBy: { uid: callerUid, email: callerEmail, displayName: callerDisplayName, phoneNumber: callerPhone },
      filedAt: admin.firestore.FieldValue.serverTimestamp(),
      recipientUid,
      recipientEmail,
      recipientDisplayName,
      recipientPhoneNumber: recipientPhone,
      issueType,
      description: description.trim(),
      evidence: [],
      recipientResponse: null,
      recipientResponseAt: null,
      recipientEvidence: null,
      assignedAdmin: null,
      investigationFindings: null,
      investigationSubmittedAt: null,
      reviewingSupervisor: null,
      supervisorDecision: null,
      supervisorNotes: null,
      supervisorDecidedAt: null,
      reviewingManager: null,
      managerDecision: null,
      managerDecisionAmount: null,
      managerNotes: null,
      managerDecidedAt: null,
      resolvedAt: null,
      resolutionType: null,
      amountRecovered: null,
      amountUnrecovered: null,
      currentHoldAmount: holdAmount,
      holdHistory: [],
      feeCharged: fee,
      feeRefunded: false,
      feeDeductedFrom,
      escalatedToSuperAdmin: false,
      superAdminDecision: null,
      superAdminDecidedAt: null,
      stuckCaseFlag: false,
      notificationsSent: {},
      graceTriggered: false,
      graceTriggeredAt: null,
      expectedResolutionBy: admin.firestore.Timestamp.fromMillis(Date.now() + THREE_DAYS_MS),
    });

    // Update dispute_history
    const historyRef = db.collection('dispute_history').doc(callerUid);
    await historyRef.set({
      userUid: callerUid,
      totalFiled: admin.firestore.FieldValue.increment(1),
      totalActiveCount: admin.firestore.FieldValue.increment(1),
      lastFiledAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Audit log
    await db.collection('audit_logs').add({
      userId: callerUid,
      operation: 'userFileDispute',
      result: 'success',
      amount: disputedAmount,
      currency: txCurrency,
      metadata: { disputeId, originalTransactionId, issueType, fee, feeDeductedFrom },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      disputeId,
      currentHoldAmount: holdAmount,
      feeCharged: fee,
      expectedResolutionBy: Date.now() + THREE_DAYS_MS,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('userFileDispute failed', { caller: callerUid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to file dispute: ' + error.message);
  }
});

/**
 * User: View a single dispute. Filer and recipient only.
 * Internal admin fields are hidden from user view.
 */
exports.userViewDispute = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  const callerUid = context.auth.uid;
  const { disputeId } = data || {};
  if (!disputeId) throw new functions.https.HttpsError('invalid-argument', 'disputeId is required.');

  const withinLimit = await checkRateLimitPersistent(callerUid, 'userViewDispute');
  if (!withinLimit) throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.userViewDispute.message);

  const doc = await db.collection('disputes').doc(disputeId).get();
  if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Dispute not found.');
  const d = doc.data();

  const isFiler = d.filedBy.uid === callerUid;
  const isRecipient = d.recipientUid === callerUid;
  if (!isFiler && !isRecipient) throw new functions.https.HttpsError('permission-denied', 'Access denied.');

  const sanitized = {
    disputeId: d.disputeId,
    status: d.status,
    originalTransactionId: d.originalTransactionId,
    disputedAmount: d.disputedAmount,
    disputedCurrency: d.disputedCurrency,
    issueType: d.issueType,
    description: d.description,
    filedAt: d.filedAt,
    expectedResolutionBy: d.expectedResolutionBy,
    currentHoldAmount: d.currentHoldAmount,
    feeCharged: d.feeCharged,
    resolvedAt: d.resolvedAt,
    resolutionType: d.resolutionType,
    amountRecovered: d.amountRecovered,
    recipientResponse: d.recipientResponse,
    recipientResponseAt: d.recipientResponseAt,
  };
  if (isFiler) {
    sanitized.filedBy = d.filedBy;
    sanitized.recipientDisplayName = d.recipientDisplayName;
    sanitized.evidence = d.evidence;
  } else {
    sanitized.recipientUid = d.recipientUid;
    sanitized.recipientEvidence = d.recipientEvidence;
  }

  return { success: true, dispute: sanitized };
});

/**
 * User: List user's disputes as filer or recipient.
 */
exports.userGetMyDisputes = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  const callerUid = context.auth.uid;
  const { role: queryRole, limit: requestedLimit } = data || {};

  const withinLimit = await checkRateLimitPersistent(callerUid, 'userGetMyDisputes');
  if (!withinLimit) throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.userGetMyDisputes.message);

  if (queryRole && queryRole !== 'filer' && queryRole !== 'recipient') {
    throw new functions.https.HttpsError('invalid-argument', 'role must be "filer" or "recipient".');
  }

  let limit = 50;
  if (requestedLimit && typeof requestedLimit === 'number') {
    limit = Math.min(Math.max(requestedLimit, 1), 50);
  }

  let query;
  if (queryRole === 'recipient') {
    query = db.collection('disputes')
      .where('recipientUid', '==', callerUid)
      .orderBy('filedAt', 'desc')
      .limit(limit);
  } else {
    query = db.collection('disputes')
      .where('filedBy.uid', '==', callerUid)
      .orderBy('filedAt', 'desc')
      .limit(limit);
  }

  const snap = await query.get();
  const disputes = snap.docs.map(doc => {
    const d = doc.data();
    return {
      disputeId: d.disputeId,
      status: d.status,
      disputedAmount: d.disputedAmount,
      disputedCurrency: d.disputedCurrency,
      issueType: d.issueType,
      filedAt: d.filedAt,
      expectedResolutionBy: d.expectedResolutionBy,
      resolutionType: d.resolutionType,
      resolvedAt: d.resolvedAt,
    };
  });

  return { success: true, disputes };
});

/**
 * User: Recipient responds to a dispute filed against them.
 */
exports.userRespondToDispute = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  const callerUid = context.auth.uid;
  const { disputeId, response, idempotencyKey } = data || {};

  if (!disputeId) throw new functions.https.HttpsError('invalid-argument', 'disputeId is required.');
  if (!response || typeof response !== 'string' || response.trim().length < 10) {
    throw new functions.https.HttpsError('invalid-argument', 'response must be at least 10 characters.');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey must be at least 16 characters.');
  }

  const withinLimit = await checkRateLimitPersistent(callerUid, 'userRespondToDispute');
  if (!withinLimit) throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.userRespondToDispute.message);

  try {
    const disputeRef = db.collection('disputes').doc(disputeId);
    const disputeSnap = await disputeRef.get();
    if (!disputeSnap.exists) throw new functions.https.HttpsError('not-found', 'Dispute not found.');
    const dispute = disputeSnap.data();

    if (dispute.recipientUid !== callerUid) {
      throw new functions.https.HttpsError('permission-denied', 'Only the recipient can respond.');
    }

    const TERMINAL = ['resolved', 'closed_stuck'];
    if (TERMINAL.includes(dispute.status)) {
      throw new functions.https.HttpsError('failed-precondition', 'Dispute is already resolved.');
    }

    await disputeRef.update({
      recipientResponse: response.trim(),
      recipientResponseAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify assigned admin if one exists
    if (dispute.assignedAdmin && dispute.assignedAdmin.email) {
      await sendProposalEmail({
        to: dispute.assignedAdmin.email,
        toName: dispute.assignedAdmin.displayName || null,
        subject: `Recipient submitted response on ${disputeId}`,
        htmlBody: `<p>The recipient has submitted a response on dispute <strong>${disputeId}</strong>.</p><p>Please review in the admin dashboard.</p>`,
        textBody: `Recipient responded on dispute ${disputeId}. Review in dashboard.`,
        relatedTo: `dispute:${disputeId}`,
      });
    }

    await db.collection('audit_logs').add({
      userId: callerUid,
      operation: 'userRespondToDispute',
      result: 'success',
      metadata: { disputeId },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, disputeId };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('userRespondToDispute failed', { disputeId, caller: callerUid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to respond: ' + error.message);
  }
});

/**
 * Admin: Assign an admin to investigate a dispute.
 * admin_supervisor or higher can assign.
 */
exports.adminAssignDispute = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin_supervisor');
  const { disputeId, adminUid, idempotencyKey } = data || {};

  if (!disputeId || typeof disputeId !== 'string') throw new functions.https.HttpsError('invalid-argument', 'disputeId is required.');
  if (!adminUid || typeof adminUid !== 'string') throw new functions.https.HttpsError('invalid-argument', 'adminUid is required.');
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey must be at least 16 characters.');
  }

  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminAssignDispute');
  if (!withinLimit) throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminAssignDispute.message);

  try {
    const disputeRef = db.collection('disputes').doc(disputeId);
    const disputeSnap = await disputeRef.get();
    if (!disputeSnap.exists) throw new functions.https.HttpsError('not-found', `Dispute ${disputeId} not found.`);
    const dispute = disputeSnap.data();

    if (dispute.status !== 'filed' && !(dispute.status === 'investigating' && !dispute.assignedAdmin)) {
      throw new functions.https.HttpsError('failed-precondition',
        `Dispute status is '${dispute.status}'. Can only assign when filed or investigating without admin.`);
    }

    // Verify adminUid is a valid admin+ user
    const adminUserDoc = await db.collection('users').doc(adminUid).get();
    if (!adminUserDoc.exists) throw new functions.https.HttpsError('not-found', 'Assigned admin user not found.');
    const adminData = adminUserDoc.data();
    const adminRole = adminData.role;
    const roleHierarchy = { viewer: 1, auditor: 2, support: 3, admin: 4, admin_supervisor: 5, finance: 6, admin_manager: 7, super_admin: 8 };
    if (!adminRole || (roleHierarchy[adminRole] || 0) < (roleHierarchy['admin'] || 0)) {
      throw new functions.https.HttpsError('invalid-argument', 'Assigned user must have admin role or higher.');
    }

    const assignedAdminRecord = await admin.auth().getUser(adminUid);
    const assignedEmail = assignedAdminRecord.email || 'unknown';
    const assignedDisplayName = assignedAdminRecord.displayName || assignedEmail;

    await disputeRef.update({
      assignedAdmin: { uid: adminUid, email: assignedEmail, displayName: assignedDisplayName },
      status: 'investigating',
    });

    await sendProposalEmail({
      to: assignedEmail,
      toName: assignedDisplayName,
      subject: `You've been assigned to investigate dispute ${disputeId}`,
      htmlBody: `<p>You've been assigned to investigate dispute <strong>${disputeId}</strong>.</p>
<p><strong>Issue:</strong> ${dispute.issueType}<br>
<strong>Amount:</strong> ${dispute.disputedAmount} ${dispute.disputedCurrency}<br>
<strong>Filed by:</strong> ${dispute.filedBy.displayName}</p>
<p>Please review and submit your findings via the admin dashboard.</p>`,
      textBody: `Assigned to investigate dispute ${disputeId}. Review in admin dashboard.`,
      relatedTo: `dispute:${disputeId}`,
    });

    const callerEmail = (await admin.auth().getUser(caller.uid)).email || 'unknown';
    await db.collection('audit_logs').add({
      userId: caller.uid, operation: 'adminAssignDispute', result: 'success',
      metadata: { disputeId, assignedAdminUid: adminUid },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('admin_activity').add({
      uid: caller.uid, email: callerEmail, role: caller.role,
      action: 'assign_dispute', details: `Assigned ${assignedDisplayName} to dispute ${disputeId}`,
      ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, disputeId, assignedAdmin: { uid: adminUid, email: assignedEmail, displayName: assignedDisplayName } };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminAssignDispute failed', { disputeId, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to assign dispute: ' + error.message);
  }
});

/**
 * Admin: Submit investigation findings for a dispute.
 * Assigned admin submits findings, moves dispute to supervisor_review.
 */
exports.adminSubmitInvestigation = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin');
  const { disputeId, findings, idempotencyKey } = data || {};

  if (!disputeId) throw new functions.https.HttpsError('invalid-argument', 'disputeId is required.');
  if (!findings || typeof findings !== 'string' || findings.trim().length < 50) {
    throw new functions.https.HttpsError('invalid-argument', 'findings must be at least 50 characters.');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey must be at least 16 characters.');
  }

  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminSubmitInvestigation');
  if (!withinLimit) throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminSubmitInvestigation.message);

  try {
    const disputeRef = db.collection('disputes').doc(disputeId);
    const disputeSnap = await disputeRef.get();
    if (!disputeSnap.exists) throw new functions.https.HttpsError('not-found', `Dispute ${disputeId} not found.`);
    const dispute = disputeSnap.data();

    if (dispute.status !== 'investigating') {
      throw new functions.https.HttpsError('failed-precondition', `Dispute status is '${dispute.status}', expected 'investigating'.`);
    }
    if (!dispute.assignedAdmin || dispute.assignedAdmin.uid !== caller.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only the assigned admin can submit investigation findings.');
    }

    await disputeRef.update({
      investigationFindings: findings.trim(),
      investigationSubmittedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'supervisor_review',
    });

    // Email admin_supervisors
    const supervisorsSnap = await db.collection('admin_users')
      .where('role', '==', 'admin_supervisor')
      .get();
    const callerDisplayName = (await admin.auth().getUser(caller.uid)).displayName || 'Admin';
    for (const sv of supervisorsSnap.docs) {
      await sendProposalEmail({
        to: sv.id,
        toName: sv.data().displayName || null,
        subject: `Investigation submitted for dispute ${disputeId} — supervisor review needed`,
        htmlBody: `<p>Admin ${callerDisplayName} has submitted investigation findings for dispute <strong>${disputeId}</strong>.</p>
<p>Please review and either agree or kick back via the admin dashboard.</p>`,
        textBody: `Investigation submitted for ${disputeId}. Supervisor review needed.`,
        relatedTo: `dispute:${disputeId}`,
      });
    }

    const callerEmail = (await admin.auth().getUser(caller.uid)).email || 'unknown';
    await db.collection('audit_logs').add({
      userId: caller.uid, operation: 'adminSubmitInvestigation', result: 'success',
      metadata: { disputeId }, timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('admin_activity').add({
      uid: caller.uid, email: callerEmail, role: caller.role,
      action: 'submit_investigation', details: `Submitted findings for dispute ${disputeId}`,
      ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, disputeId, status: 'supervisor_review' };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminSubmitInvestigation failed', { disputeId, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to submit investigation: ' + error.message);
  }
});
