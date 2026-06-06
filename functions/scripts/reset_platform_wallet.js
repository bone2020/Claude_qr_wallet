const admin = require('firebase-admin');
const readline = require('readline');

admin.initializeApp({ projectId: 'qr-wallet-1993' });
const db = admin.firestore();

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(question, (ans) => { rl.close(); resolve(ans); }));
}

async function resetPlatformWallet() {
  const now = new Date().toISOString();

  console.log('========================================');
  console.log('  QR Wallet - Platform Wallet RESET');
  console.log('========================================\n');

  const platformRef = db.collection('wallets').doc('platform');
  const platformSnap = await platformRef.get();

  if (!platformSnap.exists) {
    console.log('wallets/platform does not exist - nothing to reset.');
    console.log('Run setup_platform_wallet.js first if you need to create it.');
    return;
  }

  const data = platformSnap.data();
  const balancesSnap = await platformRef.collection('balances').get();

  console.log('This will ZERO the following (all other fields left untouched):\n');
  console.log('  wallets/platform');
  console.log('    totalBalanceUSD    ' + (data.totalBalanceUSD || 0) + '  ->  0');
  console.log('    totalTransactions  ' + (data.totalTransactions || 0) + '  ->  0');
  console.log('    totalFeesCollected ' + (data.totalFeesCollected || 0) + '  ->  0');
  console.log('\n  wallets/platform/balances/{currency}  (' + balancesSnap.size + ' currencies)');
  balancesSnap.forEach((doc) => {
    const b = doc.data();
    console.log('    ' + doc.id + '  amount=' + (b.amount || 0) + '  usd=' + (b.usdEquivalent || 0) + '  txCount=' + (b.txCount || 0) + '  ->  0 / 0 / 0, lastTransactionAt -> null');
  });

  console.log('\nThis permanently wipes the accumulated ledger. It cannot be undone.');
  const answer = await ask('Type  RESET  to proceed (anything else aborts): ');

  if (answer.trim() !== 'RESET') {
    console.log('\nAborted - no changes made.');
    return;
  }

  console.log('\nResetting...');
  const batch = db.batch();

  batch.update(platformRef, {
    totalBalanceUSD: 0,
    totalTransactions: 0,
    totalFeesCollected: 0,
    lastResetAt: now,
    updatedAt: now,
  });

  balancesSnap.forEach((doc) => {
    batch.update(doc.ref, {
      amount: 0,
      usdEquivalent: 0,
      txCount: 0,
      lastTransactionAt: null,
      updatedAt: now,
    });
  });

  await batch.commit();
  console.log('Done - platform totals + ' + balancesSnap.size + ' currency balances zeroed.');
}

resetPlatformWallet()
  .then(() => process.exit(0))
  .catch((err) => { console.error('Error:', err); process.exit(1); });
