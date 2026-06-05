import React, { useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';

const COLLECTIONS = [
  { value: 'audit_logs', label: 'Audit Logs' },
  { value: 'admin_activity', label: 'Admin Activity' },
  { value: 'platform_transfer_proposals', label: 'Transfer Proposals' },
];

function prettyJson(obj) {
  try {
    return JSON.stringify(obj, null, 2);
  } catch {
    return String(obj);
  }
}

function ArchiveRestorePage() {
  const { isFinance, isSuperAdmin } = useAuth();

  const [collection, setCollection] = useState('audit_logs');
  const [docId, setDocId] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [collision, setCollision] = useState(null); // { existingData, archivedData } | null

  const restoreFn = httpsCallable(functions, 'adminRestoreFromArchive');

  const callRestore = async (mode) => {
    const id = docId.trim();
    if (!id) {
      setError('Enter a document ID to restore.');
      return null;
    }
    setLoading(true);
    setError('');
    try {
      const result = await restoreFn({ collection, docId: id, mode });
      return result.data;
    } catch (err) {
      setError(err.message || 'Restore failed.');
      return null;
    } finally {
      setLoading(false);
    }
  };

  const handleRestore = async () => {
    setError('');
    setSuccess('');
    setCollision(null);
    const data = await callRestore('safe');
    if (!data) return;
    if (data.collision) {
      setCollision({ existingData: data.existingData, archivedData: data.archivedData });
    } else if (data.success) {
      setSuccess(`Restored ${data.collection}/${data.docId} successfully.`);
    }
  };

  const handleReplace = async () => {
    const data = await callRestore('overwrite');
    if (!data) return;
    setCollision(null);
    if (data.success) {
      setSuccess(`Replaced the live record at ${data.collection}/${data.docId} with the archived copy.`);
    }
  };

  const handleKeepBoth = async () => {
    const data = await callRestore('keep_both');
    if (!data) return;
    setCollision(null);
    if (data.success) {
      setSuccess(`Kept both. Archived copy restored as ${data.collection}/${data.targetDocId}.`);
    }
  };

  if (!isFinance) {
    return (
      <div>
        <h2 className="text-2xl font-bold text-gray-900">Archive Restore</h2>
        <div className="mt-6 p-4 bg-yellow-50 border border-yellow-200 text-yellow-800 rounded-lg">
          This tool is restricted to finance, manager, and super_admin accounts.
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900">Archive Restore</h2>
        <p className="text-gray-500 text-sm mt-1">
          Restore an archived record back into the live system. Replacing a live record is super_admin only.
        </p>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg mb-6">{error}</div>
      )}
      {success && (
        <div className="p-4 bg-green-50 border border-green-200 text-green-700 rounded-lg mb-6">{success}</div>
      )}

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 max-w-2xl">
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-1">Record type</label>
          <select
            value={collection}
            onChange={(e) => setCollection(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          >
            {COLLECTIONS.map((c) => (
              <option key={c.value} value={c.value}>{c.label}</option>
            ))}
          </select>
        </div>

        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-1">Document ID</label>
          <input
            type="text"
            value={docId}
            onChange={(e) => setDocId(e.target.value)}
            placeholder="e.g. aBc123XyZ"
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm font-mono focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <p className="text-xs text-gray-400 mt-1">
            The ID of the archived record (matches the archived file name).
          </p>
        </div>

        <button
          onClick={handleRestore}
          disabled={loading}
          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg text-sm transition-colors"
        >
          {loading ? 'Working…' : 'Restore'}
        </button>
      </div>

      {collision && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-lg max-w-4xl w-full p-6 max-h-[90vh] overflow-y-auto">
            <h3 className="text-lg font-bold text-gray-900">A live record already exists</h3>
            <p className="text-gray-500 text-sm mt-1 mb-4">
              There is already a live record at{' '}
              <span className="font-mono">{collection}/{docId}</span>. Compare the two below,
              then choose what to do. Nothing has been changed yet.
            </p>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
              <div>
                <div className="text-xs font-semibold text-gray-500 uppercase mb-1">Current live record</div>
                <pre className="bg-gray-50 border border-gray-200 rounded-lg p-3 text-xs overflow-auto max-h-72">
                  {prettyJson(collision.existingData)}
                </pre>
              </div>
              <div>
                <div className="text-xs font-semibold text-gray-500 uppercase mb-1">Archived record (to restore)</div>
                <pre className="bg-gray-50 border border-gray-200 rounded-lg p-3 text-xs overflow-auto max-h-72">
                  {prettyJson(collision.archivedData)}
                </pre>
              </div>
            </div>

            {!isSuperAdmin && (
              <p className="text-xs text-gray-400 mb-3">
                Replacing the live record is restricted to super_admin. You can keep both instead.
              </p>
            )}

            <div className="flex justify-end gap-2">
              <button
                onClick={() => setCollision(null)}
                disabled={loading}
                className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={handleKeepBoth}
                disabled={loading}
                className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm transition-colors disabled:opacity-50"
              >
                {loading ? 'Working…' : 'Keep both'}
              </button>
              {isSuperAdmin && (
                <button
                  onClick={handleReplace}
                  disabled={loading}
                  className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg text-sm transition-colors disabled:opacity-50"
                >
                  {loading ? 'Working…' : 'Replace live record'}
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default ArchiveRestorePage;
