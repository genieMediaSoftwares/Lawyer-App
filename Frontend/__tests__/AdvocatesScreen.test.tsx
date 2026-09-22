import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AxiosError, AxiosHeaders } from 'axios';

import { AdvocatesScreen } from '../src/screens/client/Advocates/AdvocatesScreen';
import type { LawyerProfile } from '../src/types/domain';

jest.mock('../src/api/advocatesApi', () => {
  const actual = jest.requireActual('../src/api/advocatesApi');
  return {
    ...actual,
    advocatesApi: { list: jest.fn() },
    favoritesApi: { list: jest.fn(), toggle: jest.fn() },
  };
});

jest.mock('../src/api/clientApi', () => {
  const actual = jest.requireActual('../src/api/clientApi');
  return {
    ...actual,
    notificationsApi: {
      ...actual.notificationsApi,
      list: jest.fn(() => Promise.resolve({ items: [], unreadCount: 2 })),
    },
  };
});

const { advocatesApi, favoritesApi } = jest.requireMock('../src/api/advocatesApi');

const act = ReactTestRenderer.act;

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children.map(child => (typeof child === 'string' ? child : textOf(child))).join('');

const find = (root: ReactTestRenderer.ReactTestInstance, id: string) =>
  root.findAll(node => node.props.testID === id && typeof node.type !== 'string')[0];

const settle = async () => {
  for (let i = 0; i < 6; i += 1) {
    await act(async () => {
      await new Promise<void>(resolve => setTimeout(resolve, 10));
    });
  }
};

const lawyer = (id: string, extra: Partial<LawyerProfile> = {}, user: object = {}): LawyerProfile =>
  ({
    _id: `lawyer-${id}`,
    user: {
      _id: `user-${id}`,
      fullName: `Advocate ${id}`,
      email: '',
      mobile: '',
      profileImage: '/uploads/profiles/a.jpg',
      location: 'Visakhapatnam, Andhra Pradesh, India',
      isVerified: false,
      ...user,
    },
    specialization: 'Criminal Law',
    rating: 4.8,
    totalReviews: 12,
    officeAddress: '',
    ...extra,
  } as unknown as LawyerProfile);

const mount = async (wait = true) => {
  const navigate = jest.fn();
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false, gcTime: 0 }, mutations: { retry: false } },
  });
  let renderer!: ReactTestRenderer.ReactTestRenderer;
  await act(async () => {
    renderer = ReactTestRenderer.create(
      <QueryClientProvider client={client}>
        <AdvocatesScreen navigation={{ navigate } as any} route={{ params: undefined } as any} />
      </QueryClientProvider>,
    );
  });
  if (wait) {
    await settle();
  }
  return {
    root: renderer.root,
    navigate,
    done: () => {
      act(() => renderer.unmount());
      client.clear();
    },
  };
};

beforeEach(() => {
  jest.clearAllMocks();
  favoritesApi.list.mockResolvedValue([]);
  favoritesApi.toggle.mockResolvedValue({ isFavorite: true });
});

describe('AdvocatesScreen', () => {
  it('shows skeletons while loading, never placeholder advocates', async () => {
    advocatesApi.list.mockReturnValue(new Promise(() => {}));
    const { root, done } = await mount(false);

    expect(find(root, 'advocates-loading')).toBeDefined();
    expect(textOf(root)).not.toContain('Advocate ');
    done();
  });

  it('renders the real advocates with real counts, rating and review count', async () => {
    advocatesApi.list.mockResolvedValue([
      lawyer('a', {}, { isVerified: true }),
      lawyer('b', { rating: 0, totalReviews: 0, specialization: '' }, { location: '' }),
    ]);
    const { root, done } = await mount();

    const all = textOf(root);
    expect(all).toContain('Advocate a');
    expect(all).toContain('Criminal Law');
    expect(all).toContain('4.8 (12)');
    expect(all).toContain('No reviews yet');
    expect(all).toContain('Practice area not specified');
    expect(all).toContain('Location not specified');
    expect(textOf(find(root, 'advocates-segment-all'))).toContain('2');
    expect(textOf(find(root, 'advocates-segment-verified'))).toContain('1');
    done();
  });

  it('never shows online status or distance, which the backend does not provide', async () => {
    advocatesApi.list.mockResolvedValue([lawyer('a', {}, { isActive: true })]);
    const { root, done } = await mount();

    const all = textOf(root).toLowerCase();
    expect(all).not.toContain('online');
    expect(all).not.toContain('offline');
    expect(all).not.toContain('nearby');
    expect(all).not.toContain('km away');
    done();
  });

  it('does not show the backend placeholder "Office Address" as a location', async () => {
    advocatesApi.list.mockResolvedValue([
      lawyer('a', { officeAddress: 'Office Address' }, { location: '' }),
    ]);
    const { root, done } = await mount();

    expect(textOf(root)).not.toContain('Office Address');
    expect(textOf(root)).toContain('Location not specified');
    done();
  });

  it('opens the profile with the real user id from the card and from View Profile', async () => {
    advocatesApi.list.mockResolvedValue([lawyer('a'), lawyer('b')]);
    const { root, navigate, done } = await mount();

    await act(async () => {
      find(root, 'advocate-card-user-b').props.onPress();
    });
    expect(navigate).toHaveBeenLastCalledWith('AdvocateProfile', { userId: 'user-b' });

    await act(async () => {
      find(root, 'advocate-view-user-a').props.onPress();
    });
    expect(navigate).toHaveBeenLastCalledWith('AdvocateProfile', { userId: 'user-a' });
    done();
  });

  it('filters to verified advocates without another request', async () => {
    advocatesApi.list.mockResolvedValue([lawyer('a', {}, { isVerified: true }), lawyer('b')]);
    const { root, done } = await mount();
    const calls = advocatesApi.list.mock.calls.length;

    await act(async () => {
      find(root, 'advocates-segment-verified').props.onPress();
    });

    expect(find(root, 'advocate-card-user-a')).toBeDefined();
    expect(find(root, 'advocate-card-user-b')).toBeUndefined();
    expect(advocatesApi.list.mock.calls.length).toBe(calls);
    done();
  });

  it('saves an advocate through the favorites API with their user id', async () => {
    advocatesApi.list.mockResolvedValue([lawyer('a')]);
    const { root, done } = await mount();

    await act(async () => {
      find(root, 'advocate-bookmark-user-a').props.onPress();
    });
    await settle();

    expect(favoritesApi.toggle).toHaveBeenCalledWith('user-a');
    done();
  });

  it('marks advocates the client already saved', async () => {
    advocatesApi.list.mockResolvedValue([lawyer('a')]);
    favoritesApi.list.mockResolvedValue([{ _id: 'f1', lawyer: { _id: 'user-a' }, profile: null }]);
    const { root, done } = await mount();

    expect(find(root, 'advocate-bookmark-user-a').props.accessibilityState).toEqual({
      selected: true,
    });
    done();
  });

  it('shows an empty state when the backend has no advocates', async () => {
    advocatesApi.list.mockResolvedValue([]);
    const { root, done } = await mount();

    expect(textOf(root)).toContain('No advocates listed yet');
    done();
  });

  it('shows an error with Retry when the request fails', async () => {
    const config = { headers: new AxiosHeaders() };
    advocatesApi.list.mockRejectedValue(
      new AxiosError('fail', 'ERR_BAD_RESPONSE', config, null, {
        status: 500,
        statusText: '',
        data: { success: false, message: 'Internal' },
        headers: {},
        config,
      }),
    );
    const { root, done } = await mount();

    expect(find(root, 'advocates-error')).toBeDefined();
    expect(textOf(root)).toContain('Could not load advocates');

    advocatesApi.list.mockResolvedValue([lawyer('a')]);
    const retry = root.findAll(
      node => node.props.accessibilityRole === 'button' && /try again/i.test(textOf(node)),
    )[0];
    await act(async () => {
      retry.props.onPress();
    });
    await settle();

    expect(find(root, 'advocate-card-user-a')).toBeDefined();
    done();
  });
});
