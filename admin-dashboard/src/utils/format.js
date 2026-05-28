// admin-dashboard/src/utils/format.js
//
// Centralized currency and date formatting for the admin dashboard.
// Resolves two recurring bugs:
//   (1) Cents-as-dollars: amounts stored in minor units (cents/kobo/pesewas)
//       displayed without /100 division.
//   (2) Invalid Date: Firestore Timestamp objects passed to new Date()
//       producing NaN-based strings.

const CURRENCY_SYMBOLS = {
  NGN: '₦', GHS: 'GH₵', KES: 'KSh', ZAR: 'R', UGX: 'USh',
  RWF: 'FRw', TZS: 'TSh', EGP: 'E£', USD: '$', GBP: '£', EUR: '€',
};

/**
 * Return the display symbol for a currency code (e.g. "NGN" -> "₦").
 * Falls back to the code itself when no symbol is mapped.
 */
export function currencySymbol(code) {
  if (!code) return '';
  return CURRENCY_SYMBOLS[code] || code;
}

/**
 * Format a monetary amount with currency symbol and thousands separators.
 *
 * Default: assumes the value is in MINOR units (e.g. cents, kobo, pesewas)
 * and divides by 100. This matches how transaction amounts, wallet balances,
 * dispute amounts, and fraud-alert amounts are stored server-side.
 *
 * Pass { unit: 'major' } when the value is already in major units (e.g.
 * platform treasury totals, transfer proposals, USD equivalents on
 * platform-level data).
 *
 * Returns '—' for null/undefined/non-numeric input.
 *
 * Examples:
 *   formatCurrency(150000, 'NGN')                    -> "₦1,500.00"
 *   formatCurrency(150000, 'NGN', { unit: 'major' }) -> "₦150,000.00"
 *   formatCurrency(null, 'NGN')                      -> "—"
 *   formatCurrency(0, 'KES')                         -> "KSh0.00"
 */
export function formatCurrency(value, currencyCode, options = {}) {
  if (value === null || value === undefined) return '—';
  const num = Number(value);
  if (!Number.isFinite(num)) return '—';

  const unit = options.unit || 'minor';
  const major = unit === 'major' ? num : num / 100;

  const symbol = currencySymbol(currencyCode);
  const formatted = major.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `${symbol}${formatted}`;
}

/**
 * Coerce a value to a Date. Returns null when no valid Date can be produced.
 *
 * Handles:
 *   - JS Date instance
 *   - ISO 8601 string ("2026-05-27T00:30:12.000Z")
 *   - Firestore Timestamp client-side shape ({ seconds, nanoseconds })
 *   - Firestore Timestamp callable-serialized shape ({ _seconds, _nanoseconds })
 *   - Millisecond epoch number
 *   - null / undefined / empty / invalid -> null
 */
function coerceToDate(value) {
  if (value === null || value === undefined || value === '') return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;

  if (typeof value === 'number') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }

  if (typeof value === 'string') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }

  if (typeof value === 'object') {
    const seconds = value.seconds ?? value._seconds;
    const nanoseconds = value.nanoseconds ?? value._nanoseconds ?? 0;
    if (typeof seconds === 'number') {
      const ms = seconds * 1000 + Math.floor(nanoseconds / 1e6);
      const d = new Date(ms);
      return Number.isNaN(d.getTime()) ? null : d;
    }
  }

  return null;
}

/**
 * Format a date/timestamp for display.
 *
 * Robust against: ISO string, Date object, Firestore Timestamp (either
 * client { seconds } or callable-serialized { _seconds }), millisecond
 * epoch number, or null.
 *
 * Options:
 *   - dateOnly: true  -> "5/27/2026" (no time)
 *   - fallback: string returned when value can't be parsed (default: "—")
 *
 * Examples:
 *   formatDate("2026-05-27T00:30:12.000Z")  -> "5/27/2026, 12:30:12 AM"
 *   formatDate({ _seconds: 1748305812 })    -> "5/27/2026, 12:30:12 AM"
 *   formatDate(null)                        -> "—"
 *   formatDate("not a date")                -> "—"
 */
export function formatDate(value, options = {}) {
  const fallback = options.fallback ?? '—';
  const date = coerceToDate(value);
  if (!date) return fallback;
  if (options.dateOnly) return date.toLocaleDateString();
  return date.toLocaleString();
}
