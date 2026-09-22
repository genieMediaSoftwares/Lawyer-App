import React from 'react';
import { RefreshControl } from 'react-native';
import ReactTestRenderer from 'react-test-renderer';

import { GenieRefreshControl } from '../src/components/ui/GenieRefreshControl';
import { usePollWhileFocused } from '../src/hooks/useScreenFocused';

const act = ReactTestRenderer.act;

const spinnerOf = (renderer: ReactTestRenderer.ReactTestRenderer) =>
  renderer.root.findByType(RefreshControl);

describe('GenieRefreshControl', () => {
  it('is idle by default, so background refetches never show the spinner', async () => {
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(<GenieRefreshControl onRefresh={jest.fn()} />);
    });

    expect(spinnerOf(renderer).props.refreshing).toBe(false);
    act(() => renderer.unmount());
  });

  it('spins only while a user-pulled refresh is in flight', async () => {
    let resolveRefetch!: () => void;
    const onRefresh = jest.fn(
      () => new Promise<void>(resolve => {
        resolveRefetch = resolve;
      }),
    );

    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(<GenieRefreshControl onRefresh={onRefresh} />);
    });

    await act(async () => {
      spinnerOf(renderer).props.onRefresh();
    });
    expect(onRefresh).toHaveBeenCalledTimes(1);
    expect(spinnerOf(renderer).props.refreshing).toBe(true);

    await act(async () => {
      resolveRefetch();
    });
    expect(spinnerOf(renderer).props.refreshing).toBe(false);
    act(() => renderer.unmount());
  });
});

describe('usePollWhileFocused', () => {
  it('keeps the requested interval for a screen rendered outside a navigator', async () => {
    let interval: (() => number | false) | undefined;
    const Probe = () => {
      interval = usePollWhileFocused()(3000);
      return null;
    };

    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(<Probe />);
    });

    expect(interval?.()).toBe(3000);
    act(() => renderer.unmount());
  });
});
