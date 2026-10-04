const path = require('path');
const XLSX = require('../backend/node_modules/xlsx');
const { pool } = require('../backend/config/neondb');

function cleanHeader(h) {
  return String(h || '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

function parseDateValue(val) {
  if (!val) return null;
  if (val instanceof Date) return isNaN(val.getTime()) ? null : val;
  if (typeof val === 'number') {
    const date = new Date(Math.round((val - 25569) * 86400 * 1000));
    return isNaN(date.getTime()) ? null : date;
  }
  const str = String(val).trim();
  if (!str) return null;
  const ddmmyyyyMatch = str.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})(?:,\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?)?/i);
  if (ddmmyyyyMatch) {
    const day = parseInt(ddmmyyyyMatch[1], 10);
    const month = parseInt(ddmmyyyyMatch[2], 10) - 1;
    const year = parseInt(ddmmyyyyMatch[3], 10);
    let hour = ddmmyyyyMatch[4] ? parseInt(ddmmyyyyMatch[4], 10) : 0;
    const min = ddmmyyyyMatch[5] ? parseInt(ddmmyyyyMatch[5], 10) : 0;
    const sec = ddmmyyyyMatch[6] ? parseInt(ddmmyyyyMatch[6], 10) : 0;
    const ampm = ddmmyyyyMatch[7] ? ddmmyyyyMatch[7].toLowerCase() : null;
    if (ampm === 'pm' && hour < 12) hour += 12;
    if (ampm === 'am' && hour === 12) hour = 0;
    return new Date(Date.UTC(year, month, day, hour, min, sec));
  }
  const standard = new Date(str);
  return isNaN(standard.getTime()) ? null : standard;
}

async function simulateUpload() {
  console.log('Simulating upload on Data.xlsx...');
  const t0 = Date.now();
  const filePath = path.join(__dirname, '../Data.xlsx');
  
  const workbook = XLSX.readFile(filePath, { cellDates: true, dense: true });
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: null });
  console.log(`Parsed ${rows.length} rows in ${(Date.now() - t0)/1000}s`);

  const headers = rows[0].map(cleanHeader);
  const getColIdx = (...aliases) => {
    for (const alias of aliases) {
      const idx = headers.indexOf(alias);
      if (idx !== -1) return idx;
    }
    return -1;
  };

  const colSerial = getColIdx('serialno', 'serialnumber', 'serial');
  const colEndDate = getColIdx('enddate');
  const now = new Date();
  
  let found = 0;
  let total = 0;
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    if (!row) continue;
    const rawSerial = colSerial !== -1 ? row[colSerial] : row[30];
    if (!rawSerial) continue;
    total++;
    const rawEndDate = colEndDate !== -1 ? row[colEndDate] : row[14];
    const parsedEndDate = parseDateValue(rawEndDate);
    if (parsedEndDate) {
      const diff = now.getTime() - parsedEndDate.getTime();
      const days = Math.round(diff / (86400000));
      if (days >= 0 && days <= 60) {
        found++;
      }
    }
  }

  console.log(`Audit complete in ${(Date.now() - t0)/1000}s! Total valid serials: ${total}, Found within 60 days: ${found}`);
  
  // Now let's test how fast DB batch insert would take for 1 batch
  console.log('Testing 1 batch insertion into DB...');
  const client = await pool.connect();
  try {
    const tBatch = Date.now();
    await client.query('SELECT 1');
    console.log(`Neon ping took ${(Date.now() - tBatch)}ms`);
  } finally {
    client.release();
    await pool.end();
  }
}

simulateUpload().catch(console.error);
