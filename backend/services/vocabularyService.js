/**
 * ------------------------------------------------------------
 * Vocabulary Service
 * ------------------------------------------------------------
 * Builds and caches a searchable vocabulary from the products table.
 *
 * Responsibilities:
 * - Load all product_name values from PostgreSQL
 * - Normalize each product name using the same preprocessing logic
 * - Split normalized names into words
 * - Build a unique Set of searchable words
 * - Cache the vocabulary in memory so it is reused across requests
 * ------------------------------------------------------------
 */

const { pool } = require('../config/neondb');
const { preprocessSearchText } = require('../utils/searchPreprocessor');

let vocabularyCache = null;
let vocabularyPromise = null;

/**
 * Load the vocabulary from the products table exactly once.
 * Subsequent calls reuse the cached in-memory Set.
 *
 * @returns {Promise<Set<string>>}
 */
async function loadVocabulary() {
  if (vocabularyCache) {
    console.log('[vocabularyService] Reusing cached vocabulary.');
    return vocabularyCache;
  }

  if (!vocabularyPromise) {
    vocabularyPromise = (async () => {
      console.log('[vocabularyService] Loading vocabulary from products table...');

      const result = await pool.query(
        'SELECT product_name FROM products WHERE product_name IS NOT NULL'
      );

      const vocabulary = new Set();

      for (const row of result.rows) {
        const normalizedName = preprocessSearchText(row.product_name);

        if (!normalizedName) {
          continue;
        }

        const tokens = normalizedName.split(/\s+/).filter(Boolean);

        for (const token of tokens) {
          vocabulary.add(token);
        }
      }

      vocabularyCache = vocabulary;

      console.log(
        `[vocabularyService] Vocabulary loaded with ${vocabulary.size} unique words.`
      );

      return vocabulary;
    })().catch((error) => {
      vocabularyPromise = null;
      throw error;
    });
  }

  return vocabularyPromise;
}

/**
 * Return the cached vocabulary if it has already been loaded.
 *
 * @returns {Set<string>|null}
 */
function getVocabulary() {
  return vocabularyCache;
}

module.exports = {
  loadVocabulary,
  getVocabulary,
};
