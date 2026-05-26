const mongoose = require('mongoose');

const invoiceSchema = new mongoose.Schema(
  {
    invoiceNumber: { type: String, required: true, unique: true },
    technicianName: { type: String, required: true },
    customerName: { type: String, required: true },
    customerEmail: { type: String },
    customerPhone: { type: String },
    items: [
      {
        description: { type: String, required: true },
        quantity: { type: Number, required: true },
        rate: { type: Number, required: true },
        amount: { type: Number, required: true },
        gstPercent: { type: Number },
      },
    ],
    subTotal: { type: Number, required: true },
    gstAmount: { type: Number, default: 0 },
    serviceCharge: { type: Number, default: 0 },
    totalAmount: { type: Number, required: true },
    pdfUrl: { type: String },
    status: { type: String, default: 'Generated' },
  },
  { 
    timestamps: true,
    strict: false // Allow dynamic fields based on existing UI payloads
  }
);

module.exports = mongoose.models.Invoice || mongoose.model('Invoice', invoiceSchema);
