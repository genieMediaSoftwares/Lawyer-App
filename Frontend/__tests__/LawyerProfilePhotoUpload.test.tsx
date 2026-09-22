import React from 'react';
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

// The native (Android) picker: returns a content:// URI, not a browser File.
jest.mock('@react-native-documents/picker', () => ({
  pick: jest.fn(),
  types: { images: 'image/*', pdf: 'application/pdf', docx: 'docx', plainText: 'text/plain', csv: 'text/csv' },
  errorCodes: { OPERATION_CANCELED: 'OPERATION_CANCELED' },
  isErrorWithCode: (e: any) => Boolean(e && e.code),
}));

const { lawyerApi } = jest.requireMock('../src/api/lawyerApi');
const { authApi } = jest.requireMock('../src/api/authApi');
const { pick } = jest.requireMock('@react-native-documents/picker');

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

  it('uploads a photo picked with the native Android picker and refreshes the profile', async () => {
    lawyerApi.getProfile.mockResolvedValue(profile());
    authApi.uploadProfileImage.mockResolvedValue({});
    pick.mockResolvedValue([
      { uri: 'content://media/picker/0/42', name: 'IMG_0042.jpg', type: 'image/jpeg', size: 812345 },
    ]);

    const { root, done } = await mount();
    await act(async () => {
      find(root, 'Change profile photo').props.onPress();
    });
    await settle();

    expect(pick).toHaveBeenCalledWith(expect.objectContaining({ allowMultiSelection: false }));
    expect(authApi.uploadProfileImage).toHaveBeenCalledWith({
      uri: 'content://media/picker/0/42',
      name: 'IMG_0042.jpg',
      type: 'image/jpeg',
    });
    expect(lawyerApi.getProfile).toHaveBeenCalledTimes(2); // initial + refetch after upload
    done();
  });

  it('does nothing when the user cancels the picker', async () => {
    lawyerApi.getProfile.mockResolvedValue(profile());
    pick.mockRejectedValue({ code: 'OPERATION_CANCELED' });

    const { root, done } = await mount();
    await act(async () => {
      find(root, 'Change profile photo').props.onPress();
    });
    await settle();

    expect(authApi.uploadProfileImage).not.toHaveBeenCalled();
    done();
  });
});
