require('dotenv').config();
const mongoose = require('mongoose');
const xlsx = require('xlsx');
const Component = require('./models/Component');

const importData = async () => {
  try {
    // 1. Connect to MongoDB
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected successfully!');

    // 2. Read the Excel file
    const filePath = 'C:\\Users\\Prasad\\Downloads\\Projects\\Electrolyte-App\\resources\\New Part Price List - Copy.xlsx';
    console.log(`Reading Excel file from ${filePath}...`);
    const workbook = xlsx.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    
    // Parse to JSON (assuming the first row contains headers)
    const data = xlsx.utils.sheet_to_json(worksheet);
    
    console.log(`Found ${data.length} records. Processing...`);

    let importedCount = 0;
    let updatedCount = 0;
    let failedCount = 0;

    // 3. Process each row
    for (const row of data) {
      if (!row['Product Code'] || !row['Product Name']) {
        // Skip empty or invalid rows
        continue;
      }

      const componentData = {
        active: row['Active (Product)'] === true || String(row['Active (Product)']).toLowerCase() === 'true',
        name: row['Product Name'],
        code: String(row['Product Code']).trim(),
        description: row['Product Description'] || '',
        customerPrice: parseFloat(row['Customer Price']) || 0,
        aspPrice: parseFloat(row['ASP Price']) || 0
      };

      try {
        // Upsert (update if exists, insert if new) based on Product Code
        const result = await Component.updateOne(
          { code: componentData.code },
          { $set: componentData },
          { upsert: true }
        );

        if (result.upsertedCount > 0) {
          importedCount++;
        } else if (result.modifiedCount > 0) {
          updatedCount++;
        }
      } catch (err) {
        console.error(`Error saving component ${componentData.code}:`, err.message);
        failedCount++;
      }
    }

    console.log('\n--- Import Summary ---');
    console.log(`Successfully added: ${importedCount}`);
    console.log(`Successfully updated: ${updatedCount}`);
    console.log(`Failed: ${failedCount}`);
    console.log('----------------------\n');

  } catch (error) {
    console.error('Migration failed:', error);
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB.');
    process.exit(0);
  }
};

importData();
