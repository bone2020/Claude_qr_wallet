/**
 * Convert array of objects to CSV string and trigger download.
 * @param {Array} data - Array of objects
 * @param {string} filename - Name of the downloaded file
 * @param {Array} columns - Optional column config: [{ key: 'field', label: 'Header' }]
 */
export function exportToCSV(data, filename, columns) {
  if (!data || data.length === 0) {
    alert('No data to export.');
    return;
  }

  // Determine columns from data or config
  const cols = columns || Object.keys(data[0]).map(key => ({ key, label: key }));

  // Build CSV header
  const header = cols.map(c => `"${c.label}"`).join(',');

  // Build CSV rows
  const rows = data.map(row =>
    cols.map(c => {
      let val = row[c.key];
      if (val === null || val === undefined) val = '';
      if (typeof val === 'object') val = JSON.stringify(val);
      // Escape quotes
      val = String(val).replace(/"/g, '""');
      return `"${val}"`;
    }).join(',')
  );

  const csv = [header, ...rows].join('\n');

  // Trigger download
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `${filename}_${new Date().toISOString().split('T')[0]}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}
