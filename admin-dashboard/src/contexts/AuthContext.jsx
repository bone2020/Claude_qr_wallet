import React, { createContext, useContext, useEffect, useState } from 'react';
import { onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { httpsCallable } from 'firebase/functions';
import { auth, functions } from '../firebase';

// 8-role hierarchy. Must stay in sync with verifyAdmin in functions/index.js.
// (Q-03 decision was 7-role; finance was added later between admin_supervisor
// and admin_manager — see commit 24c45fb.)
const ROLE_LEVELS = {
  viewer: 1,
  auditor: 2,
  support: 3,
  admin: 4,
  admin_supervisor: 5,
  finance: 6,
  admin_manager: 7,
  super_admin: 8,
};

const VALID_ROLES = Object.keys(ROLE_LEVELS);

const AuthContext = createContext(null);

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [role, setRole] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        const tokenResult = await firebaseUser.getIdTokenResult(true);
        const userRole = tokenResult.claims.role;

        if (userRole && VALID_ROLES.includes(userRole)) {
          setUser(firebaseUser);
          setRole(userRole);
        } else {
          await signOut(auth);
          setUser(null);
          setRole(null);
        }
      } else {
        setUser(null);
        setRole(null);
      }
      setLoading(false);
    });

    return unsubscribe;
  }, []);

  const login = async (email, password) => {
    const credential = await signInWithEmailAndPassword(auth, email, password);
    const tokenResult = await credential.user.getIdTokenResult(true);
    const userRole = tokenResult.claims.role;

    // H-03: Removed auto-call to setupSuperAdmin. Users without a role are
    // rejected here. Admins are provisioned via adminPromoteUser/promoteSuperAdmin.
    if (!userRole || !VALID_ROLES.includes(userRole)) {
      await signOut(auth);
      throw new Error('You do not have admin privileges.');
    }

    setRole(userRole);

    // Log login activity
    try {
      const logActivity = httpsCallable(functions, 'adminLogActivity');
      await logActivity({ action: 'login', metadata: { timestamp: new Date().toISOString() } });
    } catch (e) {
      console.error('Failed to log login activity:', e);
    }

    return credential.user;
  };

  const logout = async () => {
    try {
      const logActivity = httpsCallable(functions, 'adminLogActivity');
      await logActivity({ action: 'logout', metadata: { timestamp: new Date().toISOString() } });
    } catch (e) {
      console.error('Failed to log logout activity:', e);
    }

    await signOut(auth);
    setUser(null);
    setRole(null);
  };

  // Helper: check if current user can promote/demote target to a specific role
  const canChangeRoleTo = (targetRole) => {
    if (!role) return false;
    if (!VALID_ROLES.includes(targetRole)) return false;
    // Caller must be strictly above target level
    return ROLE_LEVELS[role] > ROLE_LEVELS[targetRole];
  };

  // Helper: get list of roles current user can promote/demote to
  const availableTargetRoles = () => {
    if (!role) return [];
    const callerLevel = ROLE_LEVELS[role];
    return VALID_ROLES.filter(r => ROLE_LEVELS[r] < callerLevel);
  };

  const value = {
    user,
    role,
    loading,
    login,
    logout,

    // Numeric level for comparisons
    currentLevel: role ? ROLE_LEVELS[role] : 0,

    // Per-role flags (true if at this level or above)
    isSuperAdmin: role === 'super_admin',
    isAdminManager: role ? ROLE_LEVELS[role] >= ROLE_LEVELS.admin_manager : false,
    isFinance: role ? ROLE_LEVELS[role] >= ROLE_LEVELS.finance : false,
    isAdminSupervisor: role ? ROLE_LEVELS[role] >= ROLE_LEVELS.admin_supervisor : false,
    isAdmin: role ? ROLE_LEVELS[role] >= ROLE_LEVELS.admin : false,
    isSupport: role ? ROLE_LEVELS[role] >= ROLE_LEVELS.support : false,
    isAuditor: role ? ROLE_LEVELS[role] >= ROLE_LEVELS.auditor : false,
    isViewer: role ? ROLE_LEVELS[role] >= ROLE_LEVELS.viewer : false,

    // Backward compat alias for isSuperAdmin (some pages still use isSuper)
    isSuper: role === 'super_admin',

    // Helpers for role management UI
    canChangeRoleTo,
    availableTargetRoles,
    ROLE_LEVELS,
    VALID_ROLES,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

// Export constants for use by other components
export { ROLE_LEVELS, VALID_ROLES };
