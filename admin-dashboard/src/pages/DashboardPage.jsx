import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import StatsCard from '../components/StatsCard';

function DashboardPage() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      setLoading(true);
      const adminGetStats = httpsCallable(functions, 'adminGetStats');
      const result = await adminGetStats();
      setStats(result.data.stats);

      // Also load fraud stats
      try {
        const fraudResult = await httpsCallable(functions, 'adminGetFraudStats')();
        setStats(prev => ({ ...prev, ...fraudResult.data.stats }));
      } catch (e) {
        // Fraud stats optional
      }
    } catch (err) {
      setError(err.message || 'Failed to load stats.');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg">
        {error}
      </div>
    );
  }

  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-6">Dashboard</h2>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <StatsCard
          title="Total Users"
          value={stats?.totalUsers || 0}
          icon="👥"
          color="indigo"
        />
        <StatsCard
          title="Total Wallets"
          value={stats?.totalWallets || 0}
          icon="💰"
          color="green"
        />
        <StatsCard
          title="Blocked Accounts"
          value={stats?.blockedAccounts || 0}
          icon="🚫"
          color="red"
        />
        <StatsCard
          title="KYC Completed"
          value={stats?.kycCompleted || 0}
          icon="✅"
          color="blue"
        />
        <StatsCard
          title="Transactions (24h)"
          value={stats?.recentTransactions || 0}
          icon="📊"
          color="purple"
        />
        <StatsCard
          title="Flagged Transactions"
          value={stats?.flaggedTransactions || 0}
          icon="⚠️"
          color="yellow"
        />
        <StatsCard
          title="Open Fraud Alerts"
          value={stats?.open || 0}
          icon="🚨"
          color="red"
        />
      </div>

      <div className="mt-8">
        <button
          onClick={loadStats}
          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg transition-colors text-sm"
        >
          Refresh Stats
        </button>
      </div>
    </div>
  );
}

export default DashboardPage;
