const supabase = require('../config/supabaseClient');
const Component = require('../models/Component');
require('dotenv').config();

const formatComponent = (comp) => ({
  id: comp._id.toString(),
  part_name: comp.name,
  part_code: comp.code,
  model: comp.description || 'N/A',
  price: comp.customerPrice || 0,
  stock_quantity: 10, // Default fallback
  status: comp.active ? 'Available' : 'Out of Stock'
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
    if (!sessionId && supabase) {
      const { data: sessionData, error: sessionError } = await supabase
        .from('chat_sessions')
        .insert([{ title: userMessage.substring(0, 30) + (userMessage.length > 30 ? '...' : '') }])
        .select()
        .single();
      
      if (sessionError) {
        console.error("Session Create Error:", sessionError);
      } else {
        sessionId = sessionData.id;
      }
    }

    // Save User Message
    if (sessionId && supabase) {
      await supabase.from('chat_messages').insert([
        { session_id: sessionId, role: 'user', content: userMessage }
      ]);
      // Update session timestamp
      await supabase.from('chat_sessions').update({ updated_at: new Date() }).eq('id', sessionId);
    }

    // Search MongoDB Components
    // Escape regex characters in userMessage just in case, but standard regex search works for most inputs.
    const escapedMessage = userMessage.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regexQuery = { $regex: escapedMessage, $options: 'i' };
    
    const components = await Component.find({
      $or: [
        { name: regexQuery },
        { code: regexQuery },
        { description: regexQuery }
      ]
    }).limit(20);

    let replyMessage = "";
    let formattedComponents = [];

    if (components.length === 0) {
      replyMessage = "No matching spare parts found for your query.";
    } else {
      replyMessage = `Found ${components.length} matching component(s):`;
      formattedComponents = components.map(formatComponent);
    }

    // Save Assistant Response
    if (sessionId && supabase) {
      await supabase.from('chat_messages').insert([
        { session_id: sessionId, role: 'assistant', content: replyMessage }
      ]);
    }

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
    if (!supabase) {
      return res.json([]);
    }
    const { data, error } = await supabase
      .from('chat_sessions')
      .select('*')
      .order('updated_at', { ascending: false });
    if (error) throw error;
    res.json(data);
  } catch (err) {
    console.error("Get Sessions Error:", err);
    res.status(500).json({ error: "Failed to fetch chat history" });
  }
};

exports.getSessionMessages = async (req, res) => {
  const { sessionId } = req.params;
  try {
    if (!supabase) {
      return res.json([]);
    }
    const { data, error } = await supabase
      .from('chat_messages')
      .select('*')
      .eq('session_id', sessionId)
      .order('created_at', { ascending: true });
    if (error) throw error;
    res.json(data);
  } catch (err) {
    console.error("Get Messages Error:", err);
    res.status(500).json({ error: "Failed to fetch messages" });
  }
};

