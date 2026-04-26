import React, { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { v4 as uuidv4 } from 'uuid';
import { functions } from '../firebase';

const ALLOWED_TYPES = ['application/pdf', 'image/jpeg', 'image/png'];
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB

const SINGLE_TYPES = ['invoice', 'receipt'];

const capitalize = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : '');

const formatDate = (dateStr) => (dateStr ? new Date(dateStr).toLocaleString() : '—');

const stripBase64Prefix = (dataUrl) => {
  const idx = dataUrl.indexOf(',');
  return idx >= 0 ? dataUrl.slice(idx + 1) : dataUrl;
};

const readFileAsBase64 = (file) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(stripBase64Prefix(reader.result));
    reader.onerror = () => reject(reader.error || new Error('File read failed.'));
    reader.readAsDataURL(file);
  });

function DocumentUploadWidget({
  proposalId,
  documentType,
  existingFiles,
  readOnly = false,
  maxFiles,
  onUploadSuccess,
}) {
  const [files, setFiles] = useState(Array.isArray(existingFiles) ? existingFiles : []);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    setFiles(Array.isArray(existingFiles) ? existingFiles : []);
  }, [existingFiles]);

  const isSingle = SINGLE_TYPES.includes(documentType);
  const effectiveMax = maxFiles || (isSingle ? 1 : 4);
  const canUpload = !readOnly && files.length < effectiveMax;

  const handleView = async (index) => {
    setError('');
    try {
      const params = { proposalId, documentType };
      if (!isSingle) params.index = index;
      const result = await httpsCallable(functions, 'adminGetProposalDocumentUrl')(params);
      const url = result.data?.documentUrl;
      if (url) {
        window.open(url, '_blank', 'noopener,noreferrer');
      } else {
        setError('No document URL returned.');
      }
    } catch (err) {
      setError(err?.message || 'Failed to load document.');
    }
  };

  const handleFileChange = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;

    if (!ALLOWED_TYPES.includes(file.type)) {
      setError('Only PDF, JPEG, PNG allowed.');
      return;
    }
    if (file.size > MAX_BYTES) {
      setError('File too large (max 10 MB).');
      return;
    }

    setUploading(true);
    setError('');
    try {
      const fileBase64 = await readFileAsBase64(file);
      const result = await httpsCallable(functions, 'adminUploadProposalDocument')({
        proposalId,
        documentType,
        fileBase64,
        contentType: file.type,
        fileName: file.name,
        idempotencyKey: uuidv4(),
      });

      const uploaded = result.data?.document || {
        fileName: file.name,
        contentType: file.type,
        uploadedAt: new Date().toISOString(),
      };
      const next = [...files, uploaded];
      setFiles(next);
      if (onUploadSuccess) onUploadSuccess(uploaded);
    } catch (err) {
      setError(err?.message || 'Upload failed.');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4">
      <div className="flex items-center justify-between mb-3">
        <h4 className="text-sm font-semibold text-gray-800">{capitalize(documentType)}</h4>
        <span className="text-xs text-gray-500">
          {files.length} / {effectiveMax} {documentType}{files.length === 1 ? '' : 's'}
        </span>
      </div>

      {error && (
        <div className="mb-3 p-2 bg-red-50 border border-red-200 text-red-700 rounded text-xs">
          {error}
        </div>
      )}

      <ul className="space-y-1 mb-3">
        {files.length === 0 ? (
          <li className="text-xs text-gray-400 italic">No files uploaded yet.</li>
        ) : (
          files.map((f, i) => (
            <li
              key={`${f.fileName || documentType}-${i}`}
              className="flex items-center justify-between text-sm bg-gray-50 rounded px-3 py-1.5"
            >
              <div className="min-w-0 flex-1">
                <div className="truncate text-gray-800">
                  {f.fileName || `${documentType}_${i + 1}`}
                </div>
                <div className="text-xs text-gray-400">{formatDate(f.uploadedAt)}</div>
              </div>
              <button
                type="button"
                onClick={() => handleView(i)}
                className="ml-3 text-xs text-indigo-600 hover:text-indigo-800 font-medium"
              >
                View
              </button>
            </li>
          ))
        )}
      </ul>

      {canUpload && (
        <div className="relative">
          <label className="block">
            <span className="text-xs text-gray-500 block mb-1">
              Upload PDF, JPEG, or PNG (max 10 MB)
            </span>
            <input
              type="file"
              accept="application/pdf,image/jpeg,image/png"
              onChange={handleFileChange}
              disabled={uploading}
              className="block w-full text-sm text-gray-600 file:mr-3 file:py-1.5 file:px-3 file:rounded file:border-0 file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100 disabled:opacity-50"
            />
          </label>
          {uploading && (
            <div className="absolute inset-0 bg-white bg-opacity-80 flex items-center justify-center rounded">
              <span className="text-xs text-gray-600">Uploading...</span>
            </div>
          )}
        </div>
      )}

      {!readOnly && files.length >= effectiveMax && (
        <p className="text-xs text-gray-500 italic">
          Maximum {effectiveMax} {documentType}{effectiveMax === 1 ? '' : 's'} uploaded.
        </p>
      )}
    </div>
  );
}

export default DocumentUploadWidget;
