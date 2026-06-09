const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'qr-wallet-1993' });
const db = admin.firestore();

// Currencies Shop Afrik operates in. MUST remain a subset of VALID_CURRENCIES
// in functions/index.js. Excludes retired SLL and the non-African card/sandbox
// currencies USD/EUR/GBP. To change Shop Afrik market coverage, edit ONLY this
// map (and keep every key present in VALID_CURRENCIES).
const SHOP_AFRIK_CURRENCIES = {
  GHS: { country: 'Ghana', region: 'West Africa' },
  NGN: { country: 'Nigeria', region: 'West Africa' },
  KES: { country: 'Kenya', region: 'East Africa' },
  ZAR: { country: 'South Africa', region: 'Southern Africa' },
  TZS: { country: 'Tanzania', region: 'East Africa' },
  UGX: { country: 'Uganda', region: 'East Africa' },
  RWF: { country: 'Rwanda', region: 'East Africa' },
  XOF: { countries: ['Ivory Coast', 'Benin', 'Guinea Bissau', 'Senegal'], region: 'West Africa' },
  XAF: { countries: ['Cameroon', 'Congo Brazzaville', 'Gabon'], region: 'Central Africa' },
  EGP: { country: 'Egypt', region: 'North Africa' },
  GNF: { country: 'Guinea Conakry', region: 'West Africa' },
  LRD: { country: 'Liberia', region: 'West Africa' },
  ZMW: { country: 'Zambia', region: 'Southern Africa' },
  ZWG: { country: 'Zimbabwe', region: 'Southern Africa' },
  SZL: { country: 'Eswatini', region: 'Southern Africa' },
  SSP: { country: 'South Sudan', region: 'East Africa' },
  SLE: { country: 'Sierra Leone', region: 'West Africa' },
  CDF: { country: 'DRC', region: 'Central Africa' },
};

async function setupShopAfrikWallet() {
  const now = new Date().toISOString();

  console.log('========================================');
  console.log('  Shop Afrik - Platform Account Setup');
  console.log('========================================\n');

  try {
    const existing = await db.collection('wallets').doc('shop_afrik').get();
    if (existing.exists) {
      console.log('wallets/shop_afrik already exists - nothing to do.');
      console.log('(Use a dedicated reset script if you intend to re-seed.)');
      return;
    }

    console.log('1. Creating Shop Afrik platform account doc...');
    await db.collection('wallets').doc('shop_afrik').set({
      walletId: 'QRW-SHOPAFRIK',
      type: 'shop_afrik',
      name: 'Shop Afrik',
      description: 'Shop Afrik marketplace platform account. Segregated from QR Wallet revenue; never commingled.',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    });
    console.log('   Done.\n');

    console.log('2. Creating per-currency bucket balances (escrowHeld / owedToSellers / commissionEarned)...');
    const batch = db.batch();
    let count = 0;
    for (const [currency, info] of Object.entries(SHOP_AFRIK_CURRENCIES)) {
      const ref = db.collection('wallets').doc('shop_afrik').collection('balances').doc(currency);
      const data = {
        currency: currency,
        escrowHeld: 0,
        owedToSellers: 0,
        commissionEarned: 0,
        txCount: 0,
        region: info.region,
        lastTransactionAt: null,
        createdAt: now,
        updatedAt: now,
      };
      if (info.country) {
        data.country = info.country;
      } else if (info.countries) {
        data.countries = info.countries;
      }
      batch.set(ref, data);
      count += 1;
      console.log('   - ' + currency + ': ' + (info.country || info.countries.join(', ')));
    }
    await batch.commit();

    console.log('\n========================================');
    console.log('  Setup Complete.');
    console.log('  Account: QRW-SHOPAFRIK  (wallets/shop_afrik)');
    console.log('  Currencies seeded: ' + count);
    console.log('  All buckets initialized to 0.');
    console.log('========================================\n');
  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
}

setupShopAfrikWallet()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
