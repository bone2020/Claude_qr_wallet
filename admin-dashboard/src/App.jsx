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
import ActivityLogPage from './pages/ActivityLogPage';
import AuditLogPage from './pages/AuditLogPage';
import RevenuePage from './pages/RevenuePage';
import TransactionsPage from './pages/TransactionsPage';
import ReportsPage from './pages/ReportsPage';
import FraudAlertsPage from './pages/FraudAlertsPage';

const ComingSoon = ({ title }) => (
  <div className="p-8 text-center text-slate-500">
    <h2 className="text-xl font-semibold text-slate-700 mb-2">{title}</h2>
    <p>Coming in Phase 3b.</p>
  </div>
);

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/" element={<ProtectedRoute><Layout /></ProtectedRoute>}>
            <Route index element={<DashboardPage />} />
            <Route path="users" element={<UserSearchPage />} />
            <Route path="users/:uid" element={<UserDetailsPage />} />
            <Route path="recovery" element={<RecoveryPage />} />
            <Route path="transactions" element={<TransactionsPage />} />
            <Route path="fraud" element={<FraudAlertsPage />} />
            <Route path="activity" element={<ActivityLogPage />} />
            <Route path="revenue" element={<RevenuePage />} />
            <Route path="reports" element={<ReportsPage />} />
            <Route path="audit" element={<AuditLogPage />} />
            <Route path="admins" element={<AdminManagementPage />} />
            <Route path="disputes" element={<ComingSoon title="Disputes" />} />
            <Route path="recovery-watch" element={<ComingSoon title="Recovery Watch" />} />
            <Route path="audit-export" element={<ComingSoon title="Audit Export" />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;
