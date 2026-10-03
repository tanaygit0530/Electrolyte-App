/**
 * ------------------------------------------------------------
 * LLM Service
 * ------------------------------------------------------------
 * Thin wrapper around the official Groq SDK.
 *
 * Responsibilities:
 * - Generate concise replies for product search results
 * - Generate a plain conversational reply for general chat requests
 * - Never invent product data or inventory information
 * ------------------------------------------------------------
 */

const { Groq } = require('groq-sdk');
const { responsePrompt } = require('../prompts/responsePrompt');
require('dotenv').config();

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY,
});

/**
 * Build a structured prompt for the search response.
 *
 * @param {string} userMessage
 * @param {Array<object>} products
 * @returns {string}
 */
function buildSearchPrompt(userMessage, products) {
  const productSummary = products.length
    ? products
        .map((product) => (
          `- ${product.product_name || 'Unknown'} | ${product.product_code || 'N/A'} | ${product.description || 'N/A'} | stock ${product.stock_quantity ?? 'N/A'} | location ${product.location || 'N/A'}`
        ))
        .join('\n')
    : 'No products were supplied.';

  return `${responsePrompt}\n\nUser question: ${userMessage}\n\nBackend products:\n${productSummary}`;
}

/**
 * Generate a reply for product search queries using the LLM.
 *
 * The backend remains the single source of truth.
 * The model is only asked to summarize supplied product data.
 *
 * @param {string} userMessage
 * @param {Array<object>} products
 * @returns {Promise<string>}
 */
async function generateSearchReply(userMessage, products) {
  if (typeof userMessage !== 'string' || !userMessage.trim()) {
    console.log('[llmService] Missing userMessage for search reply.');
    return 'No matching spare parts found.';
  }

  try {
    const completion = await groq.chat.completions.create({
      model: process.env.GROQ_MODEL || 'llama-3.3-70b-versatile',
      messages: [
        {
          role: 'system',
          content: responsePrompt,
        },
        {
          role: 'user',
          content: buildSearchPrompt(userMessage, products),
        },
      ],
      temperature: 0.2,
      max_tokens: 220,
    });

    const reply = completion.choices?.[0]?.message?.content?.trim();

    if (!reply) {
      throw new Error('Empty Groq response.');
    }

    console.log('[llmService] Generated search reply successfully.');
    return reply;
  } catch (error) {
    console.error('[llmService] Groq search reply failed:', error?.message || error);
    return products.length
      ? `Found ${products.length} matching component(s).`
      : 'No matching spare parts found.';
  }
}

/**
 * Generate a general conversational reply when the user is not searching products.
 *
 * @param {string} userMessage
 * @returns {Promise<string>}
 */
async function generateGeneralReply(userMessage) {
  if (typeof userMessage !== 'string' || !userMessage.trim()) {
    console.log('[llmService] Missing userMessage for general reply.');
    return 'How can I help you today?';
  }

  try {
    const completion = await groq.chat.completions.create({
      model: process.env.GROQ_MODEL || 'llama-3.3-70b-versatile',
      messages: [
        {
          role: 'system',
          content: responsePrompt,
        },
        {
          role: 'user',
          content: `You are replying to a normal conversation request. Keep it concise and friendly. User message: ${userMessage}`,
        },
      ],
      temperature: 0.3,
      max_tokens: 160,
    });

    const reply = completion.choices?.[0]?.message?.content?.trim();

    if (!reply) {
      throw new Error('Empty Groq response.');
    }

    console.log('[llmService] Generated general reply successfully.');
    return reply;
  } catch (error) {
    console.error('[llmService] Groq general reply failed:', error?.message || error);
    return 'How can I help you today?';
  }
}

module.exports = {
  generateSearchReply,
  generateGeneralReply,
};
