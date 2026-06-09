'use strict';
const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'qr-wallet-1993' });
const db = admin.firestore();

async function dumpDocSubs(path, label) {
  const subs = await db.doc(path).listCollections();
  console.log('=== ' + label + ' ' + path + ' subcollections: ' + subs.map(c => c.id).join(', '));
  for (const sub of subs) {
    let s;
    try { s = await sub.orderBy('createdAt', 'desc').limit(5).get(); }
    catch (e) { s = await sub.limit(5).get(); }
    console.log('  --- ' + sub.id + ' (' + s.size + '):');
    s.forEach(d => console.log('    ' + JSON.stringify(d.data())));
  }
}

(async () => {
  await dumpDocSubs('users/HL4rztZzXmasUaW87FXCJHvAoez1', 'Joe');
  await dumpDocSubs('users/hF4h8yovG3XxAuKFifKZGM4BTRP2', 'Magret');
  for (const c of ['pending_transactions', 'momo_transactions']) {
    let s;
    try { s = await db.collection(c).orderBy('createdAt', 'desc').limit(4).get(); }
    catch (e) { s = await db.collection(c).limit(4).get(); }
    console.log('=== ' + c + ' (' + s.size + ') ===');
    s.forEach(d => console.log('  ' + JSON.stringify(d.data())));
  }
  process.exit(0);
})().catch(e => { console.error(e.message); process.exit(1); });
