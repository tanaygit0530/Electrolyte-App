const { pool } = require('../config/neondb');
require('dotenv').config();

const formatComponent = (prod) => ({
  id: String(prod.id),
  part_name: prod.product_name,
  part_code: prod.product_code,
  model: prod.description || 'N/A',
  price: parseFloat(prod.product_price) || 0,
  stock_quantity: prod.stock_quantity !== undefined ? prod.stock_quantity : 0,
  status: prod.stock_quantity > 0 ? 'Available' : 'Out of Stock'
});

exports.processChat = async (req, res) => {
  try {
    const { message: userMessage } = req.body;
    let { sessionId } = req.body;

    if (!userMessage) {
      return res.status(400).json({
        reply: "Message cannot be empty."
      });
    }

    console.log("User Message:", userMessage);

    // Handle Session
    if (!sessionId) {
      const title = userMessage.substring(0, 30) + (userMessage.length > 30 ? '...' : '');
      const sessionRes = await pool.query(
        'INSERT INTO chat_sessions (title) VALUES ($1) RETURNING *',
        [title]
      );
      sessionId = sessionRes.rows[0].id;
    } else {
      await pool.query(
        'UPDATE chat_sessions SET updated_at = CURRENT_TIMESTAMP WHERE id = $1',
        [sessionId]
      );
    }

    // Save User Message
    await pool.query(
      'INSERT INTO chat_messages (session_id, role, content) VALUES ($1, $2, $3)',
      [sessionId, 'user', userMessage]
    );

    // Search NeonDB Products
    const queryStr = `%${userMessage}%`;
    const prodRes = await pool.query(
      `SELECT * FROM products 
       WHERE product_name ILIKE $1 
          OR product_code ILIKE $1 
          OR description ILIKE $1 
       LIMIT 20`,
      [queryStr]
    );
    const components = prodRes.rows;

    let replyMessage = "";
    let formattedComponents = [];

    if (components.length === 0) {
      replyMessage = "No matching spare parts found for your query.";
    } else {
      replyMessage = `Found ${components.length} matching component(s):`;
      formattedComponents = components.map(formatComponent);
    }

    // Save Assistant Response
    await pool.query(
      'INSERT INTO chat_messages (session_id, role, content) VALUES ($1, $2, $3)',
      [sessionId, 'assistant', replyMessage]
    );

    res.json({ 
      reply: replyMessage, 
      components: formattedComponents,
      sessionId: sessionId 
    });

  } catch (err) {
    console.error("SERVER ERROR:", err);
    res.status(500).json({
      reply: "Internal server error. Please try again."
    });
  }
};

exports.getSessions = async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM chat_sessions ORDER BY updated_at DESC');
    res.json(result.rows);
  } catch (err) {
    console.error("Get Sessions Error:", err);
    res.status(500).json({ error: "Failed to fetch chat history" });
  }
};

exports.getSessionMessages = async (req, res) => {
  const { sessionId } = req.params;
  try {
    const result = await pool.query(
      'SELECT * FROM chat_messages WHERE session_id = $1 ORDER BY created_at ASC',
      [sessionId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error("Get Messages Error:", err);
    res.status(500).json({ error: "Failed to fetch messages" });
  }
};
