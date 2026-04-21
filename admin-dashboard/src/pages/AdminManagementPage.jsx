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
  const { isSuperAdmin, isAdminManager, isAdminSupervisor, isAdmin, role: callerRole, user, availableTargetRoles, canChangeRoleTo } = useAuth();

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

  // Staff onboarding state (Commit 26b)
  const [onboardingRequests, setOnboardingRequests] = useState([]);
  const [onboardingRecent, setOnboardingRecent] = useState([]);
  const [onboardingLoading, setOnboardingLoading] = useState(false);

  // Request form (supervisor)
  const [reqEmail, setReqEmail] = useState('');
  const [reqDisplayName, setReqDisplayName] = useState('');
  const [reqReason, setReqReason] = useState('');

  // Direct onboarding form (manager+)
  const [directEmail, setDirectEmail] = useState('');
  const [directDisplayName, setDirectDisplayName] = useState('');

  // Reject modal
  const [rejectModal, setRejectModal] = useState(null);   // {requestId, email} | null
  const [rejectReason, setRejectReason] = useState('');

  // Password setup link display modal (after creating an account)
  const [linkModal, setLinkModal] = useState(null);  // {email, link} | null

  // Offboarding modal state (Commit 23d)
  const [removeModal, setRemoveModal] = useState(null);  // {uid, email, role} | null
  const [removeProcessing, setRemoveProcessing] = useState(false);

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
      // Load staff onboarding data in parallel (doesn't block main load)
      loadOnboardingData();
    } catch (err) {
      setError(err.message || 'Failed to load data.');
    } finally {
      setLoading(false);
    }
  };

  // Staff onboarding: load pending requests + recent activity
  const loadOnboardingData = async () => {
    if (!isAdminSupervisor) return;  // No onboarding section visible
    try {
      setOnboardingLoading(true);
      const listFn = httpsCallable(functions, 'staffOnboardingListPending');
      const [pendingRes, approvedRes, setupCompleteRes] = await Promise.all([
        listFn({ status: 'pending' }),
        listFn({ status: 'approved' }),
        listFn({ status: 'setup_complete' }),
      ]);
      setOnboardingRequests(pendingRes.data.requests || []);
      // Recent activity = approved + setup_complete combined, most recent first
      const combined = [
        ...(approvedRes.data.requests || []),
        ...(setupCompleteRes.data.requests || []),
      ].sort((a, b) => {
        const aT = a.requestedAt?._seconds || a.requestedAt?.seconds || 0;
        const bT = b.requestedAt?._seconds || b.requestedAt?.seconds || 0;
        return bT - aT;
      }).slice(0, 10);
      setOnboardingRecent(combined);
    } catch (err) {
      console.warn('Could not load staff onboarding data:', err.message);
    } finally {
      setOnboardingLoading(false);
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
  // Staff onboarding: supervisor submits a request
  const handleStaffRequest = async (e) => {
    e.preventDefault();
    if (!reqEmail.trim() || !reqReason.trim()) return;
    setActionLoading('staff-request');
    try {
      const fn = httpsCallable(functions, 'staffOnboardingRequest');
      await fn({
        email: reqEmail.trim(),
        displayName: reqDisplayName.trim() || null,
        reason: reqReason.trim(),
      });
      setReqEmail('');
      setReqDisplayName('');
      setReqReason('');
      showMessage('Onboarding request submitted. A manager will review.');
      await loadOnboardingData();
    } catch (err) {
      showError(err.message || 'Failed to submit request.');
    } finally {
      setActionLoading('');
    }
  };

  // Staff onboarding: manager onboards directly
  const handleStaffDirect = async (e) => {
    e.preventDefault();
    if (!directEmail.trim()) return;
    setActionLoading('staff-direct');
    try {
      const fn = httpsCallable(functions, 'staffOnboardingDirect');
      const result = await fn({
        email: directEmail.trim(),
        displayName: directDisplayName.trim() || null,
      });
      setDirectEmail('');
      setDirectDisplayName('');
      // Show the password setup link in a modal so manager can copy it
      setLinkModal({ email: result.data.email, link: result.data.passwordResetLink });
      showMessage('Account created. Send the password setup link to the employee.');
      await loadOnboardingData();
    } catch (err) {
      showError(err.message || 'Failed to onboard.');
    } finally {
      setActionLoading('');
    }
  };

  // Staff onboarding: manager approves a pending request
  const handleStaffApprove = async (requestId) => {
    setActionLoading('staff-approve-' + requestId);
    try {
      const fn = httpsCallable(functions, 'staffOnboardingApprove');
      const result = await fn({ requestId });
      setLinkModal({ email: result.data.email, link: result.data.passwordResetLink });
      showMessage('Approved. Send the password setup link to the employee.');
      await loadOnboardingData();
    } catch (err) {
      showError(err.message || 'Failed to approve.');
    } finally {
      setActionLoading('');
    }
  };

  // Staff onboarding: manager opens the reject modal
  const handleStaffOpenReject = (requestId, email) => {
    setRejectModal({ requestId, email });
    setRejectReason('');
  };

  // Staff onboarding: manager confirms rejection from the modal
  const handleStaffReject = async () => {
    if (!rejectModal || !rejectReason.trim() || rejectReason.trim().length < 5) {
      showError('Rejection reason must be at least 5 characters.');
      return;
    }
    setActionLoading('staff-reject-' + rejectModal.requestId);
    try {
      const fn = httpsCallable(functions, 'staffOnboardingReject');
      await fn({ requestId: rejectModal.requestId, reason: rejectReason.trim() });
      setRejectModal(null);
      setRejectReason('');
      showMessage('Request rejected.');
      await loadOnboardingData();
    } catch (err) {
      showError(err.message || 'Failed to reject.');
    } finally {
      setActionLoading('');
    }
  };

  const copyToClipboard = async (text) => {
    try {
      await navigator.clipboard.writeText(text);
      showMessage('Link copied to clipboard.');
    } catch (e) {
      showError('Could not copy. Please select and copy manually.');
    }
  };

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
  // Open the offboarding confirmation modal (Commit 23d).
  // Actual demotion happens in confirmDemote when user clicks confirm.
  const handleDemote = (adminUser) => {
    if (adminUser.uid === user?.uid) {
      showError('You cannot demote yourself.');
      return;
    }
    setRemoveModal({
      uid: adminUser.uid,
      email: adminUser.email || '(unknown)',
      role: adminUser.role,
    });
  };

  // Perform the actual demote after the operator confirms in the modal.
  const confirmDemote = async () => {
    if (!removeModal) return;
    const { uid, role } = removeModal;
    setRemoveProcessing(true);
    try {
      const adminDemoteUser = httpsCallable(functions, 'adminDemoteUser');
      // Send by UID (we already have it from the table). Could send by email
      // too — backend accepts either since 23a — but UID is more direct.
      await adminDemoteUser({ targetUid: uid });
      setRemoveModal(null);
      showMessage(`Admin privileges removed (was ${ROLE_DISPLAY_NAMES[role]}).`);
      await loadAll();
    } catch (err) {
      showError(err.message || 'Failed to demote user.');
    } finally {
      setRemoveProcessing(false);
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

      {/* === STAFF ONBOARDING (Commit 26b) === */}
      {isAdminSupervisor && (
        <div className="bg-white rounded-lg shadow p-6 mb-6">
          <h3 className="text-lg font-semibold mb-2">Staff Onboarding</h3>
          <p className="text-sm text-gray-500 mb-4">
            Create new staff Firebase accounts so they can later be promoted to admin roles.
            Direct creation is reserved for managers; supervisors submit requests for manager approval.
          </p>

          {/* DIRECT ONBOARDING (manager+) */}
          {isAdminManager && (
            <div className="mb-6 border border-indigo-200 rounded-lg p-4 bg-indigo-50/40">
              <h4 className="font-medium text-gray-900 mb-1">Onboard Staff Directly</h4>
              <p className="text-xs text-gray-500 mb-3">
                Creates the staff account immediately. You'll receive a password setup link to email to the new staff member.
              </p>
              <form onSubmit={handleStaffDirect} className="flex flex-wrap gap-3">
                <input
                  type="email"
                  value={directEmail}
                  onChange={(e) => setDirectEmail(e.target.value)}
                  placeholder="staff@bongroups.co"
                  className="flex-1 min-w-[200px] px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
                />
                <input
                  type="text"
                  value={directDisplayName}
                  onChange={(e) => setDirectDisplayName(e.target.value)}
                  placeholder="Full name (optional)"
                  className="flex-1 min-w-[180px] px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
                />
                <button
                  type="submit"
                  disabled={!directEmail.trim() || actionLoading === 'staff-direct'}
                  className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg transition-colors disabled:opacity-50"
                >
                  {actionLoading === 'staff-direct' ? 'Creating...' : 'Create Account'}
                </button>
              </form>
            </div>
          )}

          {/* REQUEST FORM (supervisor only — managers don't need to request from themselves) */}
          {!isAdminManager && (
            <div className="mb-6 border border-gray-200 rounded-lg p-4">
              <h4 className="font-medium text-gray-900 mb-1">Request Staff Onboarding</h4>
              <p className="text-xs text-gray-500 mb-3">
                Submit a request for a manager to approve. Pending more than 5 days will auto-expire.
              </p>
              <form onSubmit={handleStaffRequest} className="space-y-3">
                <div className="flex flex-wrap gap-3">
                  <input
                    type="email"
                    value={reqEmail}
                    onChange={(e) => setReqEmail(e.target.value)}
                    placeholder="staff@bongroups.co"
                    className="flex-1 min-w-[200px] px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
                  />
                  <input
                    type="text"
                    value={reqDisplayName}
                    onChange={(e) => setReqDisplayName(e.target.value)}
                    placeholder="Full name (optional)"
                    className="flex-1 min-w-[180px] px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
                <textarea
                  value={reqReason}
                  onChange={(e) => setReqReason(e.target.value)}
                  placeholder="Reason for onboarding (department, role context, hiring confirmation)"
                  rows={2}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
                />
                <button
                  type="submit"
                  disabled={!reqEmail.trim() || !reqReason.trim() || actionLoading === 'staff-request'}
                  className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg transition-colors disabled:opacity-50"
                >
                  {actionLoading === 'staff-request' ? 'Submitting...' : 'Submit Request'}
                </button>
              </form>
            </div>
          )}

          {/* PENDING REQUESTS QUEUE (manager+) */}
          {isAdminManager && (
            <div className="mb-6">
              <h4 className="font-medium text-gray-900 mb-2">
                Pending Requests
                {onboardingRequests.length > 0 && (
                  <span className="ml-2 inline-block bg-amber-100 text-amber-800 text-xs px-2 py-0.5 rounded-full">
                    {onboardingRequests.length}
                  </span>
                )}
              </h4>
              {onboardingRequests.length === 0 ? (
                <p className="text-sm text-gray-400 italic">No pending requests.</p>
              ) : (
                <div className="space-y-2">
                  {onboardingRequests.map((r) => (
                    <div key={r.id} className="border border-amber-200 rounded-lg p-3 bg-amber-50/30">
                      <div className="flex justify-between items-start gap-3 flex-wrap">
                        <div className="flex-1 min-w-[200px]">
                          <div className="font-medium text-gray-900">{r.email}</div>
                          {r.displayName && <div className="text-sm text-gray-600">{r.displayName}</div>}
                          <div className="text-xs text-gray-500 mt-1">Reason: {r.reason}</div>
                          <div className="text-xs text-gray-400 mt-1">
                            Requested by {r.requestedBy?.email || r.requestedBy?.uid}
                          </div>
                        </div>
                        <div className="flex gap-2">
                          <button
                            onClick={() => handleStaffApprove(r.id)}
                            disabled={actionLoading === 'staff-approve-' + r.id}
                            className="px-3 py-1.5 text-sm bg-green-600 hover:bg-green-700 text-white rounded transition-colors disabled:opacity-50"
                          >
                            {actionLoading === 'staff-approve-' + r.id ? 'Approving...' : 'Approve'}
                          </button>
                          <button
                            onClick={() => handleStaffOpenReject(r.id, r.email)}
                            disabled={actionLoading === 'staff-reject-' + r.id}
                            className="px-3 py-1.5 text-sm bg-gray-200 hover:bg-gray-300 text-gray-700 rounded transition-colors disabled:opacity-50"
                          >
                            Reject
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* RECENT ACTIVITY */}
          {onboardingRecent.length > 0 && (
            <div>
              <h4 className="font-medium text-gray-900 mb-2">Recent Onboardings</h4>
              <div className="space-y-1 text-sm">
                {onboardingRecent.map((r) => (
                  <div key={r.id} className="flex justify-between items-center py-1 px-2 hover:bg-gray-50 rounded">
                    <div>
                      <span className="font-medium">{r.email}</span>
                      <span className={
                        'ml-2 text-xs px-2 py-0.5 rounded-full ' +
                        (r.status === 'setup_complete'
                          ? 'bg-green-100 text-green-800'
                          : 'bg-blue-100 text-blue-800')
                      }>
                        {r.status === 'setup_complete' ? 'Ready to Promote' : 'Setup Pending'}
                      </span>
                    </div>
                    {r.passwordResetLink && (
                      <button
                        onClick={() => setLinkModal({ email: r.email, link: r.passwordResetLink })}
                        className="text-xs text-indigo-600 hover:underline"
                      >
                        View Setup Link
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}
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
                          onClick={() => handleDemote(adminUser)}
                          disabled={!!actionLoading}
                          className="text-red-600 hover:text-red-900 text-sm font-medium disabled:opacity-50"
                        >
                          {actionLoading === adminUser.uid ? 'Removing...' : 'Remove from Admin Team'}
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

      {/* Password setup link modal (Commit 26b) */}
      {linkModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-2xl max-w-lg w-full p-6">
            <h3 className="text-lg font-bold text-gray-900 mb-2">Account Created</h3>
            <p className="text-sm text-gray-600 mb-4">
              Send this password setup link to <span className="font-medium">{linkModal.email}</span>.
              They'll click it to create their password and complete signup.
            </p>
            <div className="bg-gray-50 rounded-lg p-3 mb-4">
              <p className="text-xs text-gray-500 mb-1">Password setup link:</p>
              <div className="font-mono text-xs break-all text-gray-700 bg-white p-2 rounded border border-gray-200">
                {linkModal.link}
              </div>
            </div>
            <p className="text-xs text-gray-500 mb-6 bg-amber-50 rounded p-2">
              <span className="font-medium">Important:</span> this link is the only way for them to set a password.
              Anyone with the link can take over the account. Send it via your company email; do not share publicly.
              Email infrastructure is the next session task; for now, copy and email manually.
            </p>
            <div className="flex gap-2">
              <button
                onClick={() => copyToClipboard(linkModal.link)}
                className="flex-1 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium transition-colors"
              >
                Copy Link
              </button>
              <button
                onClick={() => setLinkModal(null)}
                className="flex-1 px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg font-medium transition-colors"
              >
                Done
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reject request modal (Commit 26b) */}
      {rejectModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-2xl max-w-md w-full p-6">
            <h3 className="text-lg font-bold text-gray-900 mb-2">Reject Request?</h3>
            <p className="text-sm text-gray-600 mb-4">
              Rejecting the onboarding request for <span className="font-medium">{rejectModal.email}</span>.
              The supervisor will see your reason.
            </p>
            <textarea
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              placeholder="Reason for rejection (at least 5 characters)"
              rows={3}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
              autoFocus
            />
            <div className="flex gap-2 mt-4">
              <button
                onClick={() => { setRejectModal(null); setRejectReason(''); }}
                className="flex-1 px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg font-medium transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleStaffReject}
                disabled={!rejectReason.trim() || rejectReason.trim().length < 5 || actionLoading.startsWith('staff-reject-')}
                className="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium transition-colors disabled:opacity-50"
              >
                {actionLoading.startsWith('staff-reject-') ? 'Rejecting...' : 'Reject Request'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Offboarding confirmation modal (Commit 23d) */}
      {removeModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-2xl max-w-md w-full p-6">
            <h3 className="text-lg font-bold text-gray-900 mb-2">Remove from Admin Team?</h3>

            <div className="bg-gray-50 rounded-lg p-3 mb-4 text-sm">
              <div className="flex justify-between mb-1">
                <span className="text-gray-500">User:</span>
                <span className="font-medium">{removeModal.email}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Current role:</span>
                <span className="font-medium">{ROLE_DISPLAY_NAMES[removeModal.role] || removeModal.role}</span>
              </div>
            </div>

            <p className="text-sm text-gray-700 mb-2">This will:</p>
            <ul className="text-sm text-gray-600 space-y-1 mb-4 ml-4 list-disc">
              <li>Remove their admin role and all admin access</li>
              <li>Force-log them out within minutes</li>
              <li>Remove them from this admin list</li>
            </ul>

            <p className="text-xs text-gray-500 mb-6 bg-gray-50 rounded p-2">
              Their wallet account remains active. They can still use the app
              as a regular customer.
            </p>

            <div className="flex gap-2">
              <button
                onClick={() => setRemoveModal(null)}
                disabled={removeProcessing}
                className="flex-1 px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg font-medium transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={confirmDemote}
                disabled={removeProcessing}
                className="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium transition-colors disabled:opacity-50"
              >
                {removeProcessing ? 'Removing...' : 'Remove from Admin Team'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default AdminManagementPage;
