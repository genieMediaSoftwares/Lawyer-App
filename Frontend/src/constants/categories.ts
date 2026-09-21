export interface LegalCategory {
  id: string;
  title: string;
  slug: string;
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

export const orderedCategories = (): LegalCategory[] => {
  const popular = popularCategories();
  const rest = LEGAL_CATEGORIES.filter(
    c => !POPULAR_CATEGORY_IDS.includes(c.id),
  );
  return [...popular, ...rest];
};
