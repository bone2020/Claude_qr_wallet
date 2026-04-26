import React, { useEffect, useMemo, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { v4 as uuidv4 } from 'uuid';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';

const STATUS_OPTIONS = [
  'all',
  'held_pending_confirmation',
  'released_to_filer',
  'cancelled',
];

const CONFIRM_FILTER_OPTIONS = ['any', 'yes', 'no'];

const CANCEL_REASONS = [
  { value: 'recipient_disputes_debt', label: 'Recipient disputes debt' },
  { value: 'admin_cancelled', label: 'Admin cancelled' },
  { value: 'investigation_required', label: 'Investigation required' },
  { value: 'other', label: 'Other' },
];

const currencySymbols = {
  NGN: '₦', GHS: 'GH₵', KES: 'KSh', ZAR: 'R', UGX: 'USh',
  RWF: 'FRw', TZS: 'TSh', EGP: 'E£', USD: '$', GBP: '£', EUR: '€',
};

const symbol = (c) => currencySymbols[c] || c || '';
const formatDate = (iso) => (iso ? new Date(iso).toLocaleString() : '—');

const ageLabel = (iso) => {
  if (!iso) return '—';
  const ms = Date.now() - new Date(iso).getTime();
  if (ms < 0) return '—';
  const days = Math.floor(ms / 86400000);
  if (days >= 1) return `${days}d`;
  const hours = Math.floor(ms / 3600000);
  return `${hours}h`;
};

const statusBadgeClass = (status) => {
  switch (status) {
    case 'held_pending_confirmation':
      return 'bg-amber-100 text-amber-800';
    case 'released_to_filer':
      return 'bg-green-100 text-green-700';
    case 'cancelled':
      return 'bg-gray-200 text-gray-700';
    default:
      return 'bg-gray-100 text-gray-600';
  }
};

function StatusBadge({ status }) {
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${statusBadgeClass(status)}`}>
      {status || 'unknown'}
    </span>
  );
}

function CheckMark({ value }) {
  return value ? (
    <span className="text-green-600 font-bold" title="Confirmed">✓</span>
  ) : (
    <span className="text-gray-300" title="Not confirmed">✗</span>
  );
}

function ModalShell({ title, onClose, children, maxWidth = 'max-w-md' }) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-2 md:p-4">
      <div className={`bg-white rounded-xl shadow-2xl ${maxWidth} w-full p-4 md:p-6 max-h-[90vh] overflow-y-auto`}>
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-bold text-gray-900">{title}</h3>
          <button
            onClick={onClose}
            aria-label="Close"
            className="text-gray-400 hover:text-gray-600 text-2xl leading-none"
          >
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

function RecoveryNotesModal({
  title,
  recovery,
  cfName,
  extraPayload,
  notesMin = 0,
  onClose,
  onDone,
}) {
  const [notes, setNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const canSubmit = !submitting && notes.trim().length >= notesMin;

  const handleSubmit = async () => {
    if (!canSubmit) return;
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, cfName)({
        recoveryId: recovery.recoveryId || recovery.id,
        notes: notes.trim(),
        idempotencyKey: uuidv4(),
        ...(extraPayload || {}),
      });
      if (onDone) onDone();
      onClose();
    } catch (err) {
      setError(err?.message || 'Action failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title={title} onClose={onClose}>
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}
      <div className="bg-gray-50 rounded-lg p-3 mb-4 text-sm space-y-1">
        <div className="flex justify-between">
          <span className="text-gray-500">Recovery</span>
          <span className="font-mono text-xs">{recovery.recoveryId || recovery.id}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-500">Amount</span>
          <span className="font-medium">
            {symbol(recovery.currency)}{Number(recovery.amount || 0).toFixed(2)} {recovery.currency}
          </span>
        </div>
      </div>

      <div className="flex items-center justify-between mb-1">
        <label className="text-sm text-gray-700 font-medium">
          Notes{notesMin > 0 ? ` (min ${notesMin})` : ' (optional)'}
        </label>
        {notesMin > 0 && (
          <span className={`text-xs ${notes.trim().length >= notesMin ? 'text-gray-500' : 'text-amber-600'}`}>
            {notes.length} / {notesMin}
          </span>
        )}
      </div>
      <textarea
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
        rows={4}
        placeholder="Document this action..."
        className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
      />

      <div className="flex gap-2 mt-5">
        <button
          onClick={handleSubmit}
          disabled={!canSubmit}
          className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-3 md:py-2 rounded-lg text-sm font-medium disabled:opacity-50"
        >
          {submitting ? 'Submitting...' : 'Submit'}
        </button>
        <button
          onClick={onClose}
          disabled={submitting}
          className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Cancel
        </button>
      </div>
    </ModalShell>
  );
}

function CancelRecoveryModal({ recovery, onClose, onDone }) {
  const [cancelReason, setCancelReason] = useState(CANCEL_REASONS[0].value);
  const [notes, setNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const canSubmit = !submitting && notes.trim().length >= 20;

  const handleSubmit = async () => {
    if (!canSubmit) return;
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminCancelRecovery')({
        recoveryId: recovery.recoveryId || recovery.id,
        cancelReason,
        notes: notes.trim(),
        idempotencyKey: uuidv4(),
      });
      if (onDone) onDone();
      onClose();
    } catch (err) {
      setError(err?.message || 'Cancel failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title="Cancel Recovery" onClose={onClose}>
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}
      <div className="bg-gray-50 rounded-lg p-3 mb-4 text-sm">
        <div className="flex justify-between">
          <span className="text-gray-500">Recovery</span>
          <span className="font-mono text-xs">{recovery.recoveryId || recovery.id}</span>
        </div>
      </div>

      <label className="text-sm text-gray-700 font-medium block mb-1">Reason</label>
      <select
        value={cancelReason}
        onChange={(e) => setCancelReason(e.target.value)}
        className="w-full border border-gray-300 rounded-lg px-4 py-2 mb-3"
      >
        {CANCEL_REASONS.map((r) => (
          <option key={r.value} value={r.value}>{r.label}</option>
        ))}
      </select>

      <div className="flex items-center justify-between mb-1">
        <label className="text-sm text-gray-700 font-medium">Notes</label>
        <span className={`text-xs ${notes.trim().length >= 20 ? 'text-gray-500' : 'text-amber-600'}`}>
          {notes.length} / 20
        </span>
      </div>
      <textarea
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
        rows={4}
        placeholder="Explain why this recovery is being cancelled..."
        className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
      />

      <div className="flex gap-2 mt-5">
        <button
          onClick={handleSubmit}
          disabled={!canSubmit}
          className="flex-1 bg-red-600 hover:bg-red-700 text-white px-4 py-3 md:py-2 rounded-lg text-sm font-medium disabled:opacity-50"
        >
          {submitting ? 'Cancelling...' : 'Cancel Recovery'}
        </button>
        <button
          onClick={onClose}
          disabled={submitting}
          className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Back
        </button>
      </div>
    </ModalShell>
  );
}

function RecoveryWatchPage() {
  const { isAdminSupervisor, isAdminManager } = useAuth();

  const [statusFilter, setStatusFilter] = useState('held_pending_confirmation');
  const [filerConfirmedFilter, setFilerConfirmedFilter] = useState('any');
  const [recipientConfirmedFilter, setRecipientConfirmedFilter] = useState('any');

  const [recoveries, setRecoveries] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [refreshKey, setRefreshKey] = useState(0);

  const [activeAction, setActiveAction] = useState(null); // { kind, recovery }

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setError('');
      try {
        const params = { limit: 50 };
        if (statusFilter && statusFilter !== 'all') params.status = statusFilter;
        const result = await httpsCallable(functions, 'adminListRecoveries')(params);
        if (!cancelled) setRecoveries(result.data?.recoveries || []);
      } catch (err) {
        if (!cancelled) setError(err?.message || 'Failed to load recoveries.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => {
      cancelled = true;
    };
  }, [statusFilter, refreshKey]);

  const refresh = () => setRefreshKey((k) => k + 1);

  const filtered = useMemo(() => {
    return recoveries.filter((r) => {
      if (filerConfirmedFilter === 'yes' && !r.filerConfirmed) return false;
      if (filerConfirmedFilter === 'no' && r.filerConfirmed) return false;
      if (recipientConfirmedFilter === 'yes' && !r.recipientConfirmed) return false;
      if (recipientConfirmedFilter === 'no' && r.recipientConfirmed) return false;
      return true;
    });
  }, [recoveries, filerConfirmedFilter, recipientConfirmedFilter]);

  if (!isAdminSupervisor) {
    return (
      <div className="space-y-6 p-6">
        <h1 className="text-2xl font-bold text-gray-900">Recovery Watch</h1>
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 text-sm text-gray-500">
          You do not have access to recovery watch.
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Recovery Watch</h1>
          <p className="text-sm text-gray-500 mt-1">
            Held debt recoveries awaiting two-party confirmation before release to the filer.
          </p>
        </div>
        <button
          onClick={refresh}
          disabled={loading}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm transition-colors disabled:opacity-50"
        >
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg">
          {error}
        </div>
      )}

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div className="flex flex-wrap items-end gap-3 mb-4">
          <div>
            <label className="text-xs text-gray-500 block mb-1">Status</label>
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="border border-gray-300 rounded-lg px-3 py-1.5 text-sm"
            >
              {STATUS_OPTIONS.map((s) => (
                <option key={s} value={s}>{s === 'all' ? 'All statuses' : s}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-xs text-gray-500 block mb-1">Filer Confirmed</label>
            <select
              value={filerConfirmedFilter}
              onChange={(e) => setFilerConfirmedFilter(e.target.value)}
              className="border border-gray-300 rounded-lg px-3 py-1.5 text-sm"
            >
              {CONFIRM_FILTER_OPTIONS.map((o) => (
                <option key={o} value={o}>{o}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-xs text-gray-500 block mb-1">Recipient Confirmed</label>
            <select
              value={recipientConfirmedFilter}
              onChange={(e) => setRecipientConfirmedFilter(e.target.value)}
              className="border border-gray-300 rounded-lg px-3 py-1.5 text-sm"
            >
              {CONFIRM_FILTER_OPTIONS.map((o) => (
                <option key={o} value={o}>{o}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="overflow-x-auto rounded-lg border border-gray-200">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recovery</th>
                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Debt</th>
                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispute</th>
                <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filer</th>
                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Deducted</th>
                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Age</th>
                <th className="px-3 py-2 text-center text-xs font-medium text-gray-500 uppercase">Filer&nbsp;&#10003;</th>
                <th className="px-3 py-2 text-center text-xs font-medium text-gray-500 uppercase">Recipient&nbsp;&#10003;</th>
                <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={12} className="px-3 py-8 text-center text-gray-400 text-sm">
                    {loading ? 'Loading...' : 'No recoveries match.'}
                  </td>
                </tr>
              ) : (
                filtered.map((r) => {
                  const id = r.recoveryId || r.id;
                  const pending = r.status === 'held_pending_confirmation';
                  const canConfirmFiler = pending && !r.filerConfirmed;
                  const canConfirmRecipient = pending && !r.recipientConfirmed;
                  const canCancel = pending;
                  const canRelease =
                    pending && r.filerConfirmed && r.recipientConfirmed && isAdminManager;

                  return (
                    <tr key={id} className="hover:bg-gray-50">
                      <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                      <td className="px-3 py-2 text-xs font-mono text-gray-500">{r.debtId || '—'}</td>
                      <td className="px-3 py-2 text-xs font-mono text-gray-500">{r.disputeId || '—'}</td>
                      <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                        {symbol(r.currency)}{Number(r.amount || 0).toFixed(2)}
                        <div className="text-xs text-gray-400">{r.currency}</div>
                      </td>
                      <td className="px-3 py-2 text-sm text-gray-700">
                        <div>{r.recipient?.name || r.recipientName || '—'}</div>
                        <div className="text-xs text-gray-400">{r.recipient?.email || r.recipientEmail || ''}</div>
                      </td>
                      <td className="px-3 py-2 text-sm text-gray-700">
                        <div>{r.filer?.name || r.filerName || '—'}</div>
                        <div className="text-xs text-gray-400">{r.filer?.email || r.filerEmail || ''}</div>
                      </td>
                      <td className="px-3 py-2"><StatusBadge status={r.status} /></td>
                      <td className="px-3 py-2 text-xs text-gray-500">{formatDate(r.deductedAt)}</td>
                      <td className="px-3 py-2 text-xs text-gray-700">{ageLabel(r.deductedAt)}</td>
                      <td className="px-3 py-2 text-center"><CheckMark value={!!r.filerConfirmed} /></td>
                      <td className="px-3 py-2 text-center"><CheckMark value={!!r.recipientConfirmed} /></td>
                      <td className="px-3 py-2 text-right whitespace-nowrap">
                        <button
                          disabled={!canConfirmFiler}
                          onClick={() => setActiveAction({ kind: 'confirm_filer', recovery: r })}
                          className="text-xs text-indigo-600 hover:text-indigo-800 font-medium disabled:opacity-30 disabled:cursor-not-allowed"
                        >
                          Confirm Filer
                        </button>
                        <button
                          disabled={!canConfirmRecipient}
                          onClick={() => setActiveAction({ kind: 'confirm_recipient', recovery: r })}
                          className="ml-3 text-xs text-indigo-600 hover:text-indigo-800 font-medium disabled:opacity-30 disabled:cursor-not-allowed"
                        >
                          Confirm Recipient
                        </button>
                        <button
                          disabled={!canCancel}
                          onClick={() => setActiveAction({ kind: 'cancel', recovery: r })}
                          className="ml-3 text-xs text-red-600 hover:text-red-800 font-medium disabled:opacity-30 disabled:cursor-not-allowed"
                        >
                          Cancel
                        </button>
                        {isAdminManager && (
                          <button
                            disabled={!canRelease}
                            onClick={() => setActiveAction({ kind: 'release', recovery: r })}
                            className="ml-3 text-xs text-green-700 hover:text-green-900 font-medium disabled:opacity-30 disabled:cursor-not-allowed"
                          >
                            Release to Filer
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {activeAction?.kind === 'confirm_filer' && (
        <RecoveryNotesModal
          title="Confirm Filer"
          recovery={activeAction.recovery}
          cfName="adminConfirmFilerForRecovery"
          onClose={() => setActiveAction(null)}
          onDone={refresh}
        />
      )}
      {activeAction?.kind === 'confirm_recipient' && (
        <RecoveryNotesModal
          title="Confirm Recipient"
          recovery={activeAction.recovery}
          cfName="adminConfirmRecipientForRecovery"
          onClose={() => setActiveAction(null)}
          onDone={refresh}
        />
      )}
      {activeAction?.kind === 'cancel' && (
        <CancelRecoveryModal
          recovery={activeAction.recovery}
          onClose={() => setActiveAction(null)}
          onDone={refresh}
        />
      )}
      {activeAction?.kind === 'release' && (
        <RecoveryNotesModal
          title="Release to Filer"
          recovery={activeAction.recovery}
          cfName="adminReleaseRecovery"
          onClose={() => setActiveAction(null)}
          onDone={refresh}
        />
      )}
    </div>
  );
}

export default RecoveryWatchPage;
