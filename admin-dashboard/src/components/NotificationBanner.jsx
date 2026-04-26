import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { httpsCallable } from 'firebase/functions';
import { getApp } from 'firebase/app';
import { doc, getDoc, getFirestore } from 'firebase/firestore';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';

const RESOLVED_DISPUTE_STATUSES = new Set(['resolved', 'closed_stuck']);

function Banner({ tone, onClick, children }) {
  const toneClass =
    tone === 'red'
      ? 'bg-red-600 text-white hover:bg-red-700'
      : tone === 'yellow'
      ? 'bg-amber-400 text-amber-950 hover:bg-amber-500'
      : tone === 'black'
      ? 'bg-gray-900 text-white hover:bg-gray-800'
      : 'bg-gray-200 text-gray-900 hover:bg-gray-300';

  return (
    <button
      type="button"
      onClick={onClick}
      className={`w-full text-left px-4 py-3 md:py-2 text-sm font-medium transition-colors ${toneClass}`}
    >
      {children}
    </button>
  );
}

function NotificationBanner() {
  const { user, isFinance } = useAuth();
  const navigate = useNavigate();

  const [overdueCount, setOverdueCount] = useState(0);
  const [blocked, setBlocked] = useState(false);
  const [pendingDisputes, setPendingDisputes] = useState(0);

  useEffect(() => {
    if (!user) return;
    let cancelled = false;

    const loadOverdueAndBlocked = async () => {
      if (!isFinance) return;
      try {
        const result = await httpsCallable(functions, 'adminListTransferProposals')({
          status: 'evidence_overdue',
          limit: 10,
        });
        const mine = (result.data?.proposals || []).filter(
          (p) => (p.proposedBy?.uid || p.proposedByUid) === user.uid
        );
        if (!cancelled) setOverdueCount(mine.length);
      } catch (err) {
        // Banner is best-effort; failure is silent.
        // eslint-disable-next-line no-console
        console.warn('Failed to load overdue evidence count:', err?.message);
      }

      try {
        const db = getFirestore(getApp());
        const snap = await getDoc(doc(db, 'blocked_finance_users', user.uid));
        if (!cancelled) setBlocked(snap.exists());
      } catch (err) {
        // eslint-disable-next-line no-console
        console.warn('Failed to read blocked_finance_users:', err?.message);
      }
    };

    const loadPendingDisputes = async () => {
      try {
        const result = await httpsCallable(functions, 'userGetMyDisputes')({
          role: 'recipient',
          limit: 10,
        });
        const active = (result.data?.disputes || []).filter(
          (d) => !RESOLVED_DISPUTE_STATUSES.has(d.status)
        );
        if (!cancelled) setPendingDisputes(active.length);
      } catch (err) {
        // eslint-disable-next-line no-console
        console.warn('Failed to load my disputes:', err?.message);
      }
    };

    loadOverdueAndBlocked();
    loadPendingDisputes();

    return () => {
      cancelled = true;
    };
  }, [user, isFinance]);

  if (!user) return null;
  if (!overdueCount && !blocked && !pendingDisputes) return null;

  return (
    <div className="flex flex-col">
      {blocked && (
        <Banner tone="black">
          🚫 You are blocked from new proposals. Upload evidence on your overdue proposals to unblock.
        </Banner>
      )}
      {overdueCount > 0 && (
        <Banner
          tone="red"
          onClick={() => navigate('/revenue?filter=evidence_overdue')}
        >
          ⚠️ You have {overdueCount} overdue evidence upload{overdueCount === 1 ? '' : 's'}. Close them or you'll be blocked.
        </Banner>
      )}
      {pendingDisputes > 0 && (
        <Banner tone="yellow" onClick={() => navigate('/disputes')}>
          📋 You have {pendingDisputes} active dispute{pendingDisputes === 1 ? '' : 's'} against you. Tap to respond.
        </Banner>
      )}
    </div>
  );
}

export default NotificationBanner;
