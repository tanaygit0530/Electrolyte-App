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

    const userMessage = req.body.message;

    if (!userMessage) {
      return res.status(400).json({
        reply: "Message cannot be empty."
      });
    }

    console.log("User Message:", userMessage);

    // 2. Initialize Gemini (using @google/genai and gemini-flash-latest)
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

    let extracted = {
      part_code: "",
      part_name: "",
      model: ""
    };

    // 3. Safe JSON Parsing
    try {
      let responseText = result.text;
      console.log("Gemini Raw Response:", responseText);

      // Clean potential markdown blocks
      if (responseText.includes("```json")) {
        responseText = responseText.split("```json")[1].split("```")[0].trim();
      } else if (responseText.includes("```")) {
        responseText = responseText.split("```")[1].split("```")[0].trim();
      }
      
      extracted = JSON.parse(responseText);
      console.log("Parsed Intent:", extracted);
    } catch (jsonError) {
      console.log("JSON parse error:", jsonError, "Raw text:", result.text);
      return res.json({
        reply: "Sorry, I couldn't understand that. Please try to specify a part name or code."
      });
    }

    // 4. Query Supabase
    let query = supabase.from("spare_parts").select("*");

    if (extracted.part_code) {
      query = query.eq('part_code', extracted.part_code);
    } else if (extracted.part_name) {
      query = query.ilike('part_name', `%${extracted.part_name}%`);
    } else if (extracted.model) {
      query = query.ilike('model', `%${extracted.model}%`);
    } else {
      return res.json({
        reply: "Please mention part code, name, or model so I can help you better."
      });
    }

    const { data: parts, error } = await query;

    if (error) {
      console.log("Supabase error:", error);
      return res.status(500).json({
        reply: "Database error occurred while checking inventory."
      });
    }

    // 5. Build Reply Message
    if (!parts || parts.length === 0) {
      return res.json({
        reply: "No matching spare part found in our database."
      });
    }

    let replyMessage = "";
    parts.forEach(part => {
      replyMessage += `
Part Name: ${part.part_name}
Model: ${part.model}
Price: ₹${part.price}
Stock: ${part.stock_quantity}
Status: ${part.status}
`;
    });

    console.log("Sending successful reply");
    res.json({ reply: replyMessage.trim() });

  } catch (err) {
    console.error("SERVER ERROR:", err);
    res.status(500).json({
      reply: "Internal server error. Please try again."
    });
  }
};
