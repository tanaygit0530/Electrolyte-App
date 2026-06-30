const { pool } = require('../config/neondb');

// Map NeonDB product row to match legacy format for the Flutter app
const formatComponent = (prod) => ({
  id: String(prod.id),
  part_name: prod.product_name,
  part_code: prod.product_code,
  model: prod.description || 'N/A',
  price: parseFloat(prod.product_price) || 0,
  stock_quantity: prod.stock_quantity !== undefined ? prod.stock_quantity : 0,
  location: prod.location ?? 'N/A',
  status: prod.stock_quantity > 0 ? 'Available' : 'Out of Stock'
});

exports.getAllParts = async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products ORDER BY id ASC');
    const formattedData = result.rows.map(formatComponent);
    res.status(200).json(formattedData);
  } catch (error) {
    console.error("Get All Parts Error:", error);
    res.status(500).json({ error: error.message });
  }
};

exports.getPartByCode = async (req, res) => {
  const { code } = req.params;
  try {
    const result = await pool.query('SELECT * FROM products WHERE product_code = $1', [code]);
    const prod = result.rows[0];

    if (!prod) {
      return res.status(404).json({ message: 'Part not found' });
    }
    
    res.status(200).json(formatComponent(prod));
  } catch (error) {
    console.error("Get Part By Code Error:", error);
    res.status(500).json({ error: error.message });
  }
};

exports.searchParts = async (req, res) => {
  const { q } = req.query;
  
  if (!q) {
    return res.status(200).json([]);
  }

  try {
    const queryStr = `%${q}%`;
    const result = await pool.query(
      'SELECT * FROM products WHERE product_name ILIKE $1 OR product_code ILIKE $1 OR description ILIKE $1 LIMIT 5',
      [queryStr]
    );

    const formattedData = result.rows.map(formatComponent);
    res.status(200).json(formattedData);
  } catch (error) {
    console.error("Search Parts Error:", error);
    res.status(500).json({ error: error.message });
  }
};
