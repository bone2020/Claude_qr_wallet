import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { v4 as uuidv4 } from 'uuid';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';
import { exportToCSV } from '../utils/csvExport';

const currencySymbols = {
  NGN: '\u20A6', GHS: 'GH\u20B5', KES: 'KSh', ZAR: 'R', UGX: 'USh',
  RWF: 'FRw', TZS: 'TSh', EGP: 'E\u00A3', USD: '$', GBP: '\u00A3', EUR: '\u20AC',
};

function RevenuePage() {
  const { isSuper } = useAuth();
  const [wallet, setWallet] = useState(null);
  const [balances, setBalances] = useState([]);
  const [fees, setFees] = useState([]);
  const [withdrawals, setWithdrawals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [activeTab, setActiveTab] = useState('overview');

  // Bank transfer form
  const [wdAmount, setWdAmount] = useState('');
  const [wdCurrency, setWdCurrency] = useState('');
  const [wdPurpose, setWdPurpose] = useState('');
  const [wdNotes, setWdNotes] = useState('');
  const [wdLoading, setWdLoading] = useState(false);
  const [banks, setBanks] = useState([]);
  const [bankCode, setBankCode] = useState('');
  const [accountNumber, setAccountNumber] = useState('');
  const [accountName, setAccountName] = useState('');
  const [verifying, setVerifying] = useState(false);
  const [verified, setVerified] = useState(false);
  const [bankCountry, setBankCountry] = useState('nigeria');

  // OTP confirmation modal (L-35)
  const [otpModalOpen, setOtpModalOpen] = useState(false);
  const [otpModalData, setOtpModalData] = useState(null);
  const [otpInput, setOtpInput] = useState('');
  const [otpAttempts, setOtpAttempts] = useState(0);
  const [otpRemaining, setOtpRemaining] = useState(3);
  const [otpLoading, setOtpLoading] = useState(false);

  // Platform limits (D-08)
  const [limits, setLimits] = useState({ perTransferUSD: 50000, dailyUSD: 100000 });

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      setError('');

      const [walletResult, feeResult, wdResult] = await Promise.all([
        httpsCallable(functions, 'adminGetPlatformWallet')(),
        httpsCallable(functions, 'adminGetFeeHistory')({ limit: 50 }),
        httpsCallable(functions, 'adminGetPlatformWithdrawals')({ limit: 50 }),
      ]);

      // D-08: Try to load platform limits (fallback to defaults if missing)
      try {
        const limitsResult = await httpsCallable(functions, 'adminGetPlatformLimits')();
        if (limitsResult.data) {
          setLimits({
            perTransferUSD: limitsResult.data.perTransferUSD || 50000,
            dailyUSD: limitsResult.data.dailyUSD || 100000,
          });
        }
      } catch (e) {
        console.log('Could not load platform limits, using defaults');
      }

      setWallet(walletResult.data.wallet);
      setBalances(walletResult.data.balances || []);
      setFees(feeResult.data.fees || []);
      setWithdrawals(wdResult.data.withdrawals || []);
    } catch (err) {
      setError(err.message || 'Failed to load data.');
    } finally {
      setLoading(false);
    }
  };

  const loadBanks = async (country) => {
    try {
      const result = await httpsCallable(functions, 'adminGetBanks')({ country });
      setBanks(result.data.banks || []);
      setBankCode('');
      setAccountNumber('');
      setAccountName('');
      setVerified(false);
    } catch (err) {
      setError(err.message || 'Failed to load banks.');
    }
  };

  const verifyAccount = async () => {
    if (!accountNumber || !bankCode) return;

    setVerifying(true);
    setAccountName('');
    setVerified(false);
    setError('');

    try {
      const result = await httpsCallable(functions, 'adminVerifyBankAccount')({
        accountNumber,
        bankCode,
      });
      setAccountName(result.data.accountName);
      setVerified(true);
    } catch (err) {
      setError(err.message || 'Account verification failed.');
    } finally {
      setVerifying(false);
    }
  };

  const handleBankTransfer = async (e) => {
    e.preventDefault();
    if (!wdAmount || !wdCurrency || !wdPurpose || !bankCode || !accountNumber || !verified) return;

    setWdLoading(true);
    setError('');
    setMessage('');

    try {
      const idempotencyKey = uuidv4(); // D-07
      const result = await httpsCallable(functions, 'adminInitiateTransfer')({
        amount: parseFloat(wdAmount),
        currency: wdCurrency,
        bankCode,
        accountNumber,
        accountName,
        purpose: wdPurpose,
        notes: wdNotes || null,
        idempotencyKey,
      });

      // L-35: Check if Paystack requires OTP
      if (result.data.otpRequired === true) {
        // Open OTP modal — do NOT clear form yet (in case OTP fails and user wants to retry)
        setOtpModalData({
          reference: result.data.transfer.reference,
          transferCode: result.data.transfer.transferCode,
          amount: result.data.transfer.amount,
          currency: result.data.transfer.currency,
          accountName: result.data.transfer.accountName,
          purpose: result.data.transfer.purpose,
        });
        setOtpAttempts(0);
        setOtpRemaining(3);
        setOtpInput('');
        setOtpModalOpen(true);
      } else {
        // Auto-completed (no OTP needed)
        setMessage(`Transfer completed: ${wdCurrency} ${parseFloat(wdAmount).toFixed(2)} to ${accountName}. Reference: ${result.data.transfer.reference}`);
        clearTransferForm();
        await loadData();
      }
    } catch (err) {
      setError(err.message || 'Transfer failed.');
    } finally {
      setWdLoading(false);
    }
  };

  const clearTransferForm = () => {
    setWdAmount('');
    setWdCurrency('');
    setWdPurpose('');
    setWdNotes('');
    setBankCode('');
    setAccountNumber('');
    setAccountName('');
    setVerified(false);
  };

  // L-35: Submit OTP to finalize transfer
  const handleOtpSubmit = async () => {
    if (!otpInput.trim()) return;
    setOtpLoading(true);
    setError('');

    try {
      const idempotencyKey = uuidv4();
      const result = await httpsCallable(functions, 'adminFinalizeTransfer')({
        action: 'finalize',
        reference: otpModalData.reference,
        transferCode: otpModalData.transferCode,
        otp: otpInput.trim(),
        idempotencyKey,
      });

      if (result.data.success === true && result.data.status === 'completed') {
        setMessage(`Transfer completed: ${otpModalData.currency} ${otpModalData.amount.toFixed(2)} to ${otpModalData.accountName}. Reference: ${otpModalData.reference}`);
        setOtpModalOpen(false);
        setOtpModalData(null);
        clearTransferForm();
        await loadData();
      } else if (result.data.status === 'cancelled') {
        // Auto-cancelled (3 strikes)
        setError(result.data.message || 'Transfer auto-cancelled after 3 wrong OTP attempts. Balance refunded.');
        setOtpModalOpen(false);
        setOtpModalData(null);
        clearTransferForm();
        await loadData();
      } else {
        // Wrong OTP, attempts remaining
        setOtpAttempts(result.data.attemptsUsed || otpAttempts + 1);
        setOtpRemaining(result.data.attemptsRemaining || (otpRemaining - 1));
        setOtpInput('');
        setError(result.data.message || `OTP rejected. ${result.data.attemptsRemaining || 0} attempts remaining.`);
      }
    } catch (err) {
      setError(err.message || 'OTP submission failed.');
    } finally {
      setOtpLoading(false);
    }
  };

  // L-35: Cancel transfer (refund balance)
  const handleOtpCancel = async () => {
    if (!window.confirm('Cancel this transfer and refund the platform balance?')) return;
    setOtpLoading(true);
    setError('');

    try {
      const idempotencyKey = uuidv4();
      const result = await httpsCallable(functions, 'adminFinalizeTransfer')({
        action: 'cancel',
        reference: otpModalData.reference,
        idempotencyKey,
      });

      setMessage(`Transfer cancelled. ${result.data.currency} ${result.data.refundedAmount.toFixed(2)} refunded to platform balance.`);
      setOtpModalOpen(false);
      setOtpModalData(null);
      clearTransferForm();
      await loadData();
    } catch (err) {
      setError(err.message || 'Cancel failed.');
    } finally {
      setOtpLoading(false);
    }
  };

  const handleExportFees = () => {
    exportToCSV(fees, 'fee_history', [
      { key: 'createdAt', label: 'Date' },
      { key: 'transactionId', label: 'Transaction ID' },
      { key: 'originalAmount', label: 'Fee Amount' },
      { key: 'currency', label: 'Currency' },
      { key: 'usdAmount', label: 'USD Equivalent' },
      { key: 'senderName', label: 'Sender' },
      { key: 'transferAmount', label: 'Transfer Amount' },
    ]);
  };

  const handleExportWithdrawals = () => {
    exportToCSV(withdrawals, 'platform_withdrawals', [
      { key: 'createdAt', label: 'Date' },
      { key: 'amount', label: 'Amount' },
      { key: 'currency', label: 'Currency' },
      { key: 'usdEquivalent', label: 'USD Equivalent' },
      { key: 'purpose', label: 'Purpose' },
      { key: 'withdrawnByEmail', label: 'Withdrawn By' },
      { key: 'status', label: 'Status' },
      { key: 'notes', label: 'Notes' },
    ]);
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return 'N/A';
    return new Date(dateStr).toLocaleString();
  };

  const getSymbol = (currency) => currencySymbols[currency] || currency;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Revenue</h2>
          <p className="text-gray-500 text-sm mt-1">Platform fee collection and withdrawals</p>
        </div>
        <div className="flex gap-2">
          {activeTab === 'fees' && (
            <button onClick={handleExportFees} className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg text-sm transition-colors">
              Export Fees CSV
            </button>
          )}
          {activeTab === 'withdrawals' && (
            <button onClick={handleExportWithdrawals} className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg text-sm transition-colors">
              Export Withdrawals CSV
            </button>
          )}
          <button onClick={loadData} className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm transition-colors">
            Refresh
          </button>
        </div>
      </div>

      {error && <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg mb-6">{error}</div>}
      {message && <div className="p-4 bg-green-50 border border-green-200 text-green-700 rounded-lg mb-6">{message}</div>}

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <p className="text-gray-500 text-sm">Total Revenue (USD)</p>
          <p className="text-3xl font-bold text-green-600 mt-1">${wallet?.totalBalanceUSD?.toFixed(2) || '0.00'}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <p className="text-gray-500 text-sm">Total Transactions</p>
          <p className="text-3xl font-bold text-indigo-600 mt-1">{wallet?.totalTransactions || 0}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <p className="text-gray-500 text-sm">Fees Collected</p>
          <p className="text-3xl font-bold text-purple-600 mt-1">{wallet?.totalFeesCollected || 0}</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-200 mb-6">
        {['overview', 'fees', 'withdrawals', ...(isSuper ? ['transfer'] : [])].map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              activeTab === tab
                ? 'border-indigo-600 text-indigo-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            {tab.charAt(0).toUpperCase() + tab.slice(1)}
          </button>
        ))}
      </div>

      {/* Overview Tab — Per-Currency Balances */}
      {activeTab === 'overview' && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Currency</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Balance</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">USD Equivalent</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Transactions</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Last Activity</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {balances.length === 0 ? (
                <tr><td colSpan={5} className="px-6 py-12 text-center text-gray-400">No balances yet</td></tr>
              ) : (
                balances.map((b) => (
                  <tr key={b.currency} className="hover:bg-gray-50">
                    <td className="px-6 py-4 font-medium text-gray-900">{getSymbol(b.currency)} {b.currency}</td>
                    <td className="px-6 py-4 text-right font-bold text-gray-900">{getSymbol(b.currency)}{b.amount?.toFixed(2) || '0.00'}</td>
                    <td className="px-6 py-4 text-right text-green-600">${b.usdEquivalent?.toFixed(2) || '0.00'}</td>
                    <td className="px-6 py-4 text-right text-gray-500">{b.txCount || 0}</td>
                    <td className="px-6 py-4 text-sm text-gray-400">{formatDate(b.lastTransactionAt)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Fees Tab — Fee History */}
      {activeTab === 'fees' && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Transaction</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Fee</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">USD</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Sender</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Transfer Amount</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {fees.length === 0 ? (
                <tr><td colSpan={6} className="px-6 py-12 text-center text-gray-400">No fees collected yet</td></tr>
              ) : (
                fees.map((f) => (
                  <tr key={f.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 text-sm text-gray-500">{formatDate(f.createdAt)}</td>
                    <td className="px-6 py-4 text-sm font-mono text-gray-500">{f.transactionId?.slice(0, 16) || '-'}...</td>
                    <td className="px-6 py-4 text-right font-medium text-gray-900">{getSymbol(f.currency)}{f.originalAmount?.toFixed(2)}</td>
                    <td className="px-6 py-4 text-right text-green-600">${f.usdAmount?.toFixed(2)}</td>
                    <td className="px-6 py-4 text-sm text-gray-500">{f.senderName || '-'}</td>
                    <td className="px-6 py-4 text-right text-sm text-gray-500">{getSymbol(f.currency)}{f.transferAmount?.toFixed(2)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Withdrawals Tab */}
      {activeTab === 'withdrawals' && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">USD</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Purpose</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">By</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {withdrawals.length === 0 ? (
                <tr><td colSpan={6} className="px-6 py-12 text-center text-gray-400">No withdrawals yet</td></tr>
              ) : (
                withdrawals.map((w) => (
                  <tr key={w.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 text-sm text-gray-500">{formatDate(w.createdAt)}</td>
                    <td className="px-6 py-4 text-right font-medium text-gray-900">{getSymbol(w.currency)}{w.amount?.toFixed(2)}</td>
                    <td className="px-6 py-4 text-right text-green-600">${w.usdEquivalent?.toFixed(2)}</td>
                    <td className="px-6 py-4 text-sm text-gray-500">{w.purpose}</td>
                    <td className="px-6 py-4 text-sm text-gray-500">{w.withdrawnByEmail || '-'}</td>
                    <td className="px-6 py-4">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700">
                        {w.status}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Bank Transfer Tab (super_admin only) */}
      {activeTab === 'transfer' && isSuper && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 max-w-xl">
          <h3 className="text-lg font-bold text-gray-900 mb-4">Bank Transfer</h3>
          <p className="text-sm text-gray-500 mb-2">
            Initiate a bank transfer from the platform wallet via Paystack.
          </p>
          <p className="text-xs text-gray-400 mb-6">
            Limits: ${limits.perTransferUSD.toLocaleString()} USD per transfer, ${limits.dailyUSD.toLocaleString()} USD per day.
          </p>

          <form onSubmit={handleBankTransfer} className="space-y-4">
            <div>
              <label className="text-sm text-gray-600 block mb-1">Currency</label>
              <select
                value={wdCurrency}
                onChange={(e) => setWdCurrency(e.target.value)}
                required
                className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              >
                <option value="">Select currency</option>
                {balances.map((b) => (
                  <option key={b.currency} value={b.currency}>
                    {b.currency} — Available: {getSymbol(b.currency)}{b.amount?.toFixed(2)}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="text-sm text-gray-600 block mb-1">Country (for bank list)</label>
              <select
                value={bankCountry}
                onChange={(e) => {
                  setBankCountry(e.target.value);
                  loadBanks(e.target.value);
                }}
                className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              >
                <option value="nigeria">Nigeria</option>
                <option value="ghana">Ghana</option>
                <option value="south-africa">South Africa</option>
                <option value="kenya">Kenya</option>
              </select>
              {banks.length === 0 && (
                <button
                  type="button"
                  onClick={() => loadBanks(bankCountry)}
                  className="mt-2 text-sm text-indigo-600 hover:text-indigo-800"
                >
                  Load banks
                </button>
              )}
            </div>

            {banks.length > 0 && (
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
                  className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                >
                  <option value="">Select bank</option>
                  {banks.map((bank) => (
                    <option key={bank.code} value={bank.code}>
                      {bank.name}
                    </option>
                  ))}
                </select>
              </div>
            )}

            {bankCode && (
              <div>
                <label className="text-sm text-gray-600 block mb-1">Account Number</label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={accountNumber}
                    onChange={(e) => {
                      setAccountNumber(e.target.value);
                      setVerified(false);
                      setAccountName('');
                    }}
                    required
                    placeholder="0123456789"
                    className="flex-1 border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  />
                  <button
                    type="button"
                    onClick={verifyAccount}
                    disabled={verifying || accountNumber.length < 10}
                    className="px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg text-sm transition-colors disabled:opacity-50"
                  >
                    {verifying ? 'Verifying...' : 'Verify'}
                  </button>
                </div>
                {verified && accountName && (
                  <p className="mt-2 text-sm text-green-600 font-medium">
                    ✓ {accountName}
                  </p>
                )}
              </div>
            )}

            <div>
              <label className="text-sm text-gray-600 block mb-1">Amount</label>
              <input
                type="number"
                step="0.01"
                min="0"
                value={wdAmount}
                onChange={(e) => setWdAmount(e.target.value)}
                required
                placeholder="0.00"
                className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              />
            </div>

            <div>
              <label className="text-sm text-gray-600 block mb-1">Purpose</label>
              <select
                value={wdPurpose}
                onChange={(e) => setWdPurpose(e.target.value)}
                required
                className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              >
                <option value="">Select purpose</option>
                <option value="Google Play Service Fees">Google Play Service Fees</option>
                <option value="Apple App Store Fees">Apple App Store Fees</option>
                <option value="Staff Salaries">Staff Salaries</option>
                <option value="Tax Payment">Tax Payment</option>
                <option value="Server & Infrastructure">Server & Infrastructure</option>
                <option value="Marketing & Advertising">Marketing & Advertising</option>
                <option value="Operational Expenses">Operational Expenses</option>
                <option value="Other">Other</option>
              </select>
            </div>

            <div>
              <label className="text-sm text-gray-600 block mb-1">Notes (optional)</label>
              <textarea
                value={wdNotes}
                onChange={(e) => setWdNotes(e.target.value)}
                placeholder="Additional details..."
                rows={3}
                className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              />
            </div>

            <button
              type="submit"
              disabled={wdLoading || !verified}
              className="w-full bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-3 font-medium transition-colors disabled:opacity-50"
            >
              {wdLoading ? 'Processing Transfer...' : 'Initiate Bank Transfer'}
            </button>

            {!verified && bankCode && accountNumber && (
              <p className="text-xs text-amber-600 text-center">Please verify the bank account before initiating the transfer.</p>
            )}
          </form>
        </div>
      )}

      {/* L-35: OTP Confirmation Modal */}
      {otpModalOpen && otpModalData && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-2xl max-w-md w-full p-6">
            <h3 className="text-lg font-bold text-gray-900 mb-2">Confirm Transfer</h3>
            <p className="text-sm text-gray-600 mb-4">
              Paystack has sent an OTP to your registered phone. Enter it below to complete the transfer.
            </p>

            <div className="bg-gray-50 rounded-lg p-3 mb-4 text-sm">
              <div className="flex justify-between mb-1">
                <span className="text-gray-500">To:</span>
                <span className="font-medium">{otpModalData.accountName}</span>
              </div>
              <div className="flex justify-between mb-1">
                <span className="text-gray-500">Amount:</span>
                <span className="font-medium">{otpModalData.currency} {otpModalData.amount.toFixed(2)}</span>
              </div>
              <div className="flex justify-between mb-1">
                <span className="text-gray-500">Purpose:</span>
                <span className="font-medium">{otpModalData.purpose}</span>
              </div>
              <div className="flex justify-between text-xs text-gray-400 mt-2">
                <span>Reference:</span>
                <span className="font-mono">{otpModalData.reference}</span>
              </div>
            </div>

            <label className="block text-sm font-medium text-gray-700 mb-2">
              Enter OTP from Paystack
            </label>
            <input
              type="text"
              value={otpInput}
              onChange={(e) => setOtpInput(e.target.value.replace(/\D/g, '').slice(0, 6))}
              placeholder="6-digit OTP"
              maxLength={6}
              autoFocus
              className="w-full text-center text-2xl tracking-[0.5em] font-mono border border-gray-300 rounded-lg px-4 py-3 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            />

            {otpAttempts > 0 && (
              <p className="text-xs text-amber-600 mt-2 text-center">
                {otpAttempts} wrong attempt{otpAttempts === 1 ? '' : 's'}. {otpRemaining} remaining before auto-cancel.
              </p>
            )}

            <div className="flex gap-2 mt-6">
              <button
                onClick={handleOtpSubmit}
                disabled={otpInput.length !== 6 || otpLoading}
                className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-3 font-medium transition-colors disabled:opacity-50"
              >
                {otpLoading ? 'Confirming...' : 'Confirm Transfer'}
              </button>
              <button
                onClick={handleOtpCancel}
                disabled={otpLoading}
                className="px-4 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg py-3 font-medium transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
            </div>

            <p className="text-xs text-gray-400 text-center mt-4">
              The platform balance has already been deducted. Cancelling will refund it.
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

export default RevenuePage;
