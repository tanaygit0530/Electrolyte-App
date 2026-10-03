/**
 * ------------------------------------------------------------
 * Intent Service
 * ------------------------------------------------------------
 * Lightweight, deterministic intent detection for the chatbot.
 *
 * Responsibilities:
 * - Detect only the explicit support intents
 * - Use regex and keyword heuristics only
 * - Avoid any product-query classification in this module
 * ------------------------------------------------------------
 */

const GREETING_PATTERNS = [
  /^hi\b/i,
  /^hello\b/i,
  /^hey\b/i,
  /^good morning\b/i,
  /^good evening\b/i,
  /^good afternoon\b/i,
  /^greetings\b/i,
];

const THANKS_PATTERNS = [
  /\bthanks\b/i,
  /\bthank you\b/i,
  /\bthx\b/i,
  /\bappreciate it\b/i,
];

const GOODBYE_PATTERNS = [
  /^bye\b/i,
  /^goodbye\b/i,
  /^see you\b/i,
  /^talk to you later\b/i,
  /^take care\b/i,
];

const HELP_PATTERNS = [
  /^help\b/i,
  /\bwhat can you do\b/i,
  /\bhow can you help\b/i,
  /\bneed help\b/i,
];

/**
 * Detect only the explicit conversation intents.
 *
 * Any message that does not match these patterns is treated as
 * a normal search flow candidate and is sent to the search pipeline.
 *
 * @param {string} message
 * @returns {string}
 */
function detectIntent(message) {
  if (typeof message !== 'string') {
    console.log('[intentService] Invalid message type:', typeof message);
    return 'unknown';
  }

  const normalized = message.trim();

  if (!normalized) {
    console.log('[intentService] Empty message provided.');
    return 'unknown';
  }

  const lowerMessage = normalized.toLowerCase();

  if (GREETING_PATTERNS.some((pattern) => pattern.test(lowerMessage))) {
    console.log('[intentService] Detected intent: greeting');
    return 'greeting';
  }

  if (THANKS_PATTERNS.some((pattern) => pattern.test(lowerMessage))) {
    console.log('[intentService] Detected intent: thanks');
    return 'thanks';
  }

  if (GOODBYE_PATTERNS.some((pattern) => pattern.test(lowerMessage))) {
    console.log('[intentService] Detected intent: goodbye');
    return 'goodbye';
  }

  if (HELP_PATTERNS.some((pattern) => pattern.test(lowerMessage))) {
    console.log('[intentService] Detected intent: help');
    return 'help';
  }

  console.log('[intentService] No static intent match. Falling through to search pipeline.');
  return 'unknown';
}

module.exports = {
  detectIntent,
};
