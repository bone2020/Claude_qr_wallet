import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

function Sidebar() {
  const { user, role, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  const linkClass = ({ isActive }) =>
    `block px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
      isActive
        ? 'bg-indigo-600 text-white'
        : 'text-gray-300 hover:bg-gray-700 hover:text-white'
    }`;

  return (
    <div className="w-64 bg-gray-900 text-white flex flex-col">
      <div className="p-4 border-b border-gray-700">
        <h1 className="text-xl font-bold">QR Wallet Admin</h1>
        <p className="text-xs text-gray-400 mt-1">{role}</p>
      </div>

      <nav className="flex-1 p-4 space-y-1">
        <NavLink to="/" end className={linkClass}>
          Dashboard
        </NavLink>
        <NavLink to="/users" className={linkClass}>
          User Search
        </NavLink>
        <NavLink to="/recovery" className={linkClass}>
          Account Recovery
        </NavLink>
        {(role === 'super_admin' || role === 'admin') && (
          <NavLink to="/admins" className={linkClass}>
            Admin Management
          </NavLink>
        )}
      </nav>

      <div className="p-4 border-t border-gray-700">
        <p className="text-xs text-gray-400 truncate">{user?.email}</p>
        <button
          onClick={handleLogout}
          className="mt-2 w-full px-4 py-2 text-sm bg-red-600 hover:bg-red-700 rounded-lg transition-colors"
        >
          Sign Out
        </button>
      </div>
    </div>
  );
}

export default Sidebar;
