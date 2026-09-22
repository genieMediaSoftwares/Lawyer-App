import React from 'react';
import { Platform } from 'react-native';
import ReactTestRenderer from 'react-test-renderer';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

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
const { authApi } = jest.requireMock('../src/api/authApi');

const act = ReactTestRenderer.act;

const find = (root: ReactTestRenderer.ReactTestInstance, label: string) =>
  root.findAll(node => node.props.accessibilityLabel === label && typeof node.type !== 'string')[0];

const settle = async () => {
  for (let i = 0; i < 6; i += 1) {
    await act(async () => {
      await new Promise<void>(resolve => setTimeout(resolve, 10));
    });
  }
};

const profile = (extra: Partial<LawyerProfileDetail> = {}): LawyerProfileDetail =>
  ({
    _id: 'lawyer-profile-1',
    user: { _id: 'lawyer-1', fullName: 'Adv. Sneha', profileImage: '', isVerified: false },
    specialization: 'Family Law',
    verificationStatus: 'verified',
    rating: 0,
    totalReviews: 0,
    casesHandled: 0,
    winPercentage: 0,
    subscriptionPlan: 'Free',
    ...extra,
  } as unknown as LawyerProfileDetail);

beforeEach(() => {
  jest.clearAllMocks();
  useAuthStore.setState({
    user: { id: 'lawyer-1', fullName: 'Adv. Sneha', role: 'lawyer' } as any,
    status: 'authenticated',
  } as any);
});

const mount = async () => {
  const navigate = jest.fn();
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false, gcTime: 0 } },
  });
  let renderer!: ReactTestRenderer.ReactTestRenderer;
  await act(async () => {
    renderer = ReactTestRenderer.create(
      <QueryClientProvider client={client}>
        <LawyerProfileScreen navigation={{ navigate } as any} route={{} as any} />
      </QueryClientProvider>,
    );
  });
  await settle();
  return {
    root: renderer.root,
    done: () => {
      act(() => renderer.unmount());
      client.clear();
    },
  };
};

describe('LawyerProfileScreen — profile photo upload', () => {
  it('offers a change-photo control on the avatar, same as the client profile', async () => {
    lawyerApi.getProfile.mockResolvedValue(profile());
    const { root, done } = await mount();

    expect(find(root, 'Change profile photo')).toBeDefined();
    done();
  });

  it('uploads the picked file and refreshes the lawyer profile', async () => {
    lawyerApi.getProfile.mockResolvedValue(profile());
    authApi.uploadProfileImage.mockResolvedValue({});

    // Stub the same web file-picker flow the client screen already uses,
    // regardless of what DOM (if any) this test environment provides.
    const originalPlatformOS = Platform.OS;
    (Platform as any).OS = 'web';
    const file = { name: 'photo.jpg', type: 'image/jpeg' };
    const fakeInput: any = { click: jest.fn(() => fakeInput.onchange?.({ target: { files: [file] } })) };
    const fakeDocument = { createElement: jest.fn(() => fakeInput) };
    const originalDocument = (globalThis as any).document;
    (globalThis as any).document = fakeDocument;

    const { root, done } = await mount();
    const button = find(root, 'Change profile photo');

    await act(async () => {
      button.props.onPress();
    });
    await settle();

    expect(authApi.uploadProfileImage).toHaveBeenCalledWith(file);
    expect(lawyerApi.getProfile).toHaveBeenCalledTimes(2); // initial + refetch after upload
    (globalThis as any).document = originalDocument;
    (Platform as any).OS = originalPlatformOS;
    done();
  });
});
