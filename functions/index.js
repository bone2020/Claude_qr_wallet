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
    logError('CRITICAL CONFIG MISSING', { count: missingCritical.length, keys: missingCritical.join(', '), action: 'Set via: firebase functions:config:set KEY="value". Functions depending on these keys will fail at call time.' });
  } else {
    logInfo('All critical environment configs present');
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
    // Provide user-friendly messages based on service type
    let userMessage;
    if (serviceName.startsWith('momo')) {
      userMessage = 'Mobile Money is coming soon! This feature is not yet available in your region.';
    } else {
      userMessage = `Service temporarily unavailable. Please try again later or use a different payment method.`;
    }
    throwAppError(ERROR_CODES.CONFIG_MISSING, userMessage);
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
const HTTP_TIMEOUT_MS = 15000; // 15 seconds for all external API calls

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
exports.updateExchangeRatesNow = functions.https.onRequest(async (req, res) => {
  // Only allow POST requests
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  // Validate admin secret is configured
  const adminSecret = functions.config().admin?.exchange_rate_secret;
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
exports.verifyPayment = functions.https.onCall(async (data, context) => {
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
    const amount = amountInKobo / 100; // Convert from kobo to naira
    const currency = paymentData.currency;

    // Secondary idempotency check via payments collection (defense in depth)
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
    validateWalletDocument(walletData, 'verifyPayment wallet');

    // Credit wallet using transaction
    await db.runTransaction(async (transaction) => {
      const freshWallet = await transaction.get(walletDoc.ref);
      const freshData = freshWallet.data();
      validateWalletDocument(freshData, 'verifyPayment fresh wallet');
      const currentBalance = freshData.balance;
      const newBalance = safeAdd(currentBalance, amount, 'verifyPayment credit');

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
      metadata: { reference, ...correlation.toAuditContext() },
      ipHash: hashIp(context),
    });

    return {
      success: true,
      amount: amount,
      currency: currency,
      newBalance: safeAdd(walletData.balance, amount, 'verifyPayment response balance'),
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
exports.paystackWebhook = functions.https.onRequest(async (req, res) => {
  const webhookCorrelationId = req.headers['x-correlation-id'] ||
    `webhook_paystack_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  logSecurityEvent('paystack_webhook_received', 'low', { correlationId: webhookCorrelationId, event: req.body?.event });

  // Fail fast if Paystack secret key is not configured
  if (MISSING_CRITICAL_CONFIGS.has('paystack.secret_key')) {
    logSecurityEvent('paystack_webhook_not_configured', 'high', { correlationId: webhookCorrelationId });
    return res.status(503).send('Service not configured');
  }

  // Verify webhook signature
  const hash = crypto
    .createHmac('sha512', PAYSTACK_SECRET_KEY)
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

  // Check if already processed
  const paymentRef = db.collection('payments').doc(reference);
  const paymentDoc = await paymentRef.get();

  if (paymentDoc.exists && paymentDoc.data().processed) {
    logInfo('Payment already processed', { reference });
    return;
  }

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

  const amount = receivedAmountKobo / 100;

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
  await db.runTransaction(async (transaction) => {
    const freshWallet = await transaction.get(walletDoc.ref);
    const freshData = freshWallet.data();
    validateWalletDocument(freshData, 'handleSuccessfulCharge wallet');
    const currentBalance = freshData.balance;
    const newBalance = safeAdd(currentBalance, amount, 'handleSuccessfulCharge credit');

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

  logFinancialOperation('withdrawal', 'failed_refunded', { reference });
}

// Initiate withdrawal to bank or mobile money
exports.initiateWithdrawal = functions.https.onCall(async (data, context) => {
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
exports.getBanks = functions.https.onCall(async (data, context) => {
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
exports.verifyBankAccount = functions.https.onCall(async (data, context) => {
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

  // Validate currency and phone number format
  const validatedCurrency = validateCurrency(currency, 'GHS');
  const validatedPhone = validatePhoneNumber(phoneNumber);

  return withIdempotency(idempotencyKey, 'chargeMobileMoney', userId, async () => {
  try {
    const reference = `MOMO_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const chargeResponse = await paystackRequest('POST', '/charge', {
      email: email,
      amount: Math.round(amount * 100),
      currency: currency || 'GHS',
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

        await db.runTransaction(async (transaction) => {
          const creditBalance = safeAdd(walletData.balance, amount, 'chargeMobileMoney credit');
          transaction.update(walletDoc.ref, {
            balance: creditBalance,
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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('Mobile Money charge error', { error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Payment failed. Please try again.');
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

  // Validate currency
  const validatedCurrency = validateCurrency(currency, 'GHS');

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  try {
    const reference = `TXN_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const response = await paystackRequest('POST', '/transaction/initialize', {
      email: email,
      amount: Math.round(amount * 100), // Convert to smallest unit
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
        expectedAmountKobo: Math.round(amount * 100),
        currency: currency || 'GHS',
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
const QR_SECRET_KEY = functions.config().qr?.secret || '';
const QR_EXPIRY_MS = 15 * 60 * 1000; // 15 minutes

// Helper: Generate HMAC signature
function generateQrSignature(payload) {
  requireConfig(QR_SECRET_KEY, 'qr.secret');
  return crypto.createHmac('sha256', QR_SECRET_KEY)
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
    logError('Rate limit check failed', { userId, operation, error: error.message });
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
    // If error is our own throwAppError, re-throw it
    if (error.code === 'functions/failed-precondition' || error.code === 'functions/permission-denied') {
      throw error;
    }
    // Firebase Auth error — log but don't block (fail open for auth service issues)
    logError('Email verification check failed', { userId, error: error.message });
  }

  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    throwAppError(ERROR_CODES.WALLET_NOT_FOUND, 'User account not found.');
  }

  const userData = userDoc.data();

  // Check canonical kycStatus field (authoritative, set by Cloud Functions only)
  if (userData.kycStatus === 'verified') {
    return;
  }

  // Legacy kycCompleted/kycVerified fields are no longer trusted for auto-migration.
  // Users with legacy fields must re-verify through Smile ID to get kycStatus: 'verified'.
  if (!userData.kycStatus && userData.kycCompleted === true) {
    logInfo('User has legacy KYC fields but no canonical kycStatus — re-verification required', { userId });
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

  logInfo('KYC status updated', { status, userId });

  return {
    success: true,
    kycStatus: status,
  };
});

/**
 * Mark user as KYC verified when SmileID returns "already enrolled" error.
 * This indicates the user was previously verified by SmileID, so we can
 * trust that verification and set kycStatus: 'verified' directly.
 *
 * Unlike updateKycStatus, this function doesn't require prior KYC document
 * approval because SmileID has already verified the user's identity.
 */
exports.markUserAlreadyEnrolled = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;
  const { idType } = data || {};

  logInfo('Processing SmileID already enrolled user', { userId, idType });

  // Create or update the KYC documents subcollection
  const kycDocRef = db.collection('users').doc(userId).collection('kyc').doc('documents');
  const kycDoc = await kycDocRef.get();

  if (!kycDoc.exists) {
    // Create a new KYC document for already enrolled users
    await kycDocRef.set({
      idType: idType || 'SMILE_ID_ENROLLED',
      status: 'verified',
      verificationMethod: 'smile_id_already_enrolled',
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      smileIdVerified: true,
    });
  } else {
    // Update existing document to verified status
    await kycDocRef.update({
      status: 'verified',
      smileIdVerified: true,
      verificationMethod: 'smile_id_already_enrolled',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Set the canonical kycStatus field
  await db.collection('users').doc(userId).update({
    kycStatus: 'verified',
    kycStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    kycCompleted: true,
    kycVerified: true,
  });

  logInfo('User marked as KYC verified (SmileID already enrolled)', { userId });

  return {
    success: true,
    kycStatus: 'verified',
  };
});

// ============================================================
// GDPR DATA EXPORT & DELETION
// ============================================================

/**
 * Export all user data (GDPR Article 20 — Data Portability).
 * Returns a JSON object containing all data associated with the user.
 */
exports.exportUserData = functions.https.onCall(async (data, context) => {
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
exports.deleteUserData = functions.https.onCall(async (data, context) => {
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
        maxAgeMs: 365 * 24 * 60 * 60 * 1000, // 365 days
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
exports.signQrPayload = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throwAppError(ERROR_CODES.AUTH_UNAUTHENTICATED);
  }

  const userId = context.auth.uid;

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  const { walletId, amount, note } = data;

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
exports.verifyQrSignature = functions.https.onCall(async (data, context) => {
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

  return {
    valid: true,
    walletId: parsedPayload.walletId,
    amount: parsedPayload.amount,
    note: parsedPayload.note,
    recipientName: userDoc.exists ? userDoc.data().fullName : 'QR Wallet User',
    nonce,
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

  // Return only wallet ID and display name — no profile photo, email, phone, or other PII
  return {
    found: true,
    walletId: walletData.walletId,
    recipientName: userData.fullName || 'QR Wallet User',
  };
});


// ============================================================
// SMILE ID PHONE VERIFICATION
// ============================================================

const SMILE_ID_API_KEY = functions.config().smileid?.api_key || '';
const SMILE_ID_PARTNER_ID = functions.config().smileid?.partner_id || '8244';

/**
 * Smile ID API base URL — environment-aware.
 * Set via: firebase functions:config:set smileid.environment="production"
 * Fails secure: production deployment requires explicit config.
 */
const SMILE_ID_BASE_URL = (() => {
  const smileEnv = functions.config().smileid?.environment;
  const appEnv = functions.config().app?.environment;

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
})();

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
exports.verifyPhoneNumber = functions.https.onCall(async (data, context) => {
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
  const correlation = createCorrelationContext(context, 'sendMoney');

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

      // Calculate fee (1% with min 10, max 100)
      const fee = Math.min(Math.max(amount * 0.01, 10), 100);
      const totalDebit = amount + fee;

      // Enforce daily/monthly spending limits
      const DAILY_LIMIT = 50000;   // Local currency units
      const MONTHLY_LIMIT = 500000;
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

      // Check balance (safeSubtract validates the arithmetic)
      safeSubtract(senderBalance, totalDebit, 'sendMoney debit check');

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
        updatedAt: timestamps.serverTimestamp()
      });

      // Add to recipient
      transaction.update(recipientRef, {
        balance: admin.firestore.FieldValue.increment(amount),
        updatedAt: timestamps.serverTimestamp()
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
        createdAt: timestamps.serverTimestamp(),
        completedAt: timestamps.serverTimestamp(),
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

    logFinancialOperation('sendMoney', 'success', { transactionId: result.transactionId });

    await auditLog({
      userId: senderUid, operation: 'sendMoney', result: 'success',
      amount, currency: result.currency || 'GHS',
      metadata: { transactionId: result.transactionId, recipientWalletId, fee: result.fee, ...correlation.toAuditContext() },
      ipHash: hashIp(context),
    });

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
  environment: (() => {
    const momoEnv = functions.config().momo?.environment;
    const appEnv = functions.config().app?.environment;

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

exports.momoRequestToPay = functions.https.onCall(async (data, context) => {
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

exports.momoCheckStatus = functions.https.onCall(async (data, context) => {
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
    const product = type === 'disbursement' ? 'disbursement' : 'collection';
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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('MoMo status check error', { error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Unable to check transaction status. Please try again.');
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
    });

    // Create transfer request
    const response = await momoRequest('disbursement', 'POST', '/v1_0/transfer', {
      amount: amount.toString(),
      currency: currency || 'EUR', // Sandbox only supports EUR
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
    if (error instanceof functions.https.HttpsError) throw error;
    logError('MoMo balance error', { error: error.message });
    throwAppError(ERROR_CODES.SYSTEM_INTERNAL_ERROR, 'Unable to retrieve balance. Please try again.');
  }
});

// ============================================================
// MTN MOMO - WEBHOOK (Callback for async notifications)
// ============================================================

exports.momoWebhook = functions.https.onRequest(async (req, res) => {
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
            validateWalletDocument(walletData, 'momoWebhook FAILED refund wallet');
            const refundBalance = safeAdd(walletData.balance, txData.amount, 'momoWebhook disbursement refund');

            transaction.update(walletDoc.ref, {
              balance: refundBalance,
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
