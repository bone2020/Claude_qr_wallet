import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { useAuth, ROLE_LEVELS } from '../contexts/AuthContext';

// Color badges for each role
const ROLE_BADGE_STYLES = {
  super_admin: 'bg-purple-100 text-purple-800',
  admin_manager: 'bg-red-100 text-red-800',
  finance: 'bg-yellow-100 text-yellow-800',
  admin_supervisor: 'bg-orange-100 text-orange-800',
  admin: 'bg-indigo-100 text-indigo-800',
  support: 'bg-blue-100 text-blue-800',
  auditor: 'bg-green-100 text-green-800',
  viewer: 'bg-gray-100 text-gray-800',
};

const ROLE_DISPLAY_NAMES = {
  super_admin: 'Super Admin',
  admin_manager: 'Admin Manager',
  finance: 'Finance',
  admin_supervisor: 'Admin Supervisor',
  admin: 'Admin',
  support: 'Support',
  auditor: 'Auditor',
  viewer: 'Viewer',
};

function AdminManagementPage() {
  const { isSuperAdmin, isAdmin, role: callerRole, user, availableTargetRoles, canChangeRoleTo } = useAuth();

  // Loading + errors
  const [admins, setAdmins] = useState([]);
  const [allowlist, setAllowlist] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [actionLoading, setActionLoading] = useState('');

  // Change role form state
  const [targetUid, setTargetUid] = useState('');
  const [targetRole, setTargetRole] = useState(availableTargetRoles()[0] || '');

  // Promote super_admin form state
  const [superAdminUid, setSuperAdminUid] = useState('');
  const [showSuperAdminConfirm, setShowSuperAdminConfirm] = useState(false);

  // Allowlist form state
  const [allowlistEmail, setAllowlistEmail] = useState('');

  // Lookup state for current-role display under email/UID inputs
  const [changeRoleLookup, setChangeRoleLookup] = useState(null);    // {exists, role, isAdmin, email} | null
  const [superAdminLookup, setSuperAdminLookup] = useState(null);
  const [changeRoleLookupLoading, setChangeRoleLookupLoading] = useState(false);
  const [superAdminLookupLoading, setSuperAdminLookupLoading] = useState(false);

  useEffect(() => {
    loadAll();
  }, []);

  // Debounced lookup helper (used by both forms)
  const lookupUserRole = async (input) => {
    const trimmed = input.trim();
    if (!trimmed) return null;
    try {
      const adminLookupUserRole = httpsCallable(functions, 'adminLookupUserRole');
      const payload = trimmed.includes('@')
        ? { targetEmail: trimmed }
        : { targetUid: trimmed };
      const result = await adminLookupUserRole(payload);
      return result.data;
    } catch (e) {
      // Treat lookup failures as 'not found' for graceful UI
      return { exists: false, role: null, isAdmin: false };
    }
  };

  // Debounce: trigger lookup 500ms after user stops typing in Change Role form
  useEffect(() => {
    const trimmed = targetUid.trim();
    if (!trimmed) {
      setChangeRoleLookup(null);
      return;
    }
    setChangeRoleLookupLoading(true);
    const timer = setTimeout(async () => {
      const result = await lookupUserRole(trimmed);
      setChangeRoleLookup(result);
      setChangeRoleLookupLoading(false);
    }, 500);
    return () => { clearTimeout(timer); setChangeRoleLookupLoading(false); };
  }, [targetUid]);

  // Debounce: trigger lookup 500ms after user stops typing in Promote SA form
  useEffect(() => {
    const trimmed = superAdminUid.trim();
    if (!trimmed) {
      setSuperAdminLookup(null);
      return;
    }
    setSuperAdminLookupLoading(true);
    const timer = setTimeout(async () => {
      const result = await lookupUserRole(trimmed);
      setSuperAdminLookup(result);
      setSuperAdminLookupLoading(false);
    }, 500);
    return () => { clearTimeout(timer); setSuperAdminLookupLoading(false); };
  }, [superAdminUid]);

  const loadAll = async () => {
    try {
      setLoading(true);
      setError('');
      const promises = [
        httpsCallable(functions, 'adminListAdmins')(),
      ];
      if (isSuperAdmin) {
        promises.push(httpsCallable(functions, 'adminGetAllowlist')());
      }
      const results = await Promise.all(promises);
      setAdmins(results[0].data.admins || []);
      if (isSuperAdmin && results[1]) {
        setAllowlist(results[1].data.emails || []);
      }
    } catch (err) {
      setError(err.message || 'Failed to load data.');
    } finally {
      setLoading(false);
    }
  };

  const showMessage = (msg) => {
    setMessage(msg);
    setError('');
    setTimeout(() => setMessage(''), 5000);
  };

  const showError = (err) => {
    setError(err);
    setMessage('');
  };

  // === CHANGE ROLE ===
  const handleChangeRole = async (e) => {
    e.preventDefault();
    const trimmed = targetUid.trim();
    if (!trimmed || !targetRole) return;

    setActionLoading('change');
    try {
      const adminPromoteUser = httpsCallable(functions, 'adminPromoteUser');
      // Backend accepts either targetEmail OR targetUid (Commit 23a).
      // Detect format and send the appropriate field.
      const identityField = trimmed.includes('@')
        ? { targetEmail: trimmed }
        : { targetUid: trimmed };
      await adminPromoteUser({ ...identityField, role: targetRole });
      setTargetUid('');
      setChangeRoleLookup(null);
      showMessage(`User role changed to ${ROLE_DISPLAY_NAMES[targetRole]}.`);
      await loadAll();
    } catch (err) {
      showError(err.message || 'Failed to change role.');
    } finally {
      setActionLoading('');
    }
  };

  // === DEMOTE (full removal) ===
  const handleDemote = async (uid, currentRole) => {
    if (uid === user?.uid) {
      showError('You cannot demote yourself.');
      return;
    }
    if (!window.confirm(`Remove all admin privileges from this user (currently ${ROLE_DISPLAY_NAMES[currentRole]})?`)) return;

    setActionLoading(uid);
    try {
      const adminDemoteUser = httpsCallable(functions, 'adminDemoteUser');
      await adminDemoteUser({ targetUid: uid });
      showMessage(`Admin privileges removed.`);
      await loadAll();
    } catch (err) {
      showError(err.message || 'Failed to demote user.');
    } finally {
      setActionLoading('');
    }
  };

  // === PROMOTE TO SUPER ADMIN ===
  const handlePromoteSuperAdmin = async () => {
    const trimmed = superAdminUid.trim();
    if (!trimmed) return;
    setActionLoading('super');
    try {
      const promoteSuperAdmin = httpsCallable(functions, 'promoteSuperAdmin');
      const identityField = trimmed.includes('@')
        ? { targetEmail: trimmed }
        : { targetUid: trimmed };
      await promoteSuperAdmin(identityField);
      setSuperAdminUid('');
      setSuperAdminLookup(null);
      setShowSuperAdminConfirm(false);
      showMessage('User promoted to Super Admin.');
      await loadAll();
    } catch (err) {
      showError(err.message || 'Failed to promote to super_admin.');
      setShowSuperAdminConfirm(false);
    } finally {
      setActionLoading('');
    }
  };

  // === ALLOWLIST MANAGEMENT ===
  const handleAddAllowlist = async (e) => {
    e.preventDefault();
    if (!allowlistEmail.trim()) return;
    setActionLoading('allowlist-add');
    try {
      const updateSuperAdminAllowlist = httpsCallable(functions, 'updateSuperAdminAllowlist');
      await updateSuperAdminAllowlist({ action: 'add', email: allowlistEmail.trim() });
      setAllowlistEmail('');
      showMessage(`${allowlistEmail.trim()} added to allowlist.`);
      await loadAll();
    } catch (err) {
      showError(err.message || 'Failed to add to allowlist.');
    } finally {
      setActionLoading('');
    }
  };

  const handleRemoveAllowlist = async (email) => {
    if (!window.confirm(`Remove ${email} from the super_admin allowlist?`)) return;
    setActionLoading(`allowlist-${email}`);
    try {
      const updateSuperAdminAllowlist = httpsCallable(functions, 'updateSuperAdminAllowlist');
      await updateSuperAdminAllowlist({ action: 'remove', email });
      showMessage(`${email} removed from allowlist.`);
      await loadAll();
    } catch (err) {
      showError(err.message || 'Failed to remove from allowlist.');
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

  // Non-admin users shouldn't see this page at all — handled by ProtectedRoute
  if (!isAdmin) {
    return (
      <div className="p-6 text-center text-gray-500">
        You do not have permission to access admin management.
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
      {message && (
        <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 rounded-lg text-sm">
          {message}
        </div>
      )}

      {/* === CHANGE USER ROLE === */}
      <div className="bg-white rounded-lg shadow p-6 mb-6">
        <h3 className="text-lg font-semibold mb-2">Change User Role</h3>
        <p className="text-sm text-gray-500 mb-2">
          Sets a user's role to your selection. You can move users <span className="font-medium">up or down</span> the
          hierarchy as long as the target role is below your own level.
        </p>
        <p className="text-xs text-gray-400 mb-4">
          Your role: <span className="font-medium">{ROLE_DISPLAY_NAMES[callerRole]}</span>.
          Type a user's email or UID below.
        </p>
        <form onSubmit={handleChangeRole} className="flex flex-wrap gap-4">
          <div className="flex-1 min-w-[200px]">
            <input
              type="text"
              value={targetUid}
              onChange={(e) => setTargetUid(e.target.value)}
              placeholder="User email or UID"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
            />
            {targetUid.trim() && (
              <p className="text-xs mt-1 ml-1">
                {changeRoleLookupLoading && <span className="text-gray-400">Looking up...</span>}
                {!changeRoleLookupLoading && changeRoleLookup && changeRoleLookup.exists && changeRoleLookup.isAdmin && (
                  <span className="text-gray-600">Currently: <span className="font-medium">{ROLE_DISPLAY_NAMES[changeRoleLookup.role] || changeRoleLookup.role}</span></span>
                )}
                {!changeRoleLookupLoading && changeRoleLookup && changeRoleLookup.exists && !changeRoleLookup.isAdmin && (
                  <span className="text-gray-600">Currently: <span className="font-medium">no admin role</span> (will be granted on submit)</span>
                )}
                {!changeRoleLookupLoading && changeRoleLookup && !changeRoleLookup.exists && (
                  <span className="text-amber-600">User not found.</span>
                )}
              </p>
            )}
          </div>
          <select
            value={targetRole}
            onChange={(e) => setTargetRole(e.target.value)}
            className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
          >
            {availableTargetRoles().sort((a, b) => ROLE_LEVELS[b] - ROLE_LEVELS[a]).map(r => (
              <option key={r} value={r}>{ROLE_DISPLAY_NAMES[r]}</option>
            ))}
          </select>
          <button
            type="submit"
            disabled={!!actionLoading}
            className="px-6 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg transition-colors disabled:opacity-50"
          >
            {actionLoading === 'change' ? 'Changing...' : 'Change Role'}
          </button>
        </form>
      </div>

      {/* === PROMOTE TO SUPER ADMIN (super_admin only) === */}
      {isSuperAdmin && (
        <div className="bg-white rounded-lg shadow p-6 mb-6 border-2 border-amber-200">
          <h3 className="text-lg font-semibold mb-2 text-amber-800">
            Promote to Super Admin (High Risk)
          </h3>
          <p className="text-sm text-gray-600 mb-4">
            Super admins have full control over the platform including financial operations.
            Only promote trusted users. The user's email must already be on the allowlist below.
          </p>
          <div className="flex flex-wrap gap-4">
            <div className="flex-1 min-w-[200px]">
              <input
                type="text"
                value={superAdminUid}
                onChange={(e) => setSuperAdminUid(e.target.value)}
                placeholder="User email or UID"
                className="w-full px-3 py-2 border border-amber-300 rounded-lg focus:ring-2 focus:ring-amber-500"
              />
              {superAdminUid.trim() && (
                <p className="text-xs mt-1 ml-1">
                  {superAdminLookupLoading && <span className="text-gray-400">Looking up...</span>}
                  {!superAdminLookupLoading && superAdminLookup && superAdminLookup.exists && superAdminLookup.isAdmin && (
                    <span className="text-gray-600">Currently: <span className="font-medium">{ROLE_DISPLAY_NAMES[superAdminLookup.role] || superAdminLookup.role}</span></span>
                  )}
                  {!superAdminLookupLoading && superAdminLookup && superAdminLookup.exists && !superAdminLookup.isAdmin && (
                    <span className="text-gray-600">Currently: <span className="font-medium">no admin role</span></span>
                  )}
                  {!superAdminLookupLoading && superAdminLookup && !superAdminLookup.exists && (
                    <span className="text-amber-600">User not found.</span>
                  )}
                </p>
              )}
            </div>
            <button
              onClick={() => setShowSuperAdminConfirm(true)}
              disabled={!superAdminUid.trim() || !!actionLoading}
              className="px-6 py-2 bg-amber-600 hover:bg-amber-700 text-white rounded-lg transition-colors disabled:opacity-50"
            >
              Promote to Super Admin
            </button>
          </div>

          {showSuperAdminConfirm && (
            <div className="mt-4 p-4 bg-amber-50 border border-amber-300 rounded-lg">
              <p className="text-sm font-medium text-amber-900 mb-3">
                Confirm: This will grant full administrative access to UID {superAdminUid}.
                Are you sure?
              </p>
              <div className="flex gap-2">
                <button
                  onClick={handlePromoteSuperAdmin}
                  disabled={!!actionLoading}
                  className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg text-sm disabled:opacity-50"
                >
                  {actionLoading === 'super' ? 'Promoting...' : 'Yes, promote to Super Admin'}
                </button>
                <button
                  onClick={() => setShowSuperAdminConfirm(false)}
                  disabled={!!actionLoading}
                  className="px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg text-sm disabled:opacity-50"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* === ALLOWLIST MANAGEMENT (super_admin only) === */}
      {isSuperAdmin && (
        <div className="bg-white rounded-lg shadow p-6 mb-6">
          <h3 className="text-lg font-semibold mb-2">Super Admin Allowlist</h3>
          <p className="text-sm text-gray-500 mb-4">
            Emails authorized to be promoted to super_admin. You can add or remove emails here without redeploying code.
          </p>

          <form onSubmit={handleAddAllowlist} className="flex gap-2 mb-4">
            <input
              type="email"
              value={allowlistEmail}
              onChange={(e) => setAllowlistEmail(e.target.value)}
              placeholder="email@example.com"
              className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
            />
            <button
              type="submit"
              disabled={!!actionLoading}
              className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg disabled:opacity-50"
            >
              {actionLoading === 'allowlist-add' ? 'Adding...' : 'Add Email'}
            </button>
          </form>

          {allowlist.length === 0 ? (
            <p className="text-sm text-gray-400 italic">No emails on allowlist.</p>
          ) : (
            <ul className="divide-y divide-gray-200 border border-gray-200 rounded-lg">
              {allowlist.map(email => (
                <li key={email} className="flex items-center justify-between px-4 py-2">
                  <span className="text-sm font-mono">{email}</span>
                  <button
                    onClick={() => handleRemoveAllowlist(email)}
                    disabled={!!actionLoading || email.toLowerCase() === user?.email?.toLowerCase()}
                    className="text-sm text-red-600 hover:text-red-800 disabled:opacity-30 disabled:cursor-not-allowed"
                    title={email.toLowerCase() === user?.email?.toLowerCase() ? 'Cannot remove your own email' : 'Remove'}
                  >
                    {actionLoading === `allowlist-${email}` ? 'Removing...' : 'Remove'}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {/* === CURRENT ADMINS === */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-semibold">Current Admins</h3>
          <p className="text-sm text-gray-500 mt-1">
            {admins.length} admin{admins.length === 1 ? '' : 's'} across all roles.
          </p>
        </div>
        {admins.length === 0 ? (
          <div className="p-6 text-center text-gray-500">No admin users found.</div>
        ) : (
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">UID</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {admins.sort((a, b) => (ROLE_LEVELS[b.role] || 0) - (ROLE_LEVELS[a.role] || 0)).map((adminUser) => {
                const isSelf = adminUser.uid === user?.uid;
                const canDemote = !isSelf && canChangeRoleTo(adminUser.role);
                return (
                  <tr key={adminUser.uid} className={`hover:bg-gray-50 ${isSelf ? 'bg-gray-50 opacity-75' : ''}`}>
                    <td className="px-6 py-4 text-sm text-gray-900">
                      {adminUser.email}
                      {isSelf && <span className="ml-2 text-xs text-gray-500">(you)</span>}
                    </td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 text-xs rounded-full ${ROLE_BADGE_STYLES[adminUser.role] || 'bg-gray-100 text-gray-800'}`}>
                        {ROLE_DISPLAY_NAMES[adminUser.role] || adminUser.role}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-xs font-mono text-gray-500">{adminUser.uid}</td>
                    <td className="px-6 py-4">
                      {isSelf ? (
                        <span className="text-xs text-gray-400 italic">Cannot modify self</span>
                      ) : canDemote ? (
                        <button
                          onClick={() => handleDemote(adminUser.uid, adminUser.role)}
                          disabled={!!actionLoading}
                          className="text-red-600 hover:text-red-900 text-sm font-medium disabled:opacity-50"
                        >
                          {actionLoading === adminUser.uid ? 'Removing...' : 'Remove'}
                        </button>
                      ) : (
                        <span className="text-xs text-gray-400 italic">Above your level</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

export default AdminManagementPage;
