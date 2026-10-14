/**
 * Structured / Leveled Logger Utility
 * Prevents log spam and sensitive user query leakage in production environments.
 */

const isDebug = process.env.DEBUG_SEARCH === 'true' || process.env.NODE_ENV === 'development';

const logger = {
  info: (...args) => console.log(...args),
  warn: (...args) => console.warn(...args),
  error: (...args) => console.error(...args),
  debug: (...args) => {
    if (isDebug) {
      console.log(...args);
    }
  }
};

module.exports = logger;
