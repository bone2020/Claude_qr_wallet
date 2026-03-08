import React, { createContext, useContext, useEffect, useState } from 'react';
import { onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { auth } from '../firebase';

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
        // Get custom claims to check admin role
        const tokenResult = await firebaseUser.getIdTokenResult();
        const userRole = tokenResult.claims.role;

        if (userRole && ['super_admin', 'admin', 'support'].includes(userRole)) {
          setUser(firebaseUser);
          setRole(userRole);
        } else {
          // Not an admin — sign them out
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
    const tokenResult = await credential.user.getIdTokenResult();
    const userRole = tokenResult.claims.role;

    if (!userRole || !['super_admin', 'admin', 'support'].includes(userRole)) {
      await signOut(auth);
      throw new Error('You do not have admin privileges.');
    }

    setRole(userRole);
    return credential.user;
  };

  const logout = async () => {
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
