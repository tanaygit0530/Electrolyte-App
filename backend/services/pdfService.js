const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const numberToWords = (num) => {
  const a = ['', 'One ', 'Two ', 'Three ', 'Four ', 'Five ', 'Six ', 'Seven ', 'Eight ', 'Nine ', 'Ten ', 'Eleven ', 'Twelve ', 'Thirteen ', 'Fourteen ', 'Fifteen ', 'Sixteen ', 'Seventeen ', 'Eighteen ', 'Nineteen '];
  const b = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  function n2w(n) {
    if ((n = n.toString()).length > 9) return 'overflow';
    let n_arr = ('000000000' + n).substr(-9).match(/^(\d{2})(\d{2})(\d{2})(\d{1})(\d{2})$/);
    if (!n_arr) return '';
    let str = '';
    str += (n_arr[1] != 0) ? (a[Number(n_arr[1])] || b[n_arr[1][0]] + ' ' + a[n_arr[1][1]]) + 'Crore ' : '';
    str += (n_arr[2] != 0) ? (a[Number(n_arr[2])] || b[n_arr[2][0]] + ' ' + a[n_arr[2][1]]) + 'Lakh ' : '';
    str += (n_arr[3] != 0) ? (a[Number(n_arr[3])] || b[n_arr[3][0]] + ' ' + a[n_arr[3][1]]) + 'Thousand ' : '';
    str += (n_arr[4] != 0) ? (a[Number(n_arr[4])] || b[n_arr[4][0]] + ' ' + a[n_arr[4][1]]) + 'Hundred ' : '';
    str += (n_arr[5] != 0) ? ((str != '') ? 'and ' : '') + (a[Number(n_arr[5])] || b[n_arr[5][0]] + ' ' + a[n_arr[5][1]]) : '';
    return str.trim();
  }

  const parts = Number(num).toFixed(2).split('.');
  const whole = parseInt(parts[0]);
  const decimal = parseInt(parts[1]);

  let res = n2w(whole) + ' Rupees';
  if (decimal > 0) {
    res += ' and ' + n2w(decimal) + ' Paise';
  }
  return res + ' Only';
};

const getBase64Image = (filePath) => {
  try {
    if (!fs.existsSync(filePath)) return '';
    const file = fs.readFileSync(filePath);
    const extension = path.extname(filePath).replace('.', '').toLowerCase();
    const mimeMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif'
    };
    const mimeType = mimeMap[extension] || `image/${extension}`;
    return `data:${mimeType};base64,${file.toString('base64')}`;
  } catch (err) {
    console.error(`Error reading image at ${filePath}:`, err);
    return '';
  }
};

const generatePDF = async (invoiceData) => {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  try {
    const page = await browser.newPage();

    // Load images
    const resourcesPath = path.join(__dirname, '../../resources');
    const logoBase64 = getBase64Image(path.join(resourcesPath, 'company_logo_lighttheme.png'));
    
    let brandLogoBase64 = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'; // transparent spacer
    let brandLogoWidth = 180;
    let headerPaddingRight = 210;
    let brandLogoDisplay = 'block';

    const brand = (invoiceData.brand || '').toLowerCase();
    if (brand.includes('atomberg')) {
      brandLogoBase64 = getBase64Image(path.join(resourcesPath, 'Atomberg-Logo.png'));
      brandLogoWidth = 180;
      headerPaddingRight = 210;
    } else if (brand.includes('symphony')) {
      brandLogoBase64 = getBase64Image(path.join(resourcesPath, 'Symphony-Logo-PNG1.png'));
      brandLogoWidth = 140;
      headerPaddingRight = 170;
    } else {
      brandLogoDisplay = 'none';
      headerPaddingRight = 150; // perfectly center text if no brand logo
    }

    const qrBase64 = getBase64Image(path.join(resourcesPath, 'qr_code.jpeg'));
    const stampBase64 = getBase64Image(path.join(resourcesPath, 'Stamp_with_sign.PNG'));

    // Load template
    const templatePath = path.join(__dirname, '../template.html');
    let htmlContent = fs.readFileSync(templatePath, 'utf8');

    // Prepare table rows
    const tableRows = (invoiceData.items || []).map(item => `
      <tr>
        <td>${item.name || item.description}</td>
        <td>${item.quantity || item.qty}</td>
        <td>${Number(item.rate).toFixed(2)}</td>
        <td>${Number(item.amount || (item.quantity * item.rate)).toFixed(2)}</td>
      </tr>
    `).join('');

    // Format date
    const formattedDate = new Date().toLocaleDateString('en-IN', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });

    // Prepare GST row
    const gstRow = (invoiceData.gstAmount && invoiceData.gstAmount > 0) ? `
      <tr>
        <td>GST (18%):</td>
        <td>Rs. ${Number(invoiceData.gstAmount).toFixed(2)}</td>
      </tr>
    ` : '';

    // Replace placeholders
    const replacements = {
      '{{logoBase64}}': logoBase64,
      '{{brandLogoBase64}}': brandLogoBase64,
      '{{brandLogoWidth}}': brandLogoWidth,
      '{{brandLogoDisplay}}': brandLogoDisplay,
      '{{headerPaddingRight}}': headerPaddingRight,
      '{{qrBase64}}': qrBase64,
      '{{stampBase64}}': stampBase64,
      '{{customerName}}': invoiceData.customerName || 'N/A',
      '{{customerEmail}}': invoiceData.customerEmail || 'N/A',
      '{{warrantyType}}': invoiceData.warrantyType || 'N/A',
      '{{invoiceNumber}}': invoiceData.invoiceNumber || 'N/A',
      '{{date}}': formattedDate,
      '{{caseId}}': invoiceData.caseId || 'N/A',
      '{{brand}}': invoiceData.brand || 'N/A',
      '{{serialNumber}}': invoiceData.serialNumber || 'N/A',
      '{{preparedBy}}': invoiceData.preparedBy || 'N/A',
      '{{tableRows}}': tableRows,
      '{{subTotal}}': Number(invoiceData.subTotal).toFixed(2),
      '{{gstRow}}': gstRow,
      '{{serviceCharge}}': Number(invoiceData.serviceCharge || 0).toFixed(2),
      '{{grandTotal}}': Number(invoiceData.totalAmount).toFixed(2),
      '{{totalInWords}}': numberToWords(invoiceData.totalAmount)
    };

    for (const [placeholder, value] of Object.entries(replacements)) {
      htmlContent = htmlContent.split(placeholder).join(value);
    }

    await page.setContent(htmlContent, { waitUntil: 'networkidle0' });

    const pdfBuffer = await page.pdf({
      format: 'A4',
      printBackground: true,
      margin: {
        top: '10mm',
        bottom: '10mm',
        left: '10mm',
        right: '10mm'
      }
    });

    return Buffer.from(pdfBuffer);
  } finally {
    await browser.close();
  }
};

module.exports = { generatePDF };


