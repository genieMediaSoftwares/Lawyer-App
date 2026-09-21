import type { PopulatedUser } from './domain';

export interface LawyerLead {
  caseId: string;
  clientName: string;
  clientProfileImage?: string;
  clientLocation?: string;
  issueCategory: string;
  issueTitle: string;
  location: string;
  postedTime: string;
  urgency: string;
  documentsCount?: number;
  acknowledgementDocument: string;
  preferredCourt: string;
  caseStatus: string;
  matchPercentage?: number | null;
}

export interface LawyerClientRow {
  clientId: string;
  name: string;
  profileImage: string;
  caseId: string;
  issue: string;
  category?: string;
  location?: string;
  preferredCourt?: string;
  currentStatus: string;
  acceptedAt?: string;
  lastActivity: string;
  tasksRemaining?: number;
}

export interface LawyerClientGroups {
  accepted: LawyerClientRow[];
  inProgress: LawyerClientRow[];
  closed: LawyerClientRow[];
}

export type ScheduleEventType =
  | 'consultation'
  | 'hearing'
  | 'meeting'
  | 'reminder';

export interface LawyerScheduleEvent {
  title: string;
  client: string;
  case: string;
  startTime: string;
  endTime: string;
  eventType: ScheduleEventType;
}

export interface LawyerUnreadMessages {
  unreadCount: number;
  conversationCount: number;
  latestMessage: string;
  latestClient: string;
  lastMessageTime: string | null;
}

export type LawyerVerificationStatus = 'pending' | 'verified' | 'rejected';

export interface LawyerProfileDetail {
  _id: string;
  user: PopulatedUser;
  specialization: string;
  experience: number;
  education: string;
  barCouncilNumber: string;
  languages: string[];
  consultationFee: number;
  bio: string;
  officeAddress: string;
  rating: number;
  totalReviews: number;
  verificationStatus: LawyerVerificationStatus;
  subscriptionPlan: string;
  workingHours: string;
  casesHandled: number;
  winPercentage: number;
  responseTime: string;
  district: string;
  practiceAreas: string[];
  createdAt: string;
  updatedAt: string;
}

export interface LawyerProfileUpdate {
  specialization?: string;
  experience?: number;
  education?: string;
  barCouncilNumber?: string;
  consultationFee?: number;
  bio?: string;
  officeAddress?: string;
  workingHours?: string;
}

export type AppointmentStatus =
  | 'pending'
  | 'confirmed'
  | 'completed'
  | 'cancelled';

export interface Appointment {
  _id: string;
  client: PopulatedUser | null;
  lawyer: PopulatedUser | null;
  case: { _id: string; title: string; category: string } | null;
  date: string;
  timeSlot: string;
  mode: 'Chat' | 'In-Person';
  status: AppointmentStatus;
  meetingLink: string;
  notes: string;
  createdAt: string;
  updatedAt: string;
}

export interface LawyerHearing {
  _id?: string;
  date: string;
  timeSlot?: string;
  court?: string;
  purpose?: string;
  status?: string;
  notes?: string;
  createdAt?: string;
  updatedAt?: string;
  caseId: string;
  caseTitle: string;
  caseCategory: string;
  caseStatus: string;
  clientId: string | null;
  clientName: string;
  clientImage: string;
}

export interface SubscriptionInfo {
  plan: string;
  status: string;
  startDate: string;
  endDate: string;
}

export interface LawyerNote {
  _id: string;
  title: string;
  text: string;
  case: string | null;
  lawyer: { _id: string; fullName?: string; profileImage?: string } | string;
  date: string;
  updatedAt: string;
}

export interface LawyerNoteRow extends LawyerNote {
  clientId: string;
  clientName: string;
}

export interface LawyerNoteInput {
  text: string;
  title?: string;
  caseId?: string | null;
}

export type HearingStatus =
  | 'scheduled'
  | 'completed'
  | 'adjourned'
  | 'cancelled';

export interface HearingInput {
  date: string;
  timeSlot?: string;
  court?: string;
  purpose?: string;
  status?: HearingStatus;
  notes?: string;
}

export interface ResearchSession {
  id: string;
  title: string;
  lastMessage: string;
  createdAt: string;
  updatedAt: string;
  messageCount: number;
}
