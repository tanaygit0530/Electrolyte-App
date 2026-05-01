const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
require('dotenv').config();

const User = require('./models/User'); // Ensure this path is correct based on where you run the script

const createTechnician = async () => {
  try {
    // 1. Connect to your database
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    // 2. Define the user credentials here
    const email = 'technician@example.com';
    const plainTextPassword = 'password123';
    
    // 3. Hash the password using bcrypt
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(plainTextPassword, saltRounds);

    // 4. Create the user
    const newUser = new User({
      email,
      passwordHash,
      role: 'technician' // or 'admin'
    });

    await newUser.save();
    console.log(`Successfully created user: ${email}`);

  } catch (error) {
    console.error('Error creating user:', error);
  } finally {
    mongoose.connection.close();
    process.exit(0);
  }
};

createTechnician();
