import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { v4 as uuidv4 } from 'uuid';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';

const placeholderCard = 'bg-white rounded-xl shadow-sm border border-gray-200 p-6 text-sm text-gray-500';

function RevenuePage() {
  const {
    user,
    role,
    isFinance,
    isAdminManager,
    isSuperAdmin,
    isAuditor,
  } = useAuth();

  const [platformWallet, setPlatformWallet] = useState(null);
  const [proposals, setProposals] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [refreshKey, setRefreshKey] = useState(0);

  // Stubbed loaders — real implementations land in commits 2-4.
  const loadPlatformWallet = async () => {
    /* commit 2 */
  };

  const loadProposals = async () => {
    /* commit 3 */
  };

  const loadAll = async () => {
    setLoading(true);
    setError('');
    try {
      await Promise.all([loadPlatformWallet(), loadProposals()]);
    } catch (err) {
      setError(err?.message || 'Failed to load revenue data.');
    } finally {
      setLoading(false);
    }
  };

  const refresh = () => setRefreshKey((k) => k + 1);

  useEffect(() => {
    loadAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [refreshKey]);

  // Reference unused vars so the build doesn't warn while skeleton fields are
  // still pending real wiring in later commits.
  void user;
  void role;
  void platformWallet;
  void proposals;
  void loading;
  void uuidv4;
  void httpsCallable;
  void functions;

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Revenue</h2>
          <p className="text-gray-500 text-sm mt-1">
            Platform wallet, proposals, approvals, and transfers.
          </p>
        </div>
        <button
          onClick={refresh}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm transition-colors"
        >
          Refresh
        </button>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg">
          {error}
        </div>
      )}

      {/* Section 1: Platform Wallet Overview (commit 2) */}
      <div className={placeholderCard}>
        Section 1: Platform Wallet Overview (coming in commit 2)
      </div>

      {/* Section 2: Submit New Proposal — finance only (commit 2) */}
      {isFinance && (
        <div className={placeholderCard}>
          Section 2: Propose Transfer (coming in commit 2)
        </div>
      )}

      {/* Section 3: My Pending Proposals — finance only (commit 3) */}
      {isFinance && (
        <div className={placeholderCard}>
          Section 3: My Pending Proposals (coming in commit 3)
        </div>
      )}

      {/* Section 4: Pending Approvals — admin_manager only (commit 3) */}
      {isAdminManager && (
        <div className={placeholderCard}>
          Section 4: Pending Approvals (coming in commit 3)
        </div>
      )}

      {/* Section 5: Awaiting OTP — super_admin only (commit 4) */}
      {isSuperAdmin && (
        <div className={placeholderCard}>
          Section 5: Awaiting OTP (coming in commit 4)
        </div>
      )}

      {/* Section 6: Emergency Transfer — super_admin only (commit 4) */}
      {isSuperAdmin && (
        <div className={placeholderCard}>
          Section 6: Emergency Transfer (coming in commit 4)
        </div>
      )}

      {/* Section 7: All Transfers History — auditor+ (commit 4) */}
      {isAuditor && (
        <div className={placeholderCard}>
          Section 7: History (coming in commit 4)
        </div>
      )}

      {/* Section 8: Stuck Cases — super_admin only (commit 4) */}
      {isSuperAdmin && (
        <div className={placeholderCard}>
          Section 8: Stuck Cases (coming in commit 4)
        </div>
      )}
    </div>
  );
}

export default RevenuePage;
