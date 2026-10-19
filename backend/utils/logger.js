/**
 * Structured / Leveled Logger Utility
 * Provides ISO timestamped, leveled output with request tracing capability.
 */

const isDebug = process.env.DEBUG === 'true' || process.env.NODE_ENV === 'development';

const formatMessage = (level, args) => {
  const timestamp = new Date().toISOString();
  return `[${timestamp}] [${level.toUpperCase()}]`;
};

const logger = {
  info: (...args) => console.log(formatMessage('INFO'), ...args),
  warn: (...args) => console.warn(formatMessage('WARN'), ...args),
  error: (...args) => console.error(formatMessage('ERROR'), ...args),
  debug: (...args) => {
    if (isDebug) {
      console.log(formatMessage('DEBUG'), ...args);
    }
  }
};

module.exports = logger;
