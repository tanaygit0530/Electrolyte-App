const express = require('express');
const cors = require('cors');
require('dotenv').config();

const chatRoutes = require('./routes/chatRoutes');
const partsRoutes = require('./routes/parts');
const ordersRoutes = require('./routes/orders');

const app = express();
const PORT = process.env.PORT || 5001;

app.use(cors());
app.use(express.json());

// Routes
app.use('/chat', chatRoutes);
app.use('/parts', partsRoutes);
app.use('/order', ordersRoutes);
app.use('/orders', ordersRoutes);

app.get('/', (req, res) => {
  res.send('Spare Parts Management API is running...');
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
