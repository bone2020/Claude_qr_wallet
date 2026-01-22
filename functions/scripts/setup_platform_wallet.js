const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const CURRENCY_COUNTRIES = {
  'GHS': { country: 'Ghana', region: 'West Africa' },
  'NGN': { country: 'Nigeria', region: 'West Africa' },
  'XOF': { countries: ['Ivory Coast', 'Benin', 'Guinea Bissau', 'Senegal'], region: 'West Africa' },
  'XAF': { countries: ['Cameroon', 'Congo Brazzaville', 'Gabon'], region: 'Central Africa' },
  'CDF': { country: 'DRC', region: 'Central Africa' },
  'LRD': { country: 'Liberia', region: 'West Africa' },
  'GNF': { country: 'Guinea Conakry', region: 'West Africa' },
  'SLE': { country: 'Sierra Leone', region: 'West Africa' },
  'UGX': { country: 'Uganda', region: 'East Africa' },
  'RWF': { country: 'Rwanda', region: 'East Africa' },
  'KES': { country: 'Kenya', region: 'East Africa' },
  'TZS': { country: 'Tanzania', region: 'East Africa' },
  'ETB': { country: 'Ethiopia', region: 'East Africa' },
  'MGA': { country: 'Madagascar', region: 'East Africa' },
  'ZAR': { country: 'South Africa', region: 'Southern Africa' },
  'ZMW': { country: 'Zambia', region: 'Southern Africa' },
  'MWK': { country: 'Malawi', region: 'Southern Africa' },
  'MZN': { country: 'Mozambique', region: 'Southern Africa' },
  'SZL': { country: 'Eswatini', region: 'Southern Africa' }
};

async function setupPlatformWallet() {
  const now = new Date().toISOString();
  
  console.log('========================================');
  console.log('  QR Wallet - Platform Wallet Setup');
  console.log('========================================\n');
  
  try {
    const existingWallet = await db.collection('wallets').doc('platform').get();
    if (existingWallet.exists) {
      console.log('Platform wallet already exists!');
      console.log('Balance: $' + (existingWallet.data().totalBalanceUSD || 0).toFixed(2));
      return;
    }
    
    console.log('1. Creating platform wallet...');
    
    await db.collection('wallets').doc('platform').set({
      walletId: 'QRW-PLATFORM',
      type: 'platform',
      name: 'QR Wallet',
      description: 'Platform fee collection wallet',
      totalBalanceUSD: 0,
      totalTransactions: 0,
      totalFeesCollected: 0,
      isActive: true,
      createdAt: now,
      updatedAt: now
    });
    
    console.log('   Done!\n');
    console.log('2. Creating currency balances...');
    
    const batch = db.batch();
    
    for (const [currency, info] of Object.entries(CURRENCY_COUNTRIES)) {
      const balanceRef = db.collection('wallets').doc('platform').collection('balances').doc(currency);
      
      const balanceData = {
        currency: currency,
        amount: 0,
        usdEquivalent: 0,
        region: info.region,
        txCount: 0,
        lastTransactionAt: null,
        createdAt: now,
        updatedAt: now
      };
      
      if (info.country) {
        balanceData.country = info.country;
      } else if (info.countries) {
        balanceData.countries = info.countries;
      }
      
      batch.set(balanceRef, balanceData);
      console.log('   - ' + currency + ': ' + (info.country || info.countries.join(', ')));
    }
    
    await batch.commit();
    
    console.log('\n========================================');
    console.log('  Setup Complete!');
    console.log('  Wallet ID: QRW-PLATFORM');
    console.log('  Currencies: 19');
    console.log('========================================\n');
    
  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
}

setupPlatformWallet()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
