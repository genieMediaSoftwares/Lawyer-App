const categories = require("./legalCategories.json");

/**
 * The app's legal taxonomy: 15 categories, 5 sub-types each.
 *
 * `legalCategories.json` is a copy of the Dart list in
 * `lib/models/category_item.dart` (which owns the icons and so has to stay
 * Dart). `test/legal_categories_sync_test.dart` fails if the two ever diverge.
 *
 * This module exists because the AI prompt used to hardcode a *different*
 * 12-item list — only "Criminal Law" and "Documentation" overlapped with the
 * app's 15, so roughly 10 in 12 extractions returned a category the Post Case
 * form could not select and silently dropped. Generating the prompt from the
 * real taxonomy, and normalising the model's answer back onto it, is what makes
 * auto-fill reliable.
 */

const titles = categories.map((c) => c.title);

/** Every sub-type, flattened, for validation. */
const allSubTypes = categories.flatMap((c) => c.subTypes);

/** Reduce to letters+digits so "Property & Land" ≈ "property land". */
const normaliseKey = (value) =>
  String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();

/**
 * Words too generic to carry meaning in a fuzzy match.
 *
 * Without this, "General Legal" matched "Startup Legal Help" on the single word
 * "legal" and confidently mis-filed the case under Business & Corporate. A
 * catch-all answer must resolve to null so the form leaves the dropdown alone.
 */
const GENERIC_WORDS = new Set([
  "legal",
  "law",
  "laws",
  "general",
  "other",
  "others",
  "misc",
  "miscellaneous",
  "matter",
  "matters",
  "issue",
  "issues",
  "case",
  "cases",
  "help",
  "advice",
]);

/** Significant words only — used for both fuzzy passes below. */
const significantWords = (key) =>
  key.split(" ").filter((w) => w.length > 3 && !GENERIC_WORDS.has(w));

const byNormalisedTitle = new Map(
  categories.map((c) => [normaliseKey(c.title), c])
);
const bySlug = new Map(categories.map((c) => [c.slug, c]));
const byId = new Map(categories.map((c) => [c.id, c]));

/** Sub-type -> owning category, so a sub-type alone can imply the category. */
const bySubType = new Map();
for (const category of categories) {
  for (const subType of category.subTypes) {
    bySubType.set(normaliseKey(subType), { category, subType });
  }
}

/**
 * Categories where an FIR number, police station and bail details are
 * meaningful. The Post Case form reveals that field group only for these, so
 * the extractor should not bother asking for them otherwise.
 */
const CRIMINAL_LIKE_CATEGORY_IDS = [
  "criminal_law",
  "cyber_crime",
  "motor_accident_claims",
];

const isCriminalLike = (categoryTitle) => {
  const match = byNormalisedTitle.get(normaliseKey(categoryTitle));
  return match ? CRIMINAL_LIKE_CATEGORY_IDS.includes(match.id) : false;
};

/**
 * Maps a free-form model answer onto an exact app category + sub-type.
 *
 * Returns `{ category, subType }` using the app's exact strings, or nulls when
 * nothing plausible matched — deliberately null rather than a guess, so the
 * form leaves the dropdown untouched instead of selecting something wrong.
 */
const resolveCategory = (rawCategory, rawSubType) => {
  let category = null;

  const catKey = normaliseKey(rawCategory);
  if (catKey) {
    category =
      byNormalisedTitle.get(catKey) ||
      bySlug.get(String(rawCategory).trim()) ||
      byId.get(String(rawCategory).trim()) ||
      null;

    // Tolerate word-order and wording drift ("Labour & Employment" for
    // "Employment & Labour", "Property Law" for "Property & Land") by matching
    // on shared significant words.
    if (!category) {
      const words = significantWords(catKey);
      let best = null;
      let bestScore = 0;
      for (const c of categories) {
        const target = normaliseKey(c.title).split(" ");
        const score = words.filter((w) => target.includes(w)).length;
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }
      if (bestScore > 0) category = best;
    }
  }

  // A recognised sub-type is stronger evidence than a fuzzy category, and can
  // supply the category on its own.
  let subType = null;
  const subKey = normaliseKey(rawSubType);
  if (subKey && bySubType.has(subKey)) {
    const hit = bySubType.get(subKey);
    subType = hit.subType;
    if (!category) category = hit.category;
  }

  // Some older prompt values were sub-types wearing a category's clothes —
  // "Rental & Tenancy" is really Documentation/Rental Agreement, and
  // "Cheque Bounce & Finance" is Banking & Financial/Cheque Bounce. If the
  // category string failed to resolve, try reading it as a sub-type instead.
  if (!category && catKey) {
    const words = significantWords(catKey);
    let best = null;
    let bestScore = 0;
    for (const [key, hit] of bySubType) {
      const target = key.split(" ");
      const score = words.filter((w) => target.includes(w)).length;
      if (score > bestScore) {
        bestScore = score;
        best = hit;
      }
    }
    if (best && bestScore > 0) {
      category = best.category;
      subType = subType ?? best.subType;
    }
  }

  // Only keep a sub-type that actually belongs to the resolved category.
  if (category && subType && !category.subTypes.includes(subType)) {
    subType = null;
  }

  return {
    category: category ? category.title : null,
    categoryId: category ? category.id : null,
    subType,
  };
};

/** The category/sub-type menu, rendered for the extraction prompt. */
const promptTaxonomy = () =>
  categories
    .map((c) => `- ${c.title}: ${c.subTypes.join(" | ")}`)
    .join("\n");

module.exports = {
  categories,
  titles,
  allSubTypes,
  resolveCategory,
  promptTaxonomy,
  isCriminalLike,
  CRIMINAL_LIKE_CATEGORY_IDS,
};
