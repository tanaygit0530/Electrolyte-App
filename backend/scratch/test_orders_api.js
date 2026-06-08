const http = require('http');

// 1. First, log in
const loginData = JSON.stringify({
  email: 'technician@example.com',
  password: 'password123'
});

const loginOptions = {
  hostname: 'localhost',
  port: 5001,
  path: '/auth/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': loginData.length
  }
};

const req = http.request(loginOptions, res => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => {
    const response = JSON.parse(body);
    const token = response.token;
    console.log('Got Token:', token);

    // 2. Now call /orders with this token
    const orderOptions = {
      hostname: 'localhost',
      port: 5001,
      path: '/orders',
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    };

    const orderReq = http.request(orderOptions, orderRes => {
      let orderBody = '';
      orderRes.on('data', chunk => orderBody += chunk);
      orderRes.on('end', () => {
        console.log(`Orders Status: ${orderRes.statusCode}`);
        console.log(`Orders Response: ${orderBody}`);
      });
    });

    orderReq.on('error', error => {
      console.error('Orders Request Error:', error);
    });

    orderReq.end();
  });
});

req.on('error', error => {
  console.error('Login Request Error:', error);
});

req.write(loginData);
req.end();
