const { pool } = require('../config/neondb');
const { searchProducts } = require('../services/searchService');
const { detectIntent } = require('../services/intentService');
const { generateSearchReply, generateGeneralReply } = require('../services/llmService');
require('dotenv').config();

const formatComponent = (prod) => ({
  id: String(prod.id),
  part_name: prod.product_name,
  part_code: prod.product_code,
  model: prod.description || 'N/A',
  price: parseFloat(prod.product_price) || 0,
  stock_quantity: prod.stock_quantity ?? 0,
  location: prod.location ?? 'N/A',
  status: prod.stock_quantity > 0 ? 'Available' : 'Out of Stock'
});

exports.processChat = async (req, res) => {
  const totalStart = Date.now();

  const { message: userMessage } = req.body;
  let { sessionId } = req.body;

  if (!userMessage || !userMessage.trim()) {
    return res.status(400).json({
      reply: 'Message cannot be empty.'
    });
  }

  let client;

  try {
    client = await pool.connect();

    const intent = detectIntent(userMessage);
    console.log('[chatController] Detected intent:', intent);

    // ==========================
    // CREATE NEW SESSION
    // ==========================
    if (!sessionId) {
      const title =
        userMessage.substring(0, 30) +
        (userMessage.length > 30 ? '...' : '');

      const sessionRes = await client.query(
        `
        INSERT INTO chat_sessions (title, user_id)
        VALUES ($1, $2)
        RETURNING id
        `,
        [title, req.user.id]
      );

      sessionId = sessionRes.rows[0].id;

      await client.query(
        `
        INSERT INTO chat_messages
        (session_id, role, content)
        VALUES ($1, $2, $3)
        `,
        [sessionId, 'user', userMessage]
      );
    } else {
      // ==========================
      // EXISTING SESSION
      // ==========================
      await Promise.all([
        client.query(
          `
          UPDATE chat_sessions
          SET updated_at = CURRENT_TIMESTAMP
          WHERE id = $1
          `,
          [sessionId]
        ),

        client.query(
          `
          INSERT INTO chat_messages
          (session_id, role, content)
          VALUES ($1, $2, $3)
          `,
          [sessionId, 'user', userMessage]
        )
      ]);
    }

    let replyMessage = '';
    let formattedComponents = [];

    switch (intent) {
      case 'greeting':
        replyMessage = "Hello! I'm your Spare Parts Assistant. How can I help you today?";
        break;

      case 'thanks':
        replyMessage = "You're welcome! Let me know if you need help finding any spare parts.";
        break;

      case 'goodbye':
        replyMessage = 'Goodbye! Have a great day.';
        break;

      case 'help':
        replyMessage = "You can search using product names, models (GV3, GV4, GV5), dimensions (1200mm), product codes, colours, or descriptions. Example: 'GV5 PCB', 'motor housing gv4', '1200mm renesa'.";
        break;

      default: {
        const products = await searchProducts(userMessage);

        if (products.length > 0) {
          replyMessage = `Found ${products.length} matching component(s):`;
          formattedComponents = products.map(formatComponent);
        } else {
          replyMessage = await generateGeneralReply(userMessage);
          formattedComponents = [];
        }

        break;
      }
    }

    // ==========================
    // SAVE ASSISTANT MESSAGE
    // ==========================
    await client.query(
      `
      INSERT INTO chat_messages
      (session_id, role, content)
      VALUES ($1, $2, $3)
      `,
      [sessionId, 'assistant', replyMessage]
    );

    return res.json({
      reply: replyMessage,
      components: formattedComponents,
      sessionId
    });

  } catch (err) {
    console.error('SERVER ERROR:', err);

    return res.status(500).json({
      reply: 'Internal server error. Please try again.'
    });

  } finally {
    if (client) {
      client.release();
    }
  }
};

exports.getSessions = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM chat_sessions WHERE user_id = $1 ORDER BY updated_at DESC',
      [req.user.id]
    );

    res.json(result.rows);

  } catch (err) {
    console.error('Get Sessions Error:', err);

    res.status(500).json({
      error: 'Failed to fetch chat history'
    });
  }
};

exports.getSessionMessages = async (req, res) => {
  const { sessionId } = req.params;

  try {
    const result = await pool.query(
      `
      SELECT *
      FROM chat_messages
      WHERE session_id = $1
      ORDER BY created_at ASC
      `,
      [sessionId]
    );

    res.json(result.rows);

  } catch (err) {
    console.error('Get Messages Error:', err);

    res.status(500).json({
      error: 'Failed to fetch messages'
    });
  }
};