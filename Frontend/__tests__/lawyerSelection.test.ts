import {
  initialPostCaseState,
  isStepComplete,
  REQUIRED_LAWYER_COUNT,
  toCreatePayload,
  toggleLawyer,
} from '../src/screens/client/PostCase/types';
import type { RecommendedLawyer } from '../src/types/domain';

const makeLawyer =(n: number): RecommendedLawyer => ({
  lawyerId: `profile-${n}`,
  userId: `user-${n}`,
  fullName: `Advocate ${n}`,
  profileImage: '',
  specialization: 'Civil Law',
  city: 'Hyderabad',
  district: '',
  state: 'Telangana',
  location: 'Hyderabad',
  experience: 5 + n,
  rating: 4.5,
  reviewCount: 10,
  consultationFee: 1000,
  languages: [],
  practiceAreas: [],
  verified: true,
  onlineStatus: false,
  responseTime: '',
  matchPercentage: 90,
  casesHandled: 0,
  winPercentage: 0,
  locationScore: 0,
  bio: '',
  education: '',
  barCouncilNumber: '',
  officeAddress: '',
  workingHours: '',
});

const [a, b, c, d] = [1, 2, 3, 4].map(makeLawyer);

describe('toggleLawyer', () => {
  it('requires three lawyers', () => {
    expect(REQUIRED_LAWYER_COUNT).toBe(3);
  });

  it('adds lawyers up to three', () => {
    let selected: RecommendedLawyer[] = [];
    for (const lawyer of [a, b, c]) {
      const outcome = toggleLawyer(selected, lawyer);
      expect(outcome.ok).toBe(true);
      selected = outcome.selected;
    }
    expect(selected.map(l => l.userId)).toEqual(['user-1', 'user-2', 'user-3']);
  });

  it('refuses a fourth lawyer and explains why', () => {
    const outcome = toggleLawyer([a, b, c], d);

    expect(outcome.ok).toBe(false);
    expect(outcome.selected).toHaveLength(3);
    if (!outcome.ok) {
      expect(outcome.reason).toMatch(/only 3 lawyers/i);
    }
  });

  it('deselects a lawyer who is already selected instead of adding a duplicate', () => {
    const outcome = toggleLawyer([a, b], a);

    expect(outcome.ok).toBe(true);
    expect(outcome.selected.map(l => l.userId)).toEqual(['user-2']);
  });

  it('lets a slot be freed and refilled once three are chosen', () => {
    const freed = toggleLawyer([a, b, c], b).selected;
    const refilled = toggleLawyer(freed, d);

    expect(refilled.ok).toBe(true);
    expect(refilled.selected.map(l => l.userId)).toEqual(['user-1', 'user-3', 'user-4']);
  });
});

describe('Lawyers step completion', () => {
  it.each([
    [0, false],
    [1, false],
    [2, false],
    [3, true],
  ])('with %i selected, complete is %s', (count, expected) => {
    const state = {
      ...initialPostCaseState,
      selectedLawyers: [a, b, c].slice(0, count),
    };
    expect(isStepComplete(state, 3)).toBe(expected);
  });
});

describe('toCreatePayload', () => {
  it('sends the three lawyer user ids and the idempotency key', () => {
    const payload = toCreatePayload(
      {
        ...initialPostCaseState,
        category: 'Civil Cases',
        description: 'Unpaid rent',
        location: 'Hyderabad',
        selectedLawyers: [a, b, c],
      },
      'pc-key-123',
    );

    expect(payload.selectedLawyers).toEqual(['user-1', 'user-2', 'user-3']);
    expect(payload.clientRequestId).toBe('pc-key-123');
    expect(payload).not.toHaveProperty('selectedLawyer');
  });
});
