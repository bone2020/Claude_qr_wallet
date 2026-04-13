import React, { createContext, useContext, useEffect, useState } from 'react';
import { onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { httpsCallable } from 'firebase/functions';
import { auth, functions } from '../firebase';

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

        if (userRole && ['super_admin', 'admin', 'support'].includes(userRole)) {
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
    let tokenResult = await credential.user.getIdTokenResult(true);
    let userRole = tokenResult.claims.role;

    // If no role yet, try to self-promote via setupSuperAdmin (only works for approved emails)
    if (!userRole) {
      try {
        const setupSuperAdmin = httpsCallable(functions, 'setupSuperAdmin');
        await setupSuperAdmin({});
        // Force token refresh to pick up the new claim
        tokenResult = await credential.user.getIdTokenResult(true);
        userRole = tokenResult.claims.role;
      } catch (e) {
        console.log('setupSuperAdmin not available for this user:', e.message);
      }
    }

    if (!userRole || !['super_admin', 'admin', 'support'].includes(userRole)) {
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
    // Log logout activity before signing out
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

  const value = {
    user,
    role,
    loading,
    login,
    logout,
    isSuper: role === 'super_admin',
    isAdmin: role === 'super_admin' || role === 'admin',
    isSupport: role === 'super_admin' || role === 'admin' || role === 'support',
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}
