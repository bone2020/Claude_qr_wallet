import React, { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';

const tabActive =
  'border-b-2 border-indigo-600 text-indigo-600 py-4 px-1 font-medium text-sm';
const tabInactive =
  'border-b-2 border-transparent text-gray-500 hover:text-gray-700 py-4 px-1 font-medium text-sm';

function DisputesPage() {
  const { isAdmin, isAdminSupervisor, isAdminManager, isSuperAdmin } = useAuth();

  const tabs = [];
  if (isAdmin) tabs.push({ id: 'all', label: 'All Disputes' });
  if (isAdmin) tabs.push({ id: 'assigned', label: 'My Assigned Cases' });
  if (isAdminSupervisor) tabs.push({ id: 'supervisor', label: 'Supervisor Review' });
  if (isAdminManager) tabs.push({ id: 'manager', label: 'Manager Decision' });
  if (isSuperAdmin) tabs.push({ id: 'escalated', label: 'Escalated to Super Admin' });
  if (isSuperAdmin) tabs.push({ id: 'stuck', label: 'Stuck Cases' });

  const [activeTab, setActiveTab] = useState(tabs[0]?.id || 'all');

  if (tabs.length === 0) {
    return (
      <div className="space-y-6 p-6">
        <h1 className="text-2xl font-bold text-gray-900">Disputes</h1>
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 text-sm text-gray-500">
          You do not have access to dispute management.
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 p-6">
      <h1 className="text-2xl font-bold text-gray-900">Disputes</h1>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <div className="border-b border-gray-200">
          <nav className="flex space-x-4 px-6 overflow-x-auto" aria-label="Tabs">
            {tabs.map((t) => (
              <button
                key={t.id}
                onClick={() => setActiveTab(t.id)}
                className={activeTab === t.id ? tabActive : tabInactive}
              >
                {t.label}
              </button>
            ))}
          </nav>
        </div>

        <div className="p-6 text-sm text-gray-500">
          {activeTab === 'all' && <div>All Disputes — coming in commit 2</div>}
          {activeTab === 'assigned' && <div>My Assigned Cases — coming in commit 2</div>}
          {activeTab === 'supervisor' && <div>Supervisor Review — coming in commit 3</div>}
          {activeTab === 'manager' && <div>Manager Decision — coming in commit 3</div>}
          {activeTab === 'escalated' && <div>Escalated — coming in commit 4</div>}
          {activeTab === 'stuck' && <div>Stuck Cases — coming in commit 4</div>}
        </div>
      </div>
    </div>
  );
}

export default DisputesPage;
