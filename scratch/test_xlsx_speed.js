const XLSX = require('../backend/node_modules/xlsx');
const path = require('path');

console.log('Testing XLSX.readFile on Data.xlsx...');
const start = Date.now();
const filePath = path.join(__dirname, '../Data.xlsx');
console.log('File path:', filePath);
const workbook = XLSX.readFile(filePath, { cellDates: true, dense: true });
console.log('XLSX.readFile finished in', (Date.now() - start) / 1000, 's');
const sheet = workbook.Sheets[workbook.SheetNames[0]];
const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: null });
console.log('sheet_to_json finished. Row count:', rows.length, 'Total elapsed:', (Date.now() - start) / 1000, 's');
