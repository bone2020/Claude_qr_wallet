const functions = require('firebase-functions');
const admin = require('firebase-admin');
const https = require('https');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// ============================================================
// PAYSTACK CONFIGURATION
// ============================================================

// Paystack configuration - set via: firebase functions:config:set paystack.secret_key="sk_live_xxx"
const PAYSTACK_SECRET_KEY = functions.config().paystack?.secret_key || 'sk_test_xxx';
const PAYSTACK_BASE_URL = 'api.paystack.co';

// QR Code Signing - set via: firebase functions:config:set qr.secret="your-secret-key"
const QR_SECRET_KEY = functions.config().qr?.secret || 'qr-wallet-default-secret-key-change-me';
const QR_EXPIRY_MS = 15 * 60 * 1000; // 15 minutes

// Helper function for Paystack API calls
function paystackRequest(method, path, data = null) {
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
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { reference } = data;
  if (!reference) {
    throw new functions.https.HttpsError('invalid-argument', 'Payment reference is required');
  }

  const userId = context.auth.uid;

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
      throw new functions.https.HttpsError('not-found', 'Wallet not found');
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

    return {
      success: true,
      amount: amount,
      currency: currency,
      newBalance: walletData.balance + amount,
    };

  } catch (error) {
    console.error('Payment verification error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Handle Paystack webhook events
exports.paystackWebhook = functions.https.onRequest(async (req, res) => {
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

  await db.collection('withdrawals').doc(reference).update({
    status: 'success',
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    paystackTransferCode: data.transfer_code,
  });

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
      await txQuery.docs[0].ref.update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
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
        status: 'failed',
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
        transaction.update(txQuery.docs[0].ref, {
          status: 'failed',
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
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { amount, bankCode, accountNumber, accountName, type, mobileMoneyProvider, phoneNumber } = data;
  const userId = context.auth.uid;

  console.log("initiateWithdrawal called with:", JSON.stringify({ amount, bankCode, accountNumber, accountName, type, mobileMoneyProvider, phoneNumber }));
  // Validate amount
  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
  }

  // Minimum withdrawal amount (e.g., 100)
  if (amount < 100) {
    throw new functions.https.HttpsError('invalid-argument', 'Minimum withdrawal is 100');
  }

  try {
    // Get user's wallet
    const walletSnapshot = await db.collection('wallets')
      .where('userId', '==', userId)
      .limit(1)
      .get();

    if (walletSnapshot.empty) {
      throw new functions.https.HttpsError('not-found', 'Wallet not found');
    }

    const walletDoc = walletSnapshot.docs[0];
    const walletData = walletDoc.data();

    // Check balance
    if (walletData.balance < amount) {
      throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance');
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
      throw new functions.https.HttpsError('internal', 'Failed to create transfer recipient');
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
          status: 'failed',
          failureReason: 'Transfer initiation failed',
          refunded: true,
        });
      });

      throw new functions.https.HttpsError('internal', 'Failed to initiate transfer');
    }

    // Check if OTP is required
    const transferData = transferResponse.data;
    if (transferData.status === 'otp') {
      // Store transfer code for OTP verification
      await db.collection('withdrawals').doc(reference).update({
        status: 'pending_otp',
        transferCode: transferData.transfer_code,
      });

      return {
        success: false,
        requiresOtp: true,
        transferCode: transferData.transfer_code,
        reference: reference,
        message: 'OTP verification required',
      };
    }

    return {
      success: true,
      reference: reference,
      message: 'Withdrawal initiated successfully',
    };

  } catch (error) {
    console.error('Withdrawal error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Finalize transfer with OTP
exports.finalizeTransfer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { transferCode, otp } = data;
  const userId = context.auth.uid;

  if (!transferCode || !otp) {
    throw new functions.https.HttpsError('invalid-argument', 'Transfer code and OTP are required');
  }

  try {
    // Find withdrawal by transfer code
    const withdrawalQuery = await db.collection('withdrawals')
      .where('transferCode', '==', transferCode)
      .where('userId', '==', userId)
      .limit(1)
      .get();

    if (withdrawalQuery.empty) {
      throw new functions.https.HttpsError('not-found', 'Withdrawal not found');
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
      await withdrawalDoc.ref.update({
        status: 'processing',
        otpVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

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
    throw new functions.https.HttpsError('internal', error.message);
  }
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
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Verify bank account
exports.verifyBankAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { accountNumber, bankCode } = data;

  if (!accountNumber || !bankCode) {
    throw new functions.https.HttpsError('invalid-argument', 'Account number and bank code required');
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
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { email, amount, currency, provider, phoneNumber } = data;
  const userId = context.auth.uid;

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
  }
  if (!provider || !phoneNumber) {
    throw new functions.https.HttpsError('invalid-argument', 'Provider and phone number are required');
  }

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
    throw new functions.https.HttpsError('internal', error.message || 'Payment failed');
  }
});

// ============================================================
// VIRTUAL ACCOUNT (For Bank Transfer deposits)
// ============================================================
exports.getOrCreateVirtualAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { email, name } = data;
  const userId = context.auth.uid;

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
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { email, amount, currency } = data;
  const userId = context.auth.uid;

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
  }

  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }

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
    throw new functions.https.HttpsError('internal', error.message || 'Transaction initialization failed');
  }
});

// ============================================================
// SECURE SEND MONEY (P2P TRANSFER) - Cloud Function
// ============================================================

// Helper: Generate secure transaction ID
function generateSecureTransactionId() {
  const timestamp = Date.now().toString(36);
  const randomBytes = crypto.randomBytes(8).toString('hex');
  return `TXN${timestamp}${randomBytes}`;
}

exports.sendMoney = functions.https.onCall(async (data, context) => {
  // 1. Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const senderUid = context.auth.uid;
  const { recipientWalletId, amount, note } = data;

  // 2. Validate inputs
  if (!recipientWalletId || typeof recipientWalletId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid recipient wallet ID');
  }

  if (typeof amount !== 'number' || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Amount must be positive');
  }

  if (amount > 10000000) {
    throw new functions.https.HttpsError('invalid-argument', 'Amount exceeds limit');
  }

  try {
    // 3. Run atomic transaction
    const result = await db.runTransaction(async (transaction) => {
      // Get sender wallet
      const senderWalletRef = db.collection('wallets').doc(senderUid);
      const senderWallet = await transaction.get(senderWalletRef);

      if (!senderWallet.exists) {
        throw new functions.https.HttpsError('not-found', 'Sender wallet not found');
      }

      const senderData = senderWallet.data();
      const senderBalance = senderData.balance || 0;

      // Calculate fee (1% with min 10, max 100)
      const fee = Math.min(Math.max(amount * 0.01, 10), 100);
      const totalDebit = amount + fee;

      // Check balance
      if (senderBalance < totalDebit) {
        throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance');
      }

      // Prevent self-transfer
      if (senderData.walletId === recipientWalletId) {
        throw new functions.https.HttpsError('invalid-argument', 'Cannot send to yourself');
      }

      // Find recipient
      const recipientQuery = await db.collection('wallets')
        .where('walletId', '==', recipientWalletId)
        .limit(1)
        .get();

      if (recipientQuery.empty) {
        throw new functions.https.HttpsError('not-found', 'Recipient not found');
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
        note: note || '',
        status: 'completed',
        createdAt: now.toISOString(),
        completedAt: now.toISOString(),
        reference: `TXN-${now.getTime()}`
      };

      // Sender transaction record
      transaction.set(
        db.collection('users').doc(senderUid).collection('transactions').doc(txId),
        { ...baseTxData, type: 'send' }
      );

      // Recipient transaction record
      transaction.set(
        db.collection('users').doc(recipientUid).collection('transactions').doc(txId),
        { ...baseTxData, type: 'receive' }
      );

      return {
        transactionId: txId,
        amount: amount,
        fee: fee,
        recipientName: recipientName,
        newBalance: senderBalance - totalDebit
      };
    });

    return { success: true, ...result };

  } catch (error) {
    console.error('sendMoney error:', error);
    if (error.code) throw error;
    throw new functions.https.HttpsError('internal', 'Transaction failed');
  }
});

// ============================================================
// WALLET LOOKUP (with user + IP rate limiting)
// ============================================================

// Helper: Check and update rate limit
async function checkRateLimit(limitRef, maxRequests, windowMs) {
  const now = Date.now();
  const doc = await limitRef.get();

  if (doc.exists) {
    const { count, windowStart } = doc.data();
    if (now - windowStart < windowMs && count >= maxRequests) {
      return false; // Rate limited
    }
    await limitRef.update({
      count: now - windowStart < windowMs ? count + 1 : 1,
      windowStart: now - windowStart < windowMs ? windowStart : now
    });
  } else {
    await limitRef.set({ count: 1, windowStart: now });
  }
  return true; // Allowed
}

exports.lookupWallet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { walletId } = data;

  if (!walletId || typeof walletId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid wallet ID');
  }

  // Get client IP from request headers
  const clientIp = context.rawRequest?.ip ||
    context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() ||
    'unknown';

  // Hash IP for privacy (don't store raw IPs)
  const ipHash = crypto.createHash('sha256').update(clientIp).digest('hex').substring(0, 16);

  // Rate limiting - User level: 30 requests per minute
  const userLimitRef = db.collection('rate_limits').doc(`user_${context.auth.uid}`);
  const userAllowed = await checkRateLimit(userLimitRef, 30, 60000);

  if (!userAllowed) {
    throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded');
  }

  // Rate limiting - IP level: 100 requests per minute (catches distributed attacks)
  const ipLimitRef = db.collection('rate_limits').doc(`ip_${ipHash}`);
  const ipAllowed = await checkRateLimit(ipLimitRef, 100, 60000);

  if (!ipAllowed) {
    throw new functions.https.HttpsError('resource-exhausted', 'Too many requests from this network');
  }

  // Track failed lookups per user (anti-enumeration)
  const failedLookupRef = db.collection('rate_limits').doc(`failed_${context.auth.uid}`);

  // Lookup
  const query = await db.collection('wallets')
    .where('walletId', '==', walletId)
    .limit(1)
    .get();

  if (query.empty) {
    // Track failed lookup
    const failedDoc = await failedLookupRef.get();
    const now = Date.now();

    if (failedDoc.exists) {
      const { count, windowStart } = failedDoc.data();
      const newCount = now - windowStart < 300000 ? count + 1 : 1; // 5 min window

      // Block after 10 failed lookups in 5 minutes
      if (newCount >= 10) {
        await failedLookupRef.update({ count: newCount, windowStart: now - windowStart < 300000 ? windowStart : now });
        throw new functions.https.HttpsError('resource-exhausted', 'Too many invalid lookups. Please try again later.');
      }

      await failedLookupRef.update({
        count: newCount,
        windowStart: now - windowStart < 300000 ? windowStart : now
      });
    } else {
      await failedLookupRef.set({ count: 1, windowStart: now });
    }

    throw new functions.https.HttpsError('not-found', 'Wallet not found');
  }

  // Reset failed lookup counter on success
  await failedLookupRef.delete().catch(() => {});

  const wallet = query.docs[0].data();
  const userDoc = await db.collection('users').doc(query.docs[0].id).get();

  return {
    walletId: wallet.walletId,
    userName: userDoc.exists ? userDoc.data().fullName : 'QR Wallet User',
    profilePhotoUrl: userDoc.exists ? userDoc.data().profilePhotoUrl : null
  };
});

// ============================================================
// QR CODE SIGNING (P1 Security)
// ============================================================

// Sign QR payload for secure payment requests
exports.signQrPayload = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { walletId, amount, note } = data;

  if (!walletId) {
    throw new functions.https.HttpsError('invalid-argument', 'Wallet ID required');
  }

  // Verify wallet belongs to user
  const walletDoc = await db.collection('wallets').doc(context.auth.uid).get();
  if (!walletDoc.exists || walletDoc.data().walletId !== walletId) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid wallet');
  }

  const timestamp = Date.now();
  const payload = JSON.stringify({
    walletId,
    amount: amount || null,
    note: note || '',
    timestamp,
    userId: context.auth.uid
  });

  const signature = crypto
    .createHmac('sha256', QR_SECRET_KEY)
    .update(payload)
    .digest('hex');

  return {
    payload,
    signature,
    expiresAt: timestamp + QR_EXPIRY_MS
  };
});

// Verify QR signature before processing payment
exports.verifyQrSignature = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { payload, signature } = data;

  if (!payload || !signature) {
    throw new functions.https.HttpsError('invalid-argument', 'Payload and signature required');
  }

  // Verify signature
  const expectedSig = crypto
    .createHmac('sha256', QR_SECRET_KEY)
    .update(payload)
    .digest('hex');

  if (signature !== expectedSig) {
    return { valid: false, reason: 'Invalid signature' };
  }

  // Check expiry
  const parsed = JSON.parse(payload);
  if (Date.now() > parsed.timestamp + QR_EXPIRY_MS) {
    return { valid: false, reason: 'QR code expired' };
  }

  return {
    valid: true,
    walletId: parsed.walletId,
    amount: parsed.amount,
    note: parsed.note
  };
});
