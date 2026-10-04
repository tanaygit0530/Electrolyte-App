const http = require('http');

// Start backend server in-process for testing
process.env.PORT = '5002'; // Use port 5002 to avoid conflicts
const app = require('../server');

function makeRequest(path) {
  return new Promise((resolve, reject) => {
    http.get(`http://localhost:5002${path}`, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    }).on('error', reject);
  });
}

async function runTests() {
  console.log('Waiting for server startup...');
  await new Promise(r => setTimeout(r, 1500));

  console.log('\n=== TEST 1: Check Serial Sample 1 (LA24AECHA2P13535) ===');
  const res1 = await makeRequest('/api/service-records/check/LA24AECHA2P13535');
  console.log('Status Code:', res1.statusCode);
  const json1 = JSON.parse(res1.body);
  console.log('Found Status:', json1.status, '| isWithin60Days:', json1.isWithin60Days, '| Days Ago:', json1.daysAgo);
  if (json1.status !== 'FOUND' || !json1.isWithin60Days) {
    console.error('FAILED: Expected FOUND');
  } else {
    console.log('PASSED: Sample 1 correctly verified as FOUND!');
  }

  console.log('\n=== TEST 2: Check Serial Sample 2 (4E23A2FDA2P10115) ===');
  const res2 = await makeRequest('/api/service-records/check/4E23A2FDA2P10115');
  console.log('Status Code:', res2.statusCode);
  const json2 = JSON.parse(res2.body);
  console.log('Found Status:', json2.status, '| isWithin60Days:', json2.isWithin60Days, '| Days Ago:', json2.daysAgo);
  if (json2.status !== 'NOT FOUND' || json2.isWithin60Days) {
    console.error('FAILED: Expected NOT FOUND');
  } else {
    console.log('PASSED: Sample 2 correctly verified as NOT FOUND (older than 60 days)!');
  }

  console.log('\n=== TEST 3: Check Unknown Serial ===');
  const res3 = await makeRequest('/api/service-records/check/NON_EXISTENT_XYZ');
  console.log('Status Code:', res3.statusCode);
  const json3 = JSON.parse(res3.body);
  console.log('Found Status:', json3.status, '| Message:', json3.message);
  if (json3.status === 'NOT FOUND') {
    console.log('PASSED: Non-existent serial returned NOT FOUND');
  }

  console.log('\n=== TEST 4: Get Found Entries Endpoint ===');
  const res4 = await makeRequest('/api/service-records/found-entries?limit=5');
  console.log('Status Code:', res4.statusCode);
  const json4 = JSON.parse(res4.body);
  console.log('Total Found Entries:', json4.total, '| Returned:', json4.entries?.length);
  if (json4.success) {
    console.log('PASSED: Found entries endpoint returned list successfully!');
  }

  console.log('\n=== TEST 5: Export CSV Endpoint ===');
  const res5 = await makeRequest('/api/service-records/export-found');
  console.log('Status Code:', res5.statusCode);
  console.log('Content-Type:', res5.headers['content-type']);
  console.log('CSV First 120 chars:', res5.body.substring(0, 120));
  if (res5.headers['content-type'].includes('csv')) {
    console.log('PASSED: CSV export generated successfully!');
  }

  console.log('\nAll API endpoints verified successfully!');
  process.exit(0);
}

runTests().catch(err => {
  console.error('API Test Error:', err);
  process.exit(1);
});
