const Invoice = require('../models/Invoice');
const { generatePDF } = require('../services/pdfService');
const { uploadToCloudinary } = require('../services/cloudinaryService');
const { sendEmail } = require('../services/emailService');

const createInvoice = async (req, res) => {
  try {
    const payload = req.body;
    const { 
      customerName, 
      customerEmail, 
      warrantyType, 
      brand, 
      products, 
      serialNumber, 
      preparedBy, 
      caseId, 
      serviceCharge 
    } = payload;

    // Calculate subtotal from products (name, qty, rate)
    const items = (products || []).map(p => ({
      description: p.name,
      quantity: p.qty,
      rate: p.rate,
      amount: p.qty * p.rate
    }));

    const subTotal = items.reduce((sum, item) => sum + item.amount, 0);
    const sCharge = parseFloat(serviceCharge) || 0;
    const totalAmount = subTotal + sCharge;

    // Generate invoice number ES/26-27/OWXXXX
    // ES/26-27/ (Financial year 26-27)
    // OW (Warranty type OW/IW)
    const count = await Invoice.countDocuments();
    const sequence = (count + 1).toString().padStart(4, '0');
    const warrantyCode = (warrantyType || 'OW').toUpperCase();
    const invoiceNumber = `ES/26-27/${warrantyCode}${sequence}`;

    const newInvoice = new Invoice({
      invoiceNumber,
      technicianName: preparedBy || 'Technician',
      customerName,
      customerEmail,
      warrantyType,
      brand,
      items,
      serialNumber,
      caseId,
      subTotal,
      serviceCharge: sCharge,
      totalAmount,
      status: 'Generated',
      preparedBy
    });

    const savedInvoice = await newInvoice.save();

    // Generate PDF
    const pdfBuffer = await generatePDF(savedInvoice);

    let pdfUrl = '';

    // Upload to Cloudinary
    try {
      if (process.env.CLOUDINARY_CLOUD_NAME) {
         pdfUrl = await uploadToCloudinary(pdfBuffer, `${invoiceNumber.replace(/\//g, '_')}_${Date.now()}`);
         savedInvoice.pdfUrl = pdfUrl;
         await savedInvoice.save();
      } else {
        console.warn("CLOUDINARY_CLOUD_NAME not set, skipping upload.");
      }
    } catch (uploadError) {
      console.error("Cloudinary Upload Error:", uploadError);
    }

    // Send Email
    if (savedInvoice.customerEmail) {
      try {
        await sendEmail(savedInvoice.customerEmail, invoiceNumber, pdfBuffer, pdfUrl);
      } catch (emailError) {
        console.error("Email Sending Error:", emailError);
      }
    }

    res.status(201).json({
      message: 'Invoice generated and emailed successfully',
      invoiceId: savedInvoice._id,
      invoiceNumber,
      pdfUrl,
    });

  } catch (error) {
    console.error("Invoice Creation Error:", error);
    res.status(500).json({ error: error.message || 'Internal Server Error' });
  }
};


const getInvoices = async (req, res) => {
  try {
    const { search, status } = req.query;

    let query = {};

    if (search) {
      query.$or = [
        { customerName: { $regex: search, $options: 'i' } },
        { invoiceNumber: { $regex: search, $options: 'i' } },
      ];
    }

    if (status) {
      query.status = status;
    }

    const invoices = await Invoice.find(query).sort({ createdAt: -1 });
    
    res.status(200).json({ invoices });
  } catch (error) {
    console.error("Get Invoices Error:", error);
    res.status(500).json({ error: error.message || "Internal Server Error" });
  }
};

module.exports = { createInvoice, getInvoices };
