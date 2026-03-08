import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';

const actionLabels = {
  login: { label: 'Login', color: 'bg-blue-100 text-blue-700' },
  logout: { label: 'Logout', color: 'bg-gray-100 text-gray-700' },
  block_account: { label: 'Block Account', color: 'bg-red-100 text-red-700' },
  unblock_account: { label: 'Unblock Account', color: 'bg-green-100 text-green-700' },
  update_email: { label: 'Update Email', color: 'bg-yellow-100 text-yellow-700' },
  send_recovery_otp: { label: 'Send OTP', color: 'bg-purple-100 text-purple-700' },
  verify_recovery_otp: { label: 'Verify OTP', color: 'bg-indigo-100 text-indigo-700' },
  promote_user: { label: 'Promote Staff', color: 'bg-emerald-100 text-emerald-700' },
  demote_user: { label: 'Demote Staff', color: 'bg-orange-100 text-orange-700' },
};

function ActivityLogPage() {
  const { role } = useAuth();
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filterAction, setFilterAction] = useState('all');

  useEffect(() => {
    loadLogs();
  }, []);

  const loadLogs = async () => {
    try {
      setLoading(true);
      const adminGetActivityLogs = httpsCallable(functions, 'adminGetActivityLogs');
      const result = await adminGetActivityLogs({ limit: 100 });
      setLogs(result.data.logs);
    } catch (err) {
      setError(err.message || 'Failed to load activity logs.');
    } finally {
      setLoading(false);
    }
  };

  const filteredLogs = filterAction === 'all'
    ? logs
    : logs.filter(log => log.action === filterAction);

  const formatDate = (dateStr) => {
    if (!dateStr) return 'N/A';
    const date = new Date(dateStr);
    return date.toLocaleString();
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
      <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg">{error}</div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Activity Log</h2>
          <p className="text-gray-500 text-sm mt-1">
            {role === 'support' ? 'Your recent activity' : 'All admin activity'}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <select
            value={filterAction}
            onChange={(e) => setFilterAction(e.target.value)}
            className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          >
            <option value="all">All Actions</option>
            <option value="login">Logins</option>
            <option value="logout">Logouts</option>
            <option value="block_account">Block Account</option>
            <option value="unblock_account">Unblock Account</option>
            <option value="update_email">Update Email</option>
            <option value="send_recovery_otp">Send OTP</option>
            <option value="verify_recovery_otp">Verify OTP</option>
            <option value="promote_user">Promote Staff</option>
            <option value="demote_user">Demote Staff</option>
          </select>
          <button
            onClick={loadLogs}
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm transition-colors"
          >
            Refresh
          </button>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Time</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Staff</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Action</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Details</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Target</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">IP</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {filteredLogs.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-6 py-12 text-center text-gray-400">
                  No activity logs found
                </td>
              </tr>
            ) : (
              filteredLogs.map((log) => {
                const actionInfo = actionLabels[log.action] || { label: log.action, color: 'bg-gray-100 text-gray-700' };
                return (
                  <tr key={log.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {formatDate(log.timestamp)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">{log.email}</div>
                      <div className="text-xs text-gray-400">{log.role}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${actionInfo.color}`}>
                        {actionInfo.label}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500 max-w-xs truncate">
                      {log.details || log.metadata?.reason || '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {log.targetInfo || log.targetUserId || '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-400 font-mono">
                      {log.ip || '-'}
                    </td>
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

export default ActivityLogPage;
