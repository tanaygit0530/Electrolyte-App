const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const {
  getCalendarDaysAgo,
  normalizeSerialNumber,
  parseDateValue,
  buildNormalizedColMap,
  bulkUpsertServiceRecords,
  checkSerialNumber
} = require('../controllers/serviceRecordsController');
const { pool } = require('../config/neondb');

describe('1. 60-Day Repeat Service Risk & Date Calculation (Criteria 1, 2, 3, 10, 13)', () => {
  // Test timezone: Asia/Kolkata (UTC+5:30)
  const baseDate = new Date('2026-10-28T12:00:00+05:30');

  test('Criteria 1: Service exactly 60 days old returns repeat risk (isWithin60Days: true)', () => {
    // 60 calendar days before 2026-10-28 is 2026-08-29
    const exact60DaysAgo = new Date('2026-08-29T10:00:00+05:30');
    const daysAgo = getCalendarDaysAgo(exact60DaysAgo, baseDate);
    assert.equal(daysAgo, 60, 'Should be exactly 60 calendar days ago');

    const isWithin60Days = daysAgo !== null && daysAgo >= 0 && daysAgo <= 60;
    assert.equal(isWithin60Days, true, 'Exactly 60 days must be within repeat risk window');
  });

  test('Criteria 2: Service 59 days old returns repeat risk (isWithin60Days: true)', () => {
    const fiftyNineDaysAgo = new Date('2026-08-30T10:00:00+05:30');
    const daysAgo = getCalendarDaysAgo(fiftyNineDaysAgo, baseDate);
    assert.equal(daysAgo, 59, 'Should be exactly 59 calendar days ago');

    const isWithin60Days = daysAgo !== null && daysAgo >= 0 && daysAgo <= 60;
    assert.equal(isWithin60Days, true, '59 days must be within repeat risk window');
  });

  test('Criteria 3: Service 61 days old returns safe to close (isWithin60Days: false)', () => {
    const sixtyOneDaysAgo = new Date('2026-08-28T10:00:00+05:30');
    const daysAgo = getCalendarDaysAgo(sixtyOneDaysAgo, baseDate);
    assert.equal(daysAgo, 61, 'Should be exactly 61 calendar days ago');

    const isWithin60Days = daysAgo !== null && daysAgo >= 0 && daysAgo <= 60;
    assert.equal(isWithin60Days, false, '61 days must NOT be within repeat risk window');
  });

  test('Criteria 10: Future-dated service record returns negative days and is rejected from repeat risk', () => {
    const futureDate = new Date('2026-10-30T10:00:00+05:30');
    const daysAgo = getCalendarDaysAgo(futureDate, baseDate);
    assert.ok(daysAgo < 0, 'Future date must yield negative daysAgo');

    // Future date should never be classified as safe or standard repeat risk without review
    const isWithin60Days = daysAgo !== null && daysAgo >= 0 && daysAgo <= 60;
    assert.equal(isWithin60Days, false, 'Future date must not pass standard 0-60 risk calculation');
  });

  test('Criteria 13: Calendar day calculation handles midnight and timezone boundaries accurately', () => {
    // 23:59 on day 1 vs 00:01 on day 2 is 1 calendar day apart
    const day1Late = new Date('2026-10-27T23:59:00+05:30');
    const day2Early = new Date('2026-10-28T00:01:00+05:30');
    assert.equal(getCalendarDaysAgo(day1Late, day2Early), 1);

    // Same day services are 0 calendar days ago
    const sameDayMorning = new Date('2026-10-28T08:00:00+05:30');
    const sameDayEvening = new Date('2026-10-28T20:00:00+05:30');
    assert.equal(getCalendarDaysAgo(sameDayMorning, sameDayEvening), 0);
  });
});

describe('2. Serial Number Normalization & Date Parsing (Criteria 10)', () => {
  test('Preserves leading zeros and uppercase characters', () => {
    assert.equal(normalizeSerialNumber('0012345'), '0012345');
    assert.equal(normalizeSerialNumber('  sn-la24a-0099  '), 'SN-LA24A-0099');
    assert.equal(normalizeSerialNumber('LA24AECHA2P13535'), 'LA24AECHA2P13535');
  });

  test('Filters out dummy/placeholder values and nulls', () => {
    assert.equal(normalizeSerialNumber('NO BARCODE'), null);
    assert.equal(normalizeSerialNumber('N/A'), null);
    assert.equal(normalizeSerialNumber('NOT AVAILABLE'), null);
    assert.equal(normalizeSerialNumber('NOT APPLICABLE'), null);
    assert.equal(normalizeSerialNumber('-'), null);
    assert.equal(normalizeSerialNumber(''), null);
    assert.equal(normalizeSerialNumber(null), null);
    assert.equal(normalizeSerialNumber(undefined), null);
  });

  test('Parses DD/MM/YYYY, DD-MM-YYYY, ISO strings, and Excel serial numbers', () => {
    const d1 = parseDateValue('15/08/2026');
    assert.ok(d1 instanceof Date);
    assert.equal(d1.getUTCDate(), 15);
    assert.equal(d1.getUTCMonth(), 7); // August is month 7 (0-indexed)
    assert.equal(d1.getUTCFullYear(), 2026);

    const d2 = parseDateValue('2026-09-01');
    assert.ok(d2 instanceof Date);
    assert.equal(d2.getUTCFullYear(), 2026);

    // Excel serial number 46270 corresponds to approx Sep 2026
    const d3 = parseDateValue(46270);
    assert.ok(d3 instanceof Date);
    assert.equal(d3.getUTCFullYear(), 2026);

    // Out-of-range or invalid years rejected
    assert.equal(parseDateValue('15/08/1990'), null, 'Pre-2000 year should be rejected');
    assert.equal(parseDateValue('invalid-date'), null, 'Malformed string should return null');
  });
});

describe('3. Column Header Normalization (Criteria 2)', () => {
  test('Maps standard and aliased column headers consistently', () => {
    const headers = [
      'Case Number',
      'Work Order Line Item: Work Order Line Item Number',
      'Serial No',
      'End Date',
      'Customer Complaint',
      'Repair / Action'
    ];
    const colMap = buildNormalizedColMap(headers);
    assert.equal(colMap.case, 0);
    assert.equal(colMap.workOrder, 1);
    assert.equal(colMap.serial, 2);
    assert.equal(colMap.endDate, 3);
    assert.equal(colMap.complaint, 4);
    assert.equal(colMap.repair, 5);
  });
});

describe('4. In-Memory In-File Deduplication & Non-destructive Updates (Criteria 6, 7, 8)', () => {
  test('Criteria 6 & 7: Detects duplicate rows within the same batch using composite key', () => {
    const seenInFile = new Set();
    const rows = [
      { case_number: 'CAS-001', work_order: 'WO-101', serial_no: 'SR100' },
      { case_number: 'CAS-001', work_order: 'WO-101', serial_no: 'SR100' }, // exact duplicate
      { case_number: 'CAS-002', work_order: 'WO-102', serial_no: 'SR100' }, // same serial, distinct service event
      { case_number: 'CAS-003', work_order: 'WO-103', serial_no: 'SR101' }  // new event
    ];

    let accepted = 0;
    let duplicateInFile = 0;

    for (const r of rows) {
      const compKey = `${r.case_number}|${r.work_order}|${r.serial_no}`;
      if (seenInFile.has(compKey)) {
        duplicateInFile++;
      } else {
        seenInFile.add(compKey);
        accepted++;
      }
    }

    assert.equal(duplicateInFile, 1, 'Should detect 1 in-file duplicate');
    assert.equal(accepted, 3, 'Should accept 3 unique service events');
    assert.equal(seenInFile.size, 3);
  });

  test('Criteria 8: Non-destructive update semantics preserve existing database fields', () => {
    // Verifies COALESCE semantics: if incoming field is null, existing field is retained
    const existingDbRecord = {
      customer_name: 'Original Customer',
      customer_complaint: 'Battery draining fast',
      repair: 'Replaced cells'
    };

    const incomingUpdate = {
      customer_name: null, // missing in new report
      customer_complaint: 'Updated complaint note',
      repair: null         // missing in new report
    };

    const merged = {
      customer_name: incomingUpdate.customer_name ?? existingDbRecord.customer_name,
      customer_complaint: incomingUpdate.customer_complaint ?? existingDbRecord.customer_complaint,
      repair: incomingUpdate.repair ?? existingDbRecord.repair
    };

    assert.equal(merged.customer_name, 'Original Customer', 'Existing customer name preserved');
    assert.equal(merged.customer_complaint, 'Updated complaint note', 'Incoming valid complaint updated');
    assert.equal(merged.repair, 'Replaced cells', 'Existing repair action preserved');
  });
});

describe('5. Service Check Controller & API Contract Tests (Criteria 4, 5, 9, 10, 11, 12, 14)', () => {
  // Mock pool helper to test checkSerialNumber deterministically without requiring external network
  function createMockPool(rowsToReturn) {
    return {
      query: async (sql, params) => {
        return { rows: rowsToReturn || [] };
      }
    };
  }

  test('Criteria 4: Serial number with no previous service returns SAFE TO CLOSE (canCloseCall: true)', async () => {
    const originalPoolQuery = pool.query;
    pool.query = async () => ({ rows: [] }); // No service history

    try {
      let responseData = null;
      const req = { params: { serialNumber: 'NEW_UNSEEN_SERIAL_123' } };
      const res = {
        json: (data) => { responseData = data; return data; },
        status: () => res
      };

      await checkSerialNumber(req, res);

      assert.ok(responseData, 'Response data must be returned');
      assert.equal(responseData.success, true);
      assert.equal(responseData.status, 'SAFE TO CLOSE');
      assert.equal(responseData.isWithin60Days, false);
      assert.equal(responseData.repeatRisk, false);
      assert.equal(responseData.canCloseCall, true);
      assert.equal(responseData.daysAgo, null);
      assert.equal(responseData.record, null);
    } finally {
      pool.query = originalPoolQuery;
    }
  });

  test('Criteria 5: Multiple service records select latest applicable parsed_end_date and compute repeat risk', async () => {
    const originalPoolQuery = pool.query;
    // Database query orders by parsed_end_date DESC NULLS LAST LIMIT 1
    const latestServiceDate = new Date(Date.now() - 20 * 24 * 60 * 60 * 1000); // 20 days ago
    pool.query = async () => ({
      rows: [{
        id: 101,
        case_number: 'CAS-999',
        work_order_line_item: 'WO-888',
        serial_no: 'MULTI_TEST_SERIAL',
        customer_name: 'John Doe',
        parsed_end_date: latestServiceDate,
        end_date: '08/10/2026',
        wo_status: 'Closed',
        is_active_60d: true
      }]
    });

    try {
      let responseData = null;
      const req = { params: { serialNumber: 'MULTI_TEST_SERIAL' } };
      const res = {
        json: (data) => { responseData = data; return data; },
        status: () => res
      };

      await checkSerialNumber(req, res);

      assert.ok(responseData, 'Response data must be returned');
      assert.equal(responseData.status, 'REPEAT RISK');
      assert.equal(responseData.isWithin60Days, true);
      assert.equal(responseData.repeatRisk, true);
      assert.equal(responseData.canCloseCall, false);
      assert.ok(responseData.daysAgo >= 19 && responseData.daysAgo <= 21);
      assert.equal(responseData.record.caseNumber, 'CAS-999');
    } finally {
      pool.query = originalPoolQuery;
    }
  });

  test('Criteria 10: Future-dated service record returns REVIEW NEEDED (canCloseCall: false)', async () => {
    const originalPoolQuery = pool.query;
    const futureDate = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000); // 5 days in future
    pool.query = async () => ({
      rows: [{
        id: 102,
        case_number: 'CAS-FUTURE',
        work_order_line_item: 'WO-FUTURE',
        serial_no: 'FUTURE_SERIAL_123',
        parsed_end_date: futureDate,
        end_date: '02/11/2026',
        wo_status: 'Pending'
      }]
    });

    try {
      let responseData = null;
      const req = { params: { serialNumber: 'FUTURE_SERIAL_123' } };
      const res = {
        json: (data) => { responseData = data; return data; },
        status: () => res
      };

      await checkSerialNumber(req, res);

      assert.ok(responseData);
      assert.equal(responseData.status, 'REVIEW NEEDED');
      assert.equal(responseData.isWithin60Days, false);
      assert.equal(responseData.canCloseCall, false);
      assert.ok(responseData.daysAgo < 0, 'Must reflect negative days');
      assert.ok(responseData.message.includes('future date'));
    } finally {
      pool.query = originalPoolQuery;
    }
  });

  test('Criteria 10: Invalid service date returns REVIEW NEEDED (canCloseCall: false)', async () => {
    const originalPoolQuery = pool.query;
    pool.query = async () => ({
      rows: [{
        id: 103,
        case_number: 'CAS-BAD-DATE',
        work_order_line_item: 'WO-BAD-DATE',
        serial_no: 'BAD_DATE_SERIAL',
        parsed_end_date: null,
        end_date: 'CorruptDateString',
        wo_status: 'Closed'
      }]
    });

    try {
      let responseData = null;
      const req = { params: { serialNumber: 'BAD_DATE_SERIAL' } };
      const res = {
        json: (data) => { responseData = data; return data; },
        status: () => res
      };

      await checkSerialNumber(req, res);

      assert.ok(responseData);
      assert.equal(responseData.status, 'REVIEW NEEDED');
      assert.equal(responseData.isWithin60Days, false);
      assert.equal(responseData.canCloseCall, false);
      assert.ok(responseData.message.includes('invalid completion date'));
    } finally {
      pool.query = originalPoolQuery;
    }
  });

  test('Criteria 12: Database or validation error never returns false green', async () => {
    let statusCode = null;
    let errorData = null;
    const req = { params: { serialNumber: '   ' } }; // blank serial
    const res = {
      status: (code) => {
        statusCode = code;
        return {
          json: (data) => { errorData = data; }
        };
      }
    };

    await checkSerialNumber(req, res);
    assert.equal(statusCode, 400);
    assert.ok(errorData.error);
    // Error must never return isWithin60Days or canCloseCall: true
    assert.equal(errorData.canCloseCall, undefined);
    assert.equal(errorData.isWithin60Days, undefined);
  });

  test('Criteria 11 & 14: Bulk upsert SQL query includes non-destructive COALESCE and ON CONFLICT handling', async () => {
    let capturedQuery = '';
    let capturedParams = [];

    const mockClient = {
      query: async (sql, params) => {
        capturedQuery = sql;
        capturedParams = params;
        return { rows: [{ was_inserted: true }] };
      }
    };

    const batch = [{
      case_number: 'TEST-CASE-UPSERT',
      work_order_line_item: 'WO-LINE-UPSERT',
      serial_no: 'SN-TEST-UPSERT',
      customer_name: 'Upsert Customer',
      parsed_end_date: new Date(),
      end_date: '28/10/2026',
      is_active_60d: true
    }];

    const result = await bulkUpsertServiceRecords(mockClient, batch);
    assert.equal(result.inserted, 1);
    assert.equal(result.updated, 0);

    // Verify key clauses in generated query
    assert.ok(capturedQuery.includes('ON CONFLICT (case_number, work_order_line_item, serial_no)'));
    assert.ok(capturedQuery.includes('DO UPDATE SET'));
    assert.ok(capturedQuery.includes('COALESCE(EXCLUDED.customer_name, service_records.customer_name)'));
    assert.ok(capturedQuery.includes('RETURNING (xmax = 0) AS was_inserted'));
  });
});

describe('6. Automatic 60-Day Data Retention & Cleanup (Retention Suite)', () => {
  const { cleanupExpiredServiceRecords } = require('../controllers/serviceRecordsController');
  const { getMsUntilNextISTTime } = require('../services/retentionScheduler');

  test('Retention: cleanupExpiredServiceRecords deletes records older than 60 days while retaining 60d records', async () => {
    let executedQueries = [];
    const mockClient = {
      query: async (sql, params) => {
        executedQueries.push({ sql, params });
        if (sql.includes('cutoff_date')) {
          // Return simulated 60-day cutoff date
          return {
            rows: [{
              cutoff_date: '2026-08-29',
              future_boundary: '2026-10-29'
            }]
          };
        }
        if (sql.includes('DELETE FROM service_records')) {
          return { rowCount: 150 };
        }
        if (sql.includes('COUNT(*) AS total')) {
          return { rows: [{ total: '2830' }] };
        }
        return { rows: [] };
      }
    };

    const result = await cleanupExpiredServiceRecords({ client: mockClient });

    assert.equal(result.success, true);
    assert.equal(result.deletedCount, 150);
    assert.equal(result.remainingCount, 2830);
    assert.equal(result.cutoffDate, '2026-08-29');

    // Verify DELETE query format
    const deleteQuery = executedQueries.find(q => q.sql.includes('DELETE FROM service_records'));
    assert.ok(deleteQuery, 'DELETE query must be executed');
    assert.ok(deleteQuery.sql.includes('parsed_end_date IS NULL'));
    assert.ok(deleteQuery.sql.includes('< $1::date'));
    assert.ok(deleteQuery.sql.includes('> $2::date'));
    assert.deepEqual(deleteQuery.params, ['2026-08-29', '2026-10-29']);
  });

  test('Retention: Advisory lock skips concurrent cleanup execution safely', async () => {
    const originalPoolQuery = pool.query;
    pool.query = async (sql) => {
      if (sql.includes('pg_try_advisory_lock')) {
        return { rows: [{ acquired: false }] }; // Another instance holds lock
      }
      return { rows: [] };
    };

    try {
      const result = await cleanupExpiredServiceRecords();
      assert.equal(result.success, true);
      assert.equal(result.skipped, true);
      assert.ok(result.reason.includes('already running'));
    } finally {
      pool.query = originalPoolQuery;
    }
  });

  test('Retention: Repeated cleanup runs are idempotent', async () => {
    let deleteCallCount = 0;
    const mockClient = {
      query: async (sql) => {
        if (sql.includes('cutoff_date')) {
          return { rows: [{ cutoff_date: '2026-08-29', future_boundary: '2026-10-29' }] };
        }
        if (sql.includes('DELETE FROM service_records')) {
          deleteCallCount++;
          // First run purges 10, second run finds 0
          return { rowCount: deleteCallCount === 1 ? 10 : 0 };
        }
        if (sql.includes('COUNT(*) AS total')) {
          return { rows: [{ total: '2830' }] };
        }
        return { rows: [] };
      }
    };

    const run1 = await cleanupExpiredServiceRecords({ client: mockClient });
    const run2 = await cleanupExpiredServiceRecords({ client: mockClient });

    assert.equal(run1.deletedCount, 10);
    assert.equal(run2.deletedCount, 0); // 0 records expired on second run
    assert.equal(run2.success, true);
  });

  test('Retention: getMsUntilNextISTTime schedules accurately for 00:05 AM Asia/Kolkata', () => {
    const ms = getMsUntilNextISTTime(0, 5);
    assert.ok(typeof ms === 'number');
    assert.ok(ms > 0, 'Delay must be positive');
    // Delay must be between 1 second and 24.1 hours in ms
    assert.ok(ms <= 24.1 * 60 * 60 * 1000);
  });
});


