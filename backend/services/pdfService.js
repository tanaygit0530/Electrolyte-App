process.env.PUPPETEER_CACHE_DIR = process.env.PUPPETEER_CACHE_DIR || '/opt/render/.cache/puppeteer';
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

const buildTaxTable = (invoiceData) => {
  const gstAmount = parseFloat(invoiceData.gstAmount || 0);
  if (gstAmount <= 0) return '';

  const taxableAmt = parseFloat(invoiceData.subTotal || 0);
  const cgstAmt = gstAmount / 2;
  const sgstAmt = gstAmount / 2;

  return `
    <div class="tax-table-container">
      <table class="tax-table">
        <thead>
          <tr>
            <th style="width: 20%; text-align: center;">Tax Rate</th>
            <th style="width: 20%; text-align: right;">Taxable Amt.</th>
            <th style="width: 20%; text-align: right;">CGST Amt.</th>
            <th style="width: 20%; text-align: right;">SGST Amt.</th>
            <th style="width: 20%; text-align: right;">Total Tax</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td style="text-align: center;">18%</td>
            <td style="text-align: right;">₹${taxableAmt.toFixed(2)}</td>
            <td style="text-align: right;">₹${cgstAmt.toFixed(2)}</td>
            <td style="text-align: right;">₹${sgstAmt.toFixed(2)}</td>
            <td style="text-align: right;">₹${gstAmount.toFixed(2)}</td>
          </tr>
        </tbody>
      </table>
    </div>
  `;
};

const buildBillingTable = (invoiceData, isSymphony) => {
  const items = invoiceData.items || [];
  const hsnCode = isSymphony ? '8479' : '8414';
  const unitName = 'NOS';

  let rowsHtml = '';
  items.forEach((item, index) => {
    const qty = parseFloat(item.quantity || item.qty || 0);
    const rate = parseFloat(item.rate || 0);
    const amount = qty * rate;

    rowsHtml += `
      <tr>
        <td style="text-align: center;">${index + 1}</td>
        <td style="text-align: left;">${item.description || item.name}</td>
        <td style="text-align: center;">${hsnCode}</td>
        <td style="text-align: center;">${qty.toFixed(3)}</td>
        <td style="text-align: center;">${unitName}</td>
        <td style="text-align: right;">₹${rate.toFixed(2)}</td>
        <td style="text-align: right;">₹${amount.toFixed(2)}</td>
      </tr>
    `;
  });

  // Calculate totals
  const subTotal = parseFloat(invoiceData.subTotal || 0);
  const serviceCharge = parseFloat(invoiceData.serviceCharge || 0);
  const gstAmount = parseFloat(invoiceData.gstAmount || 0);
  const total = subTotal + serviceCharge + gstAmount;
  const roundedTotal = Math.round(total);
  const roundedOff = roundedTotal - total;

  // Total Quantity
  const totalQty = items.reduce((sum, item) => sum + parseFloat(item.quantity || item.qty || 0), 0);

  // Subtotal row
  rowsHtml += `
    <tr class="summary-row">
      <td></td>
      <td style="text-align: left;"><b>Subtotal</b></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td style="text-align: right;">₹${subTotal.toFixed(2)}</td>
    </tr>
  `;

  // Service charge row
  if (serviceCharge > 0) {
    rowsHtml += `
      <tr class="summary-row">
        <td></td>
        <td style="text-align: left;">Add : Service Charge</td>
        <td></td>
        <td></td>
        <td></td>
        <td></td>
        <td style="text-align: right;">₹${serviceCharge.toFixed(2)}</td>
      </tr>
    `;
  }

  // GST rows
  if (gstAmount > 0) {
    const cgstVal = gstAmount / 2;
    const sgstVal = gstAmount / 2;
    rowsHtml += `
      <tr class="summary-row">
        <td></td>
        <td style="text-align: left;">Add : CGST @ 9.00%</td>
        <td></td>
        <td></td>
        <td></td>
        <td></td>
        <td style="text-align: right;">₹${cgstVal.toFixed(2)}</td>
      </tr>
      <tr class="summary-row">
        <td></td>
        <td style="text-align: left;">Add : SGST @ 9.00%</td>
        <td></td>
        <td></td>
        <td></td>
        <td></td>
        <td style="text-align: right;">₹${sgstVal.toFixed(2)}</td>
      </tr>
    `;
  }

  // Rounded off row
  if (Math.abs(roundedOff) > 0.001) {
    const roundedText = roundedOff < 0 ? 'Less : Rounded Off (-)' : 'Add : Rounded Off (+)';
    rowsHtml += `
      <tr class="summary-row">
        <td></td>
        <td style="text-align: left;">${roundedText}</td>
        <td></td>
        <td></td>
        <td></td>
        <td></td>
        <td style="text-align: right;">₹${Math.abs(roundedOff).toFixed(2)}</td>
      </tr>
    `;
  }

  // Grand Total row
  rowsHtml += `
    <tr class="grand-total-row">
      <td></td>
      <td style="text-align: left;"><b>Grand Total</b></td>
      <td></td>
      <td style="text-align: center;"><b>${totalQty.toFixed(3)}</b></td>
      <td style="text-align: center;"><b>${unitName}</b></td>
      <td></td>
      <td style="text-align: right;"><b>₹${roundedTotal.toFixed(2)}</b></td>
    </tr>
  `;

  return `
    <table class="items-table">
      <thead>
        <tr>
          <th style="width: 5%; text-align: center;">S.N.</th>
          <th style="width: 45%; text-align: left;">Description of Goods</th>
          <th style="width: 10%; text-align: center;">HSN/SAC</th>
          <th style="width: 10%; text-align: center;">Qty.</th>
          <th style="width: 8%; text-align: center;">Unit</th>
          <th style="width: 10%; text-align: right;">Price</th>
          <th style="width: 12%; text-align: right;">Amount</th>
        </tr>
      </thead>
      <tbody>
        ${rowsHtml}
      </tbody>
    </table>
  `;
};

const buildUnifiedDetailsBox = (invoiceData, formattedDate) => {
  const brandName = invoiceData.brand || 'Atomberg';
  const customerEmailLine = invoiceData.customerEmail ? `<p><b>EMAIL:</b> ${invoiceData.customerEmail}</p>` : '';
  const serialLine = invoiceData.serialNumber ? `<p><b>SERIAL NO:</b> ${invoiceData.serialNumber}</p>` : '';
  const phoneLine = invoiceData.customerPhone ? `<p><b>MOBILE NO:</b> ${invoiceData.customerPhone}</p>` : '';

  return `
    <div class="details-container">
      <div class="col-left">
        <p><b>Party Details :</b></p>
        <p><b>BILL TO:</b> ${invoiceData.customerName || 'Jay'}</p>
        ${phoneLine}
        ${customerEmailLine}
        ${serialLine}
      </div>
      <div class="col-right">
        <p><b>Invoice Details :</b></p>
        <p><b>INVOICE NO:</b> ${invoiceData.invoiceNumber}</p>
        <p><b>CASE ID:</b> ${invoiceData.caseId || '-'}</p>
        <p><b>BILL DATE:</b> ${formattedDate}</p>
        <p><b>BRAND:</b> ${brandName}</p>
        <p><b>PREPARED BY:</b> ${invoiceData.preparedBy || 'DIPAK MOHITE'}</p>
      </div>
    </div>
  `;
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
    let gstinLine = '27AJYPY7934L1ZS';

    let bankDetailsContent = `
      <p>A/c Name: M/s Electrolyte Solutions</p>
      <p>Bank Name: Axis Bank Ltd.</p>
      <p>Account No.: 921000031635999</p>
      <p>IFSC Code: UTIB0001622</p>
      <p>Branch: Mulund(E)</p>
    `;

    const roundedTotal = Math.round(parseFloat(invoiceData.totalAmount || 0));
    const rawWordsText = numberToWords(roundedTotal);

    let detailsBoxContent = buildUnifiedDetailsBox(invoiceData, formattedDate);
    let tableMarkup = buildBillingTable(invoiceData, isSymphony);
    let totalsBlock = '';
    let wordsText = `<b>IN WORDS:</b> ${rawWordsText.toUpperCase()}`;
    let payableNote = 'Make all cheque or bank transfers payable to: M/s Electrolyte Solutions.';
    let warrantyNote = 'Note: Spare/Products are warranted for a period of 1 year from the date of handing over to the customer.';

    if (isSymphony) {
      partnerSubtitle = 'Authorised Service Partner of Symphony Limited.';
      addressLine = 'Plot 70, Sector 1 Road No. 1, Ghansoli, Navi Mumbai, Maharashtra - 400701';
      phoneLine = '+91 8090712828 / 9029352208';
      emailLine = 'contact@electrolytesoln.com';
      gstinLine = '<p>GSTIN: 27AJYPY7934L1ZS</p>';

      bankDetailsContent = `
      <p>A/c Name: M/s Electrolyte Solutions</p>
        <p>Bank Name : Axis Bank Ltd.</p>
        <p>Account No. : 921020033685999</p>
        <p>IFSC Code : UTIB0001622</p>
        <p>Branch : Mulund(E)</p>
      `;

      payableNote = 'Make all Cheque or bank transfer payable to Name : M/s Electrolyte Solutions.';
      warrantyNote = 'Note:- Spare/Products Are Warranted for a period of 10 Days From the Date of Handing Over of the Spare/Products to the Customer.';

    } else {
      // Default / Atomberg layout
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
      '{{taxTableBlock}}': buildTaxTable(invoiceData),
      '{{signatoryTitle}}': 'Authorized Signatory'
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

module.exports = { generatePDF, closeBrowser, getBrowser };
