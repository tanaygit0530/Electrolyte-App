const { pool } = require('../config/neondb');

const formatOrder = (order) => ({
  id: String(order.id),
  part_code: order.part_code,
  part_name: order.part_name,
  quantity: order.quantity,
  price: parseFloat(order.price) || 0,
  gst: parseFloat(order.gst) || 0,
  total_amount: parseFloat(order.total_amount) || 0,
  status: order.status,
  created_at: order.created_at,
  updated_at: order.updated_at
});

exports.createOrder = async (req, res) => {
  const { part_code, quantity } = req.body;
  let client;

  try {
    client = await pool.connect();
    await client.query('BEGIN');

    // 1. Fetch product/part details
    const partRes = await client.query('SELECT * FROM products WHERE product_code = $1 FOR UPDATE', [part_code]);
    const part = partRes.rows[0];

    if (!part) {
      await client.query('ROLLBACK');
      return res.status(404).json({ message: 'Part not found' });
    }

    // 2. Check stock
    if (part.stock_quantity < quantity) {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: `Insufficient stock. Only ${part.stock_quantity} available.` });
    }

    // 3. Calculate billing
    const price = parseFloat(part.product_price || 0);
    const subtotal = price * quantity;
    const gst = subtotal * 0.18;
    const total_amount = subtotal + gst;

    // 4. Create order
    const orderRes = await client.query(
      `INSERT INTO orders (part_code, part_name, quantity, price, gst, total_amount, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'Confirmed')
       RETURNING *`,
      [part.product_code, part.product_name, quantity, price, gst, total_amount]
    );
    const order = orderRes.rows[0];

    // 5. Update stock
    const newStock = part.stock_quantity - quantity;
    await client.query(
      'UPDATE products SET stock_quantity = $1, updated_at = CURRENT_TIMESTAMP WHERE product_code = $2',
      [newStock, part_code]
    );

    await client.query('COMMIT');

    return res.status(201).json({
      message: 'Order confirmed',
      order: formatOrder(order)
    });

  } catch (error) {
    if (client) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        console.error('Error rolling back order creation transaction:', rollbackError);
      }
    }
    console.error("Order Creation Error:", error);
    res.status(500).json({ error: error.message });
  } finally {
    if (client) {
      client.release();
    }
  }
};

exports.getAllOrders = async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM orders ORDER BY created_at DESC');
    res.status(200).json(result.rows.map(formatOrder));
  } catch (error) {
    console.error("Get All Orders Error:", error);
    res.status(500).json({ error: error.message });
  }
};
