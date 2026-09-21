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

/**
 * Keyword signals per category, used ONLY as a last resort by
 * `classifyByKeywords` below.
 *
 * Each entry is [regex, weight]. Weights let a decisive term outrank several
 * incidental ones: a divorce petition that discusses property at length should
 * land in Family & Divorce, and "divorce" carrying more weight than "property"
 * is what makes that happen without any understanding of the text.
 */
const CATEGORY_SIGNALS = {
  family_divorce: [
    [/\b(divorce|talaq|khula)\b/i, 6],
    [/\b(domestic violence|dowry|498a|cruelty by husband|beating me|abus(e|ing|ed) me)\b/i, 6],
    [/\b(child custody|custody of (the |my )?child|guardianship)\b/i, 5],
    [/\b(maintenance|alimony|stridhan)\b/i, 4],
    [/\b(marriage registration|marital|husband|wife|spouse|in-laws)\b/i, 2],
  ],
  criminal_law: [
    [/\b(fir|f\.i\.r|first information report)\b/i, 5],
    [/\b(bail|anticipatory bail|remand|chargesheet|charge sheet)\b/i, 5],
    [/\b(theft|robbery|burglary|assault|kidnap|murder|extortion)\b/i, 5],
    [/\b(ipc|bns|crpc|police station|accused|complainant)\b/i, 3],
    [/\b(cheating|forgery|criminal breach of trust)\b/i, 3],
  ],
  cyber_crime: [
    [/\b(upi fraud|online scam|phishing|otp fraud|hacked|hacking|cyber ?crime)\b/i, 6],
    [/\b(identity theft|fake profile|social media harassment|morph(ed|ing)|sextortion)\b/i, 5],
    [/\b(cyber ?cell|1930|ncrp)\b/i, 4],
  ],
  property_land: [
    [/\b(land encroachment|encroach(ed|ing)?|boundary dispute|partition of property)\b/i, 5],
    [/\b(rera|builder delay|builder dispute|possession of (the )?flat)\b/i, 5],
    [/\b(sale deed|title deed|mutation|patta|survey number|registry of (the )?property)\b/i, 4],
    [/\b(property registration|landlord|tenant|eviction|lease of (the )?premises)\b/i, 2],
  ],
  civil_cases: [
    [/\b(money recovery|recovery suit|outstanding (dues|amount|payment))\b/i, 4],
    [/\b(breach of contract|contract dispute|specific performance|injunction)\b/i, 4],
    [/\b(civil suit|o\.s\. no|plaint|decree)\b/i, 3],
  ],
  employment_labour: [
    [/\b(wrongful termination|terminated|dismissal|resignation forced)\b/i, 5],
    [/\b(salary|unpaid wages|full and final|gratuity|pf|provident fund)\b/i, 4],
    [/\b(workplace harassment|posh|labour (court|dispute)|employment contract|notice period)\b/i, 4],
  ],
  consumer_complaints: [
    [/\b(defective|refund|replacement|warranty|consumer (forum|court|commission))\b/i, 5],
    [/\b(online shopping|e-?commerce|deficiency in service)\b/i, 4],
  ],
  banking_financial: [
    [/\b(cheque bounce|cheque dishonour|dishonour of cheque|section 138|138 ni act)\b/i, 6],
    [/\b(loan dispute|emi|credit card|bank fraud|recovery agent|nbfc)\b/i, 4],
  ],
  motor_accident_claims: [
    [/\b(motor accident|road accident|hit and run|mact|rash driving)\b/i, 6],
    [/\b(insurance claim|vehicle damage|injury compensation)\b/i, 3],
  ],
  medical_negligence: [
    [/\b(medical negligence|wrong diagnosis|surgical error|hospital liability|malpractice)\b/i, 6],
  ],
  gst_taxation: [
    [/\b(gst|income tax|tds|it notice|assessment order|tax filing)\b/i, 5],
  ],
  business_corporate: [
    [/\b(shareholder|partnership (deed|dispute)|company registration|nclt|trademark|copyright|patent)\b/i, 5],
  ],
  education_law: [
    [/\b(admission dispute|fee (refund|dispute)|degree (delay|withheld)|exam malpractice|ragging)\b/i, 5],
  ],
  immigration_visa: [
    [/\b(visa|immigration|work permit|deportation|citizenship|permanent residen)\b/i, 5],
  ],
  documentation: [
    [/\b(legal notice|rental agreement|affidavit|power of attorney|will preparation|drafting)\b/i, 3],
  ],
};

/**
 * Best-effort category from raw text, by explicit keyword weight.
 *
 * This is NOT a substitute for the model's judgement and is never used in its
 * place — `resolveCategory` maps what the model actually said. This runs only
 * when the model gave no usable category at all (it failed, or it answered with
 * something that matched nothing), and its answer is always flagged for the
 * client to confirm.
 *
 * It exists because `resolveCategory` is a name normaliser: handed free prose
 * it matches on incidental words, and put "someone hacked my UPI and took
 * money" under Civil Cases / Money Recovery. A wrong category filed silently is
 * worse than none, so this returns null unless a real signal fires.
 *
 * @returns {{category: string, categoryId: string, subType: null, score: number}|null}
 */
const classifyByKeywords = (text) => {
  const haystack = String(text || "");
  if (haystack.trim().length < 12) return null;

  let bestId = null;
  let bestScore = 0;

  for (const [categoryId, signals] of Object.entries(CATEGORY_SIGNALS)) {
    let score = 0;
    for (const [pattern, weight] of signals) {
      if (pattern.test(haystack)) score += weight;
    }
    if (score > bestScore) {
      bestScore = score;
      bestId = categoryId;
    }
  }

  // One incidental keyword is not a classification.
  if (!bestId || bestScore < 4) return null;

  const category = byId.get(bestId);
  if (!category) return null;

  return {
    category: category.title,
    categoryId: category.id,
    subType: null,
    score: bestScore,
  };
};

module.exports = {
  categories,
  titles,
  allSubTypes,
  resolveCategory,
  classifyByKeywords,
  promptTaxonomy,
  isCriminalLike,
  CRIMINAL_LIKE_CATEGORY_IDS,
};
