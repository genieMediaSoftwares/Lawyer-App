import React, { useState } from 'react';
import ReactTestRenderer from 'react-test-renderer';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

import { LawyersStep } from '../src/screens/client/PostCase/steps/LawyersStep';
import {
  initialPostCaseState,
  type PostCaseState,
} from '../src/screens/client/PostCase/types';
import type { RecommendedLawyer } from '../src/types/domain';

jest.mock('../src/api/advocatesApi', () => ({
  advocatesApi: { recommend: jest.fn() },
}));

const { advocatesApi } = jest.requireMock('../src/api/advocatesApi');

const makeLawyer = (n: number): RecommendedLawyer =>
  ({
    lawyerId: `profile-${n}`,
    userId: `user-${n}`,
    fullName: `Advocate ${n}`,
    profileImage: '',
    specialization: 'Civil Law',
    location: 'Hyderabad',
    experience: 5,
    rating: 4.5,
    reviewCount: 10,
    languages: [],
    verified: false,
    onlineStatus: false,
    responseTime: '',
    matchPercentage: 90,
    casesHandled: 0,
  } as unknown as RecommendedLawyer);

let latestState: PostCaseState;

const Harness: React.FC = () => {
  const [state, setState] = useState<PostCaseState>({
    ...initialPostCaseState,
    category: 'Civil Cases',
  });
  latestState = state;
  return (
    <LawyersStep
      state={state}
      onChange={patch => setState(current => ({ ...current, ...patch }))}
      onViewProfile={() => {}}
    />
  );
};

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children
    .map(child => (typeof child === 'string' ? child : textOf(child)))
    .join('');

const byTestId = (root: ReactTestRenderer.ReactTestInstance, id: string) =>
  root.findAll(node => node.props.testID === id)[0];

const allText = (root: ReactTestRenderer.ReactTestInstance) => textOf(root);

const renderStep = async () => {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false, gcTime: 0 } },
  });
  let renderer!: ReactTestRenderer.ReactTestRenderer;
  await ReactTestRenderer.act(async () => {
    renderer = ReactTestRenderer.create(
      <QueryClientProvider client={client}>
        <Harness />
      </QueryClientProvider>,
    );
  });
  for (let i = 0; i < 20 && !byTestId(renderer.root, 'lawyer-card-user-1'); i += 1) {
    await ReactTestRenderer.act(async () => {
      await new Promise<void>(resolve => setTimeout(resolve, 10));
    });
  }
  return { renderer, client };
};

const press = async (root: ReactTestRenderer.ReactTestInstance, id: string) => {
  await ReactTestRenderer.act(async () => {
    byTestId(root, id).props.onPress();
  });
};

describe('LawyersStep', () => {
  beforeEach(() => {
    advocatesApi.recommend.mockResolvedValue([1, 2, 3, 4].map(makeLawyer));
  });

  it('asks for three lawyers and starts the counter at 0 / 3', async () => {
    const { renderer, client } = await renderStep();
    const root = renderer.root;

    expect(allText(root)).toContain('Select 3 lawyers');
    expect(textOf(byTestId(root, 'lawyer-selection-counter'))).toBe('0 / 3 selected');
    expect(textOf(byTestId(root, 'lawyer-selection-hint'))).toBe(
      'Select 3 more lawyers to continue.',
    );

    renderer.unmount();
    client.clear();
  });

  it('counts selections, marks cards selected, and allows deselecting', async () => {
    const { renderer, client } = await renderStep();
    const root = renderer.root;

    await press(root, 'lawyer-card-user-1');
    await press(root, 'lawyer-card-user-2');

    expect(textOf(byTestId(root, 'lawyer-selection-counter'))).toBe('2 / 3 selected');
    expect(byTestId(root, 'lawyer-card-user-1').props.accessibilityState.checked).toBe(true);
    expect(byTestId(root, 'lawyer-card-user-3').props.accessibilityState.checked).toBe(false);

    await press(root, 'lawyer-card-user-1');

    expect(textOf(byTestId(root, 'lawyer-selection-counter'))).toBe('1 / 3 selected');
    expect(latestState.selectedLawyers.map(l => l.userId)).toEqual(['user-2']);

    renderer.unmount();
    client.clear();
  });

  it('locks the remaining cards at three and refuses a fourth selection', async () => {
    const { renderer, client } = await renderStep();
    const root = renderer.root;

    for (const id of ['user-1', 'user-2', 'user-3']) {
      await press(root, `lawyer-card-${id}`);
    }

    expect(textOf(byTestId(root, 'lawyer-selection-counter'))).toBe('3 / 3 selected');
    expect(byTestId(root, 'lawyer-card-user-4').props.accessibilityState.disabled).toBe(true);

    await press(root, 'lawyer-card-user-4');

    expect(latestState.selectedLawyers.map(l => l.userId)).toEqual([
      'user-1',
      'user-2',
      'user-3',
    ]);
    expect(allText(root)).toContain('You can select only 3 lawyers');

    renderer.unmount();
    client.clear();
  });

  it('never records the same lawyer twice', async () => {
    const { renderer, client } = await renderStep();
    const root = renderer.root;

    await press(root, 'lawyer-card-user-1');
    await press(root, 'lawyer-card-user-1');
    await press(root, 'lawyer-card-user-1');

    expect(latestState.selectedLawyers.map(l => l.userId)).toEqual(['user-1']);

    renderer.unmount();
    client.clear();
  });

  it('keeps the existing sort options', async () => {
    const { renderer, client } = await renderStep();
    const text = allText(renderer.root);

    for (const option of ['Best Match', 'Experience', 'Rating', 'Fees: Low to High']) {
      expect(text).toContain(option);
    }

    renderer.unmount();
    client.clear();
  });
});
