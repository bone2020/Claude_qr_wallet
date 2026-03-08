import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './contexts/AuthContext';
import ProtectedRoute from './components/ProtectedRoute';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import UserSearchPage from './pages/UserSearchPage';
import UserDetailsPage from './pages/UserDetailsPage';
import RecoveryPage from './pages/RecoveryPage';
import AdminManagementPage from './pages/AdminManagementPage';

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<DashboardPage />} />
            <Route path="users" element={<UserSearchPage />} />
            <Route path="users/:uid" element={<UserDetailsPage />} />
            <Route path="recovery" element={<RecoveryPage />} />
            <Route path="admins" element={<AdminManagementPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;
