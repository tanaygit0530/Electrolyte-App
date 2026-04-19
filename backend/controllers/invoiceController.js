const Invoice = require('../models/Invoice');
const { generatePDF } = require('../services/pdfService');
const { uploadToCloudinary } = require('../services/cloudinaryService');
const { sendEmail } = require('../services/emailService');

const createInvoice = async (req, res) => {
  try {
    const payload = req.body;
    const user = req.user; // from auth middleware

    const items = payload.items || [];
    let subTotal = payload.subTotal;
    let totalAmount = payload.totalAmount;

    if (subTotal === undefined) {
      subTotal = items.reduce((sum, item) => sum + (item.amount || 0), 0);
    }
    
    const serviceCharge = payload.serviceCharge || 0;
    
    if (totalAmount === undefined) {
      totalAmount = subTotal + serviceCharge;
    }

    const count = await Invoice.countDocuments();
    const invoiceNumber = `INV-${new Date().getFullYear()}-${(count + 1).toString().padStart(4, '0')}`;

    const newInvoice = new Invoice({
      ...payload,
      invoiceNumber,
      technicianName: user.name || user.email || 'Technician',
      subTotal,
      serviceCharge,
      totalAmount,
      status: 'Generated',
    });

    const savedInvoice = await newInvoice.save();

    // Generate PDF
    const pdfBuffer = await generatePDF(savedInvoice);

    let pdfUrl = '';

    // Upload to Cloudinary
    try {
      if (process.env.CLOUDINARY_CLOUD_NAME) {
         pdfUrl = await uploadToCloudinary(pdfBuffer, `${invoiceNumber}_${Date.now()}`);
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
        console.error("Resend Email Error:", emailError);
      }
    }

    res.status(201).json({
      message: 'Invoice created and sent successfully',
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
