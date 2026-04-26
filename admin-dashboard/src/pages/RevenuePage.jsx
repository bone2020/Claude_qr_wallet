import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { v4 as uuidv4 } from 'uuid';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';

const placeholderCard = 'bg-white rounded-xl shadow-sm border border-gray-200 p-6 text-sm text-gray-500';

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
    /* commit 3 */
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

  void user;
  void role;
  void proposals;
  void uuidv4;

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

      {/* Section 3: My Pending Proposals — finance only (commit 3) */}
      {isFinance && (
        <div className={placeholderCard}>
          Section 3: My Pending Proposals (coming in commit 3)
        </div>
      )}

      {/* Section 4: Pending Approvals — admin_manager only (commit 3) */}
      {isAdminManager && (
        <div className={placeholderCard}>
          Section 4: Pending Approvals (coming in commit 3)
        </div>
      )}

      {/* Section 5: Awaiting OTP — super_admin only (commit 4) */}
      {isSuperAdmin && (
        <div className={placeholderCard}>
          Section 5: Awaiting OTP (coming in commit 4)
        </div>
      )}

      {/* Section 6: Emergency Transfer — super_admin only (commit 4) */}
      {isSuperAdmin && (
        <div className={placeholderCard}>
          Section 6: Emergency Transfer (coming in commit 4)
        </div>
      )}

      {/* Section 7: All Transfers History — auditor+ (commit 4) */}
      {isAuditor && (
        <div className={placeholderCard}>
          Section 7: History (coming in commit 4)
        </div>
      )}

      {/* Section 8: Stuck Cases — super_admin only (commit 4) */}
      {isSuperAdmin && (
        <div className={placeholderCard}>
          Section 8: Stuck Cases (coming in commit 4)
        </div>
      )}
    </div>
  );
}

export default RevenuePage;
