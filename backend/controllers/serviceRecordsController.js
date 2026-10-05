const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');
const { pool } = require('../config/neondb');

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
        message: 'Safe to close the call. No prior service record found in the database.',
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
        message: `Don't close the call, it may come in repeat. Serial number was serviced ${daysAgo} days ago (End Date: ${displayEndDate}), within the 60-day repeat risk window.`,
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
      let notFoundMsg = `Safe to close the call. Last service End Date was ${daysAgo} days ago (${displayEndDate}), beyond the 60-day repeat window.`;
      if (!hasValidEndDate) {
        notFoundMsg = `Safe to close the call. No valid recent End Date found within the 60-day repeat window.`;
      }

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
        message: notFoundMsg,
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
 * 2. Bulk Upload Service Records (Admin App)
 * POST /api/service-records/upload
 */
exports.uploadServiceFile = async (req, res) => {
  let filePath = null;
  let client = null;
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded. Please provide an .xlsx, .xls, or .csv file.' });
    }

    filePath = req.file.path;
    const originalName = req.file.originalname;
    const uploadedBy = req.admin ? req.admin.email : 'Admin';

    console.log(`Starting bulk service data ingestion for "${originalName}" (${(req.file.size / (1024 * 1024)).toFixed(2)} MB)...`);
    const parseStart = Date.now();

    // Parse workbook with SheetJS (dense mode for fast memory-efficient access)
    const workbook = XLSX.readFile(filePath, { cellDates: true, dense: true });
    const firstSheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[firstSheetName];
    const rows = XLSX.utils.sheet_to_json(worksheet, { header: 1, defval: null });

    if (!rows || rows.length < 2) {
      return res.status(400).json({ error: 'The uploaded file is empty or does not contain data rows.' });
    }

    const headers = rows[0].map(cleanHeader);
    console.log(`Parsed ${rows.length - 1} rows in ${(Date.now() - parseStart) / 1000}s. Mapping columns...`);

    // Helper to find column index from potential header names
    const getColIdx = (...aliases) => {
      for (const alias of aliases) {
        const idx = headers.indexOf(alias);
        if (idx !== -1) return idx;
      }
      return -1;
    };

    const colCase = getColIdx('casenumber', 'case');
    const colCreatedDate = getColIdx('createddate', 'date', 'servicedate');
    const colWorkOrder = getColIdx('workorderlineitemnumber', 'workorder');
    const colCustomer = getColIdx('customername', 'customer');
    const colTerritory = getColIdx('serviceterritoryname', 'serviceterritory', 'territory');
    const colStreet = getColIdx('street');
    const colCity = getColIdx('city');
    const colState = getColIdx('stateprovince', 'state');
    const colZip = getColIdx('zippostalcode', 'zipcode', 'zip', 'postalcode');
    const colComplaint = getColIdx('customercomplaint', 'complaint');
    const colStatus = getColIdx('wostatus', 'status');
    const colSymptom = getColIdx('symptom');
    const colDefect = getColIdx('defect');
    const colRepair = getColIdx('repair');
    const colEndDate = getColIdx('enddate');
    const colDays = getColIdx('days');
    const colProdCode = getColIdx('productcode');
    const colProdName = getColIdx('productname');
    const colProdDesc = getColIdx('productdescription', 'description');
    const colProdType = getColIdx('producttype');
    const colProdSubType = getColIdx('productsubtype');
    const colWarranty = getColIdx('warrantystatus');
    const colTypeOfWO = getColIdx('typeofworkorder');
    const colLineItemStatus = getColIdx('lineitemstatus');
    const colSdr = getColIdx('sdrstatus');
    const colInvoiceDate = getColIdx('invoicedate');
    const colTechName = getColIdx('technicianname', 'technician');
    const colTechRemarks = getColIdx('technicianremarks', 'remarks');
    const colSerial = getColIdx('serialno', 'serialnumber', 'serial');
    const colReplSerial = getColIdx('productserialnumberreplacement', 'replacementserial', 'replacementserialno');
    const colResolution = getColIdx('typeofresolution');
    const colClosedDate = getColIdx('workordercloseddate', 'closeddate');

    const now = new Date();
    let totalRecords = 0;
    let foundWithin60Days = 0;
    let olderThan60Days = 0;

    const foundEntries = [];
    const activeFoundRows = [];
    const historicalRows = [];

    const toStr = (v) => (v !== null && v !== undefined && String(v).trim() !== '') ? String(v).trim() : null;

    // Process all rows in memory (sub-second audit execution)
    for (let i = 1; i < rows.length; i++) {
      const row = rows[i];
      if (!row || row.length === 0) continue;

      const rawSerial = colSerial !== -1 ? row[colSerial] : row[30];
      const serialNo = toStr(rawSerial);

      // Skip rows with completely empty or null serial
      if (!serialNo || serialNo === 'null' || serialNo === 'undefined') {
        continue;
      }

      totalRecords++;

      const createdDateVal = parseDateValue(colCreatedDate !== -1 ? row[colCreatedDate] : row[1]);
      const rawEndDate = colEndDate !== -1 ? row[colEndDate] : row[14];
      const parsedEndDate = parseDateValue(rawEndDate);
      const rawClosedDate = colClosedDate !== -1 ? row[colClosedDate] : row[34];

      const recordObj = {
        case_number: toStr(colCase !== -1 ? row[colCase] : row[0]),
        created_date: createdDateVal,
        work_order_line_item: toStr(colWorkOrder !== -1 ? row[colWorkOrder] : row[2]),
        customer_name: toStr(colCustomer !== -1 ? row[colCustomer] : row[3]),
        service_territory: toStr(colTerritory !== -1 ? row[colTerritory] : row[4]),
        street: toStr(colStreet !== -1 ? row[colStreet] : row[5]),
        city: toStr(colCity !== -1 ? row[colCity] : row[6]),
        state: toStr(colState !== -1 ? row[colState] : row[7]),
        zip_code: toStr(colZip !== -1 ? row[colZip] : row[8]),
        customer_complaint: toStr(colComplaint !== -1 ? row[colComplaint] : row[9]),
        wo_status: toStr(colStatus !== -1 ? row[colStatus] : row[10]),
        symptom: toStr(colSymptom !== -1 ? row[colSymptom] : row[11]),
        defect: toStr(colDefect !== -1 ? row[colDefect] : row[12]),
        repair: toStr(colRepair !== -1 ? row[colRepair] : row[13]),
        end_date: toStr(rawEndDate),
        parsed_end_date: parsedEndDate,
        days: toStr(colDays !== -1 ? row[colDays] : row[15]),
        product_code: toStr(colProdCode !== -1 ? row[colProdCode] : row[16]),
        product_name: toStr(colProdName !== -1 ? row[colProdName] : row[17]),
        product_description: toStr(colProdDesc !== -1 ? row[colProdDesc] : row[18]),
        product_type: toStr(colProdType !== -1 ? row[colProdType] : row[19]),
        product_sub_type: toStr(colProdSubType !== -1 ? row[colProdSubType] : row[20]),
        warranty_status: toStr(colWarranty !== -1 ? row[colWarranty] : row[21]),
        type_of_work_order: toStr(colTypeOfWO !== -1 ? row[colTypeOfWO] : row[22]),
        line_item_status: toStr(colLineItemStatus !== -1 ? row[colLineItemStatus] : row[23]),
        sdr_status: toStr(colSdr !== -1 ? row[colSdr] : row[24]),
        invoice_date: toStr(colInvoiceDate !== -1 ? row[colInvoiceDate] : row[25]),
        technician_name: toStr(colTechName !== -1 ? row[colTechName] : row[26]),
        technician_remarks: toStr(colTechRemarks !== -1 ? row[colTechRemarks] : row[27]),
        serial_no: serialNo,
        replacement_serial_no: toStr(colReplSerial !== -1 ? row[colReplSerial] : row[31]),
        type_of_resolution: toStr(colResolution !== -1 ? row[colResolution] : row[33]),
        closed_date: toStr(rawClosedDate)
      };

      // 60-Day Audit logic: compare strictly with End Date
      if (parsedEndDate) {
        const timeDiff = now.getTime() - parsedEndDate.getTime();
        const daysAgo = Math.round(timeDiff / (24 * 60 * 60 * 1000));
        if (daysAgo >= 0 && daysAgo <= 60) {
          foundWithin60Days++;
          foundEntries.push({
            serialNumber: serialNo,
            date: rawEndDate ? String(rawEndDate).trim() : parsedEndDate.toISOString().split('T')[0],
            endDate: rawEndDate ? String(rawEndDate).trim() : parsedEndDate.toISOString().split('T')[0],
            daysAgo: daysAgo,
            caseNumber: recordObj.case_number,
            customerName: recordObj.customer_name,
            complaint: recordObj.customer_complaint,
            repair: recordObj.repair,
            status: recordObj.wo_status
          });
          activeFoundRows.push(recordObj);
        } else {
          olderThan60Days++;
          historicalRows.push(recordObj);
        }
      } else {
        olderThan60Days++;
        historicalRows.push(recordObj);
      }
    }

    console.log(`Audit complete: Total ${totalRecords}, Found within 60 days: ${foundWithin60Days}, Older: ${olderThan60Days}`);

    // Persist active found records and audit history log synchronously
    client = await pool.connect();
    await client.query('BEGIN');

    // 1. Immediately insert active 60-day records (< 0.5s via UNNEST)
    if (activeFoundRows.length > 0) {
      await insertBatchUnnest(client, activeFoundRows);
    }

    // 2. Save upload history entry
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

    // 3. Immediately return response to Admin App! Eliminates spinning & UI timeout!
    res.json({
      success: true,
      message: `File processed successfully. ${foundWithin60Days} entries found within the active 60-day window out of ${totalRecords} records.`,
      uploadId,
      fileName: originalName,
      summary: {
        totalRecords,
        foundWithin60Days,
        olderThan60Days
      },
      foundEntries: foundEntries
    });

    // 4. Ingest remaining historical records asynchronously in the background using UNNEST (5,000 per batch)
    setImmediate(async () => {
      let bgClient = null;
      try {
        console.log(`Background ingestion starting for ${historicalRows.length} historical records...`);
        bgClient = await pool.connect();
        const BG_BATCH_SIZE = 5000;
        for (let b = 0; b < historicalRows.length; b += BG_BATCH_SIZE) {
          const chunk = historicalRows.slice(b, b + BG_BATCH_SIZE);
          await insertBatchUnnest(bgClient, chunk);
        }
        console.log(`Background ingestion complete for ${historicalRows.length} historical records.`);
      } catch (bgErr) {
        console.error('Background historical records ingestion error:', bgErr);
      } finally {
        if (bgClient) bgClient.release();
        if (filePath && fs.existsSync(filePath)) {
          try { fs.unlinkSync(filePath); } catch (e) {}
        }
      }
    });

  } catch (error) {
    if (client) {
      try { await client.query('ROLLBACK'); } catch (rbErr) {}
    }
    console.error('Service Data Upload Error:', error);
    return res.status(500).json({ error: error.message || 'Failed to process service data upload' });
  } finally {
    if (client) {
      client.release();
    }
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
