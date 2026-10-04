const { pool } = require('../backend/config/neondb');

async function testUnnestSpeed() {
  const client = await pool.connect();
  try {
    console.log('Connected to NeonDB. Starting UNNEST speed test...');
    const N = 5000; // 5000 rows at once!
    for (let b = 0; b < 3; b++) {
      const t0 = Date.now();
      
      const case_numbers = new Array(N).fill('CASE_TEST');
      const created_dates = new Array(N).fill(new Date());
      const work_orders = new Array(N).fill('WO_TEST');
      const customer_names = new Array(N).fill('CUST_TEST');
      const territories = new Array(N).fill('TERR_TEST');
      const streets = new Array(N).fill('STREET');
      const cities = new Array(N).fill('CITY');
      const states = new Array(N).fill('STATE');
      const zip_codes = new Array(N).fill('ZIP');
      const complaints = new Array(N).fill('COMPLAINT');
      const statuses = new Array(N).fill('STATUS');
      const symptoms = new Array(N).fill('SYMPTOM');
      const defects = new Array(N).fill('DEFECT');
      const repairs = new Array(N).fill('REPAIR');
      const end_dates = new Array(N).fill('23/09/2026');
      const parsed_end_dates = new Array(N).fill(new Date());
      const days = new Array(N).fill('10');
      const prod_codes = new Array(N).fill('CODE');
      const prod_names = new Array(N).fill('NAME');
      const prod_descs = new Array(N).fill('DESC');
      const prod_types = new Array(N).fill('TYPE');
      const prod_subtypes = new Array(N).fill('SUBTYPE');
      const warranties = new Array(N).fill('WARRANTY');
      const wo_types = new Array(N).fill('WO_TYPE');
      const line_statuses = new Array(N).fill('LINE_STATUS');
      const sdrs = new Array(N).fill('SDR');
      const invoice_dates = new Array(N).fill('INV_DATE');
      const tech_names = new Array(N).fill('TECH');
      const tech_remarks = new Array(N).fill('REMARKS');
      const serials = Array.from({ length: N }, (_, i) => `TEST_UNNEST_${b}_${i}`);
      const repl_serials = new Array(N).fill(null);
      const resolutions = new Array(N).fill('RES');
      const closed_dates = new Array(N).fill('CLOSED');

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
        case_numbers, created_dates, work_orders, customer_names, territories,
        streets, cities, states, zip_codes, complaints,
        statuses, symptoms, defects, repairs, end_dates,
        parsed_end_dates, days, prod_codes, prod_names, prod_descs,
        prod_types, prod_subtypes, warranties, wo_types, line_statuses,
        sdrs, invoice_dates, tech_names, tech_remarks, serials,
        repl_serials, resolutions, closed_dates
      ]);

      console.log(`Batch ${b + 1} (${N} rows via UNNEST) took ${(Date.now() - t0)/1000}s`);
    }
  } catch (e) {
    console.error('Error in UNNEST test:', e);
  } finally {
    await client.query("DELETE FROM service_records WHERE serial_no LIKE 'TEST_UNNEST_%'");
    client.release();
    await pool.end();
  }
}

testUnnestSpeed();
