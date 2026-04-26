import React, { useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { jsPDF } from 'jspdf';
import { functions } from '../firebase';
import { useAuth } from '../contexts/AuthContext';

const CATEGORIES = [
  {
    id: 'transfers',
    label: 'Transfers',
    cfName: 'adminListTransferProposals',
    responseKey: 'proposals',
    dateField: 'proposedAt',
    altDateField: 'createdAt',
    columns: [
      { key: 'proposalId', label: 'Proposal ID', value: (r) => r.proposalId || r.id || '' },
      { key: 'proposer', label: 'Proposer', value: (r) => r.proposedBy?.email || r.proposedByEmail || '' },
      { key: 'amount', label: 'Amount', value: (r) => r.amount ?? '' },
      { key: 'currency', label: 'Currency', value: (r) => r.currency || '' },
      { key: 'recipient', label: 'Recipient', value: (r) => r.accountName || r.recipient?.accountName || '' },
      { key: 'status', label: 'Status', value: (r) => r.status || '' },
      { key: 'proposedAt', label: 'Proposed At', value: (r) => r.proposedAt || r.createdAt || '' },
      { key: 'completedAt', label: 'Completed At', value: (r) => r.completedAt || '' },
    ],
  },
  {
    id: 'disputes',
    label: 'Disputes',
    cfName: 'adminListDisputes',
    responseKey: 'disputes',
    dateField: 'filedAt',
    altDateField: 'createdAt',
    columns: [
      { key: 'disputeId', label: 'Dispute ID', value: (r) => r.disputeId || r.id || '' },
      { key: 'filer', label: 'Filer', value: (r) => r.filer?.email || r.filerEmail || '' },
      { key: 'recipient', label: 'Recipient', value: (r) => r.recipient?.email || r.recipientEmail || '' },
      { key: 'amount', label: 'Amount', value: (r) => r.amount ?? r.disputedAmount ?? '' },
      { key: 'currency', label: 'Currency', value: (r) => r.currency || '' },
      { key: 'status', label: 'Status', value: (r) => r.status || '' },
      { key: 'filedAt', label: 'Filed At', value: (r) => r.filedAt || r.createdAt || '' },
    ],
  },
  {
    id: 'recoveries',
    label: 'Recoveries',
    cfName: 'adminListRecoveries',
    responseKey: 'recoveries',
    dateField: 'deductedAt',
    altDateField: 'createdAt',
    columns: [
      { key: 'recoveryId', label: 'Recovery ID', value: (r) => r.recoveryId || r.id || '' },
      { key: 'debtId', label: 'Debt ID', value: (r) => r.debtId || '' },
      { key: 'amount', label: 'Amount', value: (r) => r.amount ?? '' },
      { key: 'currency', label: 'Currency', value: (r) => r.currency || '' },
      { key: 'recipient', label: 'Recipient', value: (r) => r.recipient?.email || r.recipientEmail || '' },
      { key: 'filer', label: 'Filer', value: (r) => r.filer?.email || r.filerEmail || '' },
      { key: 'status', label: 'Status', value: (r) => r.status || '' },
      { key: 'deductedAt', label: 'Deducted At', value: (r) => r.deductedAt || '' },
    ],
  },
  {
    id: 'admin_actions',
    label: 'Admin actions',
    cfName: 'adminGetActivityLogs',
    responseKey: 'logs',
    dateField: 'timestamp',
    altDateField: 'createdAt',
    columns: [
      { key: 'id', label: 'ID', value: (r) => r.id || '' },
      { key: 'admin', label: 'Admin', value: (r) => r.actorEmail || r.adminEmail || '' },
      { key: 'action', label: 'Action', value: (r) => r.action || '' },
      { key: 'timestamp', label: 'Timestamp', value: (r) => r.timestamp || r.createdAt || '' },
      {
        key: 'metadata',
        label: 'Metadata',
        value: (r) => (r.metadata ? JSON.stringify(r.metadata) : ''),
      },
    ],
  },
  {
    id: 'audit_logs',
    label: 'Audit logs',
    cfName: 'adminGetAuditLogs',
    responseKey: 'logs',
    dateField: 'timestamp',
    altDateField: 'createdAt',
    columns: [
      { key: 'id', label: 'ID', value: (r) => r.id || '' },
      { key: 'actor', label: 'Actor', value: (r) => r.actorEmail || r.actor || '' },
      { key: 'action', label: 'Action', value: (r) => r.action || '' },
      { key: 'target', label: 'Target', value: (r) => r.target || r.targetUid || '' },
      { key: 'timestamp', label: 'Timestamp', value: (r) => r.timestamp || r.createdAt || '' },
      {
        key: 'metadata',
        label: 'Metadata',
        value: (r) => (r.metadata ? JSON.stringify(r.metadata) : ''),
      },
    ],
  },
];

const csvEscape = (val) => {
  if (val === null || val === undefined) return '';
  const str = typeof val === 'object' ? JSON.stringify(val) : String(val);
  return `"${str.replace(/"/g, '""')}"`;
};

const buildCsvForCategory = (category, records) => {
  const headerLine = category.columns.map((c) => csvEscape(c.label)).join(',');
  const dataLines = records.map((r) =>
    category.columns.map((c) => csvEscape(c.value(r))).join(',')
  );
  return [headerLine, ...dataLines].join('\n');
};

const inDateRange = (record, category, startMs, endMs) => {
  const raw = record[category.dateField] || record[category.altDateField];
  if (!raw) return true;
  const t = new Date(raw).getTime();
  if (Number.isNaN(t)) return true;
  return t >= startMs && t <= endMs;
};

const sha256Hex = async (str) => {
  const encoder = new TextEncoder();
  const data = encoder.encode(str);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
};

const triggerDownload = (blob, filename) => {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
};

const todayStamp = () => new Date().toISOString().slice(0, 10);

function AuditExportPage() {
  const { isAuditor } = useAuth();

  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [selected, setSelected] = useState({});
  const [generating, setGenerating] = useState(false);
  const [error, setError] = useState('');
  const [lastResult, setLastResult] = useState(null);

  if (!isAuditor) {
    return (
      <div className="space-y-6 p-6">
        <h1 className="text-2xl font-bold text-gray-900">Audit Export</h1>
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 text-sm text-gray-500">
          You do not have access to audit export.
        </div>
      </div>
    );
  }

  const toggleCategory = (id) => {
    setSelected((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  const selectedCategories = CATEGORIES.filter((c) => selected[c.id]);
  const canSubmit =
    !generating && !!startDate && !!endDate && startDate <= endDate && selectedCategories.length > 0;

  const handleGenerate = async () => {
    if (!canSubmit) return;
    setGenerating(true);
    setError('');
    setLastResult(null);

    try {
      const startMs = new Date(`${startDate}T00:00:00.000Z`).getTime();
      const endMs = new Date(`${endDate}T23:59:59.999Z`).getTime();

      const sectionResults = [];
      for (const category of selectedCategories) {
        const result = await httpsCallable(functions, category.cfName)({
          limit: 1000,
          startDate,
          endDate,
        });
        const records = (result.data?.[category.responseKey] || []).filter((r) =>
          inDateRange(r, category, startMs, endMs)
        );
        sectionResults.push({ category, records });
      }

      const csvSections = sectionResults.map(({ category, records }) => {
        const sectionHeader = `# ${category.label} (${records.length} records)`;
        const csvBody = buildCsvForCategory(category, records);
        return `${sectionHeader}\n${csvBody}`;
      });
      const csvString = csvSections.join('\n\n');

      const hash = await sha256Hex(csvString);

      const stamp = todayStamp();
      const csvFilename = `qr-wallet-audit-${stamp}-${startDate}-to-${endDate}.csv`;
      const pdfFilename = `qr-wallet-audit-${stamp}-${startDate}-to-${endDate}.pdf`;

      // Build PDF
      const doc = new jsPDF();
      let y = 20;
      doc.setFontSize(18);
      doc.text('QR Wallet Audit Export', 14, y);
      y += 10;
      doc.setFontSize(11);
      doc.text(`Generated: ${new Date().toISOString()}`, 14, y);
      y += 7;
      doc.text(`Date range: ${startDate} to ${endDate}`, 14, y);
      y += 10;

      doc.setFontSize(13);
      doc.text('Categories included', 14, y);
      y += 7;
      doc.setFontSize(11);
      sectionResults.forEach(({ category, records }) => {
        doc.text(`- ${category.label}: ${records.length} records`, 18, y);
        y += 6;
      });
      y += 6;

      doc.setFontSize(11);
      doc.text('Full data is in the accompanying CSV file.', 14, y);
      y += 12;

      doc.setFontSize(10);
      doc.text('CSV SHA-256 (tamper evidence):', 14, y);
      y += 6;
      doc.setFont('courier', 'normal');
      doc.setFontSize(9);
      const half = Math.ceil(hash.length / 2);
      doc.text(hash.slice(0, half), 14, y);
      y += 5;
      doc.text(hash.slice(half), 14, y);
      doc.setFont('helvetica', 'normal');

      const csvBlob = new Blob([csvString], { type: 'text/csv;charset=utf-8;' });
      const pdfBlob = doc.output('blob');

      triggerDownload(csvBlob, csvFilename);
      triggerDownload(pdfBlob, pdfFilename);

      setLastResult({
        startDate,
        endDate,
        sections: sectionResults.map(({ category, records }) => ({
          label: category.label,
          count: records.length,
        })),
        hash,
        csvFilename,
        pdfFilename,
      });
    } catch (err) {
      setError(err?.message || 'Export generation failed.');
    } finally {
      setGenerating(false);
    }
  };

  return (
    <div className="space-y-6 p-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Audit Export</h1>
        <p className="text-sm text-gray-500 mt-1">
          Generate paired CSV + PDF exports with SHA-256 tamper evidence.
        </p>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg">{error}</div>
      )}

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
          <div>
            <label className="text-sm text-gray-700 font-medium block mb-1">Start date</label>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>
          <div>
            <label className="text-sm text-gray-700 font-medium block mb-1">End date</label>
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>
        </div>

        <div className="mb-6">
          <p className="text-sm text-gray-700 font-medium mb-2">Categories (pick at least one)</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            {CATEGORIES.map((c) => (
              <label key={c.id} className="inline-flex items-center gap-2 text-sm text-gray-700">
                <input
                  type="checkbox"
                  checked={!!selected[c.id]}
                  onChange={() => toggleCategory(c.id)}
                  className="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                />
                {c.label}
              </label>
            ))}
          </div>
        </div>

        <button
          onClick={handleGenerate}
          disabled={!canSubmit}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-3 md:py-2 rounded-lg text-sm font-medium disabled:opacity-50"
        >
          {generating ? 'Generating...' : 'Generate Export'}
        </button>

        {!startDate || !endDate ? (
          <p className="mt-2 text-xs text-amber-600">Select a start and end date.</p>
        ) : startDate > endDate ? (
          <p className="mt-2 text-xs text-amber-600">Start date must be before end date.</p>
        ) : selectedCategories.length === 0 ? (
          <p className="mt-2 text-xs text-amber-600">Select at least one category.</p>
        ) : null}
      </div>

      {lastResult && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-lg font-bold text-gray-900 mb-2">Last Export</h2>
          <p className="text-sm text-gray-500 mb-4">
            Date range: {lastResult.startDate} to {lastResult.endDate}
          </p>
          <ul className="text-sm text-gray-700 list-disc pl-5 mb-4">
            {lastResult.sections.map((s) => (
              <li key={s.label}>
                {s.label}: <span className="font-medium">{s.count}</span> records
              </li>
            ))}
          </ul>
          <div className="text-xs text-gray-500 mb-1">CSV: {lastResult.csvFilename}</div>
          <div className="text-xs text-gray-500 mb-3">PDF: {lastResult.pdfFilename}</div>
          <div className="text-xs text-gray-500 mb-1">CSV SHA-256:</div>
          <code className="block break-all text-xs bg-gray-50 border border-gray-200 rounded p-2 font-mono">
            {lastResult.hash}
          </code>
        </div>
      )}
    </div>
  );
}

export default AuditExportPage;
