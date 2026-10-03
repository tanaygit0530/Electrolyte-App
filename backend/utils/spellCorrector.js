/**
 * ------------------------------------------------------------
 * Spell Corrector
 * ------------------------------------------------------------
 * Corrects common OCR-like or mistyped search words using the
 * cached vocabulary and Levenshtein distance.
 * ------------------------------------------------------------
 */

const { distance } = require('fastest-levenshtein');
const { getVocabulary } = require('../services/vocabularyService');
const { preprocessSearchText } = require('./searchPreprocessor');

/**
 * Preserve tokens that should never be altered.
 *
 * @param {string} token
 * @returns {boolean}
 */
function shouldKeepToken(token) {
  if (!token) {
    return true;
  }

  // Keep model tokens such as GV3, GV4, GV5
  if (/^gv\d+$/i.test(token)) {
    return true;
  }

  // Keep dimensions such as 1200mm, 1230mm
  if (/^\d+mm$/i.test(token)) {
    return true;
  }

  // Keep wattages such as 35w, 50w
  if (/^\d+w$/i.test(token)) {
    return true;
  }

  // Keep numeric-only tokens and product codes
  if (/^\d+$/.test(token)) {
    return true;
  }

  // Treat any token containing a digit as protected
  if (/\d/.test(token)) {
    return true;
  }

  return false;
}

/**
 * Correct misspelled words according to the cached vocabulary.
 *
 * Algorithm:
 * 1. Split normalized text into words
 * 2. Keep any word already in vocabulary unchanged
 * 3. For unknown words, compare against all vocabulary words with Levenshtein distance
 * 4. Replace only if the best distance is <= 2
 * 5. Never alter protected tokens
 *
 * @param {string} text
 * @returns {string}
 */
function correctSpelling(text) {
  if (typeof text !== 'string') {
    console.log('[spellCorrector] Invalid input received:', text);
    return '';
  }

  const normalizedText = preprocessSearchText(text);

  if (!normalizedText) {
    console.log('[spellCorrector] Empty normalized text.');
    return '';
  }

  const vocabulary = getVocabulary();

  if (!vocabulary || vocabulary.size === 0) {
    console.log('[spellCorrector] Vocabulary not loaded yet. Returning normalized text.');
    return normalizedText;
  }

  const tokens = normalizedText.split(/\s+/).filter(Boolean);
  const correctedTokens = [];

  for (const token of tokens) {
    if (shouldKeepToken(token)) {
      correctedTokens.push(token);
      continue;
    }

    if (vocabulary.has(token)) {
      correctedTokens.push(token);
      continue;
    }

    let closestWord = token;
    let closestDistance = Number.POSITIVE_INFINITY;

    for (const vocabularyWord of vocabulary) {
      const d = distance(token, vocabularyWord);

      if (d < closestDistance) {
        closestDistance = d;
        closestWord = vocabularyWord;
      }
    }

    if (closestDistance <= 2) {
      correctedTokens.push(closestWord);
      console.log(`[spellCorrector] Corrected '${token}' -> '${closestWord}' (distance ${closestDistance})`);
    } else {
      correctedTokens.push(token);
    }
  }

  const correctedText = correctedTokens.join(' ');

  console.log('[spellCorrector] Input:', normalizedText);
  console.log('[spellCorrector] Output:', correctedText);

  return correctedText;
}

module.exports = {
  correctSpelling,
};
