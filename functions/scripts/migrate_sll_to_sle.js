'use strict';
const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'qr-wallet-1993' });
const db = admin.firestore();
const APPLY = process.argv.includes('apply');

async function main() {
  const plan = [];

  const sllRef = db.doc('wallets/platform/balances/SLL');
  const sllSnap = await sllRef.get();
  if (sllSnap.exists) {
    const s = sllSnap.data();
    plan.push({
      action: 'DELETE',
      path: sllRef.path,
      detail: 'platform orphan amount=' + s.amount + ' txCount=' + s.txCount,
      run: () => sllRef.delete(),
    });
  }

  const sllWallets = await db.collection('wallets').where('currency', '==', 'SLL').get();
  sllWallets.forEach(d => {
    if (d.id === 'platform') return;
    const x = d.data();
    plan.push({
      action: 'RELABEL',
      path: d.ref.path,
      detail: 'currency SLL->SLE, balance=' + x.balance + ' (unchanged)',
      run: () => d.ref.update({ currency: 'SLE', updatedAt: admin.firestore.FieldValue.serverTimestamp() }),
    });
  });

  console.log(APPLY ? '=== APPLYING ===' : '=== DRY RUN (no writes). Re-run with "apply" to execute. ===');
  if (plan.length === 0) { console.log('Nothing to do.'); process.exit(0); }
  for (const p of plan) console.log('  [' + p.action + '] ' + p.path + ' | ' + p.detail);
  if (APPLY) {
    for (const p of plan) { await p.run(); console.log('  done: ' + p.action + ' ' + p.path); }
    console.log('=== APPLIED ' + plan.length + ' change(s) ===');
  }
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
