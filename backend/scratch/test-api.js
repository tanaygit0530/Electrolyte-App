const axios = require('axios');

const testApi = async () => {
  try {
    console.log('1. Attempting login...');
    const loginRes = await axios.post('http://localhost:5001/api/admin/login', {
      email: 'admin@electrolyte.com',
      password: 'admin123'
    });
    
    console.log('Login successful!');
    const token = loginRes.data.token;
    console.log('Token:', token);

    console.log('2. Attempting stock upload with valid token...');
    const uploadRes = await axios.post(
      'http://localhost:5001/api/admin/upload-stock',
      {
        fileName: 'test_api_sheet.xlsx',
        rows: [
          { productCode: 'EA01701', stockQuantity: 15 }
        ]
      },
      {
        headers: {
          Authorization: `Bearer ${token}`
        }
      }
    );

    console.log('Upload response status:', uploadRes.status);
    console.log('Upload response data:', JSON.stringify(uploadRes.data, null, 2));

  } catch (error) {
    console.error('API Test Failed!');
    if (error.response) {
      console.error('Response Status:', error.response.status);
      console.error('Response Headers:', error.response.headers);
      console.error('Response Data:', error.response.data);
    } else {
      console.error(error.message);
    }
  }
};

testApi();
