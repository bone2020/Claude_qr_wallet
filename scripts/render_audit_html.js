const fs = require('fs');
const path = require('path');
const { marked } = require('marked');

function main() {
  const inputPath = path.resolve(process.argv[2]);
  const outputPath = path.resolve(process.argv[3]);

  const markdown = fs.readFileSync(inputPath, 'utf8');
  const htmlBody = marked.parse(markdown);

  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>QR Wallet Audit Report</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
      color: #1f2937;
      line-height: 1.55;
      font-size: 16px;
      max-width: 980px;
      margin: 0 auto;
      padding: 40px 32px 64px;
      background: #ffffff;
    }
    h1, h2, h3, h4 {
      color: #111827;
      margin-top: 1.2em;
      margin-bottom: 0.45em;
    }
    h1 {
      font-size: 2.1rem;
      border-bottom: 2px solid #e5e7eb;
      padding-bottom: 10px;
    }
    h2 {
      font-size: 1.45rem;
      border-bottom: 1px solid #e5e7eb;
      padding-bottom: 4px;
    }
    h3 {
      font-size: 1.12rem;
    }
    ul, ol {
      padding-left: 22px;
    }
    code {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      background: #f3f4f6;
      padding: 1px 4px;
      border-radius: 4px;
      font-size: 0.95em;
    }
    pre {
      background: #f9fafb;
      border: 1px solid #e5e7eb;
      border-radius: 6px;
      padding: 12px;
      overflow: auto;
      white-space: pre-wrap;
    }
    blockquote {
      border-left: 4px solid #d1d5db;
      margin-left: 0;
      padding-left: 12px;
      color: #4b5563;
    }
    a {
      color: #0f766e;
      text-decoration: none;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 12px 0;
      font-size: 0.95rem;
    }
    th, td {
      border: 1px solid #d1d5db;
      padding: 8px;
      vertical-align: top;
    }
    th {
      background: #f3f4f6;
      text-align: left;
    }
    @media print {
      body {
        max-width: none;
        padding: 0;
        font-size: 11pt;
      }
    }
  </style>
</head>
<body>
${htmlBody}
</body>
</html>`;

  fs.writeFileSync(outputPath, html);
}

main();
