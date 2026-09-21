import { colors } from '../theme';
import type { CaseStatus, LegalCase } from '../types/domain';

/**
 * Case presentation rules.
 *
 * Nothing here invents a status. The eight values are the enum on
 * backend/src/models/Case.js; this module only decides how each one is
 * grouped, coloured and worded.
 */

/**
 * The three tabs on My Cases, and which backend statuses each contains.
 *
 * "All": Shows all cases created by the client.
 * "In Progress": Shows ONLY cases accepted by a lawyer (Accepted, In Progress, or assigned lawyer).
 * "Closed": Shows Closed or Rejected cases.
 */
export const CASE_TABS = ['All', 'In Progress', 'Closed'] as const;
export type CaseTab = (typeof CASE_TABS)[number];

const ACCEPTED_IN_PROGRESS_STATUSES: readonly CaseStatus[] = ['Accepted', 'In Progress'];
const CLOSED_STATUSES: readonly CaseStatus[] = ['Closed', 'Rejected'];

export const matchesTab = (item: LegalCase | CaseStatus, tab: CaseTab): boolean => {
  if (tab === 'All') {
    return true;
  }
  if (typeof item === 'string') {
    if (tab === 'In Progress') {
      return ACCEPTED_IN_PROGRESS_STATUSES.includes(item);
    }
    return CLOSED_STATUSES.includes(item);
  }
  if (tab === 'In Progress') {
    if (item.status === 'Closed' || item.status === 'Rejected') {
      return false;
    }
    return (
      ACCEPTED_IN_PROGRESS_STATUSES.includes(item.status) ||
      Boolean(item.assignedLawyer) ||
      Boolean(item.acceptedAt)
    );
  }
  return CLOSED_STATUSES.includes(item.status);
};

/**
 * The colour a status badge takes.
 *
 * Semantic, not decorative: green for a live engagement, gold for anything
 * waiting on someone, muted for finished, red for refused. Gold is reserved
 * for "your attention or a lawyer's is required", which is what makes it
 * meaningful when it appears.
 */
export const statusColor = (status: CaseStatus): string => {
  switch (status) {
    case 'In Progress':
      return colors.success;
    case 'Accepted':
    case 'Interested':
      return colors.info;
    case 'Submitted':
    case 'Awaiting Lawyer Acceptance':
    case 'Pending Lawyer Response':
      return colors.gold;
    case 'Rejected':
      return colors.error;
    case 'Closed':
      return colors.textMuted;
    default:
      return colors.textSecondary;
  }
};

/**
 * The four-step tracker on Case Details.
 *
 * §13 describes Posted → Selected → Consult → Resolved. Those are not backend
 * statuses, so each step is derived from statuses that genuinely exist rather
 * than from a field the server would have to grow.
 *
 * `Rejected` returns -1: the tracker is hidden entirely for a refused case,
 * because drawing it would imply the case is somewhere on a path it has left.
 */
export const CASE_STAGES = ['Posted', 'Selected', 'Consult', 'Resolved'] as const;
export type CaseStage = (typeof CASE_STAGES)[number];

export const stageIndexForStatus = (status: CaseStatus): number => {
  switch (status) {
    case 'Submitted':
      return 0;
    case 'Awaiting Lawyer Acceptance':
    case 'Pending Lawyer Response':
    case 'Interested':
      return 1;
    case 'Accepted':
    case 'In Progress':
      return 2;
    case 'Closed':
      return 3;
    case 'Rejected':
      return -1;
    default:
      return 0;
  }
};

/**
 * Urgency, as free text.
 *
 * The Case schema declares `urgency` as a plain String defaulting to
 * "Flexible" — there is no enum, so no fixed list may be asserted here. The
 * default is named so the UI can tell "not set" from a deliberate choice.
 */
export const DEFAULT_URGENCY = 'Flexible';
