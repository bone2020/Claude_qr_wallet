// ============================================================
// CUSTOM AUTH EMAILS via Resend — Phase 4a
// ============================================================
// Replaces Firebase's default email verification + password reset
// emails so they send from bongroups.co (verified, deliverable)
// instead of @firebaseapp.com (going to spam).
//
// Controlled by feature flag CUSTOM_AUTH_EMAILS_ENABLED (param).
// When 'false' (default), Flutter falls back to Firebase native flow.
//
// Reuses Phase 2b email_queue collection + processEmailQueue
// scheduler for retries on Resend transient failures.
// ============================================================

const functions = require('firebase-functions');
const { defineSecret, defineString } = require('firebase-functions/params');
const admin = require('firebase-admin');

// Re-uses the Resend secret already defined in index.js
const RESEND_API_KEY_PARAM = defineSecret('RESEND_API_KEY');

// Feature flag — when "true", Flutter calls these functions; when
// "false" or missing, Flutter falls back to Firebase native flow.
const CUSTOM_AUTH_EMAILS_ENABLED = defineString(
  'CUSTOM_AUTH_EMAILS_ENABLED',
  { default: 'false' }
);

const FROM_EMAIL = 'qrwallet@bongroups.co';
const FROM_NAME = 'QR Wallet';
const REPLY_TO = 'qrwallet.support@bongroups.co';

// ============================================================
// HELPER: queue email for retry on Resend transient failure
// Reuses Phase 2b email_queue + processEmailQueue scheduler.
// ============================================================
async function queueEmailForRetry({ to, toName, subject, htmlBody, textBody, error, relatedTo }) {
  try {
    await admin.firestore().collection('email_queue').add({
      to,
      toName: toName || null,
      fromEmail: FROM_EMAIL,
      fromName: FROM_NAME,
      replyTo: REPLY_TO,
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
    console.error('queueEmailForRetry: also failed to queue', queueError.message);
  }
}

// ============================================================
// HELPER: send via Resend with retry queue fallback
// ============================================================
async function sendViaResend({ to, toName, subject, htmlBody, textBody, relatedTo }) {
  try {
    const { Resend } = require('resend');
    const resend = new Resend(RESEND_API_KEY_PARAM.value());

    await resend.emails.send({
      from: `${FROM_NAME} <${FROM_EMAIL}>`,
      to: [toName ? `${toName} <${to}>` : to],
      subject,
      html: htmlBody,
      text: textBody,
      replyTo: REPLY_TO,
    });
    return { sent: true, queued: false };
  } catch (error) {
    console.warn('sendViaResend failed, queueing for retry', { to, subject, error: error.message });
    await queueEmailForRetry({ to, toName, subject, htmlBody, textBody, error, relatedTo });
    return { sent: false, queued: true };
  }
}

// ============================================================
// EMAIL TEMPLATES — branded HTML + plaintext fallback
// ============================================================
function verificationEmailHtml({ displayName, verifyUrl }) {
  const greeting = displayName ? `Hi ${displayName},` : 'Hi there,';
  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Verify your QR Wallet email</title></head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:40px 20px;">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;max-width:560px;width:100%;">
        <tr><td style="background:#0066FF;padding:32px;text-align:center;">
          <h1 style="color:#ffffff;margin:0;font-size:28px;font-weight:700;">QR Wallet</h1>
        </td></tr>
        <tr><td style="padding:40px 32px;">
          <h2 style="color:#1a1a1a;margin:0 0 16px;font-size:22px;">Verify your email</h2>
          <p style="color:#444;line-height:1.6;margin:0 0 24px;font-size:16px;">${greeting}</p>
          <p style="color:#444;line-height:1.6;margin:0 0 24px;font-size:16px;">
            Welcome to QR Wallet! Please confirm your email address by clicking the button below. This link will expire in 1 hour.
          </p>
          <div style="text-align:center;margin:32px 0;">
            <a href="${verifyUrl}" style="background:#0066FF;color:#ffffff;text-decoration:none;padding:14px 32px;border-radius:10px;font-weight:600;display:inline-block;font-size:16px;">Verify Email Address</a>
          </div>
          <p style="color:#666;line-height:1.6;margin:24px 0 0;font-size:14px;">
            Or copy and paste this link into your browser:<br>
            <a href="${verifyUrl}" style="color:#0066FF;word-break:break-all;">${verifyUrl}</a>
          </p>
          <hr style="border:none;border-top:1px solid #eee;margin:32px 0;">
          <p style="color:#888;line-height:1.5;margin:0;font-size:13px;">
            If you didn't create a QR Wallet account, you can safely ignore this email.
          </p>
        </td></tr>
        <tr><td style="background:#fafafa;padding:24px 32px;text-align:center;">
          <p style="color:#888;margin:0;font-size:12px;">© QR Wallet · Need help? <a href="mailto:${REPLY_TO}" style="color:#0066FF;">${REPLY_TO}</a></p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function verificationEmailText({ displayName, verifyUrl }) {
  const greeting = displayName ? `Hi ${displayName},` : 'Hi there,';
  return `${greeting}

Welcome to QR Wallet! Please confirm your email address by visiting this link (expires in 1 hour):

${verifyUrl}

If you didn't create a QR Wallet account, you can safely ignore this email.

Need help? ${REPLY_TO}
`;
}

function passwordResetEmailHtml({ displayName, resetUrl }) {
  const greeting = displayName ? `Hi ${displayName},` : 'Hi there,';
  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Reset your QR Wallet password</title></head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:40px 20px;">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;max-width:560px;width:100%;">
        <tr><td style="background:#0066FF;padding:32px;text-align:center;">
          <h1 style="color:#ffffff;margin:0;font-size:28px;font-weight:700;">QR Wallet</h1>
        </td></tr>
        <tr><td style="padding:40px 32px;">
          <h2 style="color:#1a1a1a;margin:0 0 16px;font-size:22px;">Reset your password</h2>
          <p style="color:#444;line-height:1.6;margin:0 0 24px;font-size:16px;">${greeting}</p>
          <p style="color:#444;line-height:1.6;margin:0 0 24px;font-size:16px;">
            We received a request to reset your QR Wallet password. Click the button below to set a new one. This link expires in 1 hour.
          </p>
          <div style="text-align:center;margin:32px 0;">
            <a href="${resetUrl}" style="background:#0066FF;color:#ffffff;text-decoration:none;padding:14px 32px;border-radius:10px;font-weight:600;display:inline-block;font-size:16px;">Reset Password</a>
          </div>
          <p style="color:#666;line-height:1.6;margin:24px 0 0;font-size:14px;">
            Or copy and paste this link into your browser:<br>
            <a href="${resetUrl}" style="color:#0066FF;word-break:break-all;">${resetUrl}</a>
          </p>
          <hr style="border:none;border-top:1px solid #eee;margin:32px 0;">
          <p style="color:#888;line-height:1.5;margin:0;font-size:13px;">
            <strong>Didn't request this?</strong> You can safely ignore this email — your password won't change. If you're concerned about account security, contact <a href="mailto:${REPLY_TO}" style="color:#0066FF;">${REPLY_TO}</a>.
          </p>
        </td></tr>
        <tr><td style="background:#fafafa;padding:24px 32px;text-align:center;">
          <p style="color:#888;margin:0;font-size:12px;">© QR Wallet · ${REPLY_TO}</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function passwordResetEmailText({ displayName, resetUrl }) {
  const greeting = displayName ? `Hi ${displayName},` : 'Hi there,';
  return `${greeting}

We received a request to reset your QR Wallet password. Visit this link to set a new one (expires in 1 hour):

${resetUrl}

Didn't request this? You can safely ignore this email — your password won't change. If you're concerned about account security, contact ${REPLY_TO}.
`;
}

// ============================================================
// CLOUD FUNCTION: sendCustomEmailVerification
// Authenticated callable. Generates verification link via Admin
// SDK, sends via Resend.
// ============================================================
exports.sendCustomEmailVerification = functions
  .runWith({
    enforceAppCheck: true,
    secrets: [RESEND_API_KEY_PARAM],
  })
  .https.onCall(async (data, context) => {
    if (CUSTOM_AUTH_EMAILS_ENABLED.value() !== 'true') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Custom auth emails are disabled. Client should use Firebase native flow.'
      );
    }

    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
    }

    const uid = context.auth.uid;
    let userRecord;
    try {
      userRecord = await admin.auth().getUser(uid);
    } catch (e) {
      throw new functions.https.HttpsError('not-found', 'User not found.');
    }

    if (!userRecord.email) {
      throw new functions.https.HttpsError('failed-precondition', 'User has no email address.');
    }
    if (userRecord.emailVerified) {
      return { ok: true, alreadyVerified: true };
    }

    let verifyUrl;
    try {
      verifyUrl = await admin.auth().generateEmailVerificationLink(userRecord.email);
    } catch (e) {
      console.error('generateEmailVerificationLink failed', e);
      throw new functions.https.HttpsError('internal', 'Failed to generate verification link.');
    }

    const result = await sendViaResend({
      to: userRecord.email,
      toName: userRecord.displayName || null,
      subject: 'Verify your QR Wallet email',
      htmlBody: verificationEmailHtml({ displayName: userRecord.displayName, verifyUrl }),
      textBody: verificationEmailText({ displayName: userRecord.displayName, verifyUrl }),
      relatedTo: `verification:${uid}`,
    });

    return { ok: true, sent: result.sent, queued: result.queued };
  });

// ============================================================
// CLOUD FUNCTION: sendCustomPasswordReset
// Public (unauthenticated) callable. Generates reset link, sends
// via Resend. Always returns success to prevent email enumeration.
// ============================================================
exports.sendCustomPasswordReset = functions
  .runWith({
    enforceAppCheck: true,
    secrets: [RESEND_API_KEY_PARAM],
  })
  .https.onCall(async (data, context) => {
    if (CUSTOM_AUTH_EMAILS_ENABLED.value() !== 'true') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Custom auth emails are disabled. Client should use Firebase native flow.'
      );
    }

    const email = (data && data.email ? String(data.email) : '').trim().toLowerCase();
    if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw new functions.https.HttpsError('invalid-argument', 'Valid email required.');
    }

    let userRecord = null;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
    } catch (e) {
      console.log(`sendCustomPasswordReset: no user for ${email} (silent success)`);
      return { ok: true };
    }

    let resetUrl;
    try {
      resetUrl = await admin.auth().generatePasswordResetLink(email);
    } catch (e) {
      console.error('generatePasswordResetLink failed', e);
      return { ok: true };
    }

    await sendViaResend({
      to: email,
      toName: userRecord.displayName || null,
      subject: 'Reset your QR Wallet password',
      htmlBody: passwordResetEmailHtml({ displayName: userRecord.displayName, resetUrl }),
      textBody: passwordResetEmailText({ displayName: userRecord.displayName, resetUrl }),
      relatedTo: `pwreset:${userRecord.uid}`,
    });

    return { ok: true };
  });

// ============================================================
// CLOUD FUNCTION: isCustomAuthEmailsEnabled
// Lets the Flutter client check the flag before deciding which
// flow to use. App Check enforced.
// ============================================================
exports.isCustomAuthEmailsEnabled = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    return { enabled: CUSTOM_AUTH_EMAILS_ENABLED.value() === 'true' };
  });
