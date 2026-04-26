import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { v4 as uuidv4 } from 'uuid';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';
import { exportToCSV } from '../utils/csvExport';

const currencySymbols = {
  NGN: '₦', GHS: 'GH₵', KES: 'KSh', ZAR: 'R', UGX: 'USh',
  RWF: 'FRw', TZS: 'TSh', EGP: 'E£', USD: '$', GBP: '£', EUR: '€',
};

const PROPOSAL_CURRENCIES = ['NGN', 'GHS', 'KES', 'ZAR', 'UGX', 'RWF', 'TZS', 'EGP', 'USD'];
const PROPOSAL_COUNTRIES = [
  { value: 'nigeria', label: 'Nigeria' },
  { value: 'ghana', label: 'Ghana' },
  { value: 'kenya', label: 'Kenya' },
  { value: 'south-africa', label: 'South Africa' },
];

const formatDate = (dateStr) => (dateStr ? new Date(dateStr).toLocaleString() : 'N/A');
const symbol = (currency) => currencySymbols[currency] || currency;

const STATUS_STYLES = {
  proposed: 'bg-blue-100 text-blue-700',
  approved: 'bg-indigo-100 text-indigo-700',
  pending_otp: 'bg-amber-100 text-amber-700',
  completed: 'bg-green-100 text-green-700',
  evidence_pending: 'bg-yellow-100 text-yellow-700',
  evidence_overdue: 'bg-red-100 text-red-700',
  rejected: 'bg-gray-200 text-gray-700',
  cancelled: 'bg-gray-200 text-gray-700',
  closed: 'bg-gray-100 text-gray-600',
  failed: 'bg-red-100 text-red-700',
};

const StatusBadge = ({ status }) => (
  <span
    className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
      STATUS_STYLES[status] || 'bg-gray-100 text-gray-700'
    }`}
  >
    {status || 'unknown'}
  </span>
);

const countdownLabel = (targetIso) => {
  if (!targetIso) return '—';
  const ms = new Date(targetIso).getTime() - Date.now();
  if (ms <= 0) return 'expired';
  const mins = Math.floor(ms / 60000);
  const hrs = Math.floor(mins / 60);
  const days = Math.floor(hrs / 24);
  if (days >= 1) return `${days}d ${hrs % 24}h`;
  if (hrs >= 1) return `${hrs}h ${mins % 60}m`;
  return `${mins}m`;
};

const ageInDays = (iso) => {
  if (!iso) return 0;
  return (Date.now() - new Date(iso).getTime()) / 86400000;
};

const ageInHours = (iso) => {
  if (!iso) return 0;
  return (Date.now() - new Date(iso).getTime()) / 3600000;
};

function PlatformWalletCard({ wallet, balances }) {
  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-bold text-gray-900">Platform Wallet</h3>
          <p className="text-xs text-gray-400 mt-1">
            Last update: {formatDate(wallet?.updatedAt || wallet?.lastTransactionAt)}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="rounded-lg border border-gray-100 bg-gray-50 p-4">
          <p className="text-gray-500 text-xs uppercase">Total Revenue (USD)</p>
          <p className="text-2xl font-bold text-green-600 mt-1">
            ${wallet?.totalBalanceUSD?.toFixed(2) || '0.00'}
          </p>
        </div>
        <div className="rounded-lg border border-gray-100 bg-gray-50 p-4">
          <p className="text-gray-500 text-xs uppercase">Total Transactions</p>
          <p className="text-2xl font-bold text-indigo-600 mt-1">
            {wallet?.totalTransactions || 0}
          </p>
        </div>
        <div className="rounded-lg border border-gray-100 bg-gray-50 p-4">
          <p className="text-gray-500 text-xs uppercase">Fees Collected</p>
          <p className="text-2xl font-bold text-purple-600 mt-1">
            {wallet?.totalFeesCollected || 0}
          </p>
        </div>
      </div>

      <div className="overflow-hidden rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Currency</th>
              <th className="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Balance</th>
              <th className="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">USD</th>
              <th className="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Transactions</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Last Activity</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {balances.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-gray-400 text-sm">
                  No balances yet
                </td>
              </tr>
            ) : (
              balances.map((b) => (
                <tr key={b.currency} className="hover:bg-gray-50">
                  <td className="px-4 py-2 text-sm font-medium text-gray-900">
                    {symbol(b.currency)} {b.currency}
                  </td>
                  <td className="px-4 py-2 text-right text-sm font-bold text-gray-900">
                    {symbol(b.currency)}{b.amount?.toFixed(2) || '0.00'}
                  </td>
                  <td className="px-4 py-2 text-right text-sm text-green-600">
                    ${b.usdEquivalent?.toFixed(2) || '0.00'}
                  </td>
                  <td className="px-4 py-2 text-right text-sm text-gray-500">{b.txCount || 0}</td>
                  <td className="px-4 py-2 text-sm text-gray-400">{formatDate(b.lastTransactionAt)}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function ProposeTransferForm({ onProposed }) {
  const [amount, setAmount] = useState('');
  const [currency, setCurrency] = useState('NGN');
  const [country, setCountry] = useState('nigeria');
  const [banks, setBanks] = useState([]);
  const [banksLoading, setBanksLoading] = useState(false);
  const [bankCode, setBankCode] = useState('');
  const [accountNumber, setAccountNumber] = useState('');
  const [accountName, setAccountName] = useState('');
  const [verifying, setVerifying] = useState(false);
  const [verified, setVerified] = useState(false);
  const [purpose, setPurpose] = useState('');
  const [notes, setNotes] = useState('');
  const [priorityFlag, setPriorityFlag] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    let cancelled = false;
    const loadBanks = async () => {
      setBanksLoading(true);
      setBanks([]);
      setBankCode('');
      setAccountNumber('');
      setAccountName('');
      setVerified(false);
      try {
        const result = await httpsCallable(functions, 'adminGetBanks')({ country });
        if (!cancelled) setBanks(result.data?.banks || []);
      } catch (err) {
        if (!cancelled) setError(err?.message || 'Failed to load banks.');
      } finally {
        if (!cancelled) setBanksLoading(false);
      }
    };
    loadBanks();
    return () => {
      cancelled = true;
    };
  }, [country]);

  const handleVerify = async () => {
    if (!bankCode || accountNumber.length < 10) return;
    setVerifying(true);
    setVerified(false);
    setAccountName('');
    setError('');
    try {
      const result = await httpsCallable(functions, 'adminVerifyBankAccount')({
        accountNumber,
        bankCode,
      });
      setAccountName(result.data?.accountName || '');
      setVerified(true);
    } catch (err) {
      setError(err?.message || 'Account verification failed.');
    } finally {
      setVerifying(false);
    }
  };

  const clearForm = () => {
    setAmount('');
    setBankCode('');
    setAccountNumber('');
    setAccountName('');
    setVerified(false);
    setPurpose('');
    setNotes('');
    setPriorityFlag(false);
  };

  const canSubmit =
    !submitting &&
    verified &&
    !!amount &&
    Number(amount) > 0 &&
    !!currency &&
    !!bankCode &&
    accountNumber.length >= 10 &&
    !!accountName &&
    purpose.trim().length >= 5;

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!canSubmit) return;
    setSubmitting(true);
    setError('');
    setSuccess('');
    try {
      await httpsCallable(functions, 'adminProposeTransfer')({
        amount: Number(amount),
        currency,
        bankCode,
        accountNumber,
        accountName,
        purpose: purpose.trim(),
        notes: notes.trim() || null,
        priorityFlag,
        idempotencyKey: uuidv4(),
      });
      setSuccess('Proposal submitted. Awaiting manager approval.');
      clearForm();
      if (onProposed) onProposed();
    } catch (err) {
      setError(err?.message || 'Failed to submit proposal.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <h3 className="text-lg font-bold text-gray-900 mb-1">Submit New Proposal</h3>
      <p className="text-sm text-gray-500 mb-4">
        Propose a platform transfer. Manager approval and OTP confirmation are required before
        funds move.
      </p>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}
      {success && (
        <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 rounded-lg text-sm">
          {success}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="text-sm text-gray-600 block mb-1">Amount</label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              required
              placeholder="0.00"
              className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>
          <div>
            <label className="text-sm text-gray-600 block mb-1">Currency</label>
            <select
              value={currency}
              onChange={(e) => setCurrency(e.target.value)}
              required
              className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            >
              {PROPOSAL_CURRENCIES.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="text-sm text-gray-600 block mb-1">Country</label>
            <select
              value={country}
              onChange={(e) => setCountry(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            >
              {PROPOSAL_COUNTRIES.map((c) => (
                <option key={c.value} value={c.value}>
                  {c.label}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-sm text-gray-600 block mb-1">Bank</label>
            <select
              value={bankCode}
              onChange={(e) => {
                setBankCode(e.target.value);
                setVerified(false);
                setAccountName('');
              }}
              required
              disabled={banksLoading || banks.length === 0}
              className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 disabled:bg-gray-50"
            >
              <option value="">
                {banksLoading ? 'Loading banks...' : banks.length === 0 ? 'No banks available' : 'Select bank'}
              </option>
              {banks.map((b) => (
                <option key={b.code} value={b.code}>
                  {b.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div>
          <label className="text-sm text-gray-600 block mb-1">Account Number</label>
          <div className="flex gap-2">
            <input
              type="text"
              inputMode="numeric"
              value={accountNumber}
              onChange={(e) => {
                setAccountNumber(e.target.value.replace(/\D/g, '').slice(0, 10));
                setVerified(false);
                setAccountName('');
              }}
              required
              placeholder="0123456789"
              className="flex-1 border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            />
            <button
              type="button"
              onClick={handleVerify}
              disabled={verifying || !bankCode || accountNumber.length < 10}
              className="px-4 py-2 bg-gray-700 hover:bg-gray-800 text-white rounded-lg text-sm transition-colors disabled:opacity-50"
            >
              {verifying ? 'Verifying...' : 'Verify Account'}
            </button>
          </div>
          {verified && accountName && (
            <p className="mt-2 text-sm text-green-600 font-medium">&#10003; {accountName}</p>
          )}
        </div>

        <div>
          <label className="text-sm text-gray-600 block mb-1">Account Name</label>
          <input
            type="text"
            value={accountName}
            readOnly
            placeholder="Verify the account to populate the name"
            className="w-full bg-gray-50 border border-gray-300 rounded-lg px-4 py-2 text-gray-700"
          />
        </div>

        <div>
          <div className="flex items-center justify-between mb-1">
            <label className="text-sm text-gray-600">Purpose</label>
            <span className={`text-xs ${purpose.trim().length >= 5 ? 'text-gray-400' : 'text-amber-600'}`}>
              {purpose.length} chars (min 5)
            </span>
          </div>
          <textarea
            value={purpose}
            onChange={(e) => setPurpose(e.target.value)}
            required
            rows={2}
            placeholder="Why this transfer is needed..."
            className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
        </div>

        <div>
          <label className="text-sm text-gray-600 block mb-1">Notes (optional)</label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={2}
            placeholder="Additional details..."
            className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
        </div>

        <label className="inline-flex items-center gap-2 text-sm text-gray-700">
          <input
            type="checkbox"
            checked={priorityFlag}
            onChange={(e) => setPriorityFlag(e.target.checked)}
            className="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
          />
          Priority — flag for expedited manager review
        </label>

        <button
          type="submit"
          disabled={!canSubmit}
          className="w-full bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-3 font-medium transition-colors disabled:opacity-50"
        >
          {submitting ? 'Submitting...' : 'Submit Proposal'}
        </button>

        {!verified && bankCode && accountNumber.length === 10 && (
          <p className="text-xs text-amber-600 text-center">
            Verify the bank account before submitting.
          </p>
        )}
      </form>
    </div>
  );
}

function ModalShell({ title, onClose, children, maxWidth = 'max-w-lg' }) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className={`bg-white rounded-xl shadow-2xl w-full ${maxWidth} max-h-[90vh] overflow-y-auto`}>
        <div className="flex items-center justify-between border-b border-gray-200 p-4">
          <h3 className="text-lg font-bold text-gray-900">{title}</h3>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 text-xl leading-none"
            aria-label="Close"
          >
            &times;
          </button>
        </div>
        <div className="p-4">{children}</div>
      </div>
    </div>
  );
}

function EditProposalModal({ proposal, onClose, onSaved }) {
  const [amount, setAmount] = useState(proposal.amount?.toString() || '');
  const [purpose, setPurpose] = useState(proposal.purpose || '');
  const [notes, setNotes] = useState(proposal.notes || '');
  const [priorityFlag, setPriorityFlag] = useState(!!proposal.priorityFlag);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleSave = async () => {
    if (purpose.trim().length < 5) {
      setError('Purpose must be at least 5 characters.');
      return;
    }
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminEditProposal')({
        proposalId: proposal.proposalId || proposal.id,
        fields: {
          amount: Number(amount),
          purpose: purpose.trim(),
          notes: notes.trim() || null,
          priorityFlag,
        },
        idempotencyKey: uuidv4(),
      });
      if (onSaved) onSaved();
      onClose();
    } catch (err) {
      setError(err?.message || 'Edit failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title="Edit Proposal" onClose={onClose}>
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}
      <div className="space-y-3">
        <div>
          <label className="text-sm text-gray-600 block mb-1">Amount ({proposal.currency})</label>
          <input
            type="number"
            step="0.01"
            min="0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="text-sm text-gray-600 block mb-1">Purpose</label>
          <textarea
            value={purpose}
            onChange={(e) => setPurpose(e.target.value)}
            rows={2}
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="text-sm text-gray-600 block mb-1">Notes</label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={2}
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
          />
        </div>
        <label className="inline-flex items-center gap-2 text-sm text-gray-700">
          <input
            type="checkbox"
            checked={priorityFlag}
            onChange={(e) => setPriorityFlag(e.target.checked)}
            className="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
          />
          Priority flag
        </label>
      </div>
      <div className="flex gap-2 mt-5">
        <button
          onClick={handleSave}
          disabled={submitting}
          className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm transition-colors disabled:opacity-50"
        >
          {submitting ? 'Saving...' : 'Save Changes'}
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

function CloseProposalModal({ proposal, onClose, onClosed }) {
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleClose = async () => {
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminCloseProposal')({
        proposalId: proposal.proposalId || proposal.id,
        idempotencyKey: uuidv4(),
      });
      if (onClosed) onClosed();
      onClose();
    } catch (err) {
      setError(err?.message || 'Close failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title="Close Proposal" onClose={onClose}>
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}
      <div className="space-y-3 text-sm text-gray-700">
        <p>
          Closing will mark the proposal as fully resolved with evidence on file.
        </p>
        <div className="rounded-lg bg-amber-50 border border-amber-200 p-3 text-amber-800 text-xs">
          Receipt + evidence files must be uploaded via the document upload widget
          (coming in commit 5). For now, this button assumes documents are already
          uploaded — the server will reject the close if required documents are missing.
        </div>
      </div>
      <div className="flex gap-2 mt-5">
        <button
          onClick={handleClose}
          disabled={submitting}
          className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm transition-colors disabled:opacity-50"
        >
          {submitting ? 'Closing...' : 'Confirm Close'}
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

function MyProposalsList({ proposals, currentUid, onChanged }) {
  const [editTarget, setEditTarget] = useState(null);
  const [closeTarget, setCloseTarget] = useState(null);
  const [busyId, setBusyId] = useState(null);
  const [error, setError] = useState('');

  const mine = proposals.filter(
    (p) => (p.proposedBy?.uid || p.proposedByUid) === currentUid
  );

  const handleCancel = async (p) => {
    if (!window.confirm(`Cancel proposal ${p.proposalId || p.id}? This cannot be undone.`)) return;
    setBusyId(p.proposalId || p.id);
    setError('');
    try {
      await httpsCallable(functions, 'adminCancelProposal')({
        proposalId: p.proposalId || p.id,
        idempotencyKey: uuidv4(),
      });
      if (onChanged) onChanged();
    } catch (err) {
      setError(err?.message || 'Cancel failed.');
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <h3 className="text-lg font-bold text-gray-900 mb-1">My Pending Proposals</h3>
      <p className="text-sm text-gray-500 mb-4">
        Proposals you have submitted, in any status.
      </p>

      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Currency</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Purpose</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proposed</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Expires</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {mine.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-3 py-8 text-center text-gray-400 text-sm">
                  No proposals yet
                </td>
              </tr>
            ) : (
              mine.map((p) => {
                const id = p.proposalId || p.id;
                const isProposed = p.status === 'proposed';
                const canClose = ['completed', 'evidence_pending', 'evidence_overdue'].includes(p.status);
                return (
                  <tr key={id} className="hover:bg-gray-50">
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {symbol(p.currency)}{p.amount?.toFixed(2) || '0.00'}
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">{p.currency}</td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{p.accountName || p.recipient?.accountName || '—'}</div>
                      <div className="text-xs text-gray-400">{p.accountNumber || p.recipient?.accountNumber || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700 max-w-xs truncate" title={p.purpose}>
                      {p.purpose}
                    </td>
                    <td className="px-3 py-2"><StatusBadge status={p.status} /></td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(p.proposedAt || p.createdAt)}</td>
                    <td className="px-3 py-2 text-xs text-gray-500">{countdownLabel(p.expiresAt)}</td>
                    <td className="px-3 py-2 text-right">
                      <div className="flex justify-end gap-2">
                        {isProposed && (
                          <button
                            onClick={() => setEditTarget(p)}
                            disabled={busyId === id}
                            className="text-xs text-indigo-600 hover:text-indigo-800 font-medium disabled:opacity-50"
                          >
                            Edit
                          </button>
                        )}
                        {isProposed && (
                          <button
                            onClick={() => handleCancel(p)}
                            disabled={busyId === id}
                            className="text-xs text-red-600 hover:text-red-800 font-medium disabled:opacity-50"
                          >
                            Cancel
                          </button>
                        )}
                        {canClose && (
                          <button
                            onClick={() => setCloseTarget(p)}
                            disabled={busyId === id}
                            className="text-xs text-green-600 hover:text-green-800 font-medium disabled:opacity-50"
                          >
                            Close
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {editTarget && (
        <EditProposalModal
          proposal={editTarget}
          onClose={() => setEditTarget(null)}
          onSaved={onChanged}
        />
      )}
      {closeTarget && (
        <CloseProposalModal
          proposal={closeTarget}
          onClose={() => setCloseTarget(null)}
          onClosed={onChanged}
        />
      )}
    </div>
  );
}

function RejectModal({ proposal, onClose, onRejected }) {
  const [reason, setReason] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleReject = async () => {
    if (reason.trim().length < 5) {
      setError('Rejection reason must be at least 5 characters.');
      return;
    }
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminRejectTransfer')({
        proposalId: proposal.proposalId || proposal.id,
        reason: reason.trim(),
        idempotencyKey: uuidv4(),
      });
      if (onRejected) onRejected();
      onClose();
    } catch (err) {
      setError(err?.message || 'Reject failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title="Reject Proposal" onClose={onClose}>
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}
      <div>
        <div className="flex items-center justify-between mb-1">
          <label className="text-sm text-gray-600">Reason</label>
          <span className={`text-xs ${reason.trim().length >= 5 ? 'text-gray-400' : 'text-amber-600'}`}>
            {reason.length} chars (min 5)
          </span>
        </div>
        <textarea
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          rows={3}
          placeholder="Why is this being rejected?"
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
        />
      </div>
      <div className="flex gap-2 mt-5">
        <button
          onClick={handleReject}
          disabled={submitting || reason.trim().length < 5}
          className="flex-1 bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm transition-colors disabled:opacity-50"
        >
          {submitting ? 'Rejecting...' : 'Reject'}
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

function ApprovalModal({ proposal, onClose, onApproved, onRejected }) {
  const [checks, setChecks] = useState({
    amount_verified: false,
    recipient_verified: false,
    purpose_approved: false,
    funds_available: false,
  });
  const [approvalNote, setApprovalNote] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [showReject, setShowReject] = useState(false);

  const allChecked = Object.values(checks).every(Boolean);

  const handleApprove = async () => {
    if (!allChecked) return;
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminApproveTransfer')({
        proposalId: proposal.proposalId || proposal.id,
        idempotencyKey: uuidv4(),
        approvalNote: approvalNote.trim() || null,
        checklistConfirmations: [
          { item: 'amount_verified', confirmed: true },
          { item: 'recipient_verified', confirmed: true },
          { item: 'purpose_approved', confirmed: true },
          { item: 'funds_available', confirmed: true },
        ],
      });
      if (onApproved) onApproved();
      onClose();
    } catch (err) {
      setError(err?.message || 'Approval failed.');
    } finally {
      setSubmitting(false);
    }
  };

  const toggle = (key) => setChecks((c) => ({ ...c, [key]: !c[key] }));

  return (
    <>
      <ModalShell title="Review Proposal" onClose={onClose} maxWidth="max-w-2xl">
        {error && (
          <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
            {error}
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-4 text-sm">
          <div>
            <p className="text-gray-500 text-xs uppercase">Proposer</p>
            <p className="font-medium text-gray-900">{proposal.proposedBy?.name || proposal.proposedByName || '—'}</p>
            <p className="text-xs text-gray-500">{proposal.proposedBy?.email || proposal.proposedByEmail || ''}</p>
          </div>
          <div>
            <p className="text-gray-500 text-xs uppercase">Amount</p>
            <p className="font-medium text-gray-900">
              {symbol(proposal.currency)}{proposal.amount?.toFixed(2)} {proposal.currency}
            </p>
            {proposal.usdEquivalent != null && (
              <p className="text-xs text-gray-500">≈ ${proposal.usdEquivalent.toFixed(2)} USD</p>
            )}
          </div>
          <div>
            <p className="text-gray-500 text-xs uppercase">Recipient</p>
            <p className="font-medium text-gray-900">{proposal.accountName || proposal.recipient?.accountName || '—'}</p>
            <p className="text-xs text-gray-500">
              {proposal.bankName || proposal.recipient?.bankName || proposal.bankCode}
              {' · '}
              {proposal.accountNumber || proposal.recipient?.accountNumber || ''}
            </p>
          </div>
          <div>
            <p className="text-gray-500 text-xs uppercase">Priority</p>
            <p className="font-medium text-gray-900">{proposal.priorityFlag ? 'Yes' : 'Standard'}</p>
          </div>
          <div className="md:col-span-2">
            <p className="text-gray-500 text-xs uppercase">Purpose</p>
            <p className="text-gray-900">{proposal.purpose}</p>
          </div>
          {proposal.notes && (
            <div className="md:col-span-2">
              <p className="text-gray-500 text-xs uppercase">Notes</p>
              <p className="text-gray-700 text-sm">{proposal.notes}</p>
            </div>
          )}
        </div>

        <div className="rounded-lg border border-gray-200 p-3 mb-4 text-xs text-gray-500">
          Documents (invoice + quotes) — full review widget lands in commit 5.
        </div>

        <div className="space-y-2 mb-4">
          <p className="text-sm font-medium text-gray-700">Approval checklist (all required)</p>
          {[
            ['amount_verified', 'Amount verified'],
            ['recipient_verified', 'Recipient verified'],
            ['purpose_approved', 'Purpose approved'],
            ['funds_available', 'Funds available'],
          ].map(([key, label]) => (
            <label key={key} className="flex items-center gap-2 text-sm text-gray-700">
              <input
                type="checkbox"
                checked={checks[key]}
                onChange={() => toggle(key)}
                className="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
              />
              {label}
            </label>
          ))}
        </div>

        <div className="mb-4">
          <label className="text-sm text-gray-600 block mb-1">Approval Note (optional)</label>
          <textarea
            value={approvalNote}
            onChange={(e) => setApprovalNote(e.target.value)}
            rows={2}
            className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm"
          />
        </div>

        <div className="flex gap-2">
          <button
            onClick={handleApprove}
            disabled={!allChecked || submitting}
            className="flex-1 bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors disabled:opacity-50"
          >
            {submitting ? 'Approving...' : 'Approve'}
          </button>
          <button
            onClick={() => setShowReject(true)}
            disabled={submitting}
            className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg text-sm font-medium transition-colors disabled:opacity-50"
          >
            Reject
          </button>
          <button
            onClick={onClose}
            disabled={submitting}
            className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
          >
            Close
          </button>
        </div>
      </ModalShell>

      {showReject && (
        <RejectModal
          proposal={proposal}
          onClose={() => setShowReject(false)}
          onRejected={() => {
            if (onRejected) onRejected();
            onClose();
          }}
        />
      )}
    </>
  );
}

function PendingApprovalsList({ proposals, onChanged }) {
  const [reviewTarget, setReviewTarget] = useState(null);

  const pending = proposals
    .filter((p) => p.status === 'proposed')
    .sort((a, b) => {
      const pa = a.priorityFlag ? 1 : 0;
      const pb = b.priorityFlag ? 1 : 0;
      if (pa !== pb) return pb - pa;
      const ta = new Date(a.proposedAt || a.createdAt || 0).getTime();
      const tb = new Date(b.proposedAt || b.createdAt || 0).getTime();
      return ta - tb;
    });

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <h3 className="text-lg font-bold text-gray-900 mb-1">Pending Approvals</h3>
      <p className="text-sm text-gray-500 mb-4">
        Proposals awaiting manager review. Priority items shown first.
      </p>

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Priority</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proposer</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Purpose</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proposed</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {pending.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-3 py-8 text-center text-gray-400 text-sm">
                  No proposals awaiting approval
                </td>
              </tr>
            ) : (
              pending.map((p) => {
                const id = p.proposalId || p.id;
                return (
                  <tr
                    key={id}
                    onClick={() => setReviewTarget(p)}
                    className="hover:bg-indigo-50 cursor-pointer"
                  >
                    <td className="px-3 py-2 text-sm">
                      {p.priorityFlag ? (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
                          Priority
                        </span>
                      ) : (
                        <span className="text-gray-400 text-xs">Standard</span>
                      )}
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      {p.proposedBy?.name || p.proposedByName || '—'}
                    </td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {symbol(p.currency)}{p.amount?.toFixed(2)}
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      {p.accountName || p.recipient?.accountName || '—'}
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700 max-w-xs truncate" title={p.purpose}>
                      {p.purpose}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(p.proposedAt || p.createdAt)}</td>
                    <td className="px-3 py-2 text-right">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setReviewTarget(p);
                        }}
                        className="text-xs text-indigo-600 hover:text-indigo-800 font-medium"
                      >
                        Review
                      </button>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {reviewTarget && (
        <ApprovalModal
          proposal={reviewTarget}
          onClose={() => setReviewTarget(null)}
          onApproved={onChanged}
          onRejected={onChanged}
        />
      )}
    </div>
  );
}

function OtpModal({ proposal, onClose, onFinalized }) {
  const [otp, setOtp] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async () => {
    if (otp.length !== 6) return;
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminFinalizeTransfer')({
        action: 'finalize',
        reference: proposal.proposalId || proposal.id,
        transferCode: proposal.transferCode,
        otp,
        idempotencyKey: uuidv4(),
      });
      if (onFinalized) onFinalized();
      onClose();
    } catch (err) {
      setError(err?.message || 'OTP submission failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title="Confirm Transfer with OTP" onClose={onClose}>
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}
      <div className="bg-gray-50 rounded-lg p-3 mb-4 text-sm space-y-1">
        <div className="flex justify-between">
          <span className="text-gray-500">Recipient</span>
          <span className="font-medium">{proposal.accountName || proposal.recipient?.accountName || '—'}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-500">Amount</span>
          <span className="font-medium">
            {symbol(proposal.currency)}{proposal.amount?.toFixed(2)} {proposal.currency}
          </span>
        </div>
        <div className="flex justify-between text-xs text-gray-400">
          <span>Reference</span>
          <span className="font-mono">{proposal.proposalId || proposal.id}</span>
        </div>
      </div>

      <label className="block text-sm font-medium text-gray-700 mb-2">
        Enter 6-digit OTP from Paystack
      </label>
      <input
        type="text"
        value={otp}
        onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
        placeholder="000000"
        maxLength={6}
        autoFocus
        className="w-full text-center text-2xl tracking-[0.5em] font-mono border border-gray-300 rounded-lg px-4 py-3 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
      />

      <div className="flex gap-2 mt-5">
        <button
          onClick={handleSubmit}
          disabled={otp.length !== 6 || submitting}
          className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors disabled:opacity-50"
        >
          {submitting ? 'Confirming...' : 'Confirm Transfer'}
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

function AwaitingOtpList({ proposals, onChanged }) {
  const [otpTarget, setOtpTarget] = useState(null);

  const pending = proposals.filter((p) => p.status === 'pending_otp');

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <h3 className="text-lg font-bold text-gray-900 mb-1">Awaiting OTP</h3>
      <p className="text-sm text-gray-500 mb-4">
        Approved proposals waiting for OTP confirmation to release funds.
      </p>

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proposal</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Approved</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">OTP Expires</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {pending.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-3 py-8 text-center text-gray-400 text-sm">
                  No transfers awaiting OTP
                </td>
              </tr>
            ) : (
              pending.map((p) => {
                const id = p.proposalId || p.id;
                return (
                  <tr key={id} className="hover:bg-gray-50">
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {symbol(p.currency)}{p.amount?.toFixed(2)}
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      {p.accountName || p.recipient?.accountName || '—'}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(p.approvedAt)}</td>
                    <td className="px-3 py-2 text-xs text-amber-700">
                      {countdownLabel(p.otpExpiresAt)}
                    </td>
                    <td className="px-3 py-2 text-right">
                      <button
                        onClick={() => setOtpTarget(p)}
                        className="text-xs bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg font-medium"
                      >
                        Enter OTP
                      </button>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {otpTarget && (
        <OtpModal
          proposal={otpTarget}
          onClose={() => setOtpTarget(null)}
          onFinalized={onChanged}
        />
      )}
    </div>
  );
}

function EmergencyTransferForm({ onSubmitted }) {
  const [amount, setAmount] = useState('');
  const [currency, setCurrency] = useState('NGN');
  const [country, setCountry] = useState('nigeria');
  const [banks, setBanks] = useState([]);
  const [banksLoading, setBanksLoading] = useState(false);
  const [bankCode, setBankCode] = useState('');
  const [accountNumber, setAccountNumber] = useState('');
  const [accountName, setAccountName] = useState('');
  const [verifying, setVerifying] = useState(false);
  const [verified, setVerified] = useState(false);
  const [purpose, setPurpose] = useState('');
  const [notes, setNotes] = useState('');
  const [reason, setReason] = useState('');
  const [confirmedBypass, setConfirmedBypass] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    let cancelled = false;
    const loadBanks = async () => {
      setBanksLoading(true);
      setBanks([]);
      setBankCode('');
      setAccountNumber('');
      setAccountName('');
      setVerified(false);
      try {
        const result = await httpsCallable(functions, 'adminGetBanks')({ country });
        if (!cancelled) setBanks(result.data?.banks || []);
      } catch (err) {
        if (!cancelled) setError(err?.message || 'Failed to load banks.');
      } finally {
        if (!cancelled) setBanksLoading(false);
      }
    };
    loadBanks();
    return () => {
      cancelled = true;
    };
  }, [country]);

  const handleVerify = async () => {
    if (!bankCode || accountNumber.length < 10) return;
    setVerifying(true);
    setVerified(false);
    setAccountName('');
    setError('');
    try {
      const result = await httpsCallable(functions, 'adminVerifyBankAccount')({
        accountNumber,
        bankCode,
      });
      setAccountName(result.data?.accountName || '');
      setVerified(true);
    } catch (err) {
      setError(err?.message || 'Account verification failed.');
    } finally {
      setVerifying(false);
    }
  };

  const clearForm = () => {
    setAmount('');
    setBankCode('');
    setAccountNumber('');
    setAccountName('');
    setVerified(false);
    setPurpose('');
    setNotes('');
    setReason('');
    setConfirmedBypass(false);
  };

  const baseValid =
    verified &&
    !!amount &&
    Number(amount) > 0 &&
    !!currency &&
    !!bankCode &&
    accountNumber.length >= 10 &&
    !!accountName &&
    purpose.trim().length >= 5 &&
    reason.trim().length >= 50 &&
    confirmedBypass;

  const handleConfirmedSubmit = async () => {
    if (!baseValid) return;
    setSubmitting(true);
    setError('');
    setSuccess('');
    try {
      await httpsCallable(functions, 'adminEmergencyTransfer')({
        amount: Number(amount),
        currency,
        bankCode,
        accountNumber,
        accountName,
        purpose: purpose.trim(),
        reason: reason.trim(),
        notes: notes.trim() || null,
        idempotencyKey: uuidv4(),
      });
      setSuccess('Emergency transfer initiated. Audit log entry created.');
      clearForm();
      setShowConfirm(false);
      if (onSubmitted) onSubmitted();
    } catch (err) {
      setError(err?.message || 'Emergency transfer failed.');
      setShowConfirm(false);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="bg-red-50 rounded-xl shadow-sm border-2 border-red-300 p-6">
      <div className="flex items-start gap-3 mb-4">
        <div className="flex-1">
          <h3 className="text-lg font-bold text-red-800">Emergency Transfer</h3>
          <p className="text-sm text-red-700 mt-1">
            Bypasses standard manager approval. Use only when absolutely necessary —
            every emergency transfer is audited and reviewed.
          </p>
        </div>
      </div>

      {error && (
        <div className="mb-4 p-3 bg-white border border-red-300 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}
      {success && (
        <div className="mb-4 p-3 bg-white border border-green-300 text-green-700 rounded-lg text-sm">
          {success}
        </div>
      )}

      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (baseValid) setShowConfirm(true);
        }}
        className="space-y-4"
      >
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="text-sm text-red-800 block mb-1">Amount</label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              required
              className="w-full border border-red-300 rounded-lg px-4 py-2 bg-white"
            />
          </div>
          <div>
            <label className="text-sm text-red-800 block mb-1">Currency</label>
            <select
              value={currency}
              onChange={(e) => setCurrency(e.target.value)}
              className="w-full border border-red-300 rounded-lg px-4 py-2 bg-white"
            >
              {PROPOSAL_CURRENCIES.map((c) => (
                <option key={c} value={c}>{c}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="text-sm text-red-800 block mb-1">Country</label>
            <select
              value={country}
              onChange={(e) => setCountry(e.target.value)}
              className="w-full border border-red-300 rounded-lg px-4 py-2 bg-white"
            >
              {PROPOSAL_COUNTRIES.map((c) => (
                <option key={c.value} value={c.value}>{c.label}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-sm text-red-800 block mb-1">Bank</label>
            <select
              value={bankCode}
              onChange={(e) => {
                setBankCode(e.target.value);
                setVerified(false);
                setAccountName('');
              }}
              required
              disabled={banksLoading || banks.length === 0}
              className="w-full border border-red-300 rounded-lg px-4 py-2 bg-white disabled:bg-gray-50"
            >
              <option value="">
                {banksLoading ? 'Loading...' : banks.length === 0 ? 'No banks available' : 'Select bank'}
              </option>
              {banks.map((b) => (
                <option key={b.code} value={b.code}>{b.name}</option>
              ))}
            </select>
          </div>
        </div>

        <div>
          <label className="text-sm text-red-800 block mb-1">Account Number</label>
          <div className="flex gap-2">
            <input
              type="text"
              inputMode="numeric"
              value={accountNumber}
              onChange={(e) => {
                setAccountNumber(e.target.value.replace(/\D/g, '').slice(0, 10));
                setVerified(false);
                setAccountName('');
              }}
              required
              placeholder="0123456789"
              className="flex-1 border border-red-300 rounded-lg px-4 py-2 bg-white"
            />
            <button
              type="button"
              onClick={handleVerify}
              disabled={verifying || !bankCode || accountNumber.length < 10}
              className="px-4 py-2 bg-gray-700 hover:bg-gray-800 text-white rounded-lg text-sm disabled:opacity-50"
            >
              {verifying ? 'Verifying...' : 'Verify Account'}
            </button>
          </div>
          {verified && accountName && (
            <p className="mt-2 text-sm text-green-700 font-medium">&#10003; {accountName}</p>
          )}
        </div>

        <div>
          <label className="text-sm text-red-800 block mb-1">Account Name</label>
          <input
            type="text"
            value={accountName}
            readOnly
            className="w-full bg-white border border-red-300 rounded-lg px-4 py-2 text-gray-700"
          />
        </div>

        <div>
          <label className="text-sm text-red-800 block mb-1">Purpose</label>
          <textarea
            value={purpose}
            onChange={(e) => setPurpose(e.target.value)}
            rows={2}
            required
            className="w-full border border-red-300 rounded-lg px-4 py-2 bg-white"
          />
        </div>

        <div>
          <div className="flex items-center justify-between mb-1">
            <label className="text-sm text-red-800">Reason for bypassing approval</label>
            <span className={`text-xs ${reason.trim().length >= 50 ? 'text-gray-500' : 'text-red-700 font-medium'}`}>
              {reason.length} / 50 minimum
            </span>
          </div>
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            rows={3}
            required
            placeholder="Explain why this cannot wait for the standard approval flow..."
            className="w-full border border-red-300 rounded-lg px-4 py-2 bg-white"
          />
        </div>

        <div>
          <label className="text-sm text-red-800 block mb-1">Notes (optional)</label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={2}
            className="w-full border border-red-300 rounded-lg px-4 py-2 bg-white"
          />
        </div>

        <label className="flex items-start gap-2 text-sm text-red-800 bg-white border border-red-300 rounded-lg p-3">
          <input
            type="checkbox"
            checked={confirmedBypass}
            onChange={(e) => setConfirmedBypass(e.target.checked)}
            className="mt-0.5 h-4 w-4 rounded border-red-300 text-red-600 focus:ring-red-500"
          />
          <span>I understand this bypasses the standard approval flow.</span>
        </label>

        <button
          type="submit"
          disabled={!baseValid || submitting}
          className="w-full bg-red-600 hover:bg-red-700 text-white rounded-lg py-3 font-medium transition-colors disabled:opacity-50"
        >
          {submitting ? 'Processing...' : 'Initiate Emergency Transfer'}
        </button>
      </form>

      {showConfirm && (
        <ModalShell title="Confirm Emergency Transfer" onClose={() => setShowConfirm(false)}>
          <div className="rounded-lg bg-red-50 border border-red-300 p-3 mb-4 text-sm text-red-800">
            This bypasses dual-signature approval. The transfer is logged and reviewed.
          </div>
          <div className="bg-gray-50 rounded-lg p-3 mb-4 text-sm space-y-1">
            <div className="flex justify-between">
              <span className="text-gray-500">Recipient</span>
              <span className="font-medium">{accountName}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">Amount</span>
              <span className="font-medium">{symbol(currency)}{Number(amount).toFixed(2)} {currency}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">Purpose</span>
              <span className="font-medium">{purpose}</span>
            </div>
          </div>
          <div className="flex gap-2">
            <button
              onClick={handleConfirmedSubmit}
              disabled={submitting}
              className="flex-1 bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium disabled:opacity-50"
            >
              {submitting ? 'Submitting...' : 'Confirm & Send'}
            </button>
            <button
              onClick={() => setShowConfirm(false)}
              disabled={submitting}
              className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
            >
              Cancel
            </button>
          </div>
        </ModalShell>
      )}
    </div>
  );
}

const HISTORY_STATUSES = [
  'all',
  'proposed',
  'approved',
  'pending_otp',
  'completed',
  'evidence_pending',
  'evidence_overdue',
  'rejected',
  'cancelled',
  'closed',
  'failed',
];

function TransfersHistory({ proposals, currentUid, lockMine }) {
  const [statusFilter, setStatusFilter] = useState('all');
  const [showOnlyMine, setShowOnlyMine] = useState(!!lockMine);

  useEffect(() => {
    if (lockMine) setShowOnlyMine(true);
  }, [lockMine]);

  const filtered = proposals.filter((p) => {
    if (statusFilter !== 'all' && p.status !== statusFilter) return false;
    if (showOnlyMine && (p.proposedBy?.uid || p.proposedByUid) !== currentUid) return false;
    return true;
  });

  const handleExport = () => {
    const rows = filtered.map((p) => ({
      proposalId: p.proposalId || p.id,
      proposer: p.proposedBy?.name || p.proposedByName || '',
      proposerEmail: p.proposedBy?.email || p.proposedByEmail || '',
      amount: p.amount,
      currency: p.currency,
      usdEquivalent: p.usdEquivalent,
      bank: p.bankName || p.recipient?.bankName || p.bankCode || '',
      accountNumber: p.accountNumber || p.recipient?.accountNumber || '',
      accountName: p.accountName || p.recipient?.accountName || '',
      purpose: p.purpose,
      status: p.status,
      proposedAt: p.proposedAt || p.createdAt,
      approvedAt: p.approvedAt,
      completedAt: p.completedAt,
    }));
    exportToCSV(rows, 'transfer_proposals', [
      { key: 'proposalId', label: 'Proposal ID' },
      { key: 'proposer', label: 'Proposer' },
      { key: 'proposerEmail', label: 'Proposer Email' },
      { key: 'amount', label: 'Amount' },
      { key: 'currency', label: 'Currency' },
      { key: 'usdEquivalent', label: 'USD' },
      { key: 'bank', label: 'Bank' },
      { key: 'accountNumber', label: 'Account #' },
      { key: 'accountName', label: 'Account Name' },
      { key: 'purpose', label: 'Purpose' },
      { key: 'status', label: 'Status' },
      { key: 'proposedAt', label: 'Proposed At' },
      { key: 'approvedAt', label: 'Approved At' },
      { key: 'completedAt', label: 'Completed At' },
    ]);
  };

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-bold text-gray-900">All Transfers</h3>
          <p className="text-sm text-gray-500 mt-1">Full proposal history.</p>
        </div>
        <button
          onClick={handleExport}
          className="bg-green-600 hover:bg-green-700 text-white px-3 py-1.5 rounded-lg text-sm font-medium"
        >
          Export CSV
        </button>
      </div>

      <div className="flex flex-wrap items-center gap-3 mb-4">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="border border-gray-300 rounded-lg px-3 py-1.5 text-sm"
        >
          {HISTORY_STATUSES.map((s) => (
            <option key={s} value={s}>
              {s === 'all' ? 'All statuses' : s}
            </option>
          ))}
        </select>
        <label className="inline-flex items-center gap-2 text-sm text-gray-700">
          <input
            type="checkbox"
            checked={showOnlyMine}
            onChange={(e) => setShowOnlyMine(e.target.checked)}
            disabled={lockMine}
            className="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
          />
          Show only mine{lockMine ? ' (required for finance)' : ''}
        </label>
      </div>

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proposer</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Currency</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Purpose</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proposed</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Expires</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-3 py-8 text-center text-gray-400 text-sm">
                  No proposals match the current filters
                </td>
              </tr>
            ) : (
              filtered.map((p) => {
                const id = p.proposalId || p.id;
                return (
                  <tr key={id} className="hover:bg-gray-50">
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{p.proposedBy?.name || p.proposedByName || '—'}</div>
                      <div className="text-xs text-gray-400">{p.proposedBy?.email || p.proposedByEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {symbol(p.currency)}{p.amount?.toFixed(2)}
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">{p.currency}</td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      {p.accountName || p.recipient?.accountName || '—'}
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700 max-w-xs truncate" title={p.purpose}>
                      {p.purpose}
                    </td>
                    <td className="px-3 py-2"><StatusBadge status={p.status} /></td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(p.proposedAt || p.createdAt)}</td>
                    <td className="px-3 py-2 text-xs text-gray-500">{countdownLabel(p.expiresAt)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function StuckCasesList({ proposals }) {
  const stuck = proposals.filter((p) => {
    if (p.status === 'evidence_overdue' && ageInDays(p.completedAt) > 21) return true;
    if (p.status === 'pending_otp' && ageInHours(p.approvedAt) > 1) return true;
    return false;
  });

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <h3 className="text-lg font-bold text-gray-900 mb-1">Stuck Cases</h3>
      <p className="text-sm text-gray-500 mb-4">
        These cases need manual review.
      </p>

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proposal ID</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Age</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Last Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {stuck.length === 0 ? (
              <tr>
                <td colSpan={4} className="px-3 py-8 text-center text-gray-400 text-sm">
                  No stuck cases
                </td>
              </tr>
            ) : (
              stuck.map((p) => {
                const id = p.proposalId || p.id;
                const lastIso =
                  p.status === 'pending_otp' ? p.approvedAt : p.completedAt;
                const ageDays = ageInDays(lastIso);
                const ageHours = ageInHours(lastIso);
                const ageLabel =
                  ageDays >= 1 ? `${Math.floor(ageDays)}d` : `${Math.floor(ageHours)}h`;
                return (
                  <tr key={id} className="hover:bg-gray-50">
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2"><StatusBadge status={p.status} /></td>
                    <td className="px-3 py-2 text-sm text-red-700 font-medium">{ageLabel}</td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(lastIso)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function RevenuePage() {
  const {
    user,
    role,
    isFinance,
    isAdminManager,
    isSuperAdmin,
    isAuditor,
  } = useAuth();

  const [platformWallet, setPlatformWallet] = useState(null);
  const [platformBalances, setPlatformBalances] = useState([]);
  const [proposals, setProposals] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [refreshKey, setRefreshKey] = useState(0);

  const loadPlatformWallet = async () => {
    const result = await httpsCallable(functions, 'adminGetPlatformWallet')();
    setPlatformWallet(result.data?.wallet || null);
    setPlatformBalances(result.data?.balances || []);
  };

  const loadProposals = async () => {
    const result = await httpsCallable(functions, 'adminListTransferProposals')({ limit: 50 });
    setProposals(result.data?.proposals || []);
  };

  const loadAll = async () => {
    setLoading(true);
    setError('');
    try {
      await Promise.all([loadPlatformWallet(), loadProposals()]);
    } catch (err) {
      setError(err?.message || 'Failed to load revenue data.');
    } finally {
      setLoading(false);
    }
  };

  const refresh = () => setRefreshKey((k) => k + 1);

  useEffect(() => {
    loadAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [refreshKey]);

  void role;

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Revenue</h2>
          <p className="text-gray-500 text-sm mt-1">
            Platform wallet, proposals, approvals, and transfers.
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

      {/* Section 1: Platform Wallet Overview */}
      <PlatformWalletCard wallet={platformWallet} balances={platformBalances} />

      {/* Section 2: Submit New Proposal — finance only */}
      {isFinance && <ProposeTransferForm onProposed={refresh} />}

      {/* Section 3: My Pending Proposals — finance only */}
      {isFinance && (
        <MyProposalsList proposals={proposals} currentUid={user?.uid} onChanged={refresh} />
      )}

      {/* Section 4: Pending Approvals — admin_manager only */}
      {isAdminManager && <PendingApprovalsList proposals={proposals} onChanged={refresh} />}

      {/* Section 5: Awaiting OTP — super_admin only */}
      {isSuperAdmin && <AwaitingOtpList proposals={proposals} onChanged={refresh} />}

      {/* Section 6: Emergency Transfer — super_admin only */}
      {isSuperAdmin && <EmergencyTransferForm onSubmitted={refresh} />}

      {/* Section 7: All Transfers History — auditor+ */}
      {isAuditor && (
        <TransfersHistory
          proposals={proposals}
          currentUid={user?.uid}
          lockMine={isFinance && !isAdminManager}
        />
      )}

      {/* Section 8: Stuck Cases — super_admin only */}
      {isSuperAdmin && <StuckCasesList proposals={proposals} />}
    </div>
  );
}

export default RevenuePage;
