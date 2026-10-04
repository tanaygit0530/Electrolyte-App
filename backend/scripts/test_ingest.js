const XLSX = require('xlsx');
const path = require('path');
const { pool } = require('../config/neondb');

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

async function testIngest() {
  const filePath = path.join(__dirname, '../../Data.xlsx');
  console.log('Loading Data.xlsx for ingestion test from:', filePath);
  const start = Date.now();
  const workbook = XLSX.readFile(filePath, { cellDates: true, dense: true });
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: null });
  console.log(`Loaded ${rows.length - 1} rows in ${(Date.now() - start)/1000}s`);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const now = new Date();
    let totalRecords = 0;
    let foundWithin60Days = 0;
    let olderThan60Days = 0;

    const batchSize = 1000;
    let batch = [];

    const flush = async (b) => {
      if (b.length === 0) return;
      const values = [];
      const placeholders = [];
      let pIdx = 1;
      for (const r of b) {
        placeholders.push(`(
          $${pIdx}, $${pIdx + 1}, $${pIdx + 2}, $${pIdx + 3}, $${pIdx + 4},
          $${pIdx + 5}, $${pIdx + 6}, $${pIdx + 7}, $${pIdx + 8}, $${pIdx + 9},
          $${pIdx + 10}, $${pIdx + 11}, $${pIdx + 12}, $${pIdx + 13}, $${pIdx + 14},
          $${pIdx + 15}, $${pIdx + 16}, $${pIdx + 17}, $${pIdx + 18}, $${pIdx + 19},
          $${pIdx + 20}, $${pIdx + 21}, $${pIdx + 22}, $${pIdx + 23}, $${pIdx + 24},
          $${pIdx + 25}, $${pIdx + 26}, $${pIdx + 27}, $${pIdx + 28}, $${pIdx + 29},
          $${pIdx + 30}, $${pIdx + 31}, $${pIdx + 32}
        )`);
        values.push(
          r.case_number, r.created_date, r.work_order_line_item, r.customer_name, r.service_territory,
          r.street, r.city, r.state, r.zip_code, r.customer_complaint,
          r.wo_status, r.symptom, r.defect, r.repair, r.end_date,
          r.parsed_end_date, r.days, r.product_code, r.product_name, r.product_description,
          r.product_type, r.product_sub_type, r.warranty_status, r.type_of_work_order, r.line_item_status,
          r.sdr_status, r.invoice_date, r.technician_name, r.technician_remarks, r.serial_no,
          r.replacement_serial_no, r.type_of_resolution, r.closed_date
        );
        pIdx += 33;
      }
      const q = `
        INSERT INTO service_records (
          case_number, created_date, work_order_line_item, customer_name, service_territory,
          street, city, state, zip_code, customer_complaint,
          wo_status, symptom, defect, repair, end_date,
          parsed_end_date, days, product_code, product_name, product_description,
          product_type, product_sub_type, warranty_status, type_of_work_order, line_item_status,
          sdr_status, invoice_date, technician_name, technician_remarks, serial_no,
          replacement_serial_no, type_of_resolution, closed_date
        ) VALUES ${placeholders.join(', ')}
      `;
      await client.query(q, values);
    };

    // To test speed and avoid timeout in initial run, let's ingest 5,000 rows including the target rows
    // Row 59446 (LA24AECHA2P13535) and Row 48035 (4E23A2FDA2P10115)
    console.log('Selecting rows to ingest...');
    const targetIndices = new Set([48035, 54663, 59446, 70305, 93782]);
    for (let i = 1; i <= 3000; i++) targetIndices.add(i);
    for (let i = 59000; i <= 59500; i++) targetIndices.add(i);
    for (let i = 48000; i <= 48100; i++) targetIndices.add(i);

    console.log(`Ingesting sample slice of ${targetIndices.size} rows into service_records...`);
    for (const idx of targetIndices) {
      if (idx >= rows.length) continue;
      const row = rows[idx];
      const rawSerial = row[30];
      const serialNo = rawSerial ? String(rawSerial).trim() : null;
      if (!serialNo || serialNo === 'null' || serialNo === 'NO BARCODE') continue;

      totalRecords++;
      const createdDateVal = parseDateValue(row[1]);
      const parsedEndDate = parseDateValue(row[14]);
      const parsedClosedDate = parseDateValue(row[34]);
      const effectiveDate = parsedEndDate || createdDateVal || parsedClosedDate;

      if (effectiveDate) {
        const diffMs = now.getTime() - effectiveDate.getTime();
        const daysAgo = Math.round(diffMs / (24 * 60 * 60 * 1000));
        if (daysAgo >= 0 && daysAgo <= 60) {
          foundWithin60Days++;
        } else {
          olderThan60Days++;
        }
      } else {
        olderThan60Days++;
      }

      batch.push({
        case_number: row[0] ? String(row[0]) : null,
        created_date: createdDateVal,
        work_order_line_item: row[2] ? String(row[2]) : null,
        customer_name: row[3] ? String(row[3]) : null,
        service_territory: row[4] ? String(row[4]) : null,
        street: row[5] ? String(row[5]) : null,
        city: row[6] ? String(row[6]) : null,
        state: row[7] ? String(row[7]) : null,
        zip_code: row[8] ? String(row[8]) : null,
        customer_complaint: row[9] ? String(row[9]) : null,
        wo_status: row[10] ? String(row[10]) : null,
        symptom: row[11] ? String(row[11]) : null,
        defect: row[12] ? String(row[12]) : null,
        repair: row[13] ? String(row[13]) : null,
        end_date: row[14] ? String(row[14]) : null,
        parsed_end_date: parsedEndDate,
        days: row[15] ? String(row[15]) : null,
        product_code: row[16] ? String(row[16]) : null,
        product_name: row[17] ? String(row[17]) : null,
        product_description: row[18] ? String(row[18]) : null,
        product_type: row[19] ? String(row[19]) : null,
        product_sub_type: row[20] ? String(row[20]) : null,
        warranty_status: row[21] ? String(row[21]) : null,
        type_of_work_order: row[22] ? String(row[22]) : null,
        line_item_status: row[23] ? String(row[23]) : null,
        sdr_status: row[24] ? String(row[24]) : null,
        invoice_date: row[25] ? String(row[25]) : null,
        technician_name: row[26] ? String(row[26]) : null,
        technician_remarks: row[27] ? String(row[27]) : null,
        serial_no: serialNo,
        replacement_serial_no: row[31] ? String(row[31]).trim() : null,
        type_of_resolution: row[33] ? String(row[33]) : null,
        closed_date: row[34] ? String(row[34]) : null
      });

      if (batch.length >= batchSize) {
        await flush(batch);
        batch = [];
      }
    }

    if (batch.length > 0) {
      await flush(batch);
    }

    await client.query(`
      INSERT INTO service_upload_history (file_name, uploaded_by, total_records, found_within_60_days, older_than_60_days)
      VALUES ($1, $2, $3, $4, $5)
    `, ['Data.xlsx', 'TestAdmin', totalRecords, foundWithin60Days, olderThan60Days]);

    await client.query('COMMIT');
    console.log(`Successfully ingested sample records! Total: ${totalRecords}, Found within 60: ${foundWithin60Days}, Older: ${olderThan60Days}`);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Test Ingest Failed:', err);
  } finally {
    client.release();
  }

  // Now verify check query on NeonDB
  const controller = require('../controllers/serviceRecordsController');
  console.log('\n--- Testing checkSerialNumber with Sample 1 (LA24AECHA2P13535) ---');
  await controller.checkSerialNumber({ params: { serialNumber: 'LA24AECHA2P13535' } }, {
    json: (data) => console.log('Sample 1 Result:', JSON.stringify(data, null, 2)),
    status: (code) => ({ json: (d) => console.log('Error', code, d) })
  });

  console.log('\n--- Testing checkSerialNumber with Sample 2 (4E23A2FDA2P10115) ---');
  await controller.checkSerialNumber({ params: { serialNumber: '4E23A2FDA2P10115' } }, {
    json: (data) => console.log('Sample 2 Result:', JSON.stringify(data, null, 2)),
    status: (code) => ({ json: (d) => console.log('Error', code, d) })
  });

  console.log('\n--- Testing checkSerialNumber with Non-Existent Serial ---');
  await controller.checkSerialNumber({ params: { serialNumber: 'UNKNOWN_999' } }, {
    json: (data) => console.log('Non-existent Result:', JSON.stringify(data, null, 2)),
    status: (code) => ({ json: (d) => console.log('Error', code, d) })
  });

  process.exit(0);
}

testIngest();
