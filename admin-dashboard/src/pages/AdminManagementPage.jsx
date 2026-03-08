import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';

function AdminManagementPage() {
  const { isSuper } = useAuth();
  const [admins, setAdmins] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [promoteUid, setPromoteUid] = useState('');
  const [promoteRole, setPromoteRole] = useState('support');
  const [actionLoading, setActionLoading] = useState('');

  useEffect(() => {
    loadAdmins();
  }, []);

  const loadAdmins = async () => {
    try {
      setLoading(true);
      const adminListAdmins = httpsCallable(functions, 'adminListAdmins');
      const result = await adminListAdmins();
      setAdmins(result.data.admins || []);
    } catch (err) {
      setError(err.message || 'Failed to load admins.');
    } finally {
      setLoading(false);
    }
  };

  const handlePromote = async (e) => {
    e.preventDefault();
    if (!promoteUid.trim()) return;

    setActionLoading('promote');
    setError('');

    try {
      const adminPromoteUser = httpsCallable(functions, 'adminPromoteUser');
      await adminPromoteUser({ targetUid: promoteUid.trim(), role: promoteRole });
      setPromoteUid('');
      await loadAdmins();
    } catch (err) {
      setError(err.message || 'Failed to promote user.');
    } finally {
      setActionLoading('');
    }
  };

  const handleDemote = async (targetUid) => {
    if (!window.confirm(`Are you sure you want to remove admin privileges from this user?`)) return;

    setActionLoading(targetUid);
    setError('');

    try {
      const adminDemoteUser = httpsCallable(functions, 'adminDemoteUser');
      await adminDemoteUser({ targetUid });
      await loadAdmins();
    } catch (err) {
      setError(err.message || 'Failed to demote user.');
    } finally {
      setActionLoading('');
    }
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
      <h2 className="text-2xl font-bold text-gray-900 mb-6">Admin Management</h2>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      {/* Promote User */}
      <div className="bg-white rounded-lg shadow p-6 mb-6">
        <h3 className="text-lg font-semibold mb-4">Promote User</h3>
        <form onSubmit={handlePromote} className="flex gap-4">
          <input
            type="text"
            value={promoteUid}
            onChange={(e) => setPromoteUid(e.target.value)}
            placeholder="User UID"
            className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
          />
          <select
            value={promoteRole}
            onChange={(e) => setPromoteRole(e.target.value)}
            className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
          >
            <option value="support">Support</option>
            {isSuper && <option value="admin">Admin</option>}
          </select>
          <button
            type="submit"
            disabled={!!actionLoading}
            className="px-6 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg transition-colors disabled:opacity-50"
          >
            {actionLoading === 'promote' ? 'Promoting...' : 'Promote'}
          </button>
        </form>
      </div>

      {/* Admin List */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-semibold">Current Admins</h3>
        </div>
        {admins.length === 0 ? (
          <div className="p-6 text-center text-gray-500">No admin users found.</div>
        ) : (
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">UID</th>
                {isSuper && (
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Action</th>
                )}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {admins.map((admin) => (
                <tr key={admin.uid} className="hover:bg-gray-50">
                  <td className="px-6 py-4 text-sm text-gray-900">{admin.fullName}</td>
                  <td className="px-6 py-4 text-sm text-gray-500">{admin.email}</td>
                  <td className="px-6 py-4">
                    <span className={`px-2 py-1 text-xs rounded-full ${
                      admin.role === 'super_admin' ? 'bg-purple-100 text-purple-800' :
                      admin.role === 'admin' ? 'bg-indigo-100 text-indigo-800' :
                      'bg-blue-100 text-blue-800'
                    }`}>
                      {admin.role}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-xs font-mono text-gray-500">{admin.uid}</td>
                  {isSuper && (
                    <td className="px-6 py-4">
                      {admin.role !== 'super_admin' && (
                        <button
                          onClick={() => handleDemote(admin.uid)}
                          disabled={!!actionLoading}
                          className="text-red-600 hover:text-red-900 text-sm font-medium disabled:opacity-50"
                        >
                          {actionLoading === admin.uid ? 'Removing...' : 'Remove'}
                        </button>
                      )}
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

export default AdminManagementPage;
