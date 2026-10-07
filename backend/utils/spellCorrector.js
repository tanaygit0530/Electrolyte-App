/**
 * ------------------------------------------------------------
 * Spell Corrector (Optimized)
 * ------------------------------------------------------------
 * Corrects common OCR-like or mistyped search words using length-bucketed
 * vocabulary indexing, memoization, and Levenshtein distance.
 * ------------------------------------------------------------
 */

const { distance } = require('fastest-levenshtein');
const { getVocabulary } = require('../services/vocabularyService');
const { preprocessSearchText } = require('./searchPreprocessor');

// In-memory memoization cache for corrected tokens
const tokenCorrectionCache = new Map();
const MAX_CACHE_SIZE = 3000;

// Length-partitioned buckets of vocabulary words
let cachedVocabRef = null;
let lengthBuckets = new Map();

/**
 * Partition vocabulary into length-indexed buckets for fast distance bounds.
 *
 * @param {Set<string>} vocabulary
 * @returns {Map<number, string[]>}
 */
function buildLengthBuckets(vocabulary) {
  const buckets = new Map();
  for (const word of vocabulary) {
    const len = word.length;
    if (!buckets.has(len)) {
      buckets.set(len, []);
    }
    buckets.get(len).push(word);
  }
  return buckets;
}

/**
 * Preserve tokens that should never be altered.
 *
 * @param {string} token
 * @returns {boolean}
 */
function shouldKeepToken(token) {
  if (!token) return true;

  // Keep model tokens such as GV3, GV4, GV5
  if (/^gv\d+$/i.test(token)) return true;

  // Keep dimensions such as 1200mm, 1230mm
  if (/^\d+mm$/i.test(token)) return true;

  // Keep wattages such as 35w, 50w
  if (/^\d+w$/i.test(token)) return true;

  // Keep numeric-only tokens and product codes
  if (/^\d+$/.test(token)) return true;

  // Treat any token containing a digit as protected
  if (/\d/.test(token)) return true;

  return false;
}

/**
 * Find the closest vocabulary word within edit distance <= 2 using length-bucketed filtering.
 *
 * @param {string} token
 * @param {Set<string>} vocabulary
 * @returns {string}
 */
function findClosestWord(token, vocabulary) {
  if (tokenCorrectionCache.has(token)) {
    return tokenCorrectionCache.get(token);
  }

  // Re-index buckets if the vocabulary cache reference changed
  if (vocabulary !== cachedVocabRef) {
    cachedVocabRef = vocabulary;
    lengthBuckets = buildLengthBuckets(vocabulary);
    tokenCorrectionCache.clear();
  }

  const tokenLen = token.length;
  let closestWord = token;
  let closestDistance = 3; // Only consider distances <= 2

  // An edit distance of <= 2 mathematically requires |len(w) - len(token)| <= 2
  const minLen = Math.max(1, tokenLen - 2);
  const maxLen = tokenLen + 2;

  for (let l = minLen; l <= maxLen; l++) {
    const candidates = lengthBuckets.get(l);
    if (!candidates) continue;

    for (let i = 0; i < candidates.length; i++) {
      const candidate = candidates[i];

      // Quick filter: if token has length > 3 and first letters differ, distance is rarely <= 1
      const d = distance(token, candidate);

      if (d < closestDistance) {
        closestDistance = d;
        closestWord = candidate;
        if (d === 1 && candidate[0] === token[0]) {
          break; // Good match found
        }
      }
    }

    if (closestDistance === 1) break;
  }

  const result = closestDistance <= 2 ? closestWord : token;

  // Cache result with eviction guard
  if (tokenCorrectionCache.size >= MAX_CACHE_SIZE) {
    const firstKey = tokenCorrectionCache.keys().next().value;
    tokenCorrectionCache.delete(firstKey);
  }
  tokenCorrectionCache.set(token, result);

  return result;
}

/**
 * Correct misspelled words according to the cached vocabulary.
 *
 * @param {string} text
 * @returns {string}
 */
function correctSpelling(text) {
  if (typeof text !== 'string') return '';

  const normalizedText = preprocessSearchText(text);
  if (!normalizedText) return '';

  const vocabulary = getVocabulary();
  if (!vocabulary || vocabulary.size === 0) {
    return normalizedText;
  }

  const tokens = normalizedText.split(/\s+/).filter(Boolean);
  const correctedTokens = [];

  for (const token of tokens) {
    if (shouldKeepToken(token) || vocabulary.has(token)) {
      correctedTokens.push(token);
      continue;
    }

    correctedTokens.push(findClosestWord(token, vocabulary));
  }

  return correctedTokens.join(' ');
}

module.exports = {
  correctSpelling,
  findClosestWord,
  buildLengthBuckets,
};
