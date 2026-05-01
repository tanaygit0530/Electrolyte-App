const cloudinary = require('cloudinary').v2;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const uploadToCloudinary = (fileBuffer, fileName) => {
  return new Promise((resolve, reject) => {
    const uploadStream = cloudinary.uploader.upload_stream(
      {
        folder: 'invoices',
        public_id: fileName,
        resource_type: 'image', // Cloudinary treats PDFs as images for public viewing
        format: 'pdf',
        access_mode: 'public',
      },
      (error, result) => {
        if (error || !result) {
          console.error("Cloudinary upload failed:", error);
          reject(error || new Error("Unknown error during cloudinary upload"));
        } else {
          resolve(result.secure_url);
        }
      }
    );

    uploadStream.end(fileBuffer);
  });
};

module.exports = { uploadToCloudinary };
