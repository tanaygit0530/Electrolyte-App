const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

let browserInstance = null;

// Memory Cache for static assets
let cachedLogo = '';
let cachedSymphonyLogo = '';
let cachedAtombergLogo = '';
let cachedQr = '';
let cachedStamp = '';
let cachedTemplate = '';

const getBrowser = async () => {
  if (!browserInstance) {
    browserInstance = await puppeteer.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox'
      ]
    });
    console.log('Puppeteer browser initialized');
  }
  return browserInstance;
};

const closeBrowser = async () => {
  if (browserInstance) {
    await browserInstance.close();
    browserInstance = null;
    console.log('Puppeteer browser closed');
  }
};

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
      'gif': 'image/gif',
      'webp': 'image/webp'
    };
    const mimeType = mimeMap[extension] || `image/${extension}`;
    return `data:${mimeType};base64,${file.toString('base64')}`;
  } catch (err) {
    console.error(`Error reading image at ${filePath}:`, err);
    return '';
  }
};

const generatePDF = async (invoiceData) => {
  const browser = await getBrowser();

  let page;

  try {
    page = await browser.newPage();

    // Load images with in-memory caching
    const resourcesPath = path.join(__dirname, '../resources');
    
    if (!cachedLogo) cachedLogo = getBase64Image(path.join(resourcesPath, 'company_logo_lighttheme.webp'));
    if (!cachedSymphonyLogo) cachedSymphonyLogo = getBase64Image(path.join(resourcesPath, 'Symphony-Logo-PNG1.webp'));
    if (!cachedAtombergLogo) cachedAtombergLogo = getBase64Image(path.join(resourcesPath, 'Atomberg-Logo.webp'));
    if (!cachedQr) cachedQr = getBase64Image(path.join(resourcesPath, 'qr_code.webp'));
    if (!cachedStamp) cachedStamp = getBase64Image(path.join(resourcesPath, 'Stamp_with_sign.webp'));
    
    const logoBase64 = cachedLogo;
    const qrBase64 = cachedQr;
    const stampBase64 = cachedStamp;

    let brandLogoBase64 = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'; // transparent spacer
    let brandLogoWidth = 130;
    let brandLogoDisplay = 'block';

    const brandNameLower = (invoiceData.brand || '').toLowerCase();
    const isSymphony = brandNameLower.includes('symphony');

    if (isSymphony) {
      brandLogoBase64 = cachedSymphonyLogo;
      brandLogoWidth = 120;
    } else {
      // Default to Atomberg
      brandLogoBase64 = cachedAtombergLogo;
      brandLogoWidth = 130;
    }

    // Format date to DD-MMM-YY format (e.g. 10-Feb-24)
    const options = { day: '2-digit', month: 'short', year: '2-digit' };
    const formattedDate = new Date().toLocaleDateString('en-GB', options).replace(/ /g, '-');

    // Build Brand-Specific Metadata
    let partnerSubtitle = 'Authorised Service Partner of Atomberg Technologies Pvt. Ltd.';
    let addressLine = 'Plot 70, Sector 1 Road No. 1, Ghansoli, Navi Mumbai, Maharashtra - 400701';
    let phoneLine = '+91 8090712828 / 8104096232';
    let emailLine = 'electrolytesolnservice@gmail.com';
    let gstinLine = '';
    
    let bankDetailsContent = `
      <p>A/c Name: M/s Electrolyte Solutions</p>
      <p>Bank: Axis Bank Ltd.</p>
      <p>Account No.: 921000031635999</p>
      <p>IFSC: UTIB0001622</p>
      <p>Branch: Mulund East</p>
    `;

    let detailsBoxContent = '';
    let tableMarkup = '';
    let totalsBlock = '';
    let wordsText = '';
    let payableNote = 'Make all cheque or bank transfers payable to: M/s Electrolyte Solutions.';
    let warrantyNote = 'Note: Spare/Products are warranted for a period of 1 year from the date of handing over to the customer.';

    if (isSymphony) {
      partnerSubtitle = '(Authorised Service Partner of Symphony Limited.)';
      addressLine = 'Plot 223, Road Number 1, Sector 1, Ghansoli, Navi Mumbai, Maharashtra - 400701';
      phoneLine = '+91 8090712828 / 9029352208';
      emailLine = 'contact@electrolytesoln.com';
      gstinLine = '<p>GSTIN: 27AJYPY7934L1ZS</p>';
      
      bankDetailsContent = `
        <p>Name : M/s Electrolyte Solutions</p>
        <p>Bank Name : Axis Bank Ltd.</p>
        <p>Account No. : 921020033685999</p>
        <p>IFSC Code : UTIB0001622</p>
        <p>Account Type : Current Account</p>
        <p>Branch : Mulund East</p>
      `;

      detailsBoxContent = `
        <div class="details-container">
          <div class="col-left">
            <p><b>BILL TO:</b></p>
            <p>${invoiceData.customerName || 'Mr. Milan Karpe'}</p>
            <p>Add:- ${invoiceData.customerAddress || 'Neelkanth Palm, Krishna-B, 1903, Vidyapeeth, Kapurbawdi Junction, Thane West- 400610'}</p>
            <p>Mobile No. ${invoiceData.customerPhone || '9029352208'}</p>
          </div>
          <div class="col-right">
            <p><b>TICKET:</b> ${invoiceData.caseId || '846724'}</p>
            <p><b>INVOICE NO. :</b> ${invoiceData.invoiceNumber}</p>
            <p><b>BILL DATE :</b> ${formattedDate}</p>
            <p><b>FOR :</b> Symphony Products Service</p>
            <p><b>GSITN :</b> ${formattedDate}</p>
          </div>
        </div>
      `;

      // Build Symphony 5-column table
      tableMarkup = `
        <table class="items-table">
          <thead>
            <tr>
              <th style="text-align: left; width: 50%;">DESCRIPTION</th>
              <th style="text-align: center; width: 10%;">GST</th>
              <th style="text-align: center; width: 10%;">QUANTITY</th>
              <th style="text-align: right; width: 15%;">RATE</th>
              <th style="text-align: right; width: 15%;">AMOUNT</th>
            </tr>
          </thead>
          <tbody>
      `;

      (invoiceData.items || []).forEach((item, index) => {
        const rate = parseFloat(item.rate || 0);
        const amount = parseFloat(item.amount || (item.quantity * rate));
        tableMarkup += `
          <tr>
            <td style="text-align: left;">
              <b>${index + 1}. Material</b><br>
              <span style="padding-left: 15px; display: inline-block;">${item.description || item.name}</span>
            </td>
            <td style="text-align: center;">18%</td>
            <td style="text-align: center;">${item.quantity || item.qty}</td>
            <td style="text-align: right;">₹${rate.toFixed(2)}</td>
            <td style="text-align: right;">₹${amount.toFixed(2)}</td>
          </tr>
        `;
      });

      const sCharge = parseFloat(invoiceData.serviceCharge || 0);
      if (sCharge > 0) {
        tableMarkup += `
          <tr>
            <td style="text-align: left;">
              <b>2. Service Charge</b>
            </td>
            <td style="text-align: center;">18%</td>
            <td style="text-align: center;">1</td>
            <td style="text-align: right;">₹${sCharge.toFixed(2)}</td>
            <td style="text-align: right;">₹${sCharge.toFixed(2)}</td>
          </tr>
        `;
      }

      tableMarkup += `
          <tr class="grand-total-row">
            <td colspan="4" style="text-align: right; font-weight: bold; border-right: none; font-size: 13px;">GRAND TOTAL</td>
            <td style="text-align: right; font-weight: bold; border-left: none; font-size: 13px;">₹${parseFloat(invoiceData.totalAmount).toFixed(2)}</td>
          </tr>
        </tbody>
      </table>
      `;

      const rawWordsText = numberToWords(invoiceData.totalAmount);
      // Prepend "In Words :-"
      wordsText = `<b>In Words :-</b> ${rawWordsText}`;
      payableNote = 'Make all Cheque or bank transfer payable to Name : M/s Electrolyte Solutions.';
      warrantyNote = 'Note:- Spare/Products Are Warranted for a period of 10 Days From the Date of Handing Over of the Spare/Products to the Customer.';

    } else {
      // Default / Atomberg layout
      detailsBoxContent = `
        <div class="details-container">
          <div class="col-left">
            <p><b>BILL TO:</b> ${invoiceData.customerName || 'Jay'}</p>
            <p><b>Email:</b> ${invoiceData.customerEmail || 'jay@123'}</p>
            <p><b>INVOICE NO:</b> ${invoiceData.invoiceNumber}</p>
            <p><b>BRAND:</b> ${invoiceData.brand || 'Atomberg'}</p>
            <p><b>SERIAL:</b> ${invoiceData.serialNumber || 'ma'}</p>
            <p><b>BILL DATE:</b> ${formattedDate}</p>
          </div>
          <div class="col-right">
            <p><b>Prepared By:</b> ${invoiceData.preparedBy || 'DIPAK MOHITE'}</p>
            <p><b>Case ID:</b> ${invoiceData.caseId || 'test'}</p>
            <p><b>FOR:</b> Atomberg Products Service</p>
          </div>
        </div>
      `;

      // Build Atomberg 4-column table
      tableMarkup = `
        <table class="items-table">
          <thead>
            <tr>
              <th style="text-align: left; width: 50%;">DESCRIPTION</th>
              <th style="text-align: center; width: 10%;">QUANTITY</th>
              <th style="text-align: center; width: 20%;">RATE (incl. tax)</th>
              <th style="text-align: center; width: 20%;">AMOUNT</th>
            </tr>
          </thead>
          <tbody>
      `;

      (invoiceData.items || []).forEach(item => {
        const rate = parseFloat(item.rate || 0);
        const amount = parseFloat(item.amount || (item.quantity * rate));
        tableMarkup += `
          <tr>
            <td style="text-align: left;">${item.description || item.name}</td>
            <td style="text-align: center;">${item.quantity || item.qty}</td>
            <td style="text-align: center;">Rs.${rate.toFixed(2)}</td>
            <td style="text-align: center;">Rs.${amount.toFixed(2)}</td>
          </tr>
        `;
      });

      tableMarkup += `
          </tbody>
        </table>
      `;

      totalsBlock = `
        <div class="totals-container">
          <div class="totals-row">
            <span>SUBTOTAL:</span>
            <span>Rs.${parseFloat(invoiceData.subTotal).toFixed(2)}</span>
          </div>
          <div class="totals-row">
            <span>SERVICE CHARGE:</span>
            <span>Rs.${parseFloat(invoiceData.serviceCharge || 0).toFixed(2)}</span>
          </div>
          <div class="totals-row grand-total">
            <span>GRAND TOTAL:</span>
            <span>Rs.${parseFloat(invoiceData.totalAmount).toFixed(2)}</span>
          </div>
        </div>
      `;

      const rawWordsText = numberToWords(invoiceData.totalAmount);
      wordsText = `<b>IN WORDS:</b> ${rawWordsText.toUpperCase()}`;
    }

    // Load template with in-memory caching
    if (!cachedTemplate) {
      const templatePath = path.join(__dirname, '../template.html');
      cachedTemplate = fs.readFileSync(templatePath, 'utf8');
    }
    let htmlContent = cachedTemplate;

    // Replace placeholders
    const replacements = {
      '{{brandClass}}': isSymphony ? 'brand-symphony' : 'brand-atomberg',
      '{{logoBase64}}': logoBase64,
      '{{brandLogoBase64}}': brandLogoBase64,
      '{{brandLogoWidth}}': brandLogoWidth,
      '{{brandLogoDisplay}}': brandLogoDisplay,
      '{{qrBase64}}': qrBase64,
      '{{stampBase64}}': stampBase64,
      '{{partnerSubtitle}}': partnerSubtitle,
      '{{addressLine}}': addressLine,
      '{{phoneLine}}': phoneLine,
      '{{emailLine}}': emailLine,
      '{{gstinLine}}': gstinLine,
      '{{detailsBoxContent}}': detailsBoxContent,
      '{{tableMarkup}}': tableMarkup,
      '{{totalsBlock}}': totalsBlock,
      '{{wordsText}}': wordsText,
      '{{bankDetailsContent}}': bankDetailsContent,
      '{{payableNote}}': payableNote,
      '{{warrantyNote}}': warrantyNote,
      '{{signatoryTitle}}': isSymphony ? 'Authorized Signatory<br>For Electrolyte Solutions' : 'Authorized Signatory<br>For Electrolyte Solutions'
    };

    for (const [placeholder, value] of Object.entries(replacements)) {
      htmlContent = htmlContent.split(placeholder).join(value);
    }

    console.time('setContent');

    await page.setContent(htmlContent, { waitUntil: 'domcontentloaded' });

    console.timeEnd('setContent');

    console.time('pagePdf');


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

    console.timeEnd('pagePdf');

    return Buffer.from(pdfBuffer);
  } finally {
    if (page) await page.close();
  }
};

module.exports = { generatePDF, closeBrowser };
