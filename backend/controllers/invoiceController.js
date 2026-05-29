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
    const countRes = await pool.query('SELECT COUNT(*) FROM invoices');
    const count = parseInt(countRes.rows[0].count || 0);
    const sequence = (count + 1).toString().padStart(4, '0');
    const warrantyCode = (warrantyType || 'OW').toUpperCase();
    const invoiceNumber = `ES/26-27/${warrantyCode}${sequence}`;

    const itemsJson = JSON.stringify(items);

    const invoiceRes = await pool.query(
      `INSERT INTO invoices (
        invoice_number, technician_name, customer_name, customer_email, customer_phone,
        items, sub_total, gst_amount, service_charge, total_amount, status,
        brand, serial_number, case_id, warranty_type, prepared_by
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'Generated', $11, $12, $13, $14, $15)
       RETURNING *`,
      [
        invoiceNumber, preparedBy || 'Technician', customerName, customerEmail, customerPhone,
        itemsJson, subTotal, gstAmount, sCharge, totalAmount,
        brand, serialNumber, caseId, warrantyType, preparedBy
      ]
    );

    const savedInvoice = invoiceRes.rows[0];

    // Generate PDF
    const formattedInvoiceForPDF = formatInvoice(savedInvoice);
    const pdfBuffer = await generatePDF(formattedInvoiceForPDF);

    let pdfUrl = '';

    // Upload to Cloudinary
    try {
      if (process.env.CLOUDINARY_CLOUD_NAME) {
         pdfUrl = await uploadToCloudinary(pdfBuffer, `${invoiceNumber.replace(/\//g, '_')}_${Date.now()}`);
         await pool.query('UPDATE invoices SET pdf_url = $1 WHERE id = $2', [pdfUrl, savedInvoice.id]);
      } else {
        console.warn("CLOUDINARY_CLOUD_NAME not set, skipping upload.");
      }
    } catch (uploadError) {
      console.error("Cloudinary Upload Error:", uploadError);
    }

    // Send Email
    if (customerEmail) {
      try {
        await sendEmail(customerEmail, invoiceNumber, pdfBuffer, pdfUrl);
      } catch (emailError) {
        console.error("Email Sending Error:", emailError);
      }
    }

    res.status(201).json({
      message: 'Invoice generated and emailed successfully',
      invoiceId: savedInvoice.id,
      invoiceNumber,
      pdfUrl: pdfUrl || savedInvoice.pdf_url,
    });

  } catch (error) {
    console.error("Invoice Creation Error:", error);
    res.status(500).json({ error: error.message || 'Internal Server Error' });
  }
};

const getInvoices = async (req, res) => {
  try {
    const { search, status } = req.query;

    let queryStr = 'SELECT * FROM invoices';
    const params = [];
    const conditions = [];

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
