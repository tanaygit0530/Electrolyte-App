const axios = require('axios');

const fetchHtmlError = async () => {
  try {
    console.log('Logging in...');
    const loginRes = await axios.post('http://localhost:5001/api/admin/login', {
      email: 'admin@electrolyte.com',
      password: 'admin123'
    });
    const token = loginRes.data.token;
    console.log('Login successful! Token acquired.');

    console.log('Sending stock upload request...');
    const response = await axios.post(
      'http://localhost:5001/api/admin/upload-stock',
      {
        fileName: 'test_sheet.xlsx',
        rows: [
          { productCode: 'EA01701', stockQuantity: 12 }
        ]
      },
      {
        headers: {
          Authorization: `Bearer ${token}`
        }
      }
    );
    console.log('Success! Response:', response.data);
  } catch (error) {
    console.log('Error caught!');
    if (error.response) {
      console.log('Status code:', error.response.status);
      console.log('Headers:', error.response.headers);
      console.log('Response content is type:', typeof error.response.data);
      console.log('--- RESPONSE BODY START ---');
      console.log(error.response.data);
      console.log('--- RESPONSE BODY END ---');
    } else {
      console.log('Network/Other error:', error.message);
    }
  }
};

fetchHtmlError();
