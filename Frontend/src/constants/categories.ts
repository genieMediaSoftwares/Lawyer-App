/**
 * The Genie Law legal taxonomy.
 *
 * ── Why this is a constant and not a fetch ────────────────────────────────
 *
 * The backend owns this list in `backend/src/config/legalCategories.json`, but
 * **exposes no endpoint for it**. Nothing under `backend/src/routes/` serves
 * categories; the only consumer is `services/ai/aiSmartIntakeService.js`,
 * which uses it server-side to build the extraction prompt and to normalise
 * whatever Gemini answers back onto a real category.
 *
 * So there is no request to make. This is a verbatim mirror of the backend's
 * own file — the same 15 ids, titles, slugs and sub-types, in the same order —
 * which is what §10 asks for when no category endpoint exists: use the
 * categories actually defined in the backend contract.
 *
 * This is **not** mock data. These are the real values the server validates a
 * case's `category` and `subcategory` against; a title invented here would be
 * rejected on submit, and the AI's auto-fill would never match it.
 *
 * ── Keeping it in step ────────────────────────────────────────────────────
 *
 * The backend file is itself a copy of a Dart list, kept honest by
 * `test/legal_categories_sync_test.dart`. This is a third copy, and the right
 * fix is a `GET /api/categories` endpoint that all three read from — reported
 * in the README under "Missing backend support". Until that exists, changing
 * the taxonomy means changing it here too.
 *
 * Verified against backend/src/config/legalCategories.json.
 */

export interface LegalCategory {
  /** Matches the backend id exactly. */
  id: string;
  /** The string stored in `Case.category`. */
  title: string;
  slug: string;
  /**
   * The string stored in `Case.subcategory`.
   *
   * Five per category, and the same five the AI extractor normalises its
   * `subType` answer onto — so a value picked here is one the server already
   * recognises.
   */
  subTypes: readonly string[];
}

export const LEGAL_CATEGORIES: readonly LegalCategory[] = [
  {
    id: 'criminal_law',
    title: 'Criminal Law',
    slug: 'criminal-law',
    subTypes: [
      'FIR Registration',
      'Bail',
      'Theft',
      'Assault',
      'Cheating & Fraud',
    ],
  },
  {
    id: 'family_divorce',
    title: 'Family & Divorce',
    slug: 'family-divorce',
    subTypes: [
      'Divorce',
      'Child Custody',
      'Domestic Violence',
      'Maintenance / Alimony',
      'Marriage Registration',
    ],
  },
  {
    id: 'property_land',
    title: 'Property & Land',
    slug: 'property-land',
    subTypes: [
      'Property Registration',
      'Builder Dispute',
      'Property Partition',
      'Land Encroachment',
      'RERA Complaint',
    ],
  },
  {
    id: 'civil_cases',
    title: 'Civil Cases',
    slug: 'civil-cases',
    subTypes: [
      'Money Recovery',
      'Civil Suit',
      'Property Injunction',
      'Contract Dispute',
      'Recovery of Possession',
    ],
  },
  {
    id: 'cyber_crime',
    title: 'Cyber Crime',
    slug: 'cyber-crime',
    subTypes: [
      'Online Scam',
      'UPI Fraud',
      'Social Media Harassment',
      'Identity Theft',
      'Hacking',
    ],
  },
  {
    id: 'gst_taxation',
    title: 'GST & Taxation',
    slug: 'gst-taxation',
    subTypes: [
      'GST Registration',
      'GST Notice',
      'Income Tax Notice',
      'Tax Filing',
      'Tax Consultation',
    ],
  },
  {
    id: 'employment_labour',
    title: 'Employment & Labour',
    slug: 'employment-labour',
    subTypes: [
      'Salary Issues',
      'Wrongful Termination',
      'Workplace Harassment',
      'Labour Dispute',
      'Employment Contract',
    ],
  },
  {
    id: 'consumer_complaints',
    title: 'Consumer Complaints',
    slug: 'consumer-complaints',
    subTypes: [
      'Refund Issue',
      'Defective Product',
      'Online Shopping Fraud',
      'Service Complaint',
      'Warranty Claim',
    ],
  },
  {
    id: 'banking_financial',
    title: 'Banking & Financial',
    slug: 'banking-financial',
    subTypes: [
      'Loan Dispute',
      'Bank Fraud',
      'Credit Card Dispute',
      'EMI Issues',
      'Cheque Bounce',
    ],
  },
  {
    id: 'business_corporate',
    title: 'Business & Corporate',
    slug: 'business-corporate',
    subTypes: [
      'Company Registration',
      'Partnership Dispute',
      'Contract Review',
      'Trademark',
      'Startup Legal Help',
    ],
  },
  {
    id: 'documentation',
    title: 'Documentation',
    slug: 'documentation',
    subTypes: [
      'Legal Notice',
      'Rental Agreement',
      'Affidavit',
      'Power of Attorney',
      'Will Preparation',
    ],
  },
  {
    id: 'motor_accident_claims',
    title: 'Motor Accident Claims',
    slug: 'motor-accident-claims',
    subTypes: [
      'Accident Compensation',
      'Insurance Claim',
      'Vehicle Damage',
      'Hit & Run',
      'Injury Claim',
    ],
  },
  {
    id: 'medical_negligence',
    title: 'Medical Negligence',
    slug: 'medical-negligence',
    subTypes: [
      'Doctor Negligence',
      'Hospital Liability',
      'Wrong Diagnosis',
      'Surgical Error',
      'Treatment Delay',
    ],
  },
  {
    id: 'education_law',
    title: 'Education Law',
    slug: 'education-law',
    subTypes: [
      'Admission Dispute',
      'Fee Dispute',
      'Degree Delay',
      'Harassment Case',
      'Exam Malpractice',
    ],
  },
  {
    id: 'immigration_visa',
    title: 'Immigration & Visa',
    slug: 'immigration-visa',
    subTypes: [
      'Student Visa',
      'Work Permit',
      'PR Application',
      'Citizenship',
      'Deportation Case',
    ],
  },
] as const;

/**
 * The eight shown on the Home dashboard before "See All", and the order the
 * Post Case category step lists them in.
 *
 * Chosen to match the order in the visual reference (§10); the remaining seven
 * are one tap away rather than hidden.
 */
export const POPULAR_CATEGORY_IDS: readonly string[] = [
  'civil_cases',
  'criminal_law',
  'family_divorce',
  'property_land',
  'cyber_crime',
  'gst_taxation',
  'employment_labour',
  'consumer_complaints',
];

export const popularCategories = (): LegalCategory[] =>
  POPULAR_CATEGORY_IDS.map(
    id => LEGAL_CATEGORIES.find(c => c.id === id),
  ).filter((c): c is LegalCategory => Boolean(c));

export const categoryByTitle = (title: string): LegalCategory | undefined =>
  LEGAL_CATEGORIES.find(
    c => c.title.toLowerCase() === String(title || '').toLowerCase(),
  );

export const categoryById = (id: string): LegalCategory | undefined =>
  LEGAL_CATEGORIES.find(c => c.id === id);

/**
 * Every category, ordered so the eight "popular" ones lead.
 *
 * The Post Case category step shows the whole taxonomy — a client whose matter
 * is an immigration one must be able to file it — but in the same order the
 * rest of the app presents categories, rather than the raw file order.
 */
export const orderedCategories = (): LegalCategory[] => {
  const popular = popularCategories();
  const rest = LEGAL_CATEGORIES.filter(
    c => !POPULAR_CATEGORY_IDS.includes(c.id),
  );
  return [...popular, ...rest];
};
