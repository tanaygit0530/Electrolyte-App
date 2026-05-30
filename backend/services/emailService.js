const nodemailer = require('nodemailer');

const sendEmail = async (to, invoiceNumber, pdfBuffer, pdfUrl) => {
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });

  const mailOptions = {
    from: `"Electrolyte Solutions" <${process.env.EMAIL_USER}>`,
    to: [to, 'electrolytesolservice@gmail.com'],
    subject: `Invoice - Electrolyte Solutions - ${invoiceNumber}`,
    text: `Please find the attached invoice for your recent service.\n\nYou can also view it here: ${pdfUrl}`,
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.6;">
        <h2>Electrolyte Solutions</h2>
        <p>Dear Customer,</p>
        <p>Please find attached your invoice (<strong>${invoiceNumber}</strong>) for the recent service.</p>
        // <p>You can also download or view it here: <a href="${pdfUrl}">${pdfUrl}</a></p>
        <br/>
        <p>Thank you for choosing Electrolyte Solutions!</p>
        <hr/>
        <p style="font-size: 12px; color: #666;">This is an automated email. Please do not reply.</p>
      </div>
    `,
    attachments: [
      {
        filename: `Invoice_${invoiceNumber}.pdf`,
        content: pdfBuffer,
      },
    ],
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log('Email sent: ' + info.response);
    return info;
  } catch (error) {
    console.error('Failed to send email:', error);
    throw error;
  }
};

module.exports = { sendEmail };

