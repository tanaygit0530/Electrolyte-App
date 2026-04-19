const { Resend } = require('resend');

const resendSecret = process.env.RESEND_API_KEY;
const resend = resendSecret ? new Resend(resendSecret) : null;

const sendEmail = async (to, invoiceNumber, pdfBuffer, pdfUrl) => {
  if (!resend) {
    console.warn("RESEND_API_KEY is not set. Skipping email send.");
    return false;
  }

  try {
    const data = await resend.emails.send({
      from: 'Electrolyte Solutions <onboarding@resend.dev>', // Should use verified domain
      to: [to],
      subject: `Invoice PDF - ${invoiceNumber}`,
      html: `
        <p>Dear Customer,</p>
        <p>Please find attached your invoice (<strong>${invoiceNumber}</strong>) for the recent service.</p>
        <p>You can also download or view it here: <a href="${pdfUrl}">${pdfUrl}</a></p>
        <br/>
        <p>Thank you,<br/>Electrolyte Solutions</p>
      `,
      attachments: [
        {
          filename: `Invoice_${invoiceNumber}.pdf`,
          content: pdfBuffer,
        },
      ],
    });

    return data;
  } catch (error) {
    console.error("Failed to send email:", error);
    throw error;
  }
};

module.exports = { sendEmail };
