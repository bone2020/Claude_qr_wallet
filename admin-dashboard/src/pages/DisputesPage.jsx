import React, { useEffect, useMemo, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { v4 as uuidv4 } from 'uuid';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';
import DocumentUploadWidget from '../components/DocumentUploadWidget';

const tabActive =
  'border-b-2 border-indigo-600 text-indigo-600 py-4 px-1 font-medium text-sm whitespace-nowrap';
const tabInactive =
  'border-b-2 border-transparent text-gray-500 hover:text-gray-700 py-4 px-1 font-medium text-sm whitespace-nowrap';

const STATUS_OPTIONS = [
  'all',
  'filed',
  'investigating',
  'supervisor_review',
  'manager_review',
  'super_admin_escalation',
  'solved',
  'awaiting_release',
  'resolved',
  'closed',
  'closed_returned',
  'closed_stuck',
];

const currencySymbols = {
  NGN: '₦', GHS: 'GH₵', KES: 'KSh', ZAR: 'R', UGX: 'USh',
  RWF: 'FRw', TZS: 'TSh', EGP: 'E£', USD: '$', GBP: '£', EUR: '€',
};

const symbol = (c) => currencySymbols[c] || c || '';
const formatDate = (iso) => (iso ? new Date(iso).toLocaleString() : '—');

const statusBadgeClass = (status) => {
  switch (status) {
    case 'filed':
      return 'bg-blue-100 text-blue-700';
    case 'investigating':
      return 'bg-indigo-100 text-indigo-700';
    case 'supervisor_review':
      return 'bg-purple-100 text-purple-700';
    case 'manager_review':
      return 'bg-amber-100 text-amber-800';
    case 'super_admin_escalation':
      return 'bg-red-100 text-red-700';
    case 'solved':
      return 'bg-teal-100 text-teal-700';
    case 'awaiting_release':
      return 'bg-orange-100 text-orange-700';
    case 'resolved':
      return 'bg-green-100 text-green-700';
    case 'closed':
      return 'bg-emerald-100 text-emerald-700';
    case 'closed_returned':
      return 'bg-slate-100 text-slate-700';
    case 'closed_stuck':
      return 'bg-gray-200 text-gray-700';
    default:
      return 'bg-gray-100 text-gray-600';
  }
};

function StatusBadge({ status }) {
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${statusBadgeClass(status)}`}>
      {status || 'unknown'}
    </span>
  );
}

function ModalShell({ title, onClose, children, maxWidth = 'max-w-lg' }) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-2 md:p-4">
      <div className={`bg-white rounded-xl shadow-2xl ${maxWidth} w-full p-4 md:p-6 max-h-[90vh] overflow-y-auto`}>
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-bold text-gray-900">{title}</h3>
          <button
            onClick={onClose}
            aria-label="Close"
            className="text-gray-400 hover:text-gray-600 text-2xl leading-none"
          >
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

function DetailsRow({ label, children }) {
  return (
    <div className="grid grid-cols-3 gap-2 py-1.5 border-b border-gray-100 last:border-0">
      <div className="text-xs text-gray-500 uppercase">{label}</div>
      <div className="col-span-2 text-sm text-gray-800 break-words">{children || '—'}</div>
    </div>
  );
}

function DisputeDetailsModal({ dispute, onClose }) {
  return (
    <ModalShell title={`Dispute ${dispute.disputeId || dispute.id}`} onClose={onClose} maxWidth="max-w-2xl">
      <div className="space-y-1">
        <DetailsRow label="Status"><StatusBadge status={dispute.status} /></DetailsRow>
        <DetailsRow label="Filed">{formatDate(dispute.filedAt || dispute.createdAt)}</DetailsRow>
        <DetailsRow label="Expected By">{formatDate(dispute.expectedResolutionBy)}</DetailsRow>
        <DetailsRow label="Filer">
          <div>{dispute.filer?.name || dispute.filerName || '—'}</div>
          <div className="text-xs text-gray-500">{dispute.filer?.email || dispute.filerEmail || ''}</div>
        </DetailsRow>
        <DetailsRow label="Recipient">
          <div>{dispute.recipient?.name || dispute.recipientName || '—'}</div>
          <div className="text-xs text-gray-500">{dispute.recipient?.email || dispute.recipientEmail || ''}</div>
        </DetailsRow>
        <DetailsRow label="Disputed Amount">
          {symbol(dispute.currency)}{(dispute.amount ?? dispute.disputedAmount)?.toFixed?.(2)} {dispute.currency}
        </DetailsRow>
        <DetailsRow label="Original Transaction">
          <span className="font-mono text-xs">{dispute.transactionId || '—'}</span>
        </DetailsRow>
        <DetailsRow label="Description">{dispute.description}</DetailsRow>
        <DetailsRow label="Assigned Admin">
          {dispute.assignedAdmin?.name || dispute.assignedAdminName || (
            <span className="text-gray-400 italic">unassigned</span>
          )}
        </DetailsRow>
        <DetailsRow label="Investigation Findings">{dispute.findings || dispute.investigationFindings}</DetailsRow>
        <DetailsRow label="Supervisor Decision">
          {dispute.supervisorDecision?.decision} {dispute.supervisorDecision?.notes && `— ${dispute.supervisorDecision.notes}`}
        </DetailsRow>
        <DetailsRow label="Manager Decision">
          {dispute.managerDecision?.decision} {dispute.managerDecision?.notes && `— ${dispute.managerDecision.notes}`}
        </DetailsRow>
        {/* Phase 5i E2: escrow tracking, release flow, and closing remarks fields. */}
        <DetailsRow label="Amount in Escrow">
          {dispute.amountInEscrow != null
            ? `${symbol(dispute.disputedCurrency)}${(dispute.amountInEscrow / 100).toFixed(2)} ${dispute.disputedCurrency || ''}`
            : '—'}
        </DetailsRow>
        <DetailsRow label="Amount Owed">
          {dispute.amountOwed != null
            ? `${symbol(dispute.disputedCurrency)}${(dispute.amountOwed / 100).toFixed(2)} ${dispute.disputedCurrency || ''}`
            : '—'}
        </DetailsRow>
        <DetailsRow label="Decision Direction">{dispute.decisionDirection || '—'}</DetailsRow>
        <DetailsRow label="Phase 5i Timeline">
          <div className="space-y-0.5 text-xs">
            <div>Solved: {formatDate(dispute.solvedAt)}</div>
            <div>Awaiting release: {formatDate(dispute.awaitingReleaseAt)}</div>
            <div>Funds fully collected: {formatDate(dispute.fullyCollectedAt)}</div>
            <div>Release confirmed: {formatDate(dispute.releaseConfirmedAt)}</div>
            <div>Release rejected: {formatDate(dispute.releaseRejectedAt)}</div>
          </div>
        </DetailsRow>
        <DetailsRow label="Final Release Direction">{dispute.releaseDirection || '—'}</DetailsRow>
        <DetailsRow label="Closing Remarks">{dispute.closingRemarks || '—'}</DetailsRow>
        <DetailsRow label="Release Proposal">
          {dispute.releaseProposal ? (
            <div className="space-y-0.5 text-xs">
              <div>By: {dispute.releaseProposal.proposedBy?.email || dispute.releaseProposal.proposedBy?.uid || '—'}</div>
              <div>Direction: {dispute.releaseProposal.releaseDirection || '—'}</div>
              <div>Notes: {dispute.releaseProposal.notes || '—'}</div>
              <div>Buyer contacted: {dispute.releaseProposal.buyerContacted ? 'yes' : 'no'}</div>
              <div>Seller contacted: {dispute.releaseProposal.sellerContacted ? 'yes' : 'no'}</div>
              <div>Expires: {formatDate(dispute.releaseProposal.expiresAt)}</div>
            </div>
          ) : (
            '—'
          )}
        </DetailsRow>
        <DetailsRow label="Release Confirmation">
          {dispute.releaseConfirmedBy ? (
            <div>
              {dispute.releaseConfirmedBy.email || dispute.releaseConfirmedBy.uid || 'admin'} on {formatDate(dispute.releaseConfirmedAt)}
            </div>
          ) : (
            '—'
          )}
        </DetailsRow>
        <DetailsRow label="Release Rejection">
          {dispute.releaseRejectedBy ? (
            <div className="space-y-0.5 text-xs">
              <div>By: {dispute.releaseRejectedBy.email || dispute.releaseRejectedBy.uid || 'admin'}</div>
              <div>At: {formatDate(dispute.releaseRejectedAt)}</div>
              <div>Reason: {dispute.releaseRejectionReason || '—'}</div>
            </div>
          ) : (
            '—'
          )}
        </DetailsRow>
        <DetailsRow label="Fee Refunded">{dispute.feeRefunded ? 'yes' : 'no'}</DetailsRow>
      </div>
      <div className="mt-5 flex justify-end">
        <button
          onClick={onClose}
          className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Close
        </button>
      </div>
    </ModalShell>
  );
}

function AssignDisputeModal({ dispute, onClose, onAssigned }) {
  const [adminUid, setAdminUid] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async () => {
    if (!adminUid.trim()) return;
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminAssignDispute')({
        disputeId: dispute.disputeId || dispute.id,
        adminUid: adminUid.trim(),
        idempotencyKey: uuidv4(),
      });
      if (onAssigned) onAssigned();
      onClose();
    } catch (err) {
      setError(err?.message || 'Assignment failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title="Assign Dispute" onClose={onClose}>
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}
      <p className="text-sm text-gray-600 mb-3">
        Enter the UID of the admin who should investigate this dispute.
      </p>
      <label className="text-sm text-gray-600 block mb-1">Admin UID</label>
      <input
        type="text"
        value={adminUid}
        onChange={(e) => setAdminUid(e.target.value)}
        placeholder="Firebase Auth UID"
        autoFocus
        className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
      />
      <div className="flex gap-2 mt-5">
        <button
          onClick={handleSubmit}
          disabled={!adminUid.trim() || submitting}
          className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-3 md:py-2 rounded-lg text-sm font-medium disabled:opacity-50"
        >
          {submitting ? 'Assigning...' : 'Assign'}
        </button>
        <button
          onClick={onClose}
          disabled={submitting}
          className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Cancel
        </button>
      </div>
    </ModalShell>
  );
}

function InvestigationModal({ dispute, onClose, onSubmitted }) {
  const disputeId = dispute.disputeId || dispute.id;
  const [findings, setFindings] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const canSubmit = findings.trim().length >= 50 && !submitting;

  const handleSubmit = async () => {
    if (!canSubmit) return;
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminSubmitInvestigation')({
        disputeId,
        findings: findings.trim(),
        idempotencyKey: uuidv4(),
      });
      if (onSubmitted) onSubmitted();
      onClose();
    } catch (err) {
      setError(err?.message || 'Submission failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title={`Investigate Dispute ${disputeId}`} onClose={onClose} maxWidth="max-w-2xl">
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="space-y-1 mb-4">
        <DetailsRow label="Filer">
          <div>{dispute.filer?.name || dispute.filerName || '—'}</div>
          <div className="text-xs text-gray-500">{dispute.filer?.email || dispute.filerEmail || ''}</div>
        </DetailsRow>
        <DetailsRow label="Recipient">
          <div>{dispute.recipient?.name || dispute.recipientName || '—'}</div>
          <div className="text-xs text-gray-500">{dispute.recipient?.email || dispute.recipientEmail || ''}</div>
        </DetailsRow>
        <DetailsRow label="Original Transaction">
          <span className="font-mono text-xs">{dispute.transactionId || '—'}</span>
        </DetailsRow>
        <DetailsRow label="Disputed Amount">
          {symbol(dispute.currency)}{(dispute.amount ?? dispute.disputedAmount)?.toFixed?.(2)} {dispute.currency}
        </DetailsRow>
        <DetailsRow label="Description">{dispute.description}</DetailsRow>
      </div>

      <div className="mb-4">
        <h4 className="text-sm font-semibold text-gray-700 mb-2">Filer Evidence</h4>
        <DocumentUploadWidget
          proposalId={disputeId}
          documentType="evidence"
          existingFiles={dispute.evidence || dispute.filerEvidence}
          readOnly
          maxFiles={Array.isArray(dispute.evidence) ? Math.max(dispute.evidence.length, 4) : 4}
        />
      </div>

      <div>
        <div className="flex items-center justify-between mb-1">
          <label className="text-sm text-gray-700 font-medium">Investigation Findings</label>
          <span className={`text-xs ${findings.trim().length >= 50 ? 'text-gray-500' : 'text-amber-600'}`}>
            {findings.length} / 50 minimum
          </span>
        </div>
        <textarea
          value={findings}
          onChange={(e) => setFindings(e.target.value)}
          rows={5}
          placeholder="Document what you investigated, what evidence supports the claim, what doesn't, and your recommended next step..."
          className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
        />
      </div>

      <div className="flex gap-2 mt-5">
        <button
          onClick={handleSubmit}
          disabled={!canSubmit}
          className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-3 md:py-2 rounded-lg text-sm font-medium disabled:opacity-50"
        >
          {submitting ? 'Submitting...' : 'Submit Investigation'}
        </button>
        <button
          onClick={onClose}
          disabled={submitting}
          className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Cancel
        </button>
      </div>
    </ModalShell>
  );
}

function useDisputes(statusParam) {
  const [disputes, setDisputes] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setError('');
      try {
        const params = { limit: 50 };
        if (statusParam && statusParam !== 'all') params.status = statusParam;
        const result = await httpsCallable(functions, 'adminListDisputes')(params);
        if (!cancelled) setDisputes(result.data?.disputes || []);
      } catch (err) {
        if (!cancelled) setError(err?.message || 'Failed to load disputes.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => {
      cancelled = true;
    };
  }, [statusParam, refreshKey]);

  const refresh = () => setRefreshKey((k) => k + 1);

  return { disputes, loading, error, refresh };
}

function AllDisputesTab({ canAssign }) {
  const [statusFilter, setStatusFilter] = useState('all');
  const { disputes, loading, error, refresh } = useDisputes(statusFilter);
  const [detailsTarget, setDetailsTarget] = useState(null);
  const [assignTarget, setAssignTarget] = useState(null);

  return (
    <div>
      <div className="flex flex-wrap items-center gap-3 mb-4">
        <label className="text-sm text-gray-600">Status</label>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="border border-gray-300 rounded-lg px-3 py-1.5 text-sm"
        >
          {STATUS_OPTIONS.map((s) => (
            <option key={s} value={s}>{s === 'all' ? 'All statuses' : s}</option>
          ))}
        </select>
        <button
          onClick={refresh}
          disabled={loading}
          className="ml-auto bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg text-sm disabled:opacity-50"
        >
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispute</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filer</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filed</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Expected By</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Assigned</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {disputes.length === 0 ? (
              <tr>
                <td colSpan={9} className="px-3 py-8 text-center text-gray-400 text-sm">
                  {loading ? 'Loading...' : 'No disputes match.'}
                </td>
              </tr>
            ) : (
              disputes.map((d) => {
                const id = d.disputeId || d.id;
                const assigned = d.assignedAdmin?.name || d.assignedAdminName;
                return (
                  <tr key={id} className="hover:bg-gray-50">
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.filer?.name || d.filerName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.filer?.email || d.filerEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.recipient?.name || d.recipientName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.recipient?.email || d.recipientEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {symbol(d.currency)}{(d.amount ?? d.disputedAmount)?.toFixed?.(2)}
                      <div className="text-xs text-gray-400">{d.currency}</div>
                    </td>
                    <td className="px-3 py-2"><StatusBadge status={d.status} /></td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(d.filedAt || d.createdAt)}</td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(d.expectedResolutionBy)}</td>
                    <td className="px-3 py-2 text-xs text-gray-700">
                      {assigned || <span className="text-gray-400 italic">unassigned</span>}
                    </td>
                    <td className="px-3 py-2 text-right whitespace-nowrap">
                      <button
                        onClick={() => setDetailsTarget(d)}
                        className="text-xs text-indigo-600 hover:text-indigo-800 font-medium"
                      >
                        View Details
                      </button>
                      {canAssign && !assigned && (
                        <button
                          onClick={() => setAssignTarget(d)}
                          className="ml-3 text-xs text-amber-700 hover:text-amber-900 font-medium"
                        >
                          Assign
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {detailsTarget && (
        <DisputeDetailsModal dispute={detailsTarget} onClose={() => setDetailsTarget(null)} />
      )}
      {assignTarget && (
        <AssignDisputeModal
          dispute={assignTarget}
          onClose={() => setAssignTarget(null)}
          onAssigned={refresh}
        />
      )}
    </div>
  );
}

function MyAssignedCasesTab({ currentUid }) {
  const [statusFilter, setStatusFilter] = useState('investigating');
  const { disputes, loading, error, refresh } = useDisputes(statusFilter);
  const [investigateTarget, setInvestigateTarget] = useState(null);

  const mine = useMemo(
    () =>
      disputes.filter(
        (d) => (d.assignedAdmin?.uid || d.assignedAdminUid) === currentUid
      ),
    [disputes, currentUid]
  );

  return (
    <div>
      <div className="flex flex-wrap items-center gap-3 mb-4">
        <label className="text-sm text-gray-600">Status</label>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="border border-gray-300 rounded-lg px-3 py-1.5 text-sm"
        >
          {STATUS_OPTIONS.map((s) => (
            <option key={s} value={s}>{s === 'all' ? 'All statuses' : s}</option>
          ))}
        </select>
        <button
          onClick={refresh}
          disabled={loading}
          className="ml-auto bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg text-sm disabled:opacity-50"
        >
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispute</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filer</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Expected By</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {mine.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-3 py-8 text-center text-gray-400 text-sm">
                  {loading ? 'Loading...' : 'No disputes assigned to you.'}
                </td>
              </tr>
            ) : (
              mine.map((d) => {
                const id = d.disputeId || d.id;
                return (
                  <tr key={id} className="hover:bg-gray-50">
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.filer?.name || d.filerName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.filer?.email || d.filerEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.recipient?.name || d.recipientName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.recipient?.email || d.recipientEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {symbol(d.currency)}{(d.amount ?? d.disputedAmount)?.toFixed?.(2)}
                      <div className="text-xs text-gray-400">{d.currency}</div>
                    </td>
                    <td className="px-3 py-2"><StatusBadge status={d.status} /></td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(d.expectedResolutionBy)}</td>
                    <td className="px-3 py-2 text-right whitespace-nowrap">
                      <button
                        onClick={() => setInvestigateTarget(d)}
                        className="text-xs bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg font-medium"
                      >
                        Open Investigation
                      </button>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {investigateTarget && (
        <InvestigationModal
          dispute={investigateTarget}
          onClose={() => setInvestigateTarget(null)}
          onSubmitted={refresh}
        />
      )}
    </div>
  );
}

function DecisionActionModal({
  title,
  cfName,
  basePayload,
  decision,
  requireAmount = false,
  amountMax,
  amountCurrency,
  onClose,
  onSubmitted,
}) {
  const [notes, setNotes] = useState('');
  const [amount, setAmount] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const amountValid =
    !requireAmount ||
    (amount !== '' &&
      Number(amount) > 0 &&
      (amountMax == null || Number(amount) < Number(amountMax)));
  const canSubmit = !submitting && notes.trim().length >= 20 && amountValid;

  const handleSubmit = async () => {
    if (!canSubmit) return;
    setSubmitting(true);
    setError('');
    try {
      const payload = {
        ...basePayload,
        decision,
        notes: notes.trim(),
        idempotencyKey: uuidv4(),
      };
      if (requireAmount) payload.amount = Number(amount);
      await httpsCallable(functions, cfName)(payload);
      if (onSubmitted) onSubmitted();
      onClose();
    } catch (err) {
      setError(err?.message || 'Submission failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title={title} onClose={onClose}>
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      {requireAmount && (
        <div className="mb-3">
          <div className="flex items-center justify-between mb-1">
            <label className="text-sm text-gray-700 font-medium">Refund Amount</label>
            {amountMax != null && (
              <span className="text-xs text-gray-500">
                max recoverable: {symbol(amountCurrency)}{Number(amountMax).toFixed(2)} {amountCurrency}
              </span>
            )}
          </div>
          <input
            type="number"
            step="0.01"
            min="0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
          {amount !== '' && !amountValid && (
            <p className="text-xs text-amber-600 mt-1">
              Amount must be greater than 0 and less than the recoverable hold.
            </p>
          )}
        </div>
      )}

      <div className="flex items-center justify-between mb-1">
        <label className="text-sm text-gray-700 font-medium">Notes</label>
        <span className={`text-xs ${notes.trim().length >= 20 ? 'text-gray-500' : 'text-amber-600'}`}>
          {notes.length} / 20 minimum
        </span>
      </div>
      <textarea
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
        rows={4}
        placeholder="Document the reason for this decision..."
        className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
      />

      <div className="flex gap-2 mt-5">
        <button
          onClick={handleSubmit}
          disabled={!canSubmit}
          className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-3 md:py-2 rounded-lg text-sm font-medium disabled:opacity-50"
        >
          {submitting ? 'Submitting...' : 'Submit'}
        </button>
        <button
          onClick={onClose}
          disabled={submitting}
          className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Cancel
        </button>
      </div>
    </ModalShell>
  );
}

function SupervisorReviewModal({ dispute, onClose, onDecided }) {
  const disputeId = dispute.disputeId || dispute.id;
  const [actionDecision, setActionDecision] = useState(null);

  return (
    <>
      <ModalShell title={`Supervisor Review — ${disputeId}`} onClose={onClose} maxWidth="max-w-2xl">
        <div className="space-y-1 mb-4">
          <DetailsRow label="Status"><StatusBadge status={dispute.status} /></DetailsRow>
          <DetailsRow label="Filer">
            <div>{dispute.filer?.name || dispute.filerName || '—'}</div>
            <div className="text-xs text-gray-500">{dispute.filer?.email || dispute.filerEmail || ''}</div>
          </DetailsRow>
          <DetailsRow label="Recipient">
            <div>{dispute.recipient?.name || dispute.recipientName || '—'}</div>
            <div className="text-xs text-gray-500">{dispute.recipient?.email || dispute.recipientEmail || ''}</div>
          </DetailsRow>
          <DetailsRow label="Disputed Amount">
            {symbol(dispute.currency)}{(dispute.amount ?? dispute.disputedAmount)?.toFixed?.(2)} {dispute.currency}
          </DetailsRow>
          <DetailsRow label="Description">{dispute.description}</DetailsRow>
          <DetailsRow label="Assigned Admin">
            {dispute.assignedAdmin?.name || dispute.assignedAdminName || '—'}
          </DetailsRow>
          <DetailsRow label="Investigation Findings">
            <div className="whitespace-pre-wrap">{dispute.findings || dispute.investigationFindings || '—'}</div>
          </DetailsRow>
        </div>

        <div className="flex gap-2 mt-5">
          <button
            onClick={() => setActionDecision('agree')}
            className="flex-1 bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
          >
            Agree
          </button>
          <button
            onClick={() => setActionDecision('disagree_kickback')}
            className="flex-1 bg-amber-600 hover:bg-amber-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
          >
            Disagree (Kickback)
          </button>
          <button
            onClick={onClose}
            className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
          >
            Close
          </button>
        </div>
      </ModalShell>

      {actionDecision && (
        <DecisionActionModal
          title={
            actionDecision === 'agree'
              ? 'Agree with Investigation'
              : 'Disagree — Kickback to Admin'
          }
          cfName="adminSupervisorDecision"
          basePayload={{ disputeId }}
          decision={actionDecision}
          onClose={() => setActionDecision(null)}
          onSubmitted={() => {
            if (onDecided) onDecided();
            onClose();
          }}
        />
      )}
    </>
  );
}

function ManagerDecisionModal({ dispute, onClose, onDecided }) {
  const disputeId = dispute.disputeId || dispute.id;
  const [actionDecision, setActionDecision] = useState(null);
  const recoverable = dispute.currentHoldAmount ?? dispute.amount ?? dispute.disputedAmount;

  return (
    <>
      <ModalShell title={`Manager Decision — ${disputeId}`} onClose={onClose} maxWidth="max-w-2xl">
        <div className="space-y-1 mb-4">
          <DetailsRow label="Status"><StatusBadge status={dispute.status} /></DetailsRow>
          <DetailsRow label="Filer">
            <div>{dispute.filer?.name || dispute.filerName || '—'}</div>
            <div className="text-xs text-gray-500">{dispute.filer?.email || dispute.filerEmail || ''}</div>
          </DetailsRow>
          <DetailsRow label="Recipient">
            <div>{dispute.recipient?.name || dispute.recipientName || '—'}</div>
            <div className="text-xs text-gray-500">{dispute.recipient?.email || dispute.recipientEmail || ''}</div>
          </DetailsRow>
          <DetailsRow label="Disputed Amount">
            {symbol(dispute.currency)}{(dispute.amount ?? dispute.disputedAmount)?.toFixed?.(2)} {dispute.currency}
          </DetailsRow>
          <DetailsRow label="Currently Held">
            {symbol(dispute.currency)}{Number(recoverable || 0).toFixed(2)} {dispute.currency}
          </DetailsRow>
          <DetailsRow label="Description">{dispute.description}</DetailsRow>
          <DetailsRow label="Investigation Findings">
            <div className="whitespace-pre-wrap">{dispute.findings || dispute.investigationFindings || '—'}</div>
          </DetailsRow>
          <DetailsRow label="Supervisor Decision">
            <div>{dispute.supervisorDecision?.decision || '—'}</div>
            {dispute.supervisorDecision?.notes && (
              <div className="text-xs text-gray-500 whitespace-pre-wrap mt-1">
                {dispute.supervisorDecision.notes}
              </div>
            )}
          </DetailsRow>
        </div>

        <div className="grid grid-cols-2 gap-2 mt-5">
          <button
            onClick={() => setActionDecision('refund_full')}
            className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
          >
            Refund Full
          </button>
          <button
            onClick={() => setActionDecision('refund_partial')}
            className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
          >
            Refund Partial
          </button>
          <button
            onClick={() => setActionDecision('release')}
            className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
          >
            Release
          </button>
          <button
            onClick={() => setActionDecision('kickback')}
            className="bg-amber-600 hover:bg-amber-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
          >
            Kickback
          </button>
        </div>
        <button
          onClick={onClose}
          className="w-full mt-2 px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Close
        </button>
      </ModalShell>

      {actionDecision && (
        <DecisionActionModal
          title={
            actionDecision === 'refund_full'
              ? 'Refund Full to Filer'
              : actionDecision === 'refund_partial'
              ? 'Refund Partial Amount'
              : actionDecision === 'release'
              ? 'Release Funds to Recipient'
              : 'Kickback to Supervisor'
          }
          cfName="adminManagerDecision"
          basePayload={{ disputeId }}
          decision={actionDecision}
          requireAmount={actionDecision === 'refund_partial'}
          amountMax={actionDecision === 'refund_partial' ? recoverable : undefined}
          amountCurrency={dispute.currency}
          onClose={() => setActionDecision(null)}
          onSubmitted={() => {
            if (onDecided) onDecided();
            onClose();
          }}
        />
      )}
    </>
  );
}

function SupervisorReviewTab() {
  const { disputes, loading, error, refresh } = useDisputes('supervisor_review');
  const [target, setTarget] = useState(null);

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-gray-500">
          Disputes awaiting supervisor decision after admin investigation.
        </p>
        <button
          onClick={refresh}
          disabled={loading}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg text-sm disabled:opacity-50"
        >
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispute</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filer</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Investigated By</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Expected By</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {disputes.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-3 py-8 text-center text-gray-400 text-sm">
                  {loading ? 'Loading...' : 'No disputes awaiting supervisor review.'}
                </td>
              </tr>
            ) : (
              disputes.map((d) => {
                const id = d.disputeId || d.id;
                return (
                  <tr
                    key={id}
                    onClick={() => setTarget(d)}
                    className="hover:bg-indigo-50 cursor-pointer"
                  >
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.filer?.name || d.filerName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.filer?.email || d.filerEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.recipient?.name || d.recipientName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.recipient?.email || d.recipientEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {symbol(d.currency)}{(d.amount ?? d.disputedAmount)?.toFixed?.(2)}
                      <div className="text-xs text-gray-400">{d.currency}</div>
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-700">
                      {d.assignedAdmin?.name || d.assignedAdminName || '—'}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(d.expectedResolutionBy)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {target && (
        <SupervisorReviewModal
          dispute={target}
          onClose={() => setTarget(null)}
          onDecided={refresh}
        />
      )}
    </div>
  );
}

function ManagerDecisionTab() {
  const { disputes, loading, error, refresh } = useDisputes('manager_review');
  const [target, setTarget] = useState(null);

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-gray-500">
          Disputes awaiting your final decision after supervisor review.
        </p>
        <button
          onClick={refresh}
          disabled={loading}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg text-sm disabled:opacity-50"
        >
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispute</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filer</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Disputed</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Held</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Supervisor</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Expected By</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {disputes.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-3 py-8 text-center text-gray-400 text-sm">
                  {loading ? 'Loading...' : 'No disputes awaiting manager decision.'}
                </td>
              </tr>
            ) : (
              disputes.map((d) => {
                const id = d.disputeId || d.id;
                return (
                  <tr
                    key={id}
                    onClick={() => setTarget(d)}
                    className="hover:bg-indigo-50 cursor-pointer"
                  >
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.filer?.name || d.filerName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.filer?.email || d.filerEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.recipient?.name || d.recipientName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.recipient?.email || d.recipientEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {symbol(d.currency)}{(d.amount ?? d.disputedAmount)?.toFixed?.(2)}
                      <div className="text-xs text-gray-400">{d.currency}</div>
                    </td>
                    <td className="px-3 py-2 text-right text-sm text-gray-700">
                      {symbol(d.currency)}{Number(d.currentHoldAmount ?? 0).toFixed(2)}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-700">
                      {d.supervisorDecision?.decision || '—'}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(d.expectedResolutionBy)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {target && (
        <ManagerDecisionModal
          dispute={target}
          onClose={() => setTarget(null)}
          onDecided={refresh}
        />
      )}
    </div>
  );
}

function EscalatedReviewModal({ dispute, onClose, onDecided }) {
  const disputeId = dispute.disputeId || dispute.id;
  const [actionDecision, setActionDecision] = useState(null);
  const recoverable = dispute.currentHoldAmount ?? dispute.amount ?? dispute.disputedAmount;

  return (
    <>
      <ModalShell title={`Super Admin Review — ${disputeId}`} onClose={onClose} maxWidth="max-w-2xl">
        <div className="space-y-1 mb-4">
          <DetailsRow label="Status"><StatusBadge status={dispute.status} /></DetailsRow>
          <DetailsRow label="Filed">{formatDate(dispute.filedAt || dispute.createdAt)}</DetailsRow>
          <DetailsRow label="Filer">
            <div>{dispute.filer?.name || dispute.filerName || '—'}</div>
            <div className="text-xs text-gray-500">{dispute.filer?.email || dispute.filerEmail || ''}</div>
          </DetailsRow>
          <DetailsRow label="Recipient">
            <div>{dispute.recipient?.name || dispute.recipientName || '—'}</div>
            <div className="text-xs text-gray-500">{dispute.recipient?.email || dispute.recipientEmail || ''}</div>
          </DetailsRow>
          <DetailsRow label="Disputed Amount">
            {symbol(dispute.currency)}{(dispute.amount ?? dispute.disputedAmount)?.toFixed?.(2)} {dispute.currency}
          </DetailsRow>
          <DetailsRow label="Currently Held">
            {symbol(dispute.currency)}{Number(recoverable || 0).toFixed(2)} {dispute.currency}
          </DetailsRow>
          <DetailsRow label="Description">{dispute.description}</DetailsRow>
          <DetailsRow label="Investigation Findings">
            <div className="whitespace-pre-wrap">{dispute.findings || dispute.investigationFindings || '—'}</div>
          </DetailsRow>
          <DetailsRow label="Supervisor Decision">
            <div>{dispute.supervisorDecision?.decision || '—'}</div>
            {dispute.supervisorDecision?.notes && (
              <div className="text-xs text-gray-500 whitespace-pre-wrap mt-1">
                {dispute.supervisorDecision.notes}
              </div>
            )}
          </DetailsRow>
          <DetailsRow label="Manager Decision">
            <div>{dispute.managerDecision?.decision || '—'}</div>
            {dispute.managerDecision?.notes && (
              <div className="text-xs text-gray-500 whitespace-pre-wrap mt-1">
                {dispute.managerDecision.notes}
              </div>
            )}
          </DetailsRow>
        </div>

        <div className="rounded-lg bg-red-50 border border-red-200 p-3 mb-4 text-xs text-red-800">
          You are the final decider. There is no further escalation path.
        </div>

        <div className="grid grid-cols-3 gap-2">
          <button
            onClick={() => setActionDecision('refund_full')}
            className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
          >
            Refund Full
          </button>
          <button
            onClick={() => setActionDecision('refund_partial')}
            className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
          >
            Refund Partial
          </button>
          <button
            onClick={() => setActionDecision('release')}
            className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
          >
            Release
          </button>
        </div>
        <button
          onClick={onClose}
          className="w-full mt-2 px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Close
        </button>
      </ModalShell>

      {actionDecision && (
        <DecisionActionModal
          title={
            actionDecision === 'refund_full'
              ? 'Refund Full to Filer'
              : actionDecision === 'refund_partial'
              ? 'Refund Partial Amount'
              : 'Release Funds to Recipient'
          }
          cfName="adminSuperAdminDisputeDecision"
          basePayload={{ disputeId }}
          decision={actionDecision}
          requireAmount={actionDecision === 'refund_partial'}
          amountMax={actionDecision === 'refund_partial' ? recoverable : undefined}
          amountCurrency={dispute.currency}
          onClose={() => setActionDecision(null)}
          onSubmitted={() => {
            if (onDecided) onDecided();
            onClose();
          }}
        />
      )}
    </>
  );
}

function EscalatedTab() {
  const { disputes, loading, error, refresh } = useDisputes('super_admin_escalation');
  const [target, setTarget] = useState(null);

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-gray-500">
          Disputes escalated to super admin for final adjudication.
        </p>
        <button
          onClick={refresh}
          disabled={loading}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg text-sm disabled:opacity-50"
        >
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispute</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filer</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Disputed</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Held</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Manager</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filed</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {disputes.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-3 py-8 text-center text-gray-400 text-sm">
                  {loading ? 'Loading...' : 'No disputes escalated to super admin.'}
                </td>
              </tr>
            ) : (
              disputes.map((d) => {
                const id = d.disputeId || d.id;
                return (
                  <tr
                    key={id}
                    onClick={() => setTarget(d)}
                    className="hover:bg-indigo-50 cursor-pointer"
                  >
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.filer?.name || d.filerName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.filer?.email || d.filerEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.recipient?.name || d.recipientName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.recipient?.email || d.recipientEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {symbol(d.currency)}{(d.amount ?? d.disputedAmount)?.toFixed?.(2)}
                      <div className="text-xs text-gray-400">{d.currency}</div>
                    </td>
                    <td className="px-3 py-2 text-right text-sm text-gray-700">
                      {symbol(d.currency)}{Number(d.currentHoldAmount ?? 0).toFixed(2)}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-700">
                      {d.managerDecision?.decision || '—'}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(d.filedAt || d.createdAt)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {target && (
        <EscalatedReviewModal
          dispute={target}
          onClose={() => setTarget(null)}
          onDecided={refresh}
        />
      )}
    </div>
  );
}

function StuckTab() {
  const { disputes, loading, error, refresh } = useDisputes('all');

  const stuck = useMemo(
    () =>
      disputes.filter(
        (d) => d.stuckCaseFlag === true || d.status === 'closed_stuck'
      ),
    [disputes]
  );

  const lastActionOf = (d) =>
    d.lastActionAt ||
    d.lastUpdatedAt ||
    d.managerDecision?.decidedAt ||
    d.supervisorDecision?.decidedAt ||
    d.investigatedAt ||
    d.filedAt ||
    d.createdAt;

  const ageDays = (iso) => {
    if (!iso) return null;
    const ms = Date.now() - new Date(iso).getTime();
    return Math.floor(ms / 86400000);
  };

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-gray-500">
          These cases have exceeded the 6-day resolution window and need manual review.
        </p>
        <button
          onClick={refresh}
          disabled={loading}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg text-sm disabled:opacity-50"
        >
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispute</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filer</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Age</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Last Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {stuck.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-3 py-8 text-center text-gray-400 text-sm">
                  {loading ? 'Loading...' : 'No stuck cases.'}
                </td>
              </tr>
            ) : (
              stuck.map((d) => {
                const id = d.disputeId || d.id;
                const last = lastActionOf(d);
                const days = ageDays(d.filedAt || d.createdAt);
                return (
                  <tr key={id} className="hover:bg-gray-50">
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.filer?.name || d.filerName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.filer?.email || d.filerEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.recipient?.name || d.recipientName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.recipient?.email || d.recipientEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {symbol(d.currency)}{(d.amount ?? d.disputedAmount)?.toFixed?.(2)}
                      <div className="text-xs text-gray-400">{d.currency}</div>
                    </td>
                    <td className="px-3 py-2"><StatusBadge status={d.status} /></td>
                    <td className="px-3 py-2 text-sm text-red-700 font-medium">
                      {days != null ? `${days}d` : '—'}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(last)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

// Phase 5i E3: ProposeReleaseModal — admin proposes a release direction for a
// dispute in 'awaiting_release' state. Both contact checkboxes must be ticked
// before submission is enabled. Submits to adminProposeDisputeRelease which
// requires admin_manager role or higher.
function ProposeReleaseModal({ dispute, onClose, onProposed }) {
  const disputeId = dispute.disputeId || dispute.id;
  const [direction, setDirection] = useState('');
  const [notes, setNotes] = useState('');
  const [buyerContacted, setBuyerContacted] = useState(false);
  const [sellerContacted, setSellerContacted] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const notesValid = notes.trim().length >= 50;
  const canSubmit =
    !submitting &&
    direction &&
    notesValid &&
    buyerContacted &&
    sellerContacted;

  const handleSubmit = async () => {
    if (!canSubmit) return;
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminProposeDisputeRelease')({
        disputeId,
        releaseDirection: direction,
        notes: notes.trim(),
        buyerContacted: true,
        sellerContacted: true,
        idempotencyKey: uuidv4(),
      });
      if (onProposed) onProposed();
      onClose();
    } catch (err) {
      setError(err?.message || 'Proposal failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title={`Propose Release — ${disputeId}`} onClose={onClose} maxWidth="max-w-2xl">
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="space-y-1 mb-4">
        <DetailsRow label="Status"><StatusBadge status={dispute.status} /></DetailsRow>
        <DetailsRow label="Filer">
          <div>{dispute.filer?.name || dispute.filerName || '—'}</div>
          <div className="text-xs text-gray-500">{dispute.filer?.email || dispute.filerEmail || ''}</div>
        </DetailsRow>
        <DetailsRow label="Recipient">
          <div>{dispute.recipient?.name || dispute.recipientName || '—'}</div>
          <div className="text-xs text-gray-500">{dispute.recipient?.email || dispute.recipientEmail || ''}</div>
        </DetailsRow>
        <DetailsRow label="Amount in Escrow">
          {dispute.amountInEscrow != null
            ? `${symbol(dispute.disputedCurrency)}${(dispute.amountInEscrow / 100).toFixed(2)} ${dispute.disputedCurrency || ''}`
            : '—'}
        </DetailsRow>
        <DetailsRow label="Manager's Decision Direction">{dispute.decisionDirection || '—'}</DetailsRow>
        <DetailsRow label="Description">{dispute.description}</DetailsRow>
      </div>

      <div className="mb-4">
        <label className="text-sm text-gray-700 font-medium block mb-2">Proposed Release Direction</label>
        <div className="space-y-2">
          <label className="flex items-start gap-2 p-2 border border-gray-200 rounded-lg cursor-pointer hover:bg-gray-50">
            <input
              type="radio"
              name="direction"
              value="release_to_payee"
              checked={direction === 'release_to_payee'}
              onChange={() => setDirection('release_to_payee')}
              className="mt-1"
            />
            <div>
              <div className="text-sm font-medium text-gray-900">Release as decided</div>
              <div className="text-xs text-gray-500">Funds go to the party the manager decided in favour of.</div>
            </div>
          </label>
          <label className="flex items-start gap-2 p-2 border border-gray-200 rounded-lg cursor-pointer hover:bg-gray-50">
            <input
              type="radio"
              name="direction"
              value="reverse_to_payer"
              checked={direction === 'reverse_to_payer'}
              onChange={() => setDirection('reverse_to_payer')}
              className="mt-1"
            />
            <div>
              <div className="text-sm font-medium text-gray-900">Reverse the decision</div>
              <div className="text-xs text-gray-500">Funds return to the original payer; original decision is overturned.</div>
            </div>
          </label>
        </div>
      </div>

      <div className="mb-4">
        <div className="flex items-center justify-between mb-1">
          <label className="text-sm text-gray-700 font-medium">Notes</label>
          <span className={`text-xs ${notesValid ? 'text-gray-500' : 'text-amber-600'}`}>
            {notes.length} / 50 minimum
          </span>
        </div>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          rows={4}
          placeholder="Document the reasoning behind this proposed release direction..."
          className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
        />
      </div>

      <div className="mb-4 space-y-2">
        <label className="flex items-start gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={buyerContacted}
            onChange={(e) => setBuyerContacted(e.target.checked)}
            className="mt-1"
          />
          <span className="text-sm text-gray-700">
            I have contacted the buyer about this proposed release and they have been informed of the outcome.
          </span>
        </label>
        <label className="flex items-start gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={sellerContacted}
            onChange={(e) => setSellerContacted(e.target.checked)}
            className="mt-1"
          />
          <span className="text-sm text-gray-700">
            I have contacted the seller about this proposed release and they have been informed of the outcome.
          </span>
        </label>
      </div>

      <div className="flex gap-2 mt-5">
        <button
          onClick={handleSubmit}
          disabled={!canSubmit}
          className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-3 md:py-2 rounded-lg text-sm font-medium disabled:opacity-50"
        >
          {submitting ? 'Submitting...' : 'Submit Proposal'}
        </button>
        <button
          onClick={onClose}
          disabled={submitting}
          className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Cancel
        </button>
      </div>
    </ModalShell>
  );
}

// Phase 5i E3: AwaitingReleaseTab — table of disputes in 'awaiting_release' state
// that don't yet have an active proposal. Each row opens the ProposeReleaseModal.
// Disputes WITH an active proposal belong to E4's PendingProposalTab — they are
// filtered out here via the releaseProposal == null check.
function AwaitingReleaseTab() {
  const { disputes, loading, error, refresh } = useDisputes('awaiting_release');
  const [target, setTarget] = useState(null);

  const eligible = disputes.filter(
    (d) => d.releaseProposal == null,
  );

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-gray-500">
          Disputes whose escrow is fully funded and waiting for an admin to propose a release direction.
        </p>
        <button
          onClick={refresh}
          disabled={loading}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg text-sm disabled:opacity-50"
        >
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispute</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filer</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Recipient</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Escrow</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Decision</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Awaiting Since</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {eligible.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-3 py-8 text-center text-gray-400 text-sm">
                  {loading ? 'Loading...' : 'No disputes awaiting a release proposal.'}
                </td>
              </tr>
            ) : (
              eligible.map((d) => {
                const id = d.disputeId || d.id;
                return (
                  <tr
                    key={id}
                    onClick={() => setTarget(d)}
                    className="hover:bg-indigo-50 cursor-pointer"
                  >
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.filer?.name || d.filerName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.filer?.email || d.filerEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{d.recipient?.name || d.recipientName || '—'}</div>
                      <div className="text-xs text-gray-400">{d.recipient?.email || d.recipientEmail || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {d.amountInEscrow != null
                        ? `${symbol(d.disputedCurrency)}${(d.amountInEscrow / 100).toFixed(2)}`
                        : '—'}
                      <div className="text-xs text-gray-400">{d.disputedCurrency || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-700">{d.decisionDirection || '—'}</td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(d.awaitingReleaseAt)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {target && (
        <ProposeReleaseModal
          dispute={target}
          onClose={() => setTarget(null)}
          onProposed={refresh}
        />
      )}
    </div>
  );
}

// Phase 5i E4: ConfirmReleaseModal — confirms a pending release proposal.
// Backend rejects if caller is the proposer themselves (different-admin rule).
// Calls adminConfirmDisputeRelease. Once confirmed, money moves from escrow
// and dispute closes as 'closed' or 'closed_returned'.
function ConfirmReleaseModal({ dispute, onClose, onConfirmed }) {
  const disputeId = dispute.disputeId || dispute.id;
  const proposal = dispute.releaseProposal || {};
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async () => {
    if (submitting) return;
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminConfirmDisputeRelease')({
        disputeId,
        idempotencyKey: uuidv4(),
      });
      if (onConfirmed) onConfirmed();
      onClose();
    } catch (err) {
      setError(err?.message || 'Confirmation failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title={`Confirm Release — ${disputeId}`} onClose={onClose} maxWidth="max-w-2xl">
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="space-y-1 mb-4">
        <DetailsRow label="Proposed By">
          <div>{proposal.proposedBy?.displayName || proposal.proposedBy?.email || '—'}</div>
          <div className="text-xs text-gray-500">{proposal.proposedBy?.email || ''}</div>
        </DetailsRow>
        <DetailsRow label="Proposed Direction">{proposal.releaseDirection || '—'}</DetailsRow>
        <DetailsRow label="Proposed Notes">
          <div className="whitespace-pre-wrap">{proposal.notes || '—'}</div>
        </DetailsRow>
        <DetailsRow label="Buyer Contacted">{proposal.buyerContacted ? 'yes' : 'no'}</DetailsRow>
        <DetailsRow label="Seller Contacted">{proposal.sellerContacted ? 'yes' : 'no'}</DetailsRow>
        <DetailsRow label="Proposal Expires">{formatDate(proposal.expiresAt)}</DetailsRow>
        <DetailsRow label="Amount in Escrow">
          {dispute.amountInEscrow != null
            ? `${symbol(dispute.disputedCurrency)}${(dispute.amountInEscrow / 100).toFixed(2)} ${dispute.disputedCurrency || ''}`
            : '—'}
        </DetailsRow>
      </div>

      <div className="mb-4 p-3 bg-amber-50 border border-amber-200 rounded-lg text-sm text-amber-900">
        Confirming will release the escrowed funds according to the proposed direction. This action moves money and cannot be undone.
      </div>

      <div className="flex gap-2 mt-5">
        <button
          onClick={handleSubmit}
          disabled={submitting}
          className="flex-1 bg-green-600 hover:bg-green-700 text-white px-4 py-3 md:py-2 rounded-lg text-sm font-medium disabled:opacity-50"
        >
          {submitting ? 'Confirming...' : 'Confirm Release'}
        </button>
        <button
          onClick={onClose}
          disabled={submitting}
          className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Cancel
        </button>
      </div>
    </ModalShell>
  );
}

// Phase 5i E4: RejectReleaseModal — rejects a pending release proposal with
// a reason (≥30 chars). Backend rejects if caller is the proposer (different-
// admin rule). Calls adminRejectDisputeRelease. After rejection the dispute
// returns to 'awaiting_release' status with releaseProposal cleared and the
// rejection details preserved on the dispute doc, allowing another admin to
// propose again.
function RejectReleaseModal({ dispute, onClose, onRejected }) {
  const disputeId = dispute.disputeId || dispute.id;
  const proposal = dispute.releaseProposal || {};
  const [reason, setReason] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const reasonValid = reason.trim().length >= 30;
  const canSubmit = !submitting && reasonValid;

  const handleSubmit = async () => {
    if (!canSubmit) return;
    setSubmitting(true);
    setError('');
    try {
      await httpsCallable(functions, 'adminRejectDisputeRelease')({
        disputeId,
        reason: reason.trim(),
        idempotencyKey: uuidv4(),
      });
      if (onRejected) onRejected();
      onClose();
    } catch (err) {
      setError(err?.message || 'Rejection failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalShell title={`Reject Proposal — ${disputeId}`} onClose={onClose} maxWidth="max-w-2xl">
      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="space-y-1 mb-4">
        <DetailsRow label="Proposed By">
          <div>{proposal.proposedBy?.displayName || proposal.proposedBy?.email || '—'}</div>
          <div className="text-xs text-gray-500">{proposal.proposedBy?.email || ''}</div>
        </DetailsRow>
        <DetailsRow label="Proposed Direction">{proposal.releaseDirection || '—'}</DetailsRow>
        <DetailsRow label="Proposed Notes">
          <div className="whitespace-pre-wrap">{proposal.notes || '—'}</div>
        </DetailsRow>
        <DetailsRow label="Proposal Expires">{formatDate(proposal.expiresAt)}</DetailsRow>
      </div>

      <div className="mb-4">
        <div className="flex items-center justify-between mb-1">
          <label className="text-sm text-gray-700 font-medium">Rejection Reason</label>
          <span className={`text-xs ${reasonValid ? 'text-gray-500' : 'text-amber-600'}`}>
            {reason.length} / 30 minimum
          </span>
        </div>
        <textarea
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          rows={4}
          placeholder="Explain why this proposal should not be confirmed. Another admin will see this reason if they propose again..."
          className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
        />
      </div>

      <div className="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg text-sm text-blue-900">
        Rejecting clears the proposal but leaves the dispute open for another admin to propose a different direction.
      </div>

      <div className="flex gap-2 mt-5">
        <button
          onClick={handleSubmit}
          disabled={!canSubmit}
          className="flex-1 bg-red-600 hover:bg-red-700 text-white px-4 py-3 md:py-2 rounded-lg text-sm font-medium disabled:opacity-50"
        >
          {submitting ? 'Rejecting...' : 'Submit Rejection'}
        </button>
        <button
          onClick={onClose}
          disabled={submitting}
          className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm"
        >
          Cancel
        </button>
      </div>
    </ModalShell>
  );
}

// Phase 5i E4: PendingProposalTab — table of disputes with an active release
// proposal that was NOT made by the current admin. Each row has two action
// buttons (Confirm / Reject) that open the corresponding modal. The current
// admin's own proposals are filtered out — the backend's different-admin
// enforcement would reject those actions anyway.
function PendingProposalTab() {
  const { user } = useAuth();
  const { disputes, loading, error, refresh } = useDisputes('awaiting_release');
  const [confirmTarget, setConfirmTarget] = useState(null);
  const [rejectTarget, setRejectTarget] = useState(null);

  const eligible = disputes.filter(
    (d) =>
      d.releaseProposal != null &&
      d.releaseProposal.proposedBy?.uid !== user?.uid,
  );

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-gray-500">
          Release proposals from other admins awaiting your confirmation or rejection. Your own proposals do not appear here.
        </p>
        <button
          onClick={refresh}
          disabled={loading}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg text-sm disabled:opacity-50"
        >
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispute</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proposed By</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Direction</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Escrow</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proposed</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Expires</th>
              <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {eligible.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-3 py-8 text-center text-gray-400 text-sm">
                  {loading ? 'Loading...' : 'No pending proposals from other admins.'}
                </td>
              </tr>
            ) : (
              eligible.map((d) => {
                const id = d.disputeId || d.id;
                const proposal = d.releaseProposal || {};
                return (
                  <tr key={id} className="hover:bg-indigo-50">
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2 text-sm text-gray-700">
                      <div>{proposal.proposedBy?.displayName || proposal.proposedBy?.email || '—'}</div>
                      <div className="text-xs text-gray-400">{proposal.proposedBy?.email || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-700">{proposal.releaseDirection || '—'}</td>
                    <td className="px-3 py-2 text-right text-sm font-medium text-gray-900">
                      {d.amountInEscrow != null
                        ? `${symbol(d.disputedCurrency)}${(d.amountInEscrow / 100).toFixed(2)}`
                        : '—'}
                      <div className="text-xs text-gray-400">{d.disputedCurrency || ''}</div>
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(proposal.proposedAt)}</td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(proposal.expiresAt)}</td>
                    <td className="px-3 py-2 text-right">
                      <div className="flex gap-1 justify-end">
                        <button
                          onClick={() => setConfirmTarget(d)}
                          className="bg-green-600 hover:bg-green-700 text-white px-2 py-1 rounded text-xs font-medium"
                        >
                          Confirm
                        </button>
                        <button
                          onClick={() => setRejectTarget(d)}
                          className="bg-red-600 hover:bg-red-700 text-white px-2 py-1 rounded text-xs font-medium"
                        >
                          Reject
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {confirmTarget && (
        <ConfirmReleaseModal
          dispute={confirmTarget}
          onClose={() => setConfirmTarget(null)}
          onConfirmed={refresh}
        />
      )}
      {rejectTarget && (
        <RejectReleaseModal
          dispute={rejectTarget}
          onClose={() => setRejectTarget(null)}
          onRejected={refresh}
        />
      )}
    </div>
  );
}

// Phase 5i E5: ClosedHistoryTab — read-only audit view of disputes that
// reached terminal Phase 5i states. Lists 'closed' (released as decided) and
// 'closed_returned' (decision reversed). Merges two useDisputes calls since
// the hook accepts only one status string at a time. Sorted by releaseConfirmedAt
// descending (most-recently-closed first); falls back to filedAt for any
// legacy/unusual dispute lacking the confirm timestamp. Row click opens the
// existing DisputeDetailsModal, which already surfaces all Phase 5i audit fields
// (E2). No new modals or cloud function calls.
function ClosedHistoryTab() {
  const closed = useDisputes('closed');
  const reversed = useDisputes('closed_returned');
  const [target, setTarget] = useState(null);

  const all = [...closed.disputes, ...reversed.disputes].sort((a, b) => {
    const aKey = a.releaseConfirmedAt || a.filedAt || '';
    const bKey = b.releaseConfirmedAt || b.filedAt || '';
    // Descending order
    if (aKey < bKey) return 1;
    if (aKey > bKey) return -1;
    return 0;
  });

  const loading = closed.loading || reversed.loading;
  const error = closed.error || reversed.error;
  const refresh = () => {
    closed.refresh();
    reversed.refresh();
  };

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-gray-500">
          Closed disputes — both released-as-decided and reversed decisions. Read-only audit view.
        </p>
        <button
          onClick={refresh}
          disabled={loading}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg text-sm disabled:opacity-50"
        >
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispute</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Outcome</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Filer / Recipient</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Direction</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proposed By</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Confirmed By</th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Closed At</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {all.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-3 py-8 text-center text-gray-400 text-sm">
                  {loading ? 'Loading...' : 'No closed disputes yet.'}
                </td>
              </tr>
            ) : (
              all.map((d) => {
                const id = d.disputeId || d.id;
                return (
                  <tr
                    key={id}
                    onClick={() => setTarget(d)}
                    className="hover:bg-indigo-50 cursor-pointer"
                  >
                    <td className="px-3 py-2 text-xs font-mono text-gray-600">{id}</td>
                    <td className="px-3 py-2"><StatusBadge status={d.status} /></td>
                    <td className="px-3 py-2 text-xs text-gray-700">
                      <div>{d.filer?.name || d.filerName || '—'}</div>
                      <div className="text-gray-400">→ {d.recipient?.name || d.recipientName || '—'}</div>
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-700">{d.releaseDirection || '—'}</td>
                    <td className="px-3 py-2 text-xs text-gray-700">
                      {d.releaseProposal?.proposedBy?.email || d.releaseProposal?.proposedBy?.uid || '—'}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-700">
                      {d.releaseConfirmedBy?.email || d.releaseConfirmedBy?.uid || '—'}
                    </td>
                    <td className="px-3 py-2 text-xs text-gray-500">{formatDate(d.releaseConfirmedAt)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {target && (
        <DisputeDetailsModal
          dispute={target}
          onClose={() => setTarget(null)}
        />
      )}
    </div>
  );
}

function DisputesPage() {
  const { user, isAdmin, isAdminSupervisor, isAdminManager, isSuperAdmin } = useAuth();

  const tabs = [];
  if (isAdmin) tabs.push({ id: 'all', label: 'All Disputes' });
  if (isAdmin) tabs.push({ id: 'assigned', label: 'My Assigned Cases' });
  if (isAdminSupervisor) tabs.push({ id: 'supervisor', label: 'Supervisor Review' });
  if (isAdminManager) tabs.push({ id: 'manager', label: 'Manager Decision' });
  if (isAdminManager) tabs.push({ id: 'awaiting_release', label: 'Awaiting Release' });
  if (isAdminManager) tabs.push({ id: 'pending_proposal', label: 'Pending Proposals' });
  if (isAdmin) tabs.push({ id: 'closed_history', label: 'Closed History' });
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

        <div className="p-6">
          {activeTab === 'all' && <AllDisputesTab canAssign={isAdminSupervisor} />}
          {activeTab === 'assigned' && <MyAssignedCasesTab currentUid={user?.uid} />}
          {activeTab === 'supervisor' && <SupervisorReviewTab />}
          {activeTab === 'manager' && <ManagerDecisionTab />}
          {activeTab === 'awaiting_release' && <AwaitingReleaseTab />}
          {activeTab === 'pending_proposal' && <PendingProposalTab />}
          {activeTab === 'closed_history' && <ClosedHistoryTab />}
          {activeTab === 'escalated' && <EscalatedTab />}
          {activeTab === 'stuck' && <StuckTab />}
        </div>
      </div>
    </div>
  );
}

export default DisputesPage;
