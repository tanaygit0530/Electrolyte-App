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

async function testFullUpload() {
  const filePath = path.join(__dirname, '../Data.xlsx');
  console.log('Testing full UNNEST upload pipeline on Data.xlsx...');
  const tStart = Date.now();

  const workbook = XLSX.readFile(filePath, { cellDates: true, dense: true });
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: null });
  console.log(`1. Parsed ${rows.length} rows in ${(Date.now() - tStart)/1000}s`);

  const headers = rows[0].map(cleanHeader);
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

  // Column arrays for UNNEST
  const BATCH_SIZE = 5000;
  let b_case = [], b_created_date = [], b_work_order = [], b_customer = [], b_territory = [];
  let b_street = [], b_city = [], b_state = [], b_zip = [], b_complaint = [];
  let b_status = [], b_symptom = [], b_defect = [], b_repair = [], b_end_date = [];
  let b_parsed_end_date = [], b_days = [], b_prod_code = [], b_prod_name = [], b_prod_desc = [];
  let b_prod_type = [], b_prod_sub_type = [], b_warranty = [], b_type_of_wo = [], b_line_status = [];
  let b_sdr = [], b_invoice_date = [], b_tech_name = [], b_tech_remarks = [], b_serial = [];
  let b_repl_serial = [], b_resolution = [], b_closed_date = [];

  const client = await pool.connect();
  await client.query('BEGIN');

  const flushUnnest = async () => {
    if (b_serial.length === 0) return;
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

    // Clear arrays
    b_case = []; b_created_date = []; b_work_order = []; b_customer = []; b_territory = [];
    b_street = []; b_city = []; b_state = []; b_zip = []; b_complaint = [];
    b_status = []; b_symptom = []; b_defect = []; b_repair = []; b_end_date = [];
    b_parsed_end_date = []; b_days = []; b_prod_code = []; b_prod_name = []; b_prod_desc = [];
    b_prod_type = []; b_prod_sub_type = []; b_warranty = []; b_type_of_wo = []; b_line_status = [];
    b_sdr = []; b_invoice_date = []; b_tech_name = []; b_tech_remarks = []; b_serial = [];
    b_repl_serial = []; b_resolution = []; b_closed_date = [];
  };

  const toStr = (v) => (v !== null && v !== undefined && String(v).trim() !== '') ? String(v).trim() : null;

  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    if (!row || row.length === 0) continue;
    const rawSerial = colSerial !== -1 ? row[colSerial] : row[30];
    const serialNo = toStr(rawSerial);
    if (!serialNo || serialNo === 'null' || serialNo === 'undefined') continue;

    totalRecords++;
    const rawEndDate = colEndDate !== -1 ? row[colEndDate] : row[14];
    const parsedEndDate = parseDateValue(rawEndDate);
    const createdDateVal = parseDateValue(colCreatedDate !== -1 ? row[colCreatedDate] : row[1]);
    const rawClosedDate = colClosedDate !== -1 ? row[colClosedDate] : row[34];

    if (parsedEndDate) {
      const diff = now.getTime() - parsedEndDate.getTime();
      const days = Math.round(diff / 86400000);
      if (days >= 0 && days <= 60) {
        foundWithin60Days++;
        foundEntries.push({
          serialNumber: serialNo,
          date: rawEndDate ? String(rawEndDate).trim() : parsedEndDate.toISOString().split('T')[0],
          endDate: rawEndDate ? String(rawEndDate).trim() : parsedEndDate.toISOString().split('T')[0],
          daysAgo: days,
          caseNumber: toStr(colCase !== -1 ? row[colCase] : row[0]),
          customerName: toStr(colCustomer !== -1 ? row[colCustomer] : row[3]),
          complaint: toStr(colComplaint !== -1 ? row[colComplaint] : row[9]),
          repair: toStr(colRepair !== -1 ? row[colRepair] : row[13]),
          status: toStr(colStatus !== -1 ? row[colStatus] : row[10])
        });
      } else {
        olderThan60Days++;
      }
    } else {
      olderThan60Days++;
    }

    b_case.push(toStr(colCase !== -1 ? row[colCase] : row[0]));
    b_created_date.push(createdDateVal);
    b_work_order.push(toStr(colWorkOrder !== -1 ? row[colWorkOrder] : row[2]));
    b_customer.push(toStr(colCustomer !== -1 ? row[colCustomer] : row[3]));
    b_territory.push(toStr(colTerritory !== -1 ? row[colTerritory] : row[4]));
    b_street.push(toStr(colStreet !== -1 ? row[colStreet] : row[5]));
    b_city.push(toStr(colCity !== -1 ? row[colCity] : row[6]));
    b_state.push(toStr(colState !== -1 ? row[colState] : row[7]));
    b_zip.push(toStr(colZip !== -1 ? row[colZip] : row[8]));
    b_complaint.push(toStr(colComplaint !== -1 ? row[colComplaint] : row[9]));
    b_status.push(toStr(colStatus !== -1 ? row[colStatus] : row[10]));
    b_symptom.push(toStr(colSymptom !== -1 ? row[colSymptom] : row[11]));
    b_defect.push(toStr(colDefect !== -1 ? row[colDefect] : row[12]));
    b_repair.push(toStr(colRepair !== -1 ? row[colRepair] : row[13]));
    b_end_date.push(toStr(rawEndDate));
    b_parsed_end_date.push(parsedEndDate);
    b_days.push(toStr(colDays !== -1 ? row[colDays] : row[15]));
    b_prod_code.push(toStr(colProdCode !== -1 ? row[colProdCode] : row[16]));
    b_prod_name.push(toStr(colProdName !== -1 ? row[colProdName] : row[17]));
    b_prod_desc.push(toStr(colProdDesc !== -1 ? row[colProdDesc] : row[18]));
    b_prod_type.push(toStr(colProdType !== -1 ? row[colProdType] : row[19]));
    b_prod_sub_type.push(toStr(colProdSubType !== -1 ? row[colProdSubType] : row[20]));
    b_warranty.push(toStr(colWarranty !== -1 ? row[colWarranty] : row[21]));
    b_type_of_wo.push(toStr(colTypeOfWO !== -1 ? row[colTypeOfWO] : row[22]));
    b_line_status.push(toStr(colLineItemStatus !== -1 ? row[colLineItemStatus] : row[23]));
    b_sdr.push(toStr(colSdr !== -1 ? row[colSdr] : row[24]));
    b_invoice_date.push(toStr(colInvoiceDate !== -1 ? row[colInvoiceDate] : row[25]));
    b_tech_name.push(toStr(colTechName !== -1 ? row[colTechName] : row[26]));
    b_tech_remarks.push(toStr(colTechRemarks !== -1 ? row[colTechRemarks] : row[27]));
    b_serial.push(serialNo);
    b_repl_serial.push(toStr(colReplSerial !== -1 ? row[colReplSerial] : row[31]));
    b_resolution.push(toStr(colResolution !== -1 ? row[colResolution] : row[33]));
    b_closed_date.push(toStr(rawClosedDate));

    if (b_serial.length >= BATCH_SIZE) {
      await flushUnnest();
    }
  }

  if (b_serial.length > 0) {
    await flushUnnest();
  }

  await client.query(`
    INSERT INTO service_upload_history (
      file_name, uploaded_by, total_records, found_within_60_days, older_than_60_days
    ) VALUES ($1, $2, $3, $4, $5)
  `, ['Data.xlsx', 'TestRunner', totalRecords, foundWithin60Days, olderThan60Days]);

  await client.query('COMMIT');
  client.release();

  console.log(`2. Ingestion & Audit COMPLETE in ${(Date.now() - tStart)/1000}s!`);
  console.log(`Total: ${totalRecords}, Found within 60 days: ${foundWithin60Days}, Older: ${olderThan60Days}`);
  await pool.end();
}

testFullUpload().catch(console.error);
