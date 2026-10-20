/**
 * SQL Utility functions for secure query building and pattern escaping.
 */

/**
 * Escapes characters that have special wildcard meaning in SQL LIKE / ILIKE queries:
 * % (matches any sequence of zero or more characters)
 * _ (matches any single character)
 * \ (escape character)
 *
 * @param {string} str - Raw user input string
 * @returns {string} - Escaped string safe for insertion into LIKE / ILIKE patterns
 */
function escapeLikePattern(str) {
  if (str === null || str === undefined) return '';
  return String(str).replace(/([%_\\])/g, '\\$1');
}

module.exports = {
  escapeLikePattern
};
