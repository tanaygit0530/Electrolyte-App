/**
 * ------------------------------------------------------------
 * Query Parser
 * ------------------------------------------------------------
 * Extracts structured information from a normalized search query.
 *
 * Responsibilities:
 * - Extract model numbers (GV3, GV4, GV5, etc.)
 * - Extract dimensions (1200mm, 1230mm, etc.)
 * - Extract wattage (35W, 50W, etc.)
 * - Keep remaining words as searchable keywords
 *
 * Input:
 * "motor housing gv5 1200mm 35w"
 *
 * Output:
 * {
 *   models: ["GV5"],
 *   dimensions: ["1200MM"],
 *   wattages: ["35W"],
 *   keywords: ["motor", "housing"]
 * }
 * ------------------------------------------------------------
 */

function parseQuery(text) {
  if (typeof text !== "string" || !text.trim()) {
    console.log('[queryParser] Empty or invalid input received:', text);
    return {
      models: [],
      dimensions: [],
      wattages: [],
      keywords: [],
    };
  }

  const tokens = text.split(" ").filter(Boolean);

  const models = [];
  const dimensions = [];
  const wattages = [];
  const keywords = [];

  for (const token of tokens) {
    const upperToken = token.toUpperCase();

    // Match GV models (GV3, GV4, GV5...)
    if (/^GV\d+$/i.test(token)) {
      models.push(upperToken);
      continue;
    }

    // Match dimensions (1200mm, 1230mm...)
    if (/^\d+MM$/i.test(upperToken)) {
      dimensions.push(upperToken);
      continue;
    }

    // Match wattage (35W, 50W...)
    if (/^\d+W$/i.test(upperToken)) {
      wattages.push(upperToken);
      continue;
    }

    keywords.push(token.toLowerCase());
  }

  const parsedResult = {
    models: [...new Set(models)],
    dimensions: [...new Set(dimensions)],
    wattages: [...new Set(wattages)],
    keywords: [...new Set(keywords)],
  };

  console.log('[queryParser] Input:', text);
  console.log('[queryParser] Parsed result:', parsedResult);

  return parsedResult;
}

module.exports = {
  parseQuery,
};

/*
=========================================================

Examples

parseQuery("housing gv3")

{
  models: ["GV3"],
  dimensions: [],
  wattages: [],
  keywords: ["housing"]
}

---------------------------------------------------------

parseQuery("motor housing gv5 1200mm")

{
  models:["GV5"],
  dimensions:["1200MM"],
  wattages:[],
  keywords:["motor","housing"]
}

---------------------------------------------------------

parseQuery("35w regulator gv4")

{
  models:["GV4"],
  dimensions:[],
  wattages:["35W"],
  keywords:["regulator"]
}

---------------------------------------------------------

parseQuery("renessa black housing gv5")

{
  models:["GV5"],
  dimensions:[],
  wattages:[],
  keywords:["renessa","black","housing"]
}

=========================================================
*/