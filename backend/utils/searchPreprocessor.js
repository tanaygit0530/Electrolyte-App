/**
 * ------------------------------------------------------------
 * Search Preprocessor
 * ------------------------------------------------------------
 * Normalizes user search text before parsing or searching.
 *
 * Responsibilities:
 * - Convert to lowercase
 * - Replace _, + and - with spaces
 * - Remove punctuation
 * - Collapse multiple spaces
 * - Trim whitespace
 *
 * Example:
 *
 * Input:
 * "Motor_Housing_Black_1200mm_Renesa+_GV5"
 *
 * Output:
 * "motor housing black 1200mm renesa gv5"
 * ------------------------------------------------------------
 */

function preprocessSearchText(text) {
  // Handle invalid input
  if (typeof text !== "string") {
    console.log('[searchPreprocessor] Invalid input received:', text);
    return "";
  }

  const normalizedText = text
    // Convert to lowercase
    .toLowerCase()

    // Replace separators with spaces
    .replace(/[_+-]/g, " ")

    // Remove all punctuation except letters, numbers and spaces
    .replace(/[^a-z0-9.\s]/g, "")

    // Collapse multiple spaces
    .replace(/\s+/g, " ")

    // Remove leading/trailing spaces
    .trim();

  console.log('[searchPreprocessor] Input:', text);
  console.log('[searchPreprocessor] Output:', normalizedText);

  return normalizedText;
}

module.exports = {
  preprocessSearchText,
};

/*
======================================================
Example Usage

preprocessSearchText(
"Motor_Housing_Black_1200mm_Renesa+_GV5"
);
// "motor housing black 1200mm renesa gv5"

preprocessSearchText(
"  GV5    PCB  "
);
// "gv5 pcb"

preprocessSearchText(
"Motor-Housing (Black)"
);
// "motor housing black"

preprocessSearchText(
"Renesa+_1200mm"
);
// "renesa 1200mm"

preprocessSearchText(null);
// ""

======================================================
*/