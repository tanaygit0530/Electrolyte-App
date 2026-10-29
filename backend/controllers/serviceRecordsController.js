const ExcelJS = require('exceljs');
const readline = require('readline');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const logger = require('../utils/logger');
const { pool } = require('../config/neondb');

/**
 * In-memory registry for real-time background service sheet ingestion jobs
 */
const activeJobs = new Map();

// Auto-cleanup jobs older than 1 hour to prevent memory leaks
setInterval(() => {
  const oneHourAgo = Date.now() - 3600000;
  for (const [id, job] of activeJobs.entries()) {
    if (job.completedAt && job.completedAt < oneHourAgo) {
      activeJobs.delete(id);
    }
  }
}, 600000).unref();

/**
 * Timezone-aware calendar days calculation in business timezone (Asia/Kolkata).
 * Compares calendar midnight of baseDate with calendar midnight of targetDate.
 */
function getCalendarDaysAgo(targetDate, baseDate = new Date()) {
  if (!targetDate || isNaN(targetDate.getTime())) return null;

  const toISTMidnight = (d) => {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Kolkata',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    });
    const parts = formatter.format(d).split('-').map(Number);
    return Date.UTC(parts[0], parts[1] - 1, parts[2]);
  };

  const msPerDay = 86400000;
  return Math.round((toISTMidnight(baseDate) - toISTMidnight(targetDate)) / msPerDay);
}

/**
 * Normalize serial numbers consistently:
 * Uppercase, trim whitespace, remove non-printable characters, preserve leading zeros.
 * Returns null if serial number is empty or placeholder text (e.g. 'NO BARCODE').
 */
function normalizeSerialNumber(raw) {
  if (raw === null || raw === undefined) return null;
  let s = String(raw).trim().toUpperCase();
  // Strip control and non-printable characters
  s = s.replace(/[\x00-\x1F\x7F-\x9F]/g, '');
  if (!s) return null;

  const dummyValues = new Set([
    'NO BARCODE', 'NO_BARCODE', 'NOBARCODE', 'NULL', 'UNDEFINED',
    'N/A', 'NA', 'NONE', '0', 'NOT AVAILABLE', 'NOT_AVAILABLE',
    'NOT APPLICABLE', 'NOTAPPLICABLE', '-'
  ]);
  if (dummyValues.has(s)) return null;

  return s;
}


/**
 * Standardize and validate date values from CSV / Excel / ISO strings.
 * Supports DD/MM/YYYY, DD-MM-YYYY (with optional HH:mm[:ss] am/pm), ISO strings, and Excel serial numbers.
 * Validates year realism (2000 to 2100).
 */
function parseDateValue(val) {
  if (val === null || val === undefined) return null;

  if (val instanceof Date) {
    return isNaN(val.getTime()) ? null : val;
  }

  if (typeof val === 'number') {
    // Excel date serial number (days since 1899-12-30)
    const ms = Math.round((val - 25569) * 86400 * 1000);
    const date = new Date(ms);
    return isNaN(date.getTime()) ? null : date;
  }

  const str = String(val).trim();
  if (!str) return null;

  // Handle DD/MM/YYYY or DD-MM-YYYY, with optional time
  const ddmmyyyyMatch = str.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})(?:[,\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?)?/i);
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
    const parsed = new Date(Date.UTC(year, month, day, hour, min, sec));
    if (!isNaN(parsed.getTime()) && year >= 2000 && year <= 2100) {
      return parsed;
    }
  }

  // Handle ISO format or standard JS parseable date
  const standard = new Date(str);
  if (!isNaN(standard.getTime())) {
    const y = standard.getUTCFullYear();
    if (y >= 2000 && y <= 2100) {
      return standard;
    }
  }

  return null;
}

/**
 * Format date for technician UI display (DD/MM/YYYY)
 */
function formatDisplayDate(date) {
  if (!date || isNaN(date.getTime())) return 'N/A';
  const day = String(date.getUTCDate()).padStart(2, '0');
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const year = date.getUTCFullYear();
  return `${day}/${month}/${year}`;
}

/**
 * Normalize header string to alphanumeric lowercase
 */
function cleanHeader(h) {
  return String(h || '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

/**
 * Robust, configurable column mapping for service job sheets
 */
function buildNormalizedColMap(headers) {
  const cleanedHeaders = headers.map(cleanHeader);
  const getColIdx = (...aliases) => {
    // 1. Exact alias match
    for (const alias of aliases) {
      const idx = cleanedHeaders.indexOf(alias);
      if (idx !== -1) return idx;
    }
    // 2. Substring match for compound headers like 'Work Order Line Item: Work Order Line Item Number'
    for (const alias of aliases) {
      const idx = cleanedHeaders.findIndex(h => h && h.includes(alias));
      if (idx !== -1) return idx;
    }
    return -1;
  };



  return {
    case: getColIdx('casenumber', 'case', 'caseno', 'workordernumber', 'workorderid'),
    createdDate: getColIdx('createddate', 'date', 'servicedate', 'calldate'),
    workOrder: getColIdx('workorderlineitemnumber', 'workorderlineitem', 'workorder', 'wolineitem', 'lineitem'),
    customer: getColIdx('customername', 'customer', 'clientname'),
    territory: getColIdx('serviceterritoryname', 'serviceterritory', 'territory'),
    street: getColIdx('street', 'address'),
    city: getColIdx('city'),
    state: getColIdx('stateprovince', 'state'),
    zip: getColIdx('zippostalcode', 'zipcode', 'zip', 'postalcode'),
    complaint: getColIdx('customercomplaint', 'complaint', 'issue', 'symptom'),
    status: getColIdx('wostatus', 'status', 'workorderstatus'),
    symptom: getColIdx('symptom'),
    defect: getColIdx('defect'),
    repair: getColIdx('repair', 'repairaction', 'resolution', 'actiontaken'),
    endDate: getColIdx('enddate', 'closeddate', 'workordercloseddate', 'servicedate', 'completiondate'),
    days: getColIdx('days'),
    prodCode: getColIdx('productcode', 'partcode', 'itemcode'),
    prodName: getColIdx('productname', 'product', 'itemname'),
    prodDesc: getColIdx('productdescription', 'description'),
    prodType: getColIdx('producttype'),
    prodSubType: getColIdx('productsubtype'),
    warranty: getColIdx('warrantystatus'),
    typeOfWO: getColIdx('typeofworkorder'),
    lineItemStatus: getColIdx('lineitemstatus'),
    sdr: getColIdx('sdrstatus'),
    invoiceDate: getColIdx('invoicedate'),
    techName: getColIdx('technicianname', 'technician', 'techname', 'engineer'),
    techRemarks: getColIdx('technicianremarks', 'remarks'),
    serial: getColIdx('serialno', 'serialnumber', 'serial', 'productserialnumber', 'barcode'),
    replSerial: getColIdx('productserialnumberreplacement', 'replacementserial', 'replacementserialno'),
    resolution: getColIdx('typeofresolution'),
    closedDate: getColIdx('workordercloseddate', 'closeddate')
  };
}

/**
 * Extract clean, normalized 35-column record object ready for database ingestion
 */
function extractFullRecord(vals, colMap, cleanSerial, cleanCase, cleanWoItem, parsedEndDate, displayEndDate, parsedCreatedDate, isActive60d) {
  const toStr = (v) => {
    if (v === null || v === undefined) return null;
    const s = String(v).trim();
    return s.length > 0 ? s : null;
  };

  const cleanRepl = normalizeSerialNumber(colMap.replSerial !== -1 ? vals[colMap.replSerial] : vals[32]);

  return {
    case_number: cleanCase,
    created_date: parsedCreatedDate,
    work_order_line_item: cleanWoItem,
    customer_name: toStr(colMap.customer !== -1 ? vals[colMap.customer] : vals[4]),
    service_territory: toStr(colMap.territory !== -1 ? vals[colMap.territory] : vals[5]),
    street: toStr(colMap.street !== -1 ? vals[colMap.street] : vals[6]),
    city: toStr(colMap.city !== -1 ? vals[colMap.city] : vals[7]),
    state: toStr(colMap.state !== -1 ? vals[colMap.state] : vals[8]),
    zip_code: toStr(colMap.zip !== -1 ? vals[colMap.zip] : vals[9]),
    customer_complaint: toStr(colMap.complaint !== -1 ? vals[colMap.complaint] : vals[10]),
    wo_status: toStr(colMap.status !== -1 ? vals[colMap.status] : vals[11]),
    symptom: toStr(colMap.symptom !== -1 ? vals[colMap.symptom] : vals[12]),
    defect: toStr(colMap.defect !== -1 ? vals[colMap.defect] : vals[13]),
    repair: toStr(colMap.repair !== -1 ? vals[colMap.repair] : vals[14]),
    end_date: displayEndDate,
    parsed_end_date: parsedEndDate,
    days: toStr(colMap.days !== -1 ? vals[colMap.days] : vals[16]),
    product_code: toStr(colMap.prodCode !== -1 ? vals[colMap.prodCode] : vals[17]),
    product_name: toStr(colMap.prodName !== -1 ? vals[colMap.prodName] : vals[18]),
    product_description: toStr(colMap.prodDesc !== -1 ? vals[colMap.prodDesc] : vals[19]),
    product_type: toStr(colMap.prodType !== -1 ? vals[colMap.prodType] : vals[20]),
    product_sub_type: toStr(colMap.prodSubType !== -1 ? vals[colMap.prodSubType] : vals[21]),
    warranty_status: toStr(colMap.warranty !== -1 ? vals[colMap.warranty] : vals[22]),
    type_of_work_order: toStr(colMap.typeOfWO !== -1 ? vals[colMap.typeOfWO] : vals[23]),
    line_item_status: toStr(colMap.lineItemStatus !== -1 ? vals[colMap.lineItemStatus] : vals[24]),
    sdr_status: toStr(colMap.sdr !== -1 ? vals[colMap.sdr] : vals[25]),
    invoice_date: toStr(colMap.invoiceDate !== -1 ? vals[colMap.invoiceDate] : vals[26]),
    technician_name: toStr(colMap.techName !== -1 ? vals[colMap.techName] : vals[27]),
    technician_remarks: toStr(colMap.techRemarks !== -1 ? vals[colMap.techRemarks] : vals[28]),
    serial_no: cleanSerial,
    replacement_serial_no: cleanRepl,
    type_of_resolution: toStr(colMap.resolution !== -1 ? vals[colMap.resolution] : vals[34]),
    closed_date: toStr(colMap.closedDate !== -1 ? vals[colMap.closedDate] : vals[35]),
    parsed_closed_date: parseDateValue(colMap.closedDate !== -1 ? vals[colMap.closedDate] : vals[35]),
    is_active_60d: isActive60d
  };
}

/**
 * Non-destructive bulk UPSERT using PostgreSQL UNNEST and ON CONFLICT.
 * Preserves existing valid database values if incoming values are null/empty.
 * Returns exact counts of inserted, updated, and unchanged records.
 */
async function bulkUpsertServiceRecords(client, batchRows) {
  if (!batchRows || batchRows.length === 0) {
    return { inserted: 0, updated: 0, unchanged: 0 };
  }

  const toStr = (v) => (v !== null && v !== undefined && String(v).trim() !== '') ? String(v).trim() : null;

  const b_case = [], b_created_date = [], b_work_order = [], b_customer = [], b_territory = [];
  const b_street = [], b_city = [], b_state = [], b_zip = [], b_complaint = [];
  const b_status = [], b_symptom = [], b_defect = [], b_repair = [], b_end_date = [];
  const b_parsed_end_date = [], b_days = [], b_prod_code = [], b_prod_name = [], b_prod_desc = [];
  const b_prod_type = [], b_prod_sub_type = [], b_warranty = [], b_type_of_wo = [], b_line_status = [];
  const b_sdr = [], b_invoice_date = [], b_tech_name = [], b_tech_remarks = [], b_serial = [];
  const b_repl_serial = [], b_resolution = [], b_closed_date = [], b_parsed_closed_date = [];
  const b_is_active = [];

  const toDateOrNull = (d) => (d instanceof Date && !isNaN(d.getTime())) ? d.toISOString() : null;

  for (const r of batchRows) {
    b_case.push(toStr(r.case_number));
    b_created_date.push(toDateOrNull(r.created_date));
    b_work_order.push(toStr(r.work_order_line_item));
    b_customer.push(toStr(r.customer_name));
    b_territory.push(toStr(r.service_territory));
    b_street.push(toStr(r.street));
    b_city.push(toStr(r.city));
    b_state.push(toStr(r.state));
    b_zip.push(toStr(r.zip_code));
    b_complaint.push(toStr(r.customer_complaint));
    b_status.push(toStr(r.wo_status));
    b_symptom.push(toStr(r.symptom));
    b_defect.push(toStr(r.defect));
    b_repair.push(toStr(r.repair));
    b_end_date.push(toStr(r.end_date));
    b_parsed_end_date.push(toDateOrNull(r.parsed_end_date));
    b_days.push(toStr(r.days));
    b_prod_code.push(toStr(r.product_code));
    b_prod_name.push(toStr(r.product_name));
    b_prod_desc.push(toStr(r.product_description));
    b_prod_type.push(toStr(r.product_type));
    b_prod_sub_type.push(toStr(r.product_sub_type));
    b_warranty.push(toStr(r.warranty_status));
    b_type_of_wo.push(toStr(r.type_of_work_order));
    b_line_status.push(toStr(r.line_item_status));
    b_sdr.push(toStr(r.sdr_status));
    b_invoice_date.push(toStr(r.invoice_date));
    b_tech_name.push(toStr(r.technician_name));
    b_tech_remarks.push(toStr(r.technician_remarks));
    b_serial.push(toStr(r.serial_no));
    b_repl_serial.push(toStr(r.replacement_serial_no));
    b_resolution.push(toStr(r.type_of_resolution));
    b_closed_date.push(toStr(r.closed_date));
    b_parsed_closed_date.push(toDateOrNull(r.parsed_closed_date));
    b_is_active.push(Boolean(r.is_active_60d));
  }

  const upsertQuery = `
    INSERT INTO service_records (
      case_number, created_date, work_order_line_item, customer_name, service_territory,
      street, city, state, zip_code, customer_complaint,
      wo_status, symptom, defect, repair, end_date,
      parsed_end_date, days, product_code, product_name, product_description,
      product_type, product_sub_type, warranty_status, type_of_work_order, line_item_status,
      sdr_status, invoice_date, technician_name, technician_remarks, serial_no,
      replacement_serial_no, type_of_resolution, closed_date, parsed_closed_date, is_active_60d,
      updated_at
    )
    SELECT 
      t.c1, t.c2, t.c3, t.c4, t.c5,
      t.c6, t.c7, t.c8, t.c9, t.c10,
      t.c11, t.c12, t.c13, t.c14, t.c15,
      t.c16, t.c17, t.c18, t.c19, t.c20,
      t.c21, t.c22, t.c23, t.c24, t.c25,
      t.c26, t.c27, t.c28, t.c29, t.c30,
      t.c31, t.c32, t.c33, t.c34, t.c35,
      NOW()
    FROM UNNEST(
      $1::text[], $2::timestamptz[], $3::text[], $4::text[], $5::text[],
      $6::text[], $7::text[], $8::text[], $9::text[], $10::text[],
      $11::text[], $12::text[], $13::text[], $14::text[], $15::text[],
      $16::timestamptz[], $17::text[], $18::text[], $19::text[], $20::text[],
      $21::text[], $22::text[], $23::text[], $24::text[], $25::text[],
      $26::text[], $27::text[], $28::text[], $29::text[], $30::text[],
      $31::text[], $32::text[], $33::text[], $34::timestamptz[], $35::boolean[]
    ) AS t(
      c1, c2, c3, c4, c5,
      c6, c7, c8, c9, c10,
      c11, c12, c13, c14, c15,
      c16, c17, c18, c19, c20,
      c21, c22, c23, c24, c25,
      c26, c27, c28, c29, c30,
      c31, c32, c33, c34, c35
    )
    ON CONFLICT (case_number, work_order_line_item, serial_no)

    DO UPDATE SET
      customer_name = COALESCE(EXCLUDED.customer_name, service_records.customer_name),
      service_territory = COALESCE(EXCLUDED.service_territory, service_records.service_territory),
      street = COALESCE(EXCLUDED.street, service_records.street),
      city = COALESCE(EXCLUDED.city, service_records.city),
      state = COALESCE(EXCLUDED.state, service_records.state),
      zip_code = COALESCE(EXCLUDED.zip_code, service_records.zip_code),
      customer_complaint = COALESCE(EXCLUDED.customer_complaint, service_records.customer_complaint),
      wo_status = COALESCE(EXCLUDED.wo_status, service_records.wo_status),
      symptom = COALESCE(EXCLUDED.symptom, service_records.symptom),
      defect = COALESCE(EXCLUDED.defect, service_records.defect),
      repair = COALESCE(EXCLUDED.repair, service_records.repair),
      end_date = COALESCE(EXCLUDED.end_date, service_records.end_date),
      parsed_end_date = COALESCE(EXCLUDED.parsed_end_date, service_records.parsed_end_date),
      days = COALESCE(EXCLUDED.days, service_records.days),
      product_code = COALESCE(EXCLUDED.product_code, service_records.product_code),
      product_name = COALESCE(EXCLUDED.product_name, service_records.product_name),
      product_description = COALESCE(EXCLUDED.product_description, service_records.product_description),
      product_type = COALESCE(EXCLUDED.product_type, service_records.product_type),
      product_sub_type = COALESCE(EXCLUDED.product_sub_type, service_records.product_sub_type),
      warranty_status = COALESCE(EXCLUDED.warranty_status, service_records.warranty_status),
      type_of_work_order = COALESCE(EXCLUDED.type_of_work_order, service_records.type_of_work_order),
      line_item_status = COALESCE(EXCLUDED.line_item_status, service_records.line_item_status),
      sdr_status = COALESCE(EXCLUDED.sdr_status, service_records.sdr_status),
      invoice_date = COALESCE(EXCLUDED.invoice_date, service_records.invoice_date),
      technician_name = COALESCE(EXCLUDED.technician_name, service_records.technician_name),
      technician_remarks = COALESCE(EXCLUDED.technician_remarks, service_records.technician_remarks),
      replacement_serial_no = COALESCE(EXCLUDED.replacement_serial_no, service_records.replacement_serial_no),
      type_of_resolution = COALESCE(EXCLUDED.type_of_resolution, service_records.type_of_resolution),
      closed_date = COALESCE(EXCLUDED.closed_date, service_records.closed_date),
      parsed_closed_date = COALESCE(EXCLUDED.parsed_closed_date, service_records.parsed_closed_date),
      is_active_60d = EXCLUDED.is_active_60d,
      created_date = COALESCE(EXCLUDED.created_date, service_records.created_date),
      updated_at = NOW()
    WHERE 
      service_records.parsed_end_date IS DISTINCT FROM EXCLUDED.parsed_end_date
      OR service_records.wo_status IS DISTINCT FROM EXCLUDED.wo_status
      OR service_records.repair IS DISTINCT FROM EXCLUDED.repair
      OR service_records.technician_remarks IS DISTINCT FROM EXCLUDED.technician_remarks
      OR service_records.replacement_serial_no IS DISTINCT FROM EXCLUDED.replacement_serial_no
      OR service_records.customer_complaint IS DISTINCT FROM EXCLUDED.customer_complaint
      OR service_records.is_active_60d IS DISTINCT FROM EXCLUDED.is_active_60d
    RETURNING (xmax = 0) AS was_inserted;
  `;

  const res = await client.query(upsertQuery, [
    b_case, b_created_date, b_work_order, b_customer, b_territory,
    b_street, b_city, b_state, b_zip, b_complaint,
    b_status, b_symptom, b_defect, b_repair, b_end_date,
    b_parsed_end_date, b_days, b_prod_code, b_prod_name, b_prod_desc,
    b_prod_type, b_prod_sub_type, b_warranty, b_type_of_wo, b_line_status,
    b_sdr, b_invoice_date, b_tech_name, b_tech_remarks, b_serial,
    b_repl_serial, b_resolution, b_closed_date, b_parsed_closed_date, b_is_active
  ]);

  let inserted = 0;
  let updated = 0;
  for (const row of res.rows) {
    if (row.was_inserted) {
      inserted++;
    } else {
      updated++;
    }
  }

  const unchanged = batchRows.length - res.rows.length;
  return { inserted, updated, unchanged };
}

/**
 * Memory-efficient streaming file reader for .xlsx and .csv files.
 */
async function streamReadServiceFile(filePath, onRow, onHeaders) {
  const ext = path.extname(filePath).toLowerCase();

  if (ext === '.csv') {
    const rl = readline.createInterface({
      input: fs.createReadStream(filePath),
      crlfDelay: Infinity
    });

    let rowNum = 0;
    for await (const line of rl) {
      if (!line || !line.trim()) continue;
      rowNum++;
      const parsedValues = [null]; // 1-indexed to match ExcelJS
      let cur = '';
      let inQuotes = false;
      for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (ch === '"') {
          if (inQuotes && line[i + 1] === '"') {
            cur += '"';
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (ch === ',' && !inQuotes) {
          parsedValues.push(cur.trim());
          cur = '';
        } else {
          cur += ch;
        }
      }
      parsedValues.push(cur.trim());

      if (rowNum === 1) {
        if (onHeaders) onHeaders(parsedValues);
      } else {
        await onRow(parsedValues, rowNum);
      }
    }
    return;
  }

  // .xlsx / .xls: Use ExcelJS stream reader
  return new Promise((resolve, reject) => {
    let isFirstSheet = true;
    let streamAborted = false;

    const workbookReader = new ExcelJS.stream.xlsx.WorkbookReader(filePath, {
      entries: 'emit',
      worksheets: 'emit',
      sharedStrings: 'cache',
      styles: 'ignore'
    });

    workbookReader.on('worksheet', (worksheet) => {
      if (!isFirstSheet) return;
      isFirstSheet = false;

      worksheet.on('row', async (row) => {
        try {
          if (row.number === 1) {
            if (onHeaders) onHeaders(row.values);
          } else {
            await onRow(row.values, row.number);
          }
        } catch (err) {
          streamAborted = true;
          reject(err);
        }
      });
    });

    workbookReader.on('end', () => {
      if (!streamAborted) resolve();
    });

    workbookReader.on('error', (err) => {
      reject(err);
    });

    workbookReader.read();
  });
}

/**
 * Authoritative 60-Day Data Retention Cleanup.
 * Removes expired service records (> 60 calendar days old, null date, or future-dated)
 * from the operational service_records table.
 *
 * Uses PostgreSQL advisory lock (ID: 7492813) when running as a standalone job to avoid
 * concurrent runs across multiple server instances.
 */
async function cleanupExpiredServiceRecords(options = {}) {
  const startTime = Date.now();
  const db = options.client || pool;
  const isDedicatedClient = Boolean(options.client);
  let acquiredLock = false;

  try {
    if (!isDedicatedClient) {
      const lockRes = await db.query('SELECT pg_try_advisory_lock(7492813) AS acquired;');
      if (!lockRes.rows[0].acquired) {
        return {
          success: true,
          skipped: true,
          reason: 'Another cleanup task is already running.'
        };
      }
      acquiredLock = true;
    }

    // 1. Cutoff dates in business timezone (Asia/Kolkata)
    // - Boundary of 60 days: Retained (0 to 60 calendar days is active repeat risk).
    // - Older than 60 days (61+ calendar days): Deleted.
    // - Future dates (> tomorrow in IST): Deleted.
    const cutoffRes = await db.query(`
      SELECT 
        ((NOW() AT TIME ZONE 'Asia/Kolkata')::date - INTERVAL '60 days')::date AS cutoff_date,
        ((NOW() AT TIME ZONE 'Asia/Kolkata')::date + INTERVAL '1 day')::date AS future_boundary;
    `);
    const cutoffDate = cutoffRes.rows[0].cutoff_date;
    const futureBoundary = cutoffRes.rows[0].future_boundary;

    // 2. Perform deletion of expired, null-date, and future-dated records
    const deleteRes = await db.query(`
      DELETE FROM service_records
      WHERE parsed_end_date IS NULL
         OR (parsed_end_date AT TIME ZONE 'Asia/Kolkata')::date < $1::date
         OR (parsed_end_date AT TIME ZONE 'Asia/Kolkata')::date > $2::date;
    `, [cutoffDate, futureBoundary]);

    const deletedCount = deleteRes.rowCount;

    // 3. Ensure is_active_60d flag is true for all remaining records in operational table
    await db.query(`
      UPDATE service_records
      SET is_active_60d = true
      WHERE is_active_60d IS DISTINCT FROM true;
    `);

    // 4. Query total remaining active records
    const countRes = await db.query('SELECT COUNT(*) AS total FROM service_records;');
    const remainingCount = parseInt(countRes.rows[0].total, 10);
    const durationMs = Date.now() - startTime;

    console.log(`[Retention Cleanup] Purged ${deletedCount} records (Cutoff: ${cutoffDate}). Remaining operational records: ${remainingCount} (${durationMs}ms).`);

    return {
      success: true,
      deletedCount,
      cutoffDate,
      remainingCount,
      durationMs
    };
  } catch (error) {
    console.error('[Retention Cleanup] Failed:', error);
    throw error;
  } finally {
    if (acquiredLock) {
      try {
        await db.query('SELECT pg_advisory_unlock(7492813);');
      } catch (_) {}
    }
  }
}

/**
 * Asynchronously process and ingest an uploaded service file
 */
async function processServiceFileJob(jobId, filePath, originalName, uploadedBy) {

  const job = activeJobs.get(jobId);
  if (!job) return;

  const parseStart = Date.now();
  let client = null;

  try {
    const now = new Date();
    let colMap = null;

    let totalRowsReceived = 0;
    let validRecords = 0;
    let rejectedRecords = 0;
    let duplicatesInFile = 0;
    let foundWithin60Days = 0;
    let olderThan60Days = 0;

    const rejectedReasons = {};
    const seenInFile = new Set();
    const recordsToUpsert = [];
    const foundEntries = [];

    const recordRejection = (reason) => {
      rejectedRecords++;
      rejectedReasons[reason] = (rejectedReasons[reason] || 0) + 1;
    };

    job.stage = 'Validating and preprocessing CSV records...';

    // Stream pass: Read, clean, validate, deduplicate in-memory
    await streamReadServiceFile(
      filePath,
      (vals, rowNumber) => {
        if (!colMap) return;

        // Skip completely empty rows
        if (!vals || vals.length <= 1 || vals.slice(1).every(v => v === null || v === undefined || String(v).trim() === '')) {
          return;
        }

        totalRowsReceived++;

        // 1. Extract and normalize Serial Number
        const rawSerial = colMap.serial !== -1 ? vals[colMap.serial] : vals[31];
        const cleanSerial = normalizeSerialNumber(rawSerial);
        if (!cleanSerial) {
          recordRejection('Missing or invalid serial number');
          return;
        }

        // 2. Extract and validate Service End Date
        const rawEndDate = colMap.endDate !== -1 ? vals[colMap.endDate] : vals[15];
        const parsedEndDate = parseDateValue(rawEndDate);
        if (!parsedEndDate) {
          recordRejection('Missing or unparseable end date');
          return;
        }

        // Check for future-dated records (allowing 1 day tolerance for timezone)
        const daysAgo = getCalendarDaysAgo(parsedEndDate, now);
        if (daysAgo !== null && daysAgo < -1) {
          recordRejection('Future-dated service record');
          return;
        }

        // 3. Extract Case Number & Work Order Line Item
        const rawCase = colMap.case !== -1 ? vals[colMap.case] : vals[1];
        const cleanCase = (rawCase !== null && rawCase !== undefined && String(rawCase).trim().length > 0)
          ? String(rawCase).trim().toUpperCase()
          : 'UNKNOWN';

        const rawWo = colMap.workOrder !== -1 ? vals[colMap.workOrder] : vals[3];
        const cleanWo = (rawWo !== null && rawWo !== undefined && String(rawWo).trim().length > 0)
          ? String(rawWo).trim()
          : '1';

        // 4. In-File Deduplication Check
        const compositeKey = `${cleanCase}|${cleanWo}|${cleanSerial}`;
        if (seenInFile.has(compositeKey)) {
          duplicatesInFile++;
          return;
        }
        seenInFile.add(compositeKey);

        // 5. Evaluate rolling 60-day window
        const isWithin60 = (daysAgo !== null && daysAgo >= 0 && daysAgo <= 60);
        if (isWithin60) {
          foundWithin60Days++;
        } else {
          olderThan60Days++;
        }

        const displayEndDate = formatDisplayDate(parsedEndDate);
        const parsedCreatedDate = parseDateValue(colMap.createdDate !== -1 ? vals[colMap.createdDate] : vals[2]);

        const record = extractFullRecord(
          vals,
          colMap,
          cleanSerial,
          cleanCase,
          cleanWo,
          parsedEndDate,
          displayEndDate,
          parsedCreatedDate,
          isWithin60
        );

        validRecords++;

        // Only eligible records within the rolling 60-day window are stored in the operational table
        if (isWithin60) {
          recordsToUpsert.push(record);
          foundEntries.push({
            serialNumber: cleanSerial,
            date: displayEndDate,
            endDate: displayEndDate,
            daysAgo: daysAgo,
            caseNumber: record.case_number,
            customerName: record.customer_name,
            complaint: record.customer_complaint,
            repair: record.repair,
            status: record.wo_status
          });
        }

        // Update live job counters
        if (totalRowsReceived % 250 === 0) {
          job.processedRows = totalRowsReceived;
          job.foundWithin60Days = foundWithin60Days;
          job.olderThan60Days = olderThan60Days;
        }
      },
      (headersVals) => {
        const cleaned = headersVals.map(cleanHeader);
        colMap = buildNormalizedColMap(cleaned);
      }
    );

    job.processedRows = totalRowsReceived;
    job.foundWithin60Days = foundWithin60Days;
    job.olderThan60Days = olderThan60Days;

    if (validRecords === 0) {
      job.status = 'failed';
      job.error = 'No valid service records found in file. Please verify column headers and date formats.';
      job.completedAt = Date.now();
      if (filePath && fs.existsSync(filePath)) {
        try { fs.unlinkSync(filePath); } catch (_) {}
      }
      return;
    }

    job.stage = 'Executing atomic bulk database upsert...';

    // Execute bulk upserts inside transaction
    client = await pool.connect();
    await client.query('BEGIN');

    let totalInserted = 0;
    let totalUpdated = 0;
    let totalUnchanged = 0;

    const BATCH_SIZE = 1000;
    for (let i = 0; i < recordsToUpsert.length; i += BATCH_SIZE) {
      const batch = recordsToUpsert.slice(i, i + BATCH_SIZE);
      const res = await bulkUpsertServiceRecords(client, batch);
      totalInserted += res.inserted;
      totalUpdated += res.updated;
      totalUnchanged += res.unchanged;
    }

    // Atomically purge any expired records (> 60 days) from the operational table
    await cleanupExpiredServiceRecords({ client });


    const durationMs = Date.now() - parseStart;
    const errorSummaryJson = JSON.stringify(rejectedReasons);

    const historyRes = await client.query(`
      INSERT INTO service_upload_history (
        file_name, uploaded_by, total_records, valid_records, rejected_records,
        duplicates_in_file, found_within_60_days, older_than_60_days,
        inserted_records, updated_records, unchanged_records,
        processing_duration_ms, error_summary, status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13::jsonb, $14)
      RETURNING id, uploaded_at;
    `, [
      originalName, uploadedBy, totalRowsReceived, validRecords, rejectedRecords,
      duplicatesInFile, foundWithin60Days, olderThan60Days,
      totalInserted, totalUpdated, totalUnchanged,
      durationMs, errorSummaryJson, 'completed'
    ]);

    await client.query('COMMIT');
    const uploadId = historyRes.rows[0].id;
    client.release();
    client = null;

    job.status = 'completed';
    job.stage = 'Completed';
    job.uploadId = uploadId;
    job.summary = {
      totalRecords: totalRowsReceived,
      validRecords,
      rejectedRecords,
      duplicatesInFile,
      foundWithin60Days,
      olderThan60Days,
      insertedRecords: totalInserted,
      updatedRecords: totalUpdated,
      unchangedRecords: totalUnchanged,
      processingDurationMs: durationMs,
      rejectedReasons
    };
    job.foundEntries = foundEntries;
    job.completedAt = Date.now();

    console.log(`Ingestion job ${jobId} finished in ${(durationMs / 1000).toFixed(1)}s: Total ${totalRowsReceived}, Valid: ${validRecords}, Inserted: ${totalInserted}, Updated: ${totalUpdated}, Unchanged: ${totalUnchanged}`);

  } catch (error) {
    if (client) {
      try { await client.query('ROLLBACK'); } catch (_) {}
      client.release();
    }
    console.error(`Ingestion job ${jobId} failed:`, error);
    job.status = 'failed';
    job.error = error.message || 'Failed to process service sheet.';
    job.completedAt = Date.now();
  } finally {
    if (filePath && fs.existsSync(filePath)) {
      try { fs.unlinkSync(filePath); } catch (_) {}
    }
  }
}

/**
 * 1. Single Serial Number Check (Customer App / Technician)
 * GET /api/service-records/check/:serialNumber
 */
exports.checkSerialNumber = async (req, res) => {
  const startTime = Date.now();
  try {
    const rawSerial = req.params.serialNumber;
    const cleanSerial = normalizeSerialNumber(rawSerial);

    if (!cleanSerial) {
      const duration = Date.now() - startTime;
      logger.warn(`[checkSerialNumber] Rejected invalid or empty serial in ${duration}ms`);
      return res.status(400).json({ error: 'Valid serial number is required' });
    }

    // Select the latest applicable previous service end_date for the same serial number
    const query = `
      SELECT 
        id,
        case_number,
        work_order_line_item,
        serial_no,
        replacement_serial_no,
        customer_name,
        service_territory,
        city,
        state,
        zip_code,
        customer_complaint,
        repair,
        wo_status,
        product_code,
        product_name,
        created_date,
        end_date,
        parsed_end_date,
        closed_date,
        parsed_closed_date,
        technician_name,
        technician_remarks,
        is_active_60d
      FROM service_records
      WHERE UPPER(TRIM(serial_no)) = $1 
         OR (replacement_serial_no IS NOT NULL AND UPPER(TRIM(replacement_serial_no)) = $1)
      ORDER BY 
        parsed_end_date DESC NULLS LAST,
        created_date DESC NULLS LAST
      LIMIT 1;
    `;

    const dbStart = Date.now();
    const result = await pool.query(query, [cleanSerial]);
    const dbDuration = Date.now() - dbStart;

    // Mask serial number to avoid exposing sensitive PII in logs
    const maskedSerial = cleanSerial.length > 7
      ? `${cleanSerial.slice(0, 4)}***${cleanSerial.slice(-3)}`
      : cleanSerial;

    if (result.rows.length === 0) {
      const totalDuration = Date.now() - startTime;
      logger.info(`[checkSerialNumber] Serial: ${maskedSerial} -> SAFE TO CLOSE (no prior record, db: ${dbDuration}ms, total: ${totalDuration}ms)`);
      return res.json({
        success: true,
        status: 'SAFE TO CLOSE',
        isWithin60Days: false,
        repeatRisk: false,
        canCloseCall: true,
        daysAgo: null,
        lastServiceDate: null,
        serialNumber: cleanSerial,
        message: 'No previous service history found for this serial number. Safe to close.',
        record: null
      });
    }

    const row = result.rows[0];
    const lastServiceDate = row.parsed_end_date;

    // Handle invalid date state
    if (!lastServiceDate || isNaN(lastServiceDate.getTime())) {
      const totalDuration = Date.now() - startTime;
      logger.warn(`[checkSerialNumber] Serial: ${maskedSerial} -> REVIEW NEEDED (invalid date, db: ${dbDuration}ms, total: ${totalDuration}ms)`);
      return res.json({
        success: true,
        status: 'REVIEW NEEDED',
        isWithin60Days: false,
        repeatRisk: false,
        canCloseCall: false,
        daysAgo: null,
        lastServiceDate: null,
        serialNumber: cleanSerial,
        message: 'Previous service record has an invalid completion date. Supervisor review required.',
        record: {
          caseNumber: row.case_number,
          workOrder: row.work_order_line_item,
          customerName: row.customer_name,
          serviceDate: row.end_date || 'Invalid Date',
          status: row.wo_status,
          complaint: row.customer_complaint,
          repair: row.repair,
          technician: row.technician_name
        }
      });
    }

    const daysAgo = getCalendarDaysAgo(lastServiceDate, new Date());
    const displayDate = formatDisplayDate(lastServiceDate);

    // Handle future-dated service record safely
    if (daysAgo !== null && daysAgo < 0) {
      const totalDuration = Date.now() - startTime;
      logger.warn(`[checkSerialNumber] Serial: ${maskedSerial} -> REVIEW NEEDED (future date: ${displayDate}, db: ${dbDuration}ms, total: ${totalDuration}ms)`);
      return res.json({
        success: true,
        status: 'REVIEW NEEDED',
        isWithin60Days: false,
        repeatRisk: false,
        canCloseCall: false,
        daysAgo: daysAgo,
        lastServiceDate: displayDate,
        serialNumber: cleanSerial,
        message: `Previous service record has a future date (${displayDate}). Supervisor review required.`,
        record: {
          caseNumber: row.case_number,
          workOrder: row.work_order_line_item,
          customerName: row.customer_name,
          serviceDate: displayDate,
          status: row.wo_status,
          complaint: row.customer_complaint,
          repair: row.repair,
          technician: row.technician_name
        }
      });
    }

    // Exactly 0–60 days inclusive is REPEAT RISK
    const isWithin60Days = (daysAgo !== null && daysAgo >= 0 && daysAgo <= 60);
    const totalDuration = Date.now() - startTime;

    if (isWithin60Days) {
      logger.info(`[checkSerialNumber] Serial: ${maskedSerial} -> REPEAT RISK (${daysAgo} days ago, db: ${dbDuration}ms, total: ${totalDuration}ms)`);
      return res.json({
        success: true,
        status: 'REPEAT RISK',
        isWithin60Days: true,
        repeatRisk: true,
        canCloseCall: false,
        daysAgo: daysAgo,
        lastServiceDate: displayDate,
        serialNumber: cleanSerial,
        message: `Repeat service risk: Last service was completed ${daysAgo === 0 ? 'today' : daysAgo + ' days ago'} (within 60-day warranty window). Free repeat warranty rules apply.`,
        record: {
          caseNumber: row.case_number,
          workOrder: row.work_order_line_item,
          customerName: row.customer_name,
          serviceDate: displayDate,
          status: row.wo_status,
          complaint: row.customer_complaint,
          repair: row.repair,
          technician: row.technician_name,
          technicianRemarks: row.technician_remarks
        }
      });
    } else {
      // 61+ days is SAFE TO CLOSE
      logger.info(`[checkSerialNumber] Serial: ${maskedSerial} -> SAFE TO CLOSE (${daysAgo} days ago, db: ${dbDuration}ms, total: ${totalDuration}ms)`);
      return res.json({
        success: true,
        status: 'SAFE TO CLOSE',
        isWithin60Days: false,
        repeatRisk: false,
        canCloseCall: true,
        daysAgo: daysAgo,
        lastServiceDate: displayDate,
        serialNumber: cleanSerial,
        message: `Safe to close: Last service was completed ${daysAgo} days ago (outside the 60-day window).`,
        record: {
          caseNumber: row.case_number,
          workOrder: row.work_order_line_item,
          customerName: row.customer_name,
          serviceDate: displayDate,
          status: row.wo_status,
          complaint: row.customer_complaint,
          repair: row.repair,
          technician: row.technician_name
        }
      });
    }

  } catch (error) {
    const totalDuration = Date.now() - startTime;
    logger.error(`[checkSerialNumber] Error after ${totalDuration}ms:`, error.message);
    return res.status(500).json({ error: 'Internal Server Error checking serial number' });
  }
};

/**
 * 2. Bulk Upload Service Records (Admin App)
 * POST /api/service-records/upload
 */
exports.uploadServiceFile = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded. Please provide an .xlsx, .xls, or .csv file.' });
    }

    const filePath = req.file.path;
    const originalName = req.file.originalname;
    const uploadedBy = req.admin ? req.admin.email : 'Admin';
    const jobId = crypto.randomUUID();

    const job = {
      id: jobId,
      status: 'processing',
      stage: 'File uploaded. Initializing background audit...',
      fileName: originalName,
      fileSize: req.file.size,
      uploadedBy,
      startedAt: Date.now(),
      completedAt: null,
      processedRows: 0,
      foundWithin60Days: 0,
      olderThan60Days: 0,
      summary: null,
      foundEntries: [],
      error: null
    };

    activeJobs.set(jobId, job);

    console.log(`Accepted upload for "${originalName}" (${(req.file.size / (1024 * 1024)).toFixed(2)} MB). Dispatched job ${jobId}`);

    res.status(202).json({
      success: true,
      jobId,
      fileName: originalName,
      message: 'File received. Background audit started.'
    });

    setImmediate(() => {
      processServiceFileJob(jobId, filePath, originalName, uploadedBy);
    });

  } catch (error) {
    console.error('Service Data Upload Initiation Error:', error);
    return res.status(500).json({ error: error.message || 'Failed to initiate service upload' });
  }
};

/**
 * 2b. Poll Background Ingestion Job Status
 * GET /api/service-records/job-status/:jobId
 */
exports.getJobStatus = async (req, res) => {
  try {
    const { jobId } = req.params;
    const job = activeJobs.get(jobId);
    if (!job) {
      return res.status(404).json({ success: false, error: 'Job not found or expired' });
    }

    return res.json({
      success: true,
      job: {
        id: job.id,
        status: job.status,
        stage: job.stage,
        fileName: job.fileName,
        processedRows: job.processedRows,
        foundWithin60Days: job.foundWithin60Days,
        olderThan60Days: job.olderThan60Days,
        summary: job.summary,
        foundEntries: job.status === 'completed' ? job.foundEntries : [],
        error: job.error
      }
    });
  } catch (error) {
    console.error('Get Job Status Error:', error);
    return res.status(500).json({ error: 'Failed to retrieve job status' });
  }
};

/**
 * 3. Fetch Upload History with Comprehensive Audit Metrics
 * GET /api/service-records/history
 */
exports.getUploadHistory = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        id,
        file_name,
        uploaded_by,
        total_records,
        valid_records,
        rejected_records,
        duplicates_in_file,
        found_within_60_days,
        older_than_60_days,
        inserted_records,
        updated_records,
        unchanged_records,
        processing_duration_ms,
        error_summary,
        status,
        uploaded_at
      FROM service_upload_history
      ORDER BY uploaded_at DESC
      LIMIT 50;
    `);

    return res.json({
      success: true,
      history: result.rows
    });
  } catch (error) {
    console.error('Get Upload History Error:', error);
    return res.status(500).json({ error: 'Failed to retrieve upload history' });
  }
};

/**
 * 4. Get Found Entries (All records within last 60 days currently in DB)
 * GET /api/service-records/found-entries
 */
exports.getFoundEntries = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit, 10) || 100;
    const offset = parseInt(req.query.offset, 10) || 0;
    const search = req.query.search ? String(req.query.search).trim().toUpperCase() : null;

    let whereClause = `
      WHERE (parsed_end_date >= NOW() - INTERVAL '60 days')
        AND (parsed_end_date <= NOW())
    `;
    const params = [];

    if (search) {
      params.push(`%${search}%`);
      whereClause += ` AND (UPPER(serial_no) LIKE $${params.length} OR UPPER(replacement_serial_no) LIKE $${params.length})`;
    }

    const countRes = await pool.query(`SELECT COUNT(*) FROM service_records ${whereClause}`, params);
    const totalFound = parseInt(countRes.rows[0].count, 10);

    params.push(limit);
    const limitIdx = params.length;
    params.push(offset);
    const offsetIdx = params.length;

    const dataQuery = `
      SELECT 
        id,
        serial_no AS "serialNumber",
        COALESCE(end_date, TO_CHAR(parsed_end_date, 'YYYY-MM-DD')) AS "date",
        COALESCE(end_date, TO_CHAR(parsed_end_date, 'YYYY-MM-DD')) AS "endDate",
        ROUND(EXTRACT(EPOCH FROM (NOW() - parsed_end_date)) / 86400) AS "daysAgo",
        case_number AS "caseNumber",
        customer_name AS "customerName",
        customer_complaint AS "complaint",
        repair,
        wo_status AS "status"
      FROM service_records
      ${whereClause}
      ORDER BY parsed_end_date DESC
      LIMIT $${limitIdx} OFFSET $${offsetIdx}
    `;

    const dataRes = await pool.query(dataQuery, params);

    return res.json({
      success: true,
      total: totalFound,
      limit,
      offset,
      entries: dataRes.rows
    });
  } catch (error) {
    console.error('Get Found Entries Error:', error);
    return res.status(500).json({ error: 'Failed to retrieve found entries' });
  }
};

/**
 * 5. Export Found Entries to CSV
 * GET /api/service-records/export-found
 */
exports.exportFoundCsv = async (req, res) => {
  try {
    const query = `
      SELECT 
        serial_no AS "Serial Number",
        COALESCE(end_date, TO_CHAR(parsed_end_date, 'YYYY-MM-DD')) AS "End Date",
        ROUND(EXTRACT(EPOCH FROM (NOW() - parsed_end_date)) / 86400) AS "Days Ago",
        case_number AS "Case Number",
        customer_name AS "Customer Name",
        city AS "City",
        state AS "State",
        customer_complaint AS "Customer Complaint",
        repair AS "Repair Action",
        wo_status AS "Status"
      FROM service_records
      WHERE (parsed_end_date >= NOW() - INTERVAL '60 days')
        AND (parsed_end_date <= NOW())
      ORDER BY parsed_end_date DESC;
    `;

    const result = await pool.query(query);

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="Found_Serial_Numbers_60_Days.csv"');

    if (result.rows.length === 0) {
      return res.send('Serial Number,Service Date,Days Ago,Case Number,Customer Name,City,State,Customer Complaint,Repair Action,Status\n');
    }

    const headers = Object.keys(result.rows[0]);
    let csv = headers.join(',') + '\n';

    for (const row of result.rows) {
      const line = headers.map(h => {
        // Prevent CSV injection by escaping quotes and preventing leading formula markers (=, +, -, @)
        let val = row[h] ? String(row[h]).trim() : '';
        if (/^[=+\-@]/.test(val)) {
          val = `'` + val;
        }
        return `"${val.replace(/"/g, '""')}"`;
      }).join(',');
      csv += line + '\n';
    }

    return res.send(csv);

  } catch (error) {
    console.error('Export CSV Error:', error);
    return res.status(500).json({ error: 'Failed to export CSV' });
  }
};

/**
 * Manual cleanup trigger endpoint for admins
 * POST /api/service-records/cleanup
 */
exports.triggerManualCleanup = async (req, res) => {
  try {
    const result = await cleanupExpiredServiceRecords();
    return res.json({
      success: true,
      message: '60-day data retention cleanup completed successfully',
      ...result
    });
  } catch (error) {
    console.error('Manual cleanup error:', error);
    return res.status(500).json({ success: false, error: 'Failed to execute data retention cleanup' });
  }
};

// Export helper utilities for automated test coverage and scheduler execution
exports.cleanupExpiredServiceRecords = cleanupExpiredServiceRecords;
exports.getCalendarDaysAgo = getCalendarDaysAgo;
exports.normalizeSerialNumber = normalizeSerialNumber;
exports.parseDateValue = parseDateValue;
exports.buildNormalizedColMap = buildNormalizedColMap;
exports.bulkUpsertServiceRecords = bulkUpsertServiceRecords;
exports.processServiceFileJob = processServiceFileJob;

