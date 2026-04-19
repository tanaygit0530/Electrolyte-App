const express = require('express');
const cors = require('cors');
require('dotenv').config();

const chatRoutes = require('./routes/chatRoutes');
const partsRoutes = require('./routes/parts');
const ordersRoutes = require('./routes/orders');

// New Routes
const authRoutes = require('./routes/authRoutes');
const invoiceRoutes = require('./routes/invoiceRoutes');

const connectMongoDB = require('./config/mongodb');

const app = express();
const PORT = process.env.PORT || 5001;

// Connect to MongoDB for auth & invoices (Supabase config stays in parts/chat)
connectMongoDB();

app.use(cors());
app.use(express.json());

// Routes
app.use('/chat', chatRoutes);
app.use('/parts', partsRoutes);
app.use('/order', ordersRoutes);
app.use('/orders', ordersRoutes);

app.use('/auth', authRoutes);
app.use('/invoice', invoiceRoutes);

app.get('/', (req, res) => {
  res.send('Spare Parts Management API is running...');
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
