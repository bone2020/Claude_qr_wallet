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

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

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

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

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

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

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
    throw new functions.https.HttpsError('internal', error.message || 'Transaction initialization failed');
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
    throw new functions.https.HttpsError('internal', error.message || 'Transaction initialization failed');
  }
});

// ============================================================
// QR CODE SIGNING & VERIFICATION
// ============================================================

// Secret key for signing QR codes (set via: firebase functions:config:set qr.secret="your-secret-key")
const QR_SECRET_KEY = functions.config().qr?.secret || 'qr-wallet-default-secret-key-change-me';
const QR_EXPIRY_MS = 15 * 60 * 1000; // 15 minutes

// Helper: Generate HMAC signature
function generateQrSignature(payload) {
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
    throw new functions.https.HttpsError('not-found', 'User account not found');
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
  throw new functions.https.HttpsError(
    'permission-denied',
    'KYC_REQUIRED: Identity verification is required to perform financial operations'
  );
}

// Set KYC status (called after successful Smile ID verification)
exports.updateKycStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const userId = context.auth.uid;
  const { status } = data;

  // Only allow setting to specific valid statuses
  const validStatuses = ['pending', 'verified', 'rejected'];
  if (!validStatuses.includes(status)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid KYC status');
  }

  // For 'verified', require that KYC documents have been approved in the subcollection
  if (status === 'verified') {
    const kycDoc = await db.collection('users').doc(userId)
      .collection('kyc').doc('documents').get();

    if (!kycDoc.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'No KYC documents found');
    }

    const kycData = kycDoc.data();
    if (kycData.status !== 'approved' && kycData.status !== 'verified') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'KYC documents have not been approved'
      );
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
// QR CODE SIGNING & VERIFICATION
// ============================================================

// Sign QR payload for payment requests
exports.signQrPayload = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  // Enforce KYC verification before financial operation
  await enforceKyc(context.auth.uid);

  const { walletId, amount, note } = data;

  if (!walletId || typeof walletId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid wallet ID');
  }
  
  // Verify the wallet belongs to the user
  const walletDoc = await db.collection('wallets').doc(context.auth.uid).get();
  if (!walletDoc.exists || walletDoc.data().walletId !== walletId) {
    throw new functions.https.HttpsError('permission-denied', 'Wallet does not belong to user');
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
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }
  
  const { payload, signature } = data;
  
  if (!payload || !signature) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing payload or signature');
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
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }
  
  const { walletId } = data;
  const userId = context.auth.uid;
  
  // Get IP for rate limiting (hashed for privacy)
  const ip = context.rawRequest?.headers?.['x-forwarded-for'] || 'unknown';
  const hashedIp = crypto.createHash('sha256').update(ip).digest('hex').substring(0, 16);
  
  // Check user rate limit (30 requests per minute)
  if (!checkRateLimit(`user:${userId}`, 30, 60000)) {
    throw new functions.https.HttpsError('resource-exhausted', 'Too many requests. Please wait.');
  }
  
  // Check IP rate limit (100 requests per minute)
  if (!checkRateLimit(`ip:${hashedIp}`, 100, 60000)) {
    throw new functions.https.HttpsError('resource-exhausted', 'Too many requests from this location.');
  }
  
  // Check failed lookup limit
  if (!checkFailedLookups(hashedIp)) {
    throw new functions.https.HttpsError('resource-exhausted', 'Too many failed attempts. Please wait 5 minutes.');
  }
  
  if (!walletId || typeof walletId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid wallet ID');
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
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { phoneNumber, country, firstName, lastName, idNumber } = data;

  // Validate required fields
  if (!phoneNumber || !country) {
    throw new functions.https.HttpsError('invalid-argument', 'Phone number and country are required');
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
    throw new functions.https.HttpsError('internal', error.message || 'Verification failed');
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
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const senderUid = context.auth.uid;

  // Enforce KYC verification before financial operation
  await enforceKyc(senderUid);

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

    return { success: true, ...result };

  } catch (error) {
    console.error('sendMoney error:', error);
    if (error.code) throw error;
    throw new functions.https.HttpsError('internal', 'Transaction failed');
  }
});

// ============================================================
// MTN MOMO API CONFIGURATION
// ============================================================

// MTN MoMo configuration - set via: firebase functions:config:set momo.collections_subscription_key="xxx" etc.
const MOMO_CONFIG = {
  collections: {
    subscriptionKey: functions.config().momo?.collections_subscription_key || '02e123077f6d495986e243a28aa5b357',
    apiUser: functions.config().momo?.collections_api_user || 'fbc05238-f396-4901-9d91-0885597feed7',
    apiKey: functions.config().momo?.collections_api_key || '44fd8ff16d2a4bceb10972a11b363fbb',
  },
  disbursements: {
    subscriptionKey: functions.config().momo?.disbursements_subscription_key || 'c3d6c20d5d164c238c7e5dc9da68d200',
    apiUser: functions.config().momo?.disbursements_api_user || '090f74d7-4295-4f07-8fa7-a1e8f7ef6813',
    apiKey: functions.config().momo?.disbursements_api_key || 'd9f3ba42f70d4cada7a8741e215f4500',
  },
  baseUrl: functions.config().momo?.environment === 'production'
    ? 'proxy.momoapi.mtn.com'
    : 'sandbox.momodeveloper.mtn.com',
  environment: functions.config().momo?.environment || 'sandbox',
  callbackUrl: 'https://us-central1-qr-wallet-1993.cloudfunctions.net/momoWebhook',
};

// Helper function to get MTN MoMo access token
async function getMomoAccessToken(product) {
  const config = product === 'collections' ? MOMO_CONFIG.collections : MOMO_CONFIG.disbursements;
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
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { amount, currency, phoneNumber, payerMessage, payeeNote } = data;
  const userId = context.auth.uid;

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
  }
  if (!phoneNumber) {
    throw new functions.https.HttpsError('invalid-argument', 'Phone number is required');
  }

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

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
        status: 'PENDING',
        referenceId: referenceId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        referenceId: referenceId,
        status: 'PENDING',
        message: 'Please approve the payment on your phone',
      };
    } else {
      throw new functions.https.HttpsError('internal', 'Failed to initiate payment: ' + JSON.stringify(response.data));
    }
  } catch (error) {
    console.error('MoMo RequestToPay error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================
// MTN MOMO - CHECK TRANSACTION STATUS
// ============================================================

exports.momoCheckStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { referenceId, type } = data;

  if (!referenceId) {
    throw new functions.https.HttpsError('invalid-argument', 'Reference ID is required');
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
        if (status === 'SUCCESSFUL' && txData.status !== 'SUCCESSFUL') {
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

            // Update momo transaction status
            transaction.update(txRef, {
              status: status,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          });
        } else {
          // Just update status
          await txRef.update({
            status: status,
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
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================
// MTN MOMO DISBURSEMENTS - TRANSFER (Withdraw)
// ============================================================

exports.momoTransfer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { amount, currency, phoneNumber, payerMessage, payeeNote } = data;
  const userId = context.auth.uid;

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
  }
  if (!phoneNumber) {
    throw new functions.https.HttpsError('invalid-argument', 'Phone number is required');
  }

  // Enforce KYC verification before financial operation
  await enforceKyc(userId);

  try {
    // Check wallet balance
    const walletSnapshot = await db.collection('wallets')
      .where('userId', '==', userId)
      .limit(1)
      .get();

    if (walletSnapshot.empty) {
      throw new functions.https.HttpsError('not-found', 'Wallet not found');
    }

    const walletDoc = walletSnapshot.docs[0];
    const walletData = walletDoc.data();

    if ((walletData.balance || 0) < amount) {
      throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance');
    }

    // Generate unique reference ID
    const referenceId = crypto.randomUUID();

    // Debit wallet first
    await db.runTransaction(async (transaction) => {
      const freshWallet = await transaction.get(walletDoc.ref);
      const currentBalance = freshWallet.data().balance || 0;

      if (currentBalance < amount) {
        throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance');
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
        status: 'PENDING',
        referenceId: referenceId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
          status: 'FAILED',
          failureReason: JSON.stringify(response.data),
          refunded: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      throw new functions.https.HttpsError('internal', 'Failed to initiate transfer: ' + JSON.stringify(response.data));
    }
  } catch (error) {
    console.error('MoMo Transfer error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================
// MTN MOMO - GET BALANCE
// ============================================================

exports.momoGetBalance = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
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
      throw new functions.https.HttpsError('internal', 'Failed to get balance');
    }
  } catch (error) {
    console.error('MoMo balance error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================
// MTN MOMO - WEBHOOK (Callback for async notifications)
// ============================================================

exports.momoWebhook = functions.https.onRequest(async (req, res) => {
  console.log('MoMo webhook received:', req.body);

  try {
    const { externalId, status, financialTransactionId } = req.body;

    if (externalId) {
      const txRef = db.collection('momo_transactions').doc(externalId);
      const txDoc = await txRef.get();

      if (txDoc.exists) {
        const txData = txDoc.data();

        // Update status and process if successful
        if (status === 'SUCCESSFUL' && txData.status !== 'SUCCESSFUL') {
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
              status: status,
              financialTransactionId: financialTransactionId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          });
        } else if (status === 'FAILED') {
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
                status: status,
                refunded: true,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            });
          } else {
            await txRef.update({
              status: status,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('MoMo webhook error:', error);
    res.status(500).send('Error');
  }
});
