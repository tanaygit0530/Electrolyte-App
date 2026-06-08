const { pool } = require('../config/neondb');
const { generatePDF } = require('../services/pdfService');
const { uploadToCloudinary } = require('../services/cloudinaryService');
const { sendEmail } = require('../services/emailService');

const formatInvoice = (inv) => ({
  id: String(inv.id),
  invoiceNumber: inv.invoice_number,
  technicianName: inv.technician_name,
  customerName: inv.customer_name,
  customerEmail: inv.customer_email,
  customerPhone: inv.customer_phone,
  items: typeof inv.items === 'string' ? JSON.parse(inv.items) : inv.items,
  subTotal: parseFloat(inv.sub_total) || 0,
  gstAmount: parseFloat(inv.gst_amount) || 0,
  serviceCharge: parseFloat(inv.service_charge) || 0,
  totalAmount: parseFloat(inv.total_amount) || 0,
  pdfUrl: inv.pdf_url,
  status: inv.status,
  brand: inv.brand,
  serialNumber: inv.serial_number,
  caseId: inv.case_id,
  warrantyType: inv.warranty_type,
  preparedBy: inv.prepared_by,
  createdAt: inv.created_at,
  updatedAt: inv.updated_at
});

const createInvoice = async (req, res) => {
  const totalStart = Date.now();
  try {
    const payload = req.body;
    const { 
      customerName, 
      customerEmail, 
      customerPhone,
      warrantyType, 
      brand, 
      products, 
      serialNumber, 
      preparedBy, 
      caseId, 
      serviceCharge,
      gstEnabled
    } = payload;

    // Calculate subtotal from products (name, qty, rate)
    const items = (products || []).map(p => ({
      description: p.name,
      quantity: p.qty,
      rate: p.rate,
      amount: p.qty * p.rate
    }));

    const subTotal = items.reduce((sum, item) => sum + item.amount, 0);
    const gstAmount = gstEnabled ? (subTotal * 0.18) : 0;
    const sCharge = parseFloat(serviceCharge) || 0;
    const totalAmount = subTotal + gstAmount + sCharge;

    // Generate invoice number ES/26-27/OWXXXX
    console.time('Database Insert & Invoice Number Generation');
    const itemsJson = JSON.stringify(items);
    const tempInvoiceNumber = `TEMP-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    const invoiceRes = await pool.query(
      `INSERT INTO invoices (
        invoice_number, technician_name, customer_name, customer_email, customer_phone,
        items, sub_total, gst_amount, service_charge, total_amount, status,
        brand, serial_number, case_id, warranty_type, prepared_by, user_id
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'Generated', $11, $12, $13, $14, $15, $16)
       RETURNING *`,
      [
        tempInvoiceNumber, preparedBy || 'Technician', customerName, customerEmail, customerPhone,
        itemsJson, subTotal, gstAmount, sCharge, totalAmount,
        brand, serialNumber, caseId, warrantyType, preparedBy, req.user.id
      ]
    );

    const savedInvoice = invoiceRes.rows[0];
    const savedId = savedInvoice.id;

    // Generate real invoice number from returned ID
    const sequence = savedId.toString().padStart(4, '0');
    const warrantyCode = (warrantyType || 'OW').toUpperCase();
    const invoiceNumber = `ES/26-27/${warrantyCode}${sequence}`;
    
    // Mutate the local object for PDF generation
    savedInvoice.invoice_number = invoiceNumber;

    // Update real invoice number in DB (non-blocking)
    pool.query('UPDATE invoices SET invoice_number = $1 WHERE id = $2', [invoiceNumber, savedId])
      .catch(err => console.error('DB Update Error (Invoice Number):', err));
      
    console.timeEnd('Database Insert & Invoice Number Generation');

    // Generate PDF
    console.time('PDF Generation');
    const formattedInvoiceForPDF = formatInvoice(savedInvoice);
    const pdfBuffer = await generatePDF(formattedInvoiceForPDF);
    console.timeEnd('PDF Generation');

    console.log(`Total Request Time (excluding upload & email): ${Date.now() - totalStart}ms`);

    // Return response immediately, passing base64 to avoid CORS issues on Flutter Web preview
    res.status(201).json({
      message: 'Invoice generated successfully',
      invoiceId: savedInvoice.id,
      invoiceNumber,
      pdfBase64: pdfBuffer.toString('base64')
    });

    // --- BACKGROUND TASKS ---
    (async () => {
      let finalPdfUrl = '';
      
      // 1. Upload to Cloudinary
      console.time('Cloudinary Upload (Background)');
      try {
        if (process.env.CLOUDINARY_CLOUD_NAME) {
           finalPdfUrl = await uploadToCloudinary(pdfBuffer, `${invoiceNumber.replace(/\//g, '_')}_${Date.now()}`);
           await pool.query('UPDATE invoices SET pdf_url = $1 WHERE id = $2', [finalPdfUrl, savedInvoice.id]);
        } else {
          console.warn("CLOUDINARY_CLOUD_NAME not set, skipping upload.");
        }
      } catch (uploadError) {
        console.error("Cloudinary Upload Error:", uploadError);
      }
      console.timeEnd('Cloudinary Upload (Background)');
      
      // 2. Send Email
      if (customerEmail) {
        console.time('Email Sending (Background)');
        try {
          await sendEmail(customerEmail, invoiceNumber, pdfBuffer, finalPdfUrl);
          console.log(`Email successfully sent to ${customerEmail}`);
        } catch (emailError) {
          console.error("Email Sending Error:", emailError);
        }
        console.timeEnd('Email Sending (Background)');
      }
    })();

  } catch (error) {
    console.error("Invoice Creation Error:", error);
    res.status(500).json({ error: error.message || 'Internal Server Error' });
  }
};

const getInvoices = async (req, res) => {
  try {
    const { search, status } = req.query;

    let queryStr = 'SELECT * FROM invoices';
    const params = [req.user.id];
    const conditions = ['user_id = $1'];

    if (search) {
      params.push(`%${search}%`);
      conditions.push(`(customer_name ILIKE $${params.length} OR invoice_number ILIKE $${params.length})`);
    }

    if (status) {
      params.push(status);
      conditions.push(`status = $${params.length}`);
    }

    if (conditions.length > 0) {
      queryStr += ' WHERE ' + conditions.join(' AND ');
    }

    queryStr += ' ORDER BY created_at DESC';

    const result = await pool.query(queryStr, params);
    const formattedInvoices = result.rows.map(formatInvoice);
    
    res.status(200).json({ invoices: formattedInvoices });
  } catch (error) {
    console.error("Get Invoices Error:", error);
    res.status(500).json({ error: error.message || "Internal Server Error" });
  }
};

module.exports = { createInvoice, getInvoices };
