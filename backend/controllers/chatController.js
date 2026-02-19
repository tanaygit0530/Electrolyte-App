const supabase = require('../config/supabaseClient');
const { GoogleGenAI } = require("@google/genai");
require('dotenv').config();

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY
});

exports.processChat = async (req, res) => {
  try {
    // 1. Validate Environment Variables
    if (!process.env.GEMINI_API_KEY) {
      console.error("CRITICAL: Missing GEMINI_API_KEY");
      return res.status(500).json({
        reply: "Server configuration error: Missing Gemini API key."
      });
    }

    if (!process.env.SUPABASE_URL || !process.env.SUPABASE_KEY) {
      console.error("CRITICAL: Missing Supabase Credentials");
      return res.status(500).json({
        reply: "Server configuration error: Missing Supabase credentials."
      });
    }

    const { message: userMessage } = req.body;
    let { sessionId } = req.body;

    if (!userMessage) {
      return res.status(400).json({
        reply: "Message cannot be empty."
      });
    }

    console.log("User Message:", userMessage);

    // 2. Handle Session
    if (!sessionId) {
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

    // 3. Save User Message
    if (sessionId) {
      await supabase.from('chat_messages').insert([
        { session_id: sessionId, role: 'user', content: userMessage }
      ]);
      // Update session timestamp
      await supabase.from('chat_sessions').update({ updated_at: new Date() }).eq('id', sessionId);
    }

    // 4. Initialize Gemini
    const result = await ai.models.generateContent({
      model: "gemini-flash-latest",
      contents: `
You are a spare parts assistant.
Extract part_code, part_name, or model from this message.
Return only valid JSON:
{
  "part_code": "",
  "part_name": "",
  "model": ""
}

Message: "${userMessage}"
`
    });

    let extracted = { part_code: "", part_name: "", model: "" };
    let replyMessage = "";

    // 5. Safe JSON Parsing
    try {
      let responseText = result.text;
      if (responseText.includes("```json")) {
        responseText = responseText.split("```json")[1].split("```")[0].trim();
      } else if (responseText.includes("```")) {
        responseText = responseText.split("```")[1].split("```")[0].trim();
      }
      extracted = JSON.parse(responseText);
    } catch (jsonError) {
      console.log("JSON parse error:", jsonError);
    }

    // 6. Query Supabase for parts
    let query = supabase.from("spare_parts").select("*");
    let hasQuery = false;

    if (extracted.part_code) {
      query = query.eq('part_code', extracted.part_code);
      hasQuery = true;
    } else if (extracted.part_name) {
      query = query.ilike('part_name', `%${extracted.part_name}%`);
      hasQuery = true;
    } else if (extracted.model) {
      query = query.ilike('model', `%${extracted.model}%`);
      hasQuery = true;
    }

    if (!hasQuery) {
      replyMessage = "I'm here to help with spare parts. Could you please specify a part name, code, or model?";
    } else {
      const { data: parts, error: partsError } = await query;
      if (partsError) {
        replyMessage = "Sorry, I had trouble checking the inventory.";
      } else if (!parts || parts.length === 0) {
        replyMessage = "No matching spare part found in our database.";
      } else {
        parts.forEach(part => {
          replyMessage += `Part Name: ${part.part_name}\nModel: ${part.model}\nPrice: ₹${part.price}\nStock: ${part.stock_quantity}\nStatus: ${part.status}\n\n`;
        });
      }
    }

    replyMessage = replyMessage.trim();

    // 7. Save AI Response
    if (sessionId) {
      await supabase.from('chat_messages').insert([
        { session_id: sessionId, role: 'assistant', content: replyMessage }
      ]);
    }

    res.json({ reply: replyMessage, sessionId: sessionId });

  } catch (err) {
    console.error("SERVER ERROR:", err);
    res.status(500).json({
      reply: "Internal server error. Please try again."
    });
  }
};

exports.getSessions = async (req, res) => {
  try {
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

