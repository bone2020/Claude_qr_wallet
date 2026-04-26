import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

function Sidebar() {
  const { user, role, logout, isAdmin, isAdminSupervisor, isAuditor } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  const linkClass = ({ isActive }) =>
    `block px-4 py-2.5 rounded-lg text-sm transition-colors ${
      isActive
        ? 'bg-indigo-600 text-white font-medium'
        : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
    }`;

  return (
    <div className="w-64 bg-white border-r border-gray-200 min-h-screen flex flex-col">
      <div className="p-6 border-b border-gray-200">
        <h1 className="text-xl font-bold text-indigo-600">QR Wallet</h1>
        <p className="text-xs text-gray-400 mt-1">{role}</p>
      </div>

      <nav className="flex-1 p-4 space-y-1">
        <NavLink to="/" end className={linkClass}>Dashboard</NavLink>
        <NavLink to="/users" className={linkClass}>User Search</NavLink>
        {isAdmin && <NavLink to="/transactions" className={linkClass}>Transactions</NavLink>}
        <NavLink to="/fraud" className={linkClass}>Fraud Alerts</NavLink>
        <NavLink to="/recovery" className={linkClass}>Account Recovery</NavLink>
        <NavLink to="/activity" className={linkClass}>Activity Log</NavLink>

        {isAdmin && (
          <>
            <NavLink to="/revenue" className={linkClass}>Revenue</NavLink>
            <NavLink to="/reports" className={linkClass}>Reports</NavLink>
            <NavLink to="/audit" className={linkClass}>Audit Logs</NavLink>
            <NavLink to="/admins" className={linkClass}>Admin Management</NavLink>
          </>
        )}

        {isAdmin && <NavLink to="/disputes" className={linkClass}>Disputes</NavLink>}
        {isAdminSupervisor && <NavLink to="/recovery-watch" className={linkClass}>Recovery Watch</NavLink>}
        {isAuditor && <NavLink to="/audit-export" className={linkClass}>Audit Export</NavLink>}
      </nav>

      <div className="p-4 border-t border-gray-200">
        <div className="text-sm text-gray-500 mb-2 px-4">{user?.email}</div>
        <button
          onClick={handleLogout}
          className="w-full text-left px-4 py-2.5 rounded-lg text-sm text-red-600 hover:bg-red-50 transition-colors"
        >
          Sign Out
        </button>
      </div>
    </div>
  );
}

export default Sidebar;
