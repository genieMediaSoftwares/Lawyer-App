import type { CaseStatus, LegalCase } from '../types/domain';

export interface ProgressStep {
  index: number;
  title: string;
  label: string;
}

export const PROGRESS_STEPS: ProgressStep[] = [
  { index: 1, title: 'Posted', label: 'Case Posted' },
  { index: 2, title: 'Pending', label: 'Lawyer Pending' },
  { index: 3, title: 'Accepted', label: 'Lawyer Accepted' },
  { index: 4, title: 'Consultation', label: 'Consultation' },
  { index: 5, title: 'Resolved', label: 'Resolved' },
];

/**
 * Maps backend case status and case fields to the 5-step progress stepper.
 */
export const getCaseProgressStep = (
  status: CaseStatus,
  caseItem?: LegalCase,
): { currentStep: number; isRejected: boolean; activeLabel: string } => {
  if (status === 'Rejected') {
    return { currentStep: 2, isRejected: true, activeLabel: 'Request Declined' };
  }
  if (status === 'Closed') {
    return { currentStep: 5, isRejected: false, activeLabel: 'Resolved' };
  }
  if (
    status === 'In Progress' ||
    (caseItem &&
      (caseItem.consultationDate ||
        (caseItem.hearings && caseItem.hearings.length > 0)))
  ) {
    return { currentStep: 4, isRejected: false, activeLabel: 'Consultation / In Progress' };
  }
  if (
    status === 'Accepted' ||
    (caseItem && (caseItem.assignedLawyer || caseItem.acceptedAt))
  ) {
    return { currentStep: 3, isRejected: false, activeLabel: 'Lawyer Selected & Accepted' };
  }
  if (
    status === 'Awaiting Lawyer Acceptance' ||
    status === 'Pending Lawyer Response' ||
    status === 'Interested'
  ) {
    return { currentStep: 2, isRejected: false, activeLabel: 'Lawyer Verification / Pending' };
  }
  return { currentStep: 1, isRejected: false, activeLabel: 'Posted / Awaiting Lawyer' };
};

/**
 * Color theme for case status badges.
 */
export const getStatusBadgeTheme = (
  status: CaseStatus,
): { bg: string; text: string; border: string } => {
  switch (status) {
    case 'Accepted':
    case 'In Progress':
      return { bg: 'bg-emerald-500/15', text: 'text-emerald-400', border: 'border-emerald-500/30' };
    case 'Closed':
      return { bg: 'bg-blue-500/15', text: 'text-blue-400', border: 'border-blue-500/30' };
    case 'Rejected':
      return { bg: 'bg-red-500/15', text: 'text-red-400', border: 'border-red-500/30' };
    case 'Awaiting Lawyer Acceptance':
    case 'Pending Lawyer Response':
    case 'Interested':
      return { bg: 'bg-amber-500/15', text: 'text-amber-400', border: 'border-amber-500/30' };
    case 'Submitted':
    default:
      return { bg: 'bg-gold/15', text: 'text-gold', border: 'border-gold/30' };
  }
};

/**
 * Extracts assigned or selected lawyer information from a LegalCase object.
 */
export const getAssignedLawyerData = (item: LegalCase) => {
  const userObj =
    typeof item.assignedLawyer === 'object' && item.assignedLawyer
      ? item.assignedLawyer
      : typeof item.selectedLawyer === 'object' && item.selectedLawyer
      ? item.selectedLawyer
      : null;

  const profileObj = item.assignedLawyerProfile || item.selectedLawyerProfile || null;

  if (!userObj) {
    return null;
  }

  return {
    id: userObj._id,
    fullName: userObj.fullName,
    email: userObj.email,
    mobile: userObj.mobile,
    profileImage: userObj.profileImage,
    specialization:
      profileObj?.specialization || profileObj?.practiceAreas?.[0] || 'Advocate',
    experienceYears: profileObj?.experience,
    rating: profileObj?.rating ?? 4.8,
  };
};
