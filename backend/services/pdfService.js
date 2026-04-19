const puppeteer = require('puppeteer');

const generatePDF = async (invoice) => {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const page = await browser.newPage();

  const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Invoice ${invoice.invoiceNumber}</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 40px; color: #333; }
        .header { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #ccc; padding-bottom: 20px; margin-bottom: 30px; }
        .company-details { text-align: right; }
        .company-name { font-size: 24px; font-weight: bold; color: #1a56db; }
        h1 { color: #1a56db; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
        th, td { border: 1px solid #ccc; padding: 10px; text-align: left; }
        th { background: #f9fafb; font-weight: bold; }
        .totals { margin-left: auto; width: 300px; }
        .totals table { border: none; }
        .totals td { border: none; padding: 5px; text-align: left; }
        .totals-label { font-weight: bold; }
        .footer { margin-top: 50px; font-size: 12px; color: #666; text-align: center; border-top: 1px solid #ccc; padding-top: 20px; }
        .bank-details { margin-top: 30px; font-size: 14px; }
        .bank-details strong { display: block; margin-bottom: 5px; }
      </style>
    </head>
    <body>
      <div class="header">
        <div>
          <h1>TAX INVOICE</h1>
          <strong>Invoice No:</strong> ${invoice.invoiceNumber}<br/>
          <strong>Date:</strong> ${new Date(invoice.createdAt || new Date()).toLocaleDateString()}<br/>
          <strong>Case ID / Ticket:</strong> ${invoice.get('caseId') || 'N/A'}<br/>
          <strong>Technician:</strong> ${invoice.technicianName}<br/>
        </div>
        <div class="company-details">
          <div class="company-name">Electrolyte Solutions</div>
          Plot 223, Road Number 1, Sector 1, Ghansoli,<br/>
          Navi Mumbai, Maharashtra - 400701<br/>
          Phone: +91 8090712828 / 9029352208<br/>
          Email: contact@electrolytesoln.com
        </div>
      </div>

      <div style="margin-bottom: 30px;">
        <strong>BILL TO:</strong><br/>
        ${invoice.customerName}<br/>
        ${invoice.customerEmail ? `Email: ${invoice.customerEmail}<br/>` : ''}
        ${invoice.customerPhone ? `Phone: ${invoice.customerPhone}<br/>` : ''}
      </div>

      <table>
        <thead>
          <tr>
            <th>DESCRIPTION</th>
            <th>QUANTITY</th>
            <th>RATE (incl. tax)</th>
            <th>AMOUNT</th>
          </tr>
        </thead>
        <tbody>
          ${(invoice.items || []).map(item => `
            <tr>
              <td>${item.description}</td>
              <td>${item.quantity}</td>
              <td>₹${Number(item.rate).toFixed(2)}</td>
              <td>₹${Number(item.amount).toFixed(2)}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>

      <div class="totals">
        <table>
          <tr>
            <td class="totals-label">SUBTOTAL:</td>
            <td>₹${Number(invoice.subTotal).toFixed(2)}</td>
          </tr>
          <tr>
            <td class="totals-label">SERVICE CHARGE:</td>
            <td>₹${Number(invoice.serviceCharge || 0).toFixed(2)}</td>
          </tr>
          <tr>
            <td class="totals-label"><strong>GRAND TOTAL:</strong></td>
            <td><strong>₹${Number(invoice.totalAmount).toFixed(2)}</strong></td>
          </tr>
        </table>
      </div>

      <div class="bank-details">
        <strong>Bank Details</strong>
        Name : M/s Electrolyte Solutions<br/>
        Bank Name : Axis Bank Ltd.<br/>
        Account No. : 921020033685999<br/>
        IFSC Code : UTIB0001622<br/>
        Branch : Mulund East
      </div>

      <div class="footer">
        Subjected to Navi Mumbai Jurisdiction.<br/>
        This is a computer-generated invoice. No signature required.<br/>
        Note: Spare/Products are warranted for a period of 10 Days From the Date of Handing Over to the Customer.
      </div>
    </body>
    </html>
  `;

  await page.setContent(htmlContent, { waitUntil: 'networkidle0' });
  
  const pdfBuffer = await page.pdf({
    format: 'A4',
    printBackground: true,
  });

  await browser.close();
  
  return Buffer.from(pdfBuffer);
};

module.exports = { generatePDF };
