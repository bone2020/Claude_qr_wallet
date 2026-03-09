import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';
import { exportToCSV } from '../utils/csvExport';

const typeColors = {
  send: 'bg-red-100 text-red-700',
  receive: 'bg-green-100 text-green-700',
  deposit: 'bg-blue-100 text-blue-700',
  withdraw: 'bg-orange-100 text-orange-700',
  withdrawal: 'bg-orange-100 text-orange-700',
};

const statusColors = {
  completed: 'bg-green-100 text-green-700',
  failed: 'bg-red-100 text-red-700',
  pending: 'bg-yellow-100 text-yellow-700',
};

const currencySymbols = {
  NGN: '\u20A6', GHS: 'GH\u20B5', KES: 'KSh', ZAR: 'R', UGX: 'USh',
  RWF: 'FRw', TZS: 'TSh', EGP: 'E\u00A3', USD: '$', GBP: '\u00A3', EUR: '\u20AC',
};

function TransactionsPage() {
  const { isAdmin } = useAuth();
  const [transactions, setTransactions] = useState([]);
  const [stats, setStats] = useState(null);
  const [flagged, setFlagged] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [activeTab, setActiveTab] = useState('list');
  const [statsDays, setStatsDays] = useState(7);

  // Filters
  const [filterType, setFilterType] = useState('');
  const [filterStatus, setFilterStatus] = useState('');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      setError('');

      const [txResult, statsResult, flaggedResult] = await Promise.all([
        httpsCallable(functions, 'adminGetAllTransactions')({
          limit: 100,
          type: filterType || undefined,
          status: filterStatus || undefined,
        }),
        httpsCallable(functions, 'adminGetTransactionStats')({ days: statsDays }),
        httpsCallable(functions, 'adminGetFlaggedTransactions')({ limit: 50, resolved: false }),
      ]);

      setTransactions(txResult.data.transactions || []);
      setStats(statsResult.data.stats || null);
      setFlagged(flaggedResult.data.flagged || []);
    } catch (err) {
      setError(err.message || 'Failed to load data.');
    } finally {
      setLoading(false);
    }
  };

  const handleFilter = async () => {
    try {
      setLoading(true);
      setError('');
      const result = await httpsCallable(functions, 'adminGetAllTransactions')({
        limit: 100,
        type: filterType || undefined,
        status: filterStatus || undefined,
      });
      setTransactions(result.data.transactions || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleFlag = async (userId, txId) => {
    const reason = prompt('Enter reason for flagging this transaction:');
    if (!reason) return;

    try {
      await httpsCallable(functions, 'adminFlagTransaction')({
        userId, transactionId: txId, reason,
      });
      setMessage('Transaction flagged successfully.');
      await loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleResolve = async (txId) => {
    const resolution = prompt('Enter resolution notes:');
    if (!resolution) return;

    try {
      await httpsCallable(functions, 'adminResolveFlaggedTransaction')({
        transactionId: txId, resolution,
      });
      setMessage('Flagged transaction resolved.');
      await loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleExportTransactions = () => {
    exportToCSV(transactions, 'transactions', [
      { key: 'createdAt', label: 'Date' },
      { key: 'type', label: 'Type' },
      { key: 'amount', label: 'Amount' },
      { key: 'fee', label: 'Fee' },
      { key: 'currency', label: 'Currency' },
      { key: 'senderName', label: 'Sender' },
      { key: 'receiverName', label: 'Receiver' },
      { key: 'method', label: 'Method' },
      { key: 'status', label: 'Status' },
      { key: 'userId', label: 'User ID' },
      { key: 'id', label: 'Transaction ID' },
    ]);
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return 'N/A';
    return new Date(dateStr).toLocaleString();
  };

  const getSymbol = (currency) => currencySymbols[currency] || currency || '';

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
          <h2 className="text-2xl font-bold text-gray-900">Transaction Monitoring</h2>
          <p className="text-gray-500 text-sm mt-1">View and monitor all platform transactions</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={handleExportTransactions}
            className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg text-sm transition-colors"
          >
            Export CSV
          </button>
          <button
            onClick={loadData}
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm transition-colors"
          >
            Refresh
          </button>
        </div>
      </div>

      {error && <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg mb-6">{error}</div>}
      {message && <div className="p-4 bg-green-50 border border-green-200 text-green-700 rounded-lg mb-6">{message}</div>}

      {/* Stats Cards */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4">
            <p className="text-gray-500 text-xs">Total Transactions ({stats.period})</p>
            <p className="text-2xl font-bold text-gray-900">{stats.totalTransactions}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4">
            <p className="text-gray-500 text-xs">Completed</p>
            <p className="text-2xl font-bold text-green-600">{stats.byStatus?.completed || 0}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4">
            <p className="text-gray-500 text-xs">Failed</p>
            <p className="text-2xl font-bold text-red-600">{stats.byStatus?.failed || 0}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4">
            <p className="text-gray-500 text-xs">Flagged (Unresolved)</p>
            <p className="text-2xl font-bold text-yellow-600">{flagged.length}</p>
          </div>
        </div>
      )}

      {/* Volume by Type */}
      {stats && (
        <div className="grid grid-cols-4 gap-4 mb-8">
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4 text-center">
            <p className="text-gray-500 text-xs">Sends</p>
            <p className="text-xl font-bold text-red-600">{stats.byType?.send || 0}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4 text-center">
            <p className="text-gray-500 text-xs">Receives</p>
            <p className="text-xl font-bold text-green-600">{stats.byType?.receive || 0}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4 text-center">
            <p className="text-gray-500 text-xs">Deposits</p>
            <p className="text-xl font-bold text-blue-600">{stats.byType?.deposit || 0}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4 text-center">
            <p className="text-gray-500 text-xs">Withdrawals</p>
            <p className="text-xl font-bold text-orange-600">{stats.byType?.withdraw || 0}</p>
          </div>
        </div>
      )}

      {/* Tabs */}
      <div className="flex border-b border-gray-200 mb-6">
        {['list', 'flagged', 'volume'].map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors capitalize ${
              activeTab === tab
                ? 'border-indigo-600 text-indigo-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            {tab === 'list' ? 'All Transactions' : tab === 'flagged' ? `Flagged (${flagged.length})` : 'Volume by Currency'}
          </button>
        ))}
      </div>

      {/* All Transactions Tab */}
      {activeTab === 'list' && (
        <div>
          {/* Filters */}
          <div className="flex gap-4 mb-4">
            <select
              value={filterType}
              onChange={(e) => setFilterType(e.target.value)}
              className="border border-gray-300 rounded-lg px-3 py-2 text-sm"
            >
              <option value="">All Types</option>
              <option value="send">Send</option>
              <option value="receive">Receive</option>
              <option value="deposit">Deposit</option>
              <option value="withdraw">Withdraw</option>
            </select>
            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
              className="border border-gray-300 rounded-lg px-3 py-2 text-sm"
            >
              <option value="">All Statuses</option>
              <option value="completed">Completed</option>
              <option value="failed">Failed</option>
              <option value="pending">Pending</option>
            </select>
            <button
              onClick={handleFilter}
              className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm"
            >
              Apply Filters
            </button>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Fee</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">From / To</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Method</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {transactions.length === 0 ? (
                  <tr><td colSpan={8} className="px-4 py-12 text-center text-gray-400">No transactions found</td></tr>
                ) : (
                  transactions.map((tx) => (
                    <tr key={`${tx.userId}-${tx.id}`} className="hover:bg-gray-50">
                      <td className="px-4 py-3 text-xs text-gray-500">{formatDate(tx.createdAt)}</td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${typeColors[tx.type] || 'bg-gray-100 text-gray-700'}`}>
                          {tx.type}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right font-medium text-gray-900">
                        {getSymbol(tx.currency)}{tx.amount?.toFixed(2)}
                      </td>
                      <td className="px-4 py-3 text-right text-xs text-gray-400">
                        {tx.fee > 0 ? `${getSymbol(tx.currency)}${tx.fee.toFixed(2)}` : '-'}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-500">
                        {tx.senderName && tx.receiverName
                          ? `${tx.senderName} \u2192 ${tx.receiverName}`
                          : tx.senderName || tx.receiverName || tx.phoneNumber || '-'}
                      </td>
                      <td className="px-4 py-3 text-xs text-gray-400">{tx.method || 'Internal'}</td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${statusColors[tx.status] || 'bg-gray-100 text-gray-700'}`}>
                          {tx.status}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <button
                          onClick={() => handleFlag(tx.userId, tx.id)}
                          className="text-xs text-yellow-600 hover:text-yellow-700 font-medium"
                          title="Flag for review"
                        >
                          Flag
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Flagged Tab */}
      {activeTab === 'flagged' && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Flagged At</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
                <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Parties</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Reason</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Flagged By</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {flagged.length === 0 ? (
                <tr><td colSpan={7} className="px-4 py-12 text-center text-gray-400">No flagged transactions</td></tr>
              ) : (
                flagged.map((f) => (
                  <tr key={f.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-xs text-gray-500">{formatDate(f.flaggedAt)}</td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${typeColors[f.type] || 'bg-gray-100 text-gray-700'}`}>
                        {f.type}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right font-medium text-gray-900">
                      {getSymbol(f.currency)}{f.amount?.toFixed(2)}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500">
                      {f.senderName || '-'} \u2192 {f.receiverName || '-'}
                    </td>
                    <td className="px-4 py-3 text-sm text-red-600">{f.reason}</td>
                    <td className="px-4 py-3 text-xs text-gray-400">{f.flaggedByEmail}</td>
                    <td className="px-4 py-3">
                      {isAdmin && (
                        <button
                          onClick={() => handleResolve(f.id)}
                          className="text-xs text-green-600 hover:text-green-700 font-medium"
                        >
                          Resolve
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Volume by Currency Tab */}
      {activeTab === 'volume' && stats?.volumeByCurrency && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="p-4 border-b border-gray-200 flex items-center gap-4">
            <label className="text-sm text-gray-500">Period:</label>
            <select
              value={statsDays}
              onChange={async (e) => {
                const days = parseInt(e.target.value);
                setStatsDays(days);
                try {
                  const result = await httpsCallable(functions, 'adminGetTransactionStats')({ days });
                  setStats(result.data.stats);
                } catch (err) {
                  setError(err.message);
                }
              }}
              className="border border-gray-300 rounded-lg px-3 py-1 text-sm"
            >
              <option value={1}>Last 24 hours</option>
              <option value={7}>Last 7 days</option>
              <option value={30}>Last 30 days</option>
              <option value={90}>Last 90 days</option>
            </select>
          </div>
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Currency</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Volume</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Fees Collected</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Transactions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {Object.entries(stats.volumeByCurrency)
                .sort(([, a], [, b]) => b.amount - a.amount)
                .map(([currency, data]) => (
                  <tr key={currency} className="hover:bg-gray-50">
                    <td className="px-6 py-4 font-medium text-gray-900">{getSymbol(currency)} {currency}</td>
                    <td className="px-6 py-4 text-right text-gray-900">{getSymbol(currency)}{data.amount?.toFixed(2)}</td>
                    <td className="px-6 py-4 text-right text-green-600">{getSymbol(currency)}{data.fees?.toFixed(2)}</td>
                    <td className="px-6 py-4 text-right text-gray-500">{data.count}</td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

export default TransactionsPage;
