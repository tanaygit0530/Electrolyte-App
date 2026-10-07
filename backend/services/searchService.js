/**
 * ------------------------------------------------------------
 * Search Service
 * ------------------------------------------------------------
 * Handles product search using normalized token-based filtering.
 * ------------------------------------------------------------
 */

const { pool } = require("../config/neondb");
const { preprocessSearchText } = require("../utils/searchPreprocessor");
const { parseQuery } = require("../utils/queryParser");
const logger = require("../utils/logger");
const { correctSpelling } = require("../utils/spellCorrector");
const { loadVocabulary } = require("./vocabularyService");

async function searchProducts(userMessage) {
  if (typeof userMessage !== "string" || !userMessage.trim()) {
    return [];
  }

  // Step 1: Normalize user input
  const normalizedText = preprocessSearchText(userMessage);

  logger.debug("[searchPreprocessor] Output:", normalizedText);

  // Step 2: Load vocabulary once and correct spelling before parsing
  await loadVocabulary();
  const correctedText = correctSpelling(normalizedText);

  logger.debug("[spellCorrector] Corrected text:", correctedText);

  // Step 3: Parse corrected query
  const parsedQuery = parseQuery(correctedText);

  logger.debug("[queryParser] Parsed:", parsedQuery);

  // Merge all extracted tokens
  const uniqueTokens = [
    ...new Set([
      ...parsedQuery.models.map((m) => m.toLowerCase()),
      ...parsedQuery.dimensions.map((d) => d.toLowerCase()),
      ...parsedQuery.wattages.map((w) => w.toLowerCase()),
      ...parsedQuery.keywords.map((k) => k.toLowerCase()),
    ]),
  ];

  if (uniqueTokens.length === 0) {
    return [];
  }

  // Build WHERE clause dynamically
  const whereClauses = uniqueTokens.map(
    (_, index) => `normalized_name ILIKE $${index + 1}`
  );

  const params = uniqueTokens.map((token) => `%${token}%`);

  const sql = `
WITH normalized_products AS (

SELECT
    id,
    product_name,
    product_code,
    description,
    product_price,
    stock_quantity,
    location,

    LOWER(
        REPLACE(
            REPLACE(
                REPLACE(product_name,'_',' '),
            '+',' '),
        '-',' ')
    ) AS normalized_name

FROM products

)

SELECT
    id,
    product_name,
    product_code,
    description,
    product_price,
    stock_quantity,
    location

FROM normalized_products

WHERE
    stock_quantity > 0
    AND ${whereClauses.join("\nAND ")}

LIMIT 20;
`;

  logger.debug("\n========== SEARCH DEBUG ==========");
  logger.debug("Tokens:", uniqueTokens);
  logger.debug("Params:", params);
  logger.debug("=================================\n");

  const result = await pool.query(sql, params);

  logger.debug("Rows returned:", result.rows.length);

  return result.rows;
}

module.exports = {
  searchProducts,
};