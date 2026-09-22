import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

import { LawyerMyProfileScreen } from '../src/screens/lawyer/Profile/LawyerMyProfileScreen';
import { LawyerProfileScreen } from '../src/screens/lawyer/Profile/LawyerProfileScreen';
import { useAuthStore } from '../src/store/authStore';
import type { LawyerProfileDetail } from '../src/types/lawyer';

jest.mock('../src/api/lawyerApi', () => ({
  lawyerApi: { getProfile: jest.fn() },
}));

jest.mock('../src/api/authApi', () => ({
  authApi: { uploadProfileImage: jest.fn() },
}));

const { lawyerApi } = jest.requireMock('../src/api/lawyerApi');

const act = ReactTestRenderer.act;

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children.map(child => (typeof child === 'string' ? child : textOf(child))).join('');

const find = (root: ReactTestRenderer.ReactTestInstance, label: string) =>
  root.findAll(node => node.props.accessibilityLabel === label && typeof node.type !== 'string')[0];

// Finds the exact text node, then climbs to the nearest pressable ancestor —
// robust to whatever accessibilityLabel/subtitle the row happens to carry.
const findPressableByText = (root: ReactTestRenderer.ReactTestInstance, text: string) => {
  const textNode = root.findAll(
    node => typeof node.type !== 'string' && textOf(node) === text,
  )[0];
  let current: ReactTestRenderer.ReactTestInstance | null = textNode;
  while (current) {
    if (typeof current.props.onPress === 'function') {
      return current;
    }
    current = current.parent;
  }
  throw new Error(`No pressable ancestor found for text "${text}"`);
};

const settle = async () => {
  for (let i = 0; i < 6; i += 1) {
    await act(async () => {
      await new Promise<void>(resolve => setTimeout(resolve, 10));
    });
  }
};

const profile = (): LawyerProfileDetail =>
  ({
    _id: 'lawyer-profile-1',
    user: {
      _id: 'lawyer-1',
      fullName: 'Adv. Sneha',
      email: 'sneha@example.test',
      mobile: '9876543210',
      location: 'Visakhapatnam',
      profileImage: '',
      isVerified: true,
    },
    specialization: 'Family Law',
    verificationStatus: 'verified',
    rating: 0,
    totalReviews: 0,
    casesHandled: 0,
    winPercentage: 0,
    subscriptionPlan: 'Free',
  } as unknown as LawyerProfileDetail);

beforeEach(() => {
  jest.clearAllMocks();
  useAuthStore.setState({
    user: { id: 'lawyer-1', fullName: 'Adv. Sneha', role: 'lawyer' } as any,
    status: 'authenticated',
  } as any);
});

const mount = async (Component: React.ComponentType<any>, navigate = jest.fn()) => {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false, gcTime: 0 } },
  });
  let renderer!: ReactTestRenderer.ReactTestRenderer;
  await act(async () => {
    renderer = ReactTestRenderer.create(
      <QueryClientProvider client={client}>
        <Component navigation={{ navigate, goBack: jest.fn() } as any} route={{} as any} />
      </QueryClientProvider>,
    );
  });
  await settle();
  return {
    root: renderer.root,
    navigate,
    done: () => {
      act(() => renderer.unmount());
      client.clear();
    },
  };
};

describe('LawyerMyProfileScreen', () => {
  it('shows the lawyer\'s real account details, not professional-practice fields', async () => {
    lawyerApi.getProfile.mockResolvedValue(profile());
    const { root, done } = await mount(LawyerMyProfileScreen);

    const text = textOf(root);
    expect(text).toContain('Account Summary');
    expect(text).toContain('Adv. Sneha');
    expect(text).toContain('sneha@example.test');
    expect(text).toContain('9876543210');
    expect(text).toContain('Visakhapatnam');
    // This screen is account details, not the practice-details editor.
    expect(text).not.toContain('Specialisation');
    expect(text).not.toContain('Bar Council');
    done();
  });

  it('offers the same change-photo control as the client profile', async () => {
    lawyerApi.getProfile.mockResolvedValue(profile());
    const { root, done } = await mount(LawyerMyProfileScreen);

    expect(find(root, 'Change profile photo')).toBeDefined();
    done();
  });

  it('"Edit Profile Details" opens the lawyer\'s editable profile screen', async () => {
    lawyerApi.getProfile.mockResolvedValue(profile());
    const { root, navigate, done } = await mount(LawyerMyProfileScreen);

    const editButton = findPressableByText(root, 'Edit Profile Details');
    await act(async () => {
      editButton.props.onPress();
    });

    expect(navigate).toHaveBeenCalledWith('ProfessionalDetails');
    done();
  });
});

describe('LawyerProfileScreen — "My Profile" row', () => {
  it('opens the account-summary screen, not the professional-details editor', async () => {
    lawyerApi.getProfile.mockResolvedValue(profile());
    const { root, navigate, done } = await mount(LawyerProfileScreen);

    const row = findPressableByText(root, 'My Profile');
    await act(async () => {
      row.props.onPress();
    });

    expect(navigate).toHaveBeenCalledWith('LawyerMyProfile');
    done();
  });
});
