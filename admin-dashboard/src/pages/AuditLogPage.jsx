import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { exportToCSV } from '../utils/csvExport';

function AuditLogPage() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    loadLogs();
  }, []);

  const loadLogs = async () => {
    try {
      setLoading(true);
      const adminGetAuditLogs = httpsCallable(functions, 'adminGetAuditLogs');
      const result = await adminGetAuditLogs({ limit: 100 });
      setLogs(result.data.logs);
    } catch (err) {
      setError(err.message || 'Failed to load audit logs.');
    } finally {
      setLoading(false);
    }
  };

  const handleExportAudit = () => {
    exportToCSV(logs, 'audit_logs', [
      { key: 'timestamp', label: 'Date' },
      { key: 'operation', label: 'Operation' },
      { key: 'result', label: 'Result' },
      { key: 'userId', label: 'User ID' },
      { key: 'amount', label: 'Amount' },
      { key: 'currency', label: 'Currency' },
      { key: 'error', label: 'Error' },
      { key: 'metadata', label: 'Metadata' },
    ]);
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return 'N/A';
    return new Date(dateStr).toLocaleString();
  };

  const resultColors = {
    success: 'bg-green-100 text-green-700',
    failure: 'bg-red-100 text-red-700',
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
          <h2 className="text-2xl font-bold text-gray-900">Audit Logs</h2>
          <p className="text-gray-500 text-sm mt-1">System-wide operation logs</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={handleExportAudit}
            className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg text-sm transition-colors"
          >
            Export CSV
          </button>
          <button
            onClick={loadLogs}
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm transition-colors"
          >
            Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg mb-6">{error}</div>
      )}

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Operation</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Result</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">User ID</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Details</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {logs.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-6 py-12 text-center text-gray-400">No audit logs found</td>
              </tr>
            ) : (
              logs.map((log) => (
                <tr key={log.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{formatDate(log.timestamp)}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{log.operation}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${resultColors[log.result] || 'bg-gray-100 text-gray-700'}`}>
                      {log.result}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 font-mono">{log.userId || '-'}</td>
                  <td className="px-6 py-4 text-sm text-gray-500 max-w-md truncate">
                    {log.amount ? `Amount: ${log.amount} ${log.currency || ''}` : ''}
                    {log.error ? ` Error: ${log.error}` : ''}
                    {log.metadata ? ` ${JSON.stringify(log.metadata).slice(0, 100)}` : ''}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default AuditLogPage;
