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
        ${pdfUrl ? `<p>You can also download or view it here: <a href="${pdfUrl}">${pdfUrl}</a></p>` : ''}
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

const sendPasswordResetEmail = async (to, resetToken) => {
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });

  const mailOptions = {
    from: `"Electrolyte Solutions Support" <${process.env.EMAIL_USER}>`,
    to,
    subject: 'Password Reset Request - Electrolyte App',
    text: `You requested a password reset. Your reset code is: ${resetToken}\nThis code will expire in 1 hour. If you did not make this request, please ignore this email.`,
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.6; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
        <h2 style="color: #0052cc;">Electrolyte Solutions</h2>
        <p>Hello,</p>
        <p>We received a request to reset your password. Use the verification token below to complete your reset:</p>
        <div style="background: #f4f5f7; padding: 12px 20px; font-size: 20px; font-weight: bold; letter-spacing: 2px; text-align: center; border-radius: 4px; margin: 20px 0;">
          ${resetToken}
        </div>
        <p>This token is valid for <strong>1 hour</strong>. For security reasons, do not share this token with anyone.</p>
        <p>If you did not request a password reset, you can safely ignore this email.</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
        <p style="font-size: 12px; color: #888;">Electrolyte App Security Team</p>
      </div>
    `,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log('Password reset email sent to ' + to + ':', info.response);
    return info;
  } catch (error) {
    console.error('Failed to send password reset email:', error);
    throw error;
  }
};

module.exports = { sendEmail, sendPasswordResetEmail };

