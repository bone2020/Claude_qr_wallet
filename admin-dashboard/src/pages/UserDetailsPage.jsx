import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';

function UserDetailsPage() {
  const { uid } = useParams();
  const navigate = useNavigate();
  const { isAdmin } = useAuth();
  const [userData, setUserData] = useState(null);
  const [wallet, setWallet] = useState(null);
  const [transactions, setTransactions] = useState([]);
  const [kycDocuments, setKycDocuments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [actionLoading, setActionLoading] = useState('');
  const [blockReason, setBlockReason] = useState('');

  useEffect(() => {
    loadUserDetails();
  }, [uid]);

  const loadUserDetails = async () => {
    try {
      setLoading(true);
      const adminGetUserDetails = httpsCallable(functions, 'adminGetUserDetails');
      const result = await adminGetUserDetails({ targetUid: uid });
      setUserData(result.data.user);
      setWallet(result.data.wallet);
      setTransactions(result.data.transactions || []);
      setKycDocuments(result.data.kycDocuments || []);
    } catch (err) {
      setError(err.message || 'Failed to load user details.');
    } finally {
      setLoading(false);
    }
  };

  const handleBlock = async () => {
    if (!window.confirm('Are you sure you want to block this account?')) return;
    setActionLoading('block');
    try {
      const adminBlockAccount = httpsCallable(functions, 'adminBlockAccount');
      await adminBlockAccount({ targetUid: uid, reason: blockReason });
      await loadUserDetails();
      setBlockReason('');
    } catch (err) {
      alert(err.message || 'Failed to block account.');
    } finally {
      setActionLoading('');
    }
  };

  const handleUnblock = async () => {
    if (!window.confirm('Are you sure you want to unblock this account?')) return;
    setActionLoading('unblock');
    try {
      const adminUnblockAccount = httpsCallable(functions, 'adminUnblockAccount');
      await adminUnblockAccount({ targetUid: uid });
      await loadUserDetails();
    } catch (err) {
      alert(err.message || 'Failed to unblock account.');
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

  if (error) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg">
        {error}
        <button onClick={() => navigate('/users')} className="ml-4 text-indigo-600 underline">
          Back to Search
        </button>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-2xl font-bold text-gray-900">User Details</h2>
        <button
          onClick={() => navigate('/users')}
          className="px-4 py-2 text-sm bg-gray-200 hover:bg-gray-300 rounded-lg transition-colors"
        >
          Back to Search
        </button>
      </div>

      {/* User Info */}
      <div className="bg-white rounded-lg shadow p-6 mb-6">
        <h3 className="text-lg font-semibold mb-4">Profile</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <p className="text-sm text-gray-500">Full Name</p>
            <p className="font-medium">{userData?.fullName || 'N/A'}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Email</p>
            <p className="font-medium">{userData?.email || 'N/A'}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Phone</p>
            <p className="font-medium">{userData?.phoneNumber || 'N/A'}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Country</p>
            <p className="font-medium">{userData?.countryCode || 'N/A'}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">KYC Status</p>
            <span className={`px-2 py-1 text-xs rounded-full ${
              userData?.kycStatus === 'completed' ? 'bg-green-100 text-green-800' :
              userData?.kycStatus === 'pending' ? 'bg-yellow-100 text-yellow-800' :
              'bg-gray-100 text-gray-800'
            }`}>
              {userData?.kycStatus || 'none'}
            </span>
          </div>
          <div>
            <p className="text-sm text-gray-500">Account Status</p>
            <span className={`px-2 py-1 text-xs rounded-full ${
              userData?.accountBlocked ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'
            }`}>
              {userData?.accountBlocked ? `Blocked (${userData?.accountBlockedBy || 'unknown'})` : 'Active'}
            </span>
          </div>
          <div>
            <p className="text-sm text-gray-500">Email Verified</p>
            <p className="font-medium">{userData?.emailVerified ? 'Yes' : 'No'}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Phone Verified</p>
            <p className="font-medium">{userData?.phoneVerified ? 'Yes' : 'No'}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">UID</p>
            <p className="font-mono text-xs text-gray-600">{uid}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Role</p>
            <p className="font-medium">{userData?.role || 'user'}</p>
          </div>
        </div>
      </div>

      {/* Wallet */}
      {wallet && (
        <div className="bg-white rounded-lg shadow p-6 mb-6">
          <h3 className="text-lg font-semibold mb-4">Wallet</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <p className="text-sm text-gray-500">Wallet ID</p>
              <p className="font-mono text-xs">{wallet.id}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Balance</p>
              <p className="text-2xl font-bold text-green-600">
                {wallet.currency} {wallet.balance?.toFixed(2)}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Currency</p>
              <p className="font-medium">{wallet.currency}</p>
            </div>
          </div>
        </div>
      )}

      {/* Admin Actions */}
      {isAdmin && (
        <div className="bg-white rounded-lg shadow p-6 mb-6">
          <h3 className="text-lg font-semibold mb-4">Admin Actions</h3>
          <div className="space-y-4">
            {userData?.accountBlocked ? (
              <button
                onClick={handleUnblock}
                disabled={!!actionLoading}
                className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-colors disabled:opacity-50"
              >
                {actionLoading === 'unblock' ? 'Unblocking...' : 'Unblock Account'}
              </button>
            ) : (
              <div className="flex items-center gap-4">
                <input
                  type="text"
                  value={blockReason}
                  onChange={(e) => setBlockReason(e.target.value)}
                  placeholder="Reason for blocking..."
                  className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500"
                />
                <button
                  onClick={handleBlock}
                  disabled={!!actionLoading}
                  className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors disabled:opacity-50"
                >
                  {actionLoading === 'block' ? 'Blocking...' : 'Block Account'}
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Recent Transactions */}
      <div className="bg-white rounded-lg shadow p-6 mb-6">
        <h3 className="text-lg font-semibold mb-4">Recent Transactions</h3>
        {transactions.length === 0 ? (
          <p className="text-gray-500 text-sm">No transactions found.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Amount</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Currency</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Description</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {transactions.map((tx) => (
                  <tr key={tx.id} className="hover:bg-gray-50">
                    <td className="px-4 py-2 text-sm">{tx.type}</td>
                    <td className="px-4 py-2 text-sm font-medium">{tx.amount?.toFixed(2)}</td>
                    <td className="px-4 py-2 text-sm">{tx.currency}</td>
                    <td className="px-4 py-2">
                      <span className={`px-2 py-1 text-xs rounded-full ${
                        tx.status === 'completed' ? 'bg-green-100 text-green-800' :
                        tx.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                        tx.status === 'failed' ? 'bg-red-100 text-red-800' :
                        'bg-gray-100 text-gray-800'
                      }`}>
                        {tx.status}
                      </span>
                    </td>
                    <td className="px-4 py-2 text-sm text-gray-500">{tx.description}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* KYC Documents */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-semibold mb-4">KYC Documents</h3>
        {kycDocuments.length === 0 ? (
          <p className="text-gray-500 text-sm">No KYC documents found.</p>
        ) : (
          <div className="space-y-2">
            {kycDocuments.map((doc) => (
              <div key={doc.id} className="p-3 bg-gray-50 rounded-lg">
                <p className="text-sm font-medium">{doc.type || doc.id}</p>
                <p className="text-xs text-gray-500">Status: {doc.status || 'unknown'}</p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export default UserDetailsPage;
