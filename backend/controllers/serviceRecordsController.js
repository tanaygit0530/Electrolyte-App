const XLSX = require('xlsx');
const ExcelJS = require('exceljs');
const readline = require('readline');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
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
}, 600000);

/**
 * Helper to parse various date formats from Excel/CSV
 */
function parseDateValue(val) {
  if (!val) return null;
  if (val instanceof Date) {
    return isNaN(val.getTime()) ? null : val;
  }
  if (typeof val === 'number') {
    // Excel date serial number (days since 1899-12-30)
    const date = new Date(Math.round((val - 25569) * 86400 * 1000));
    return isNaN(date.getTime()) ? null : date;
  }
  const str = String(val).trim();
  if (!str) return null;

  // Handle DD/MM/YYYY or DD-MM-YYYY, with optional time
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

/**
 * Normalize header string to alphanumeric lowercase
 */
function cleanHeader(h) {
  return String(h || '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

/**
 * 1. Single Serial Number Check (Customer App / Technician)
 * GET /api/service-records/check/:serialNumber
 */
exports.checkSerialNumber = async (req, res) => {
  try {
    const rawSerial = req.params.serialNumber;
    if (!rawSerial || !rawSerial.trim()) {
      return res.status(400).json({ error: 'Serial number is required' });
    }

    const cleanSerial = rawSerial.trim().toUpperCase();

    // Query NeonDB for records matching serial_no or replacement_serial_no, prioritizing end_date within 60 days
    const query = `
      SELECT 
        id,
        case_number,
        serial_no,
        replacement_serial_no,
        customer_name,
        service_territory,
        city,
        state,
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
        parsed_end_date AS effective_date,
        ROUND(EXTRACT(EPOCH FROM (NOW() - parsed_end_date)) / 86400) AS days_ago
      FROM service_records
      WHERE (UPPER(TRIM(serial_no)) = $1 OR UPPER(TRIM(replacement_serial_no)) = $1)
      ORDER BY 
        CASE WHEN parsed_end_date >= NOW() - INTERVAL '60 days' AND parsed_end_date <= NOW() THEN 0 ELSE 1 END ASC,
        parsed_end_date DESC NULLS LAST,
        created_date DESC NULLS LAST
      LIMIT 1;
    `;

    const result = await pool.query(query, [cleanSerial]);

    if (result.rows.length === 0) {
      return res.json({
        success: true,
        status: 'SAFE TO CLOSE',
        isWithin60Days: false,
        repeatRisk: false,
        canCloseCall: true,
        serialNumber: cleanSerial,
        message: 'Safe to close',
        record: null
      });
    }

    const row = result.rows[0];
    const daysAgo = row.days_ago !== null ? parseInt(row.days_ago, 10) : null;
    const hasValidEndDate = row.parsed_end_date !== null && !isNaN(daysAgo);
    const isWithin60Days = hasValidEndDate && daysAgo >= 0 && daysAgo <= 60;
    const displayEndDate = row.end_date || (row.parsed_end_date ? row.parsed_end_date.toISOString().split('T')[0] : 'N/A');

    if (isWithin60Days) {
      return res.json({
        success: true,
        status: 'REPEAT RISK',
        isWithin60Days: true,
        repeatRisk: true,
        canCloseCall: false,
        daysAgo: daysAgo,
        serialNumber: row.serial_no,
        serviceDate: displayEndDate,
        endDate: displayEndDate,
        message: 'Repeat risk',
        record: {
          caseNumber: row.case_number,
          customerName: row.customer_name,
          city: row.city,
          state: row.state,
          productCode: row.product_code,
          productName: row.product_name,
          complaint: row.customer_complaint,
          repair: row.repair,
          status: row.wo_status,
          endDate: displayEndDate,
          serviceDate: displayEndDate,
          createdDate: row.created_date,
          closedDate: row.closed_date
        }
      });
    } else {
      return res.json({
        success: true,
        status: 'SAFE TO CLOSE',
        isWithin60Days: false,
        repeatRisk: false,
        canCloseCall: true,
        daysAgo: daysAgo,
        serialNumber: row.serial_no,
        serviceDate: displayEndDate,
        endDate: displayEndDate,
        message: 'Safe to close',
        record: {
          caseNumber: row.case_number,
          customerName: row.customer_name,
          productName: row.product_name,
          complaint: row.customer_complaint,
          repair: row.repair,
          status: row.wo_status,
          endDate: displayEndDate,
          serviceDate: displayEndDate
        }
      });
    }

  } catch (error) {
    console.error('Check Serial Number Error:', error);
    return res.status(500).json({ error: 'Internal Server Error checking serial number' });
  }
};

/**
 * Helper to insert batches using PostgreSQL UNNEST for maximum bulk performance
 */
async function insertBatchUnnest(client, batchRows) {
  if (!batchRows || batchRows.length === 0) return;
  const toStr = (v) => (v !== null && v !== undefined && String(v).trim() !== '') ? String(v).trim() : null;

  const b_case = [], b_created_date = [], b_work_order = [], b_customer = [], b_territory = [];
  const b_street = [], b_city = [], b_state = [], b_zip = [], b_complaint = [];
  const b_status = [], b_symptom = [], b_defect = [], b_repair = [], b_end_date = [];
  const b_parsed_end_date = [], b_days = [], b_prod_code = [], b_prod_name = [], b_prod_desc = [];
  const b_prod_type = [], b_prod_sub_type = [], b_warranty = [], b_type_of_wo = [], b_line_status = [];
  const b_sdr = [], b_invoice_date = [], b_tech_name = [], b_tech_remarks = [], b_serial = [];
  const b_repl_serial = [], b_resolution = [], b_closed_date = [];

  for (const r of batchRows) {
    b_case.push(toStr(r.case_number));
    b_created_date.push(r.created_date);
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
    b_parsed_end_date.push(r.parsed_end_date);
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
    )
    SELECT * FROM UNNEST(
      $1::text[], $2::timestamptz[], $3::text[], $4::text[], $5::text[],
      $6::text[], $7::text[], $8::text[], $9::text[], $10::text[],
      $11::text[], $12::text[], $13::text[], $14::text[], $15::text[],
      $16::timestamptz[], $17::text[], $18::text[], $19::text[], $20::text[],
      $21::text[], $22::text[], $23::text[], $24::text[], $25::text[],
      $26::text[], $27::text[], $28::text[], $29::text[], $30::text[],
      $31::text[], $32::text[], $33::text[]
    )
  `;

  await client.query(q, [
    b_case, b_created_date, b_work_order, b_customer, b_territory,
    b_street, b_city, b_state, b_zip, b_complaint,
    b_status, b_symptom, b_defect, b_repair, b_end_date,
    b_parsed_end_date, b_days, b_prod_code, b_prod_name, b_prod_desc,
    b_prod_type, b_prod_sub_type, b_warranty, b_type_of_wo, b_line_status,
    b_sdr, b_invoice_date, b_tech_name, b_tech_remarks, b_serial,
    b_repl_serial, b_resolution, b_closed_date
  ]);
}

/**
 * Helper to build column index map from header values
 */
function buildColMap(headers) {
  const getColIdx = (...aliases) => {
    for (const alias of aliases) {
      const idx = headers.indexOf(alias);
      if (idx !== -1) return idx;
    }
    return -1;
  };

  return {
    case: getColIdx('casenumber', 'case'),
    createdDate: getColIdx('createddate', 'date', 'servicedate'),
    workOrder: getColIdx('workorderlineitemnumber', 'workorder'),
    customer: getColIdx('customername', 'customer'),
    territory: getColIdx('serviceterritoryname', 'serviceterritory', 'territory'),
    street: getColIdx('street'),
    city: getColIdx('city'),
    state: getColIdx('stateprovince', 'state'),
    zip: getColIdx('zippostalcode', 'zipcode', 'zip', 'postalcode'),
    complaint: getColIdx('customercomplaint', 'complaint'),
    status: getColIdx('wostatus', 'status'),
    symptom: getColIdx('symptom'),
    defect: getColIdx('defect'),
    repair: getColIdx('repair'),
    endDate: getColIdx('enddate'),
    days: getColIdx('days'),
    prodCode: getColIdx('productcode'),
    prodName: getColIdx('productname'),
    prodDesc: getColIdx('productdescription', 'description'),
    prodType: getColIdx('producttype'),
    prodSubType: getColIdx('productsubtype'),
    warranty: getColIdx('warrantystatus'),
    typeOfWO: getColIdx('typeofworkorder'),
    lineItemStatus: getColIdx('lineitemstatus'),
    sdr: getColIdx('sdrstatus'),
    invoiceDate: getColIdx('invoicedate'),
    techName: getColIdx('technicianname', 'technician'),
    techRemarks: getColIdx('technicianremarks', 'remarks'),
    serial: getColIdx('serialno', 'serialnumber', 'serial'),
    replSerial: getColIdx('productserialnumberreplacement', 'replacementserial', 'replacementserialno'),
    resolution: getColIdx('typeofresolution'),
    closedDate: getColIdx('workordercloseddate', 'closeddate')
  };
}

/**
 * Fast check if an end_date value is within the 60-day window [now - 60 days, now].
 * Returns { isWithin60: boolean, parsedDate: Date|null, displayDate: string }
 */
function evaluateEndDate60Days(val, nowMs, sixtyDaysAgoMs, currentYear) {
  if (!val) {
    return { isWithin60: false, parsedDate: null, displayDate: 'N/A' };
  }

  let parsed = null;
  let display = 'N/A';

  if (val instanceof Date) {
    parsed = isNaN(val.getTime()) ? null : val;
    display = parsed ? parsed.toISOString().split('T')[0] : 'N/A';
  } else if (typeof val === 'number') {
    const t = Math.round((val - 25569) * 86400 * 1000);
    parsed = isNaN(t) ? null : new Date(t);
    display = parsed ? parsed.toISOString().split('T')[0] : String(val);
  } else {
    const str = String(val).trim();
    if (!str) {
      return { isWithin60: false, parsedDate: null, displayDate: 'N/A' };
    }
    display = str;

    // Fast check for DD/MM/YYYY or DD-MM-YYYY
    const c2 = str.charCodeAt(2);
    if ((c2 === 47 || c2 === 45) && (str.charCodeAt(5) === 47 || str.charCodeAt(5) === 45)) {
      const year = parseInt(str.substring(6, 10), 10);
      // If year is older than currentYear - 1 (e.g. 2021-2024 when now is 2026), it's definitely older than 60 days!
      if (!isNaN(year) && year < currentYear - 1) {
        return { isWithin60: false, parsedDate: null, displayDate: display };
      }
    }

    parsed = parseDateValue(str);
    if (!display && parsed) {
      display = parsed.toISOString().split('T')[0];
    }
  }

  if (!parsed) {
    return { isWithin60: false, parsedDate: null, displayDate: display };
  }

  const t = parsed.getTime();
  const isWithin60 = (t >= sixtyDaysAgoMs && t <= nowMs);
  return { isWithin60, parsedDate: parsed, displayDate: display };
}

/**
 * Extract full 35-column record object (only called for rows being saved to database)
 */
function extractFullRecord(vals, colMap, serialNo, parsedEndDate, displayEndDate) {
  const toStr = (v) => (v !== null && v !== undefined && String(v).trim() !== '') ? String(v).trim() : null;

  return {
    case_number: toStr(colMap.case !== -1 ? vals[colMap.case] : vals[1]),
    created_date: parseDateValue(colMap.createdDate !== -1 ? vals[colMap.createdDate] : vals[2]),
    work_order_line_item: toStr(colMap.workOrder !== -1 ? vals[colMap.workOrder] : vals[3]),
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
    serial_no: serialNo,
    replacement_serial_no: toStr(colMap.replSerial !== -1 ? vals[colMap.replSerial] : vals[32]),
    type_of_resolution: toStr(colMap.resolution !== -1 ? vals[colMap.resolution] : vals[34]),
    closed_date: toStr(colMap.closedDate !== -1 ? vals[colMap.closedDate] : vals[35])
  };
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

  // .xlsx / .xls: Use ExcelJS stream reader (maintains low heap < 180MB)
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

      worksheet.on('row', (row) => {
        try {
          if (row.number === 1) {
            if (onHeaders) onHeaders(row.values);
          } else {
            onRow(row.values, row.number);
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
/**
 * Asynchronously process an uploaded service file in the background
 */
async function processServiceFileJob(jobId, filePath, originalName, uploadedBy) {
  const job = activeJobs.get(jobId);
  if (!job) return;

  const parseStart = Date.now();
  let client = null;

  try {
    const now = new Date();
    const currentYear = now.getFullYear();
    const sixtyDaysAgoMs = now.getTime() - (60 * 24 * 60 * 60 * 1000);
    const nowMs = now.getTime();

    let colMap = null;
    let totalRecords = 0;
    let foundWithin60Days = 0;
    let olderThan60Days = 0;

    const foundEntries = [];
    const activeFoundRows = [];

    job.stage = 'Auditing 60-day window and identifying repeat risks...';

    // Stream pass 1: Perform 60-day audit, updating live job counters
    await streamReadServiceFile(
      filePath,
      (vals, rowNumber) => {
        if (!colMap) return;
        const rawSerial = colMap.serial !== -1 ? vals[colMap.serial] : vals[31];
        if (!rawSerial) return;
        const serialStr = String(rawSerial).trim();
        if (!serialStr || serialStr === 'null' || serialStr === 'undefined' || serialStr.toUpperCase() === 'NO BARCODE') {
          return;
        }

        totalRecords++;

        const rawEndDate = colMap.endDate !== -1 ? vals[colMap.endDate] : vals[15];
        const { isWithin60, parsedDate, displayDate } = evaluateEndDate60Days(rawEndDate, nowMs, sixtyDaysAgoMs, currentYear);

        if (isWithin60) {
          foundWithin60Days++;
          const rec = extractFullRecord(vals, colMap, serialStr, parsedDate, displayDate);
          activeFoundRows.push(rec);

          const daysAgo = Math.round((nowMs - parsedDate.getTime()) / 86400000);
          foundEntries.push({
            serialNumber: serialStr,
            date: displayDate,
            endDate: displayDate,
            daysAgo: daysAgo,
            caseNumber: rec.case_number,
            customerName: rec.customer_name,
            complaint: rec.customer_complaint,
            repair: rec.repair,
            status: rec.wo_status
          });
        } else {
          olderThan60Days++;
        }

        // Live progress update every 100 rows
        if (totalRecords % 100 === 0) {
          job.processedRows = totalRecords;
          job.foundWithin60Days = foundWithin60Days;
          job.olderThan60Days = olderThan60Days;
        }
      },
      (headersVals) => {
        const cleaned = headersVals.map(cleanHeader);
        colMap = buildColMap(cleaned);
      }
    );

    job.processedRows = totalRecords;
    job.foundWithin60Days = foundWithin60Days;
    job.olderThan60Days = olderThan60Days;

    if (totalRecords === 0) {
      job.status = 'failed';
      job.error = 'The uploaded file does not contain valid serial number records.';
      job.completedAt = Date.now();
      if (filePath && fs.existsSync(filePath)) {
        try { fs.unlinkSync(filePath); } catch (e) {}
      }
      return;
    }

    job.stage = 'Syncing repeat risk records to database...';

    // Persist active found records and audit history log synchronously in DB transaction
    client = await pool.connect();
    await client.query('BEGIN');

    if (activeFoundRows.length > 0) {
      await insertBatchUnnest(client, activeFoundRows);
    }

    const historyRes = await client.query(`
      INSERT INTO service_upload_history (
        file_name, uploaded_by, total_records, found_within_60_days, older_than_60_days
      ) VALUES ($1, $2, $3, $4, $5)
      RETURNING id, uploaded_at;
    `, [originalName, uploadedBy, totalRecords, foundWithin60Days, olderThan60Days]);

    await client.query('COMMIT');
    const uploadId = historyRes.rows[0].id;
    client.release();
    client = null;

    // Mark job as completed - UI can now display final results immediately!
    job.status = 'completed';
    job.stage = 'Completed';
    job.uploadId = uploadId;
    job.summary = {
      totalRecords,
      foundWithin60Days,
      olderThan60Days
    };
    job.foundEntries = foundEntries;
    job.completedAt = Date.now();

    console.log(`Job ${jobId} completed in ${((Date.now() - parseStart) / 1000).toFixed(1)}s: Total ${totalRecords}, Found within 60 days: ${foundWithin60Days}, Older: ${olderThan60Days}`);

    // Throttled background streaming of remaining historical records (with sequential queue and event-loop yielding)
    setTimeout(async () => {
      let bgClient = null;
      try {
        bgClient = await pool.connect();
        let histBatch = [];
        const BATCH_SIZE = 2500;
        let queuePromise = Promise.resolve();

        await streamReadServiceFile(
          filePath,
          (vals) => {
            if (!colMap) return;
            const rawSerial = colMap.serial !== -1 ? vals[colMap.serial] : vals[31];
            if (!rawSerial) return;
            const serialStr = String(rawSerial).trim();
            if (!serialStr || serialStr === 'null' || serialStr === 'undefined' || serialStr.toUpperCase() === 'NO BARCODE') return;

            const rawEndDate = colMap.endDate !== -1 ? vals[colMap.endDate] : vals[15];
            const { isWithin60, parsedDate, displayDate } = evaluateEndDate60Days(rawEndDate, nowMs, sixtyDaysAgoMs, currentYear);
            if (isWithin60) return; // already inserted in pass 1

            const rec = extractFullRecord(vals, colMap, serialStr, parsedDate, displayDate);
            histBatch.push(rec);

            if (histBatch.length >= BATCH_SIZE) {
              const toInsert = histBatch;
              histBatch = [];
              queuePromise = queuePromise.then(async () => {
                await insertBatchUnnest(bgClient, toInsert);
                await new Promise(r => setTimeout(r, 200));
              });
            }
          }
        );

        if (histBatch.length > 0) {
          const finalBatch = histBatch;
          histBatch = [];
          queuePromise = queuePromise.then(async () => {
            await insertBatchUnnest(bgClient, finalBatch);
          });
        }

        await queuePromise;
      } catch (bgErr) {
        console.error('Background historical streaming error for job', jobId, bgErr);
      } finally {
        if (bgClient) bgClient.release();
        if (filePath && fs.existsSync(filePath)) {
          try { fs.unlinkSync(filePath); } catch (e) {}
        }
      }
    }, 1000);

  } catch (error) {
    if (client) {
      try { await client.query('ROLLBACK'); } catch (rbErr) {}
      client.release();
    }
    console.error(`Job ${jobId} failed:`, error);
    job.status = 'failed';
    job.error = error.message || 'Failed to process service sheet.';
    job.completedAt = Date.now();
    if (filePath && fs.existsSync(filePath)) {
      try { fs.unlinkSync(filePath); } catch (e) {}
    }
  }
}

/**
 * 2. Bulk Upload Service Records (Admin App)
 * POST /api/service-records/upload
 * Immediately accepts file upload and dispatches asynchronous background job
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

    // Immediately return 202 Accepted to Admin App so connection never times out!
    res.status(202).json({
      success: true,
      jobId,
      fileName: originalName,
      message: 'File received. Background audit started.'
    });

    // Run job in background
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
 * 3. Fetch Upload History
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
        found_within_60_days,
        older_than_60_days,
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
        const val = row[h] ? String(row[h]).replace(/"/g, '""') : '';
        return `"${val}"`;
      }).join(',');
      csv += line + '\n';
    }

    return res.send(csv);

  } catch (error) {
    console.error('Export CSV Error:', error);
    return res.status(500).json({ error: 'Failed to export CSV' });
  }
};
