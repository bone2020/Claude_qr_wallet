import React, { useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { exportToCSV } from '../utils/csvExport';

function ReportsPage() {
  const [loading, setLoading] = useState('');
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');

  const handleExportUsers = async () => {
    setLoading('users');
    setError('');
    setMessage('');
    try {
      const result = await httpsCallable(functions, 'adminExportUsers')();
      exportToCSV(result.data.users, 'all_users', [
        { key: 'uid', label: 'User ID' },
        { key: 'fullName', label: 'Full Name' },
        { key: 'email', label: 'Email' },
        { key: 'phoneNumber', label: 'Phone' },
        { key: 'country', label: 'Country' },
        { key: 'currency', label: 'Currency' },
        { key: 'walletId', label: 'Wallet ID' },
        { key: 'balance', label: 'Balance' },
        { key: 'kycStatus', label: 'KYC Status' },
        { key: 'kycCompleted', label: 'KYC Completed' },
        { key: 'accountBlocked', label: 'Blocked' },
        { key: 'createdAt', label: 'Created At' },
      ]);
      setMessage(`Exported ${result.data.users.length} users.`);
    } catch (err) {
      setError(err.message || 'Export failed.');
    } finally {
      setLoading('');
    }
  };

  const handleExportTransactions = async () => {
    setLoading('transactions');
    setError('');
    setMessage('');
    try {
      const result = await httpsCallable(functions, 'adminGetAllTransactions')({ limit: 200 });
      exportToCSV(result.data.transactions, 'all_transactions', [
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
      setMessage(`Exported ${result.data.transactions.length} transactions.`);
    } catch (err) {
      setError(err.message || 'Export failed.');
    } finally {
      setLoading('');
    }
  };

  const handleExportFees = async () => {
    setLoading('fees');
    setError('');
    setMessage('');
    try {
      const result = await httpsCallable(functions, 'adminGetFeeHistory')({ limit: 200 });
      exportToCSV(result.data.fees, 'fee_history', [
        { key: 'createdAt', label: 'Date' },
        { key: 'transactionId', label: 'Transaction ID' },
        { key: 'originalAmount', label: 'Fee Amount' },
        { key: 'currency', label: 'Currency' },
        { key: 'usdAmount', label: 'USD Equivalent' },
        { key: 'senderName', label: 'Sender' },
        { key: 'transferAmount', label: 'Transfer Amount' },
      ]);
      setMessage(`Exported ${result.data.fees.length} fee records.`);
    } catch (err) {
      setError(err.message || 'Export failed.');
    } finally {
      setLoading('');
    }
  };

  const reports = [
    {
      title: 'All Users',
      description: 'Export all registered users with their wallet balances, KYC status, and account info.',
      icon: '\uD83D\uDC65',
      action: handleExportUsers,
      key: 'users',
    },
    {
      title: 'All Transactions',
      description: 'Export recent transactions across all users including sends, receives, deposits, and withdrawals.',
      icon: '\uD83D\uDCB8',
      action: handleExportTransactions,
      key: 'transactions',
    },
    {
      title: 'Fee Collection History',
      description: 'Export all platform fee records with amounts, currencies, and sender details.',
      icon: '\uD83D\uDCB0',
      action: handleExportFees,
      key: 'fees',
    },
  ];

  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">Reports</h2>
      <p className="text-gray-500 text-sm mb-8">Download CSV reports for accounting and record keeping.</p>

      {error && <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg mb-6">{error}</div>}
      {message && <div className="p-4 bg-green-50 border border-green-200 text-green-700 rounded-lg mb-6">{message}</div>}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {reports.map((report) => (
          <div key={report.key} className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="text-3xl mb-3">{report.icon}</div>
            <h3 className="text-lg font-bold text-gray-900 mb-2">{report.title}</h3>
            <p className="text-sm text-gray-500 mb-4">{report.description}</p>
            <button
              onClick={report.action}
              disabled={loading === report.key}
              className="w-full px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-medium transition-colors disabled:opacity-50"
            >
              {loading === report.key ? 'Exporting...' : 'Download CSV'}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

export default ReportsPage;
