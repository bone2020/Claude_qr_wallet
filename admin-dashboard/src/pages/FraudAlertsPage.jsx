import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

const severityColors = {
  high: 'bg-red-100 text-red-700 border-red-200',
  medium: 'bg-yellow-100 text-yellow-700 border-yellow-200',
  low: 'bg-blue-100 text-blue-700 border-blue-200',
};

const severityBadge = {
  high: 'bg-red-100 text-red-700',
  medium: 'bg-yellow-100 text-yellow-700',
  low: 'bg-blue-100 text-blue-700',
};

function FraudAlertsPage() {
  const { isAdmin } = useAuth();
  const navigate = useNavigate();
  const [alerts, setAlerts] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [filterStatus, setFilterStatus] = useState('open');
  const [filterSeverity, setFilterSeverity] = useState('');

  useEffect(() => {
    loadData();
  }, [filterStatus]);

  const loadData = async () => {
    try {
      setLoading(true);
      setError('');

      const [alertsResult, statsResult] = await Promise.all([
        httpsCallable(functions, 'adminGetFraudAlerts')({
          limit: 100,
          status: filterStatus || undefined,
          severity: filterSeverity || undefined,
        }),
        httpsCallable(functions, 'adminGetFraudStats')(),
      ]);

      setAlerts(alertsResult.data.alerts || []);
      setStats(statsResult.data.stats || null);
    } catch (err) {
      setError(err.message || 'Failed to load fraud alerts.');
    } finally {
      setLoading(false);
    }
  };

  const handleResolve = async (alertId, userId) => {
    const resolution = prompt('Enter resolution notes:');
    if (!resolution) return;

    const action = window.confirm('Do you also want to BLOCK this user\'s account?') ? 'block' : 'none';

    try {
      await httpsCallable(functions, 'adminResolveFraudAlert')({
        alertId,
        resolution,
        action,
      });
      setMessage(`Alert resolved${action === 'block' ? ' and account blocked' : ''}.`);
      await loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return 'N/A';
    return new Date(dateStr).toLocaleString();
  };

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
          <h2 className="text-2xl font-bold text-gray-900">Fraud Alerts</h2>
          <p className="text-gray-500 text-sm mt-1">Automated fraud detection alerts</p>
        </div>
        <button
          onClick={loadData}
          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm transition-colors"
        >
          Refresh
        </button>
      </div>

      {error && <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg mb-6">{error}</div>}
      {message && <div className="p-4 bg-green-50 border border-green-200 text-green-700 rounded-lg mb-6">{message}</div>}

      {/* Stats */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4">
            <p className="text-gray-500 text-xs">Open Alerts</p>
            <p className="text-2xl font-bold text-red-600">{stats.open}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4">
            <p className="text-gray-500 text-xs">High Severity</p>
            <p className="text-2xl font-bold text-red-600">{stats.high}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4">
            <p className="text-gray-500 text-xs">Resolved</p>
            <p className="text-2xl font-bold text-green-600">{stats.resolved}</p>
          </div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-4">
            <p className="text-gray-500 text-xs">Total All Time</p>
            <p className="text-2xl font-bold text-gray-900">{stats.total}</p>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="flex gap-4 mb-6">
        <select
          value={filterStatus}
          onChange={(e) => setFilterStatus(e.target.value)}
          className="border border-gray-300 rounded-lg px-3 py-2 text-sm"
        >
          <option value="open">Open</option>
          <option value="resolved">Resolved</option>
          <option value="">All</option>
        </select>
        <select
          value={filterSeverity}
          onChange={(e) => { setFilterSeverity(e.target.value); loadData(); }}
          className="border border-gray-300 rounded-lg px-3 py-2 text-sm"
        >
          <option value="">All Severities</option>
          <option value="high">High</option>
          <option value="medium">Medium</option>
          <option value="low">Low</option>
        </select>
      </div>

      {/* Alerts List */}
      <div className="space-y-4">
        {alerts.length === 0 ? (
          <div className="text-center text-gray-400 py-12 bg-white rounded-xl border border-gray-200">
            No fraud alerts found
          </div>
        ) : (
          alerts.map((alert) => (
            <div key={alert.id} className={`bg-white rounded-xl shadow-sm border p-6 ${alert.severity === 'high' ? 'border-red-200' : 'border-gray-200'}`}>
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-3">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${severityBadge[alert.severity]}`}>
                    {alert.severity}
                  </span>
                  <span className="text-sm text-gray-500">{formatDate(alert.createdAt)}</span>
                  <span className={`text-xs px-2 py-0.5 rounded-full ${alert.status === 'open' ? 'bg-red-100 text-red-600' : 'bg-green-100 text-green-600'}`}>
                    {alert.status}
                  </span>
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={() => navigate(`/users/${alert.userId}`)}
                    className="text-xs text-indigo-600 hover:text-indigo-700 font-medium"
                  >
                    View User
                  </button>
                  {isAdmin && alert.status === 'open' && (
                    <button
                      onClick={() => handleResolve(alert.id, alert.userId)}
                      className="text-xs text-green-600 hover:text-green-700 font-medium"
                    >
                      Resolve
                    </button>
                  )}
                </div>
              </div>

              <div className="mb-3">
                <span className="text-sm font-medium text-gray-900">{alert.userName || 'Unknown'}</span>
                <span className="text-sm text-gray-400 ml-2">({alert.userEmail})</span>
              </div>

              <div className="text-sm text-gray-900 mb-3">
                <span className="font-medium">{alert.transactionType}</span>: {alert.currency} {alert.amount?.toFixed(2)}
              </div>

              {/* Alert Rules */}
              <div className="space-y-1">
                {alert.alerts?.map((a, i) => (
                  <div key={i} className={`text-sm px-3 py-1.5 rounded ${severityColors[a.severity] || 'bg-gray-100 text-gray-700'}`}>
                    {a.message}
                  </div>
                ))}
              </div>

              {/* Resolution */}
              {alert.status === 'resolved' && (
                <div className="mt-3 pt-3 border-t border-gray-100 text-sm text-gray-500">
                  <span className="font-medium">Resolved by:</span> {alert.resolvedByEmail} — {alert.resolution}
                  {alert.resolvedAction === 'block' && (
                    <span className="ml-2 text-red-600 font-medium">(Account blocked)</span>
                  )}
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export default FraudAlertsPage;
