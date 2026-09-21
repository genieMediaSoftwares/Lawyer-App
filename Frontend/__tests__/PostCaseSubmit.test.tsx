import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AxiosError, AxiosHeaders } from 'axios';

import { PostCaseScreen } from '../src/screens/client/PostCase/PostCaseScreen';
import type { RecommendedLawyer } from '../src/types/domain';

const mockStepProps: Record<string, any> = {};

jest.mock('@react-navigation/native', () => ({
  ...jest.requireActual('@react-navigation/native'),
  useFocusEffect: jest.fn(),
}));

jest.mock('../src/screens/client/PostCase/steps/CategoryStep', () => ({
  CategoryStep: (props: any) => {
    mockStepProps.category = props;
    return null;
  },
}));
jest.mock('../src/screens/client/PostCase/steps/DetailsStep', () => ({
  DetailsStep: () => null,
}));
jest.mock('../src/screens/client/PostCase/steps/DocumentsStep', () => ({
  DocumentsStep: () => null,
}));
jest.mock('../src/screens/client/PostCase/steps/LawyersStep', () => ({
  LawyersStep: (props: any) => {
    mockStepProps.lawyers = props;
    return null;
  },
}));
jest.mock('../src/screens/client/PostCase/steps/ReviewStep', () => ({
  ReviewStep: (props: any) => {
    mockStepProps.review = props;
    return null;
  },
}));

jest.mock('../src/api/casesApi', () => ({ casesApi: { create: jest.fn() } }));
jest.mock('../src/api/aiApi', () => {
  const actual = jest.requireActual('../src/api/aiApi');
  return {
    ...actual,
    aiApi: { ...actual.aiApi, linkCase: jest.fn(), getSession: jest.fn() },
  };
});

const { casesApi } = jest.requireMock('../src/api/casesApi');

const lawyer = (n: number) =>
  ({ userId: `user-${n}`, lawyerId: `p-${n}`, fullName: `Advocate ${n}` } as RecommendedLawyer);

const conflict = (message: string, status = 400) => {
  const config = { headers: new AxiosHeaders() };
  return new AxiosError('Request failed', 'ERR_BAD_REQUEST', config, null, {
    status,
    statusText: '',
    data: { success: false, message },
    headers: {},
    config,
  });
};

const byTestId = (root: ReactTestRenderer.ReactTestInstance, id: string) =>
  root.findAll(node => node.props.testID === id && typeof node.type !== 'string')[0];

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children
    .map(child => (typeof child === 'string' ? child : textOf(child)))
    .join('');

const act = ReactTestRenderer.act;

const setup = async () => {
  const navigation = { replace: jest.fn(), navigate: jest.fn(), goBack: jest.fn() };
  const client = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false, gcTime: 0 },
    },
  });
  let renderer!: ReactTestRenderer.ReactTestRenderer;
  await act(async () => {
    renderer = ReactTestRenderer.create(
      <QueryClientProvider client={client}>
        <PostCaseScreen
          navigation={navigation as any}
          route={{ key: 'PostCase', name: 'PostCase', params: {} } as any}
        />
      </QueryClientProvider>,
    );
  });

  const root = renderer.root;
  const next = () => byTestId(root, 'post-case-next-button');

  await act(async () => {
    mockStepProps.category.onChange({
      category: 'Civil Cases',
      subcategory: 'Money Recovery',
      description: 'Tenant has not paid rent.',
      location: 'Hyderabad',
      aiDocuments: [{ originalName: 'lease.pdf', url: '/uploads/lease.pdf', size: 10 }],
    });
  });
  for (let i = 0; i < 3; i += 1) {
    await act(async () => {
      next().props.onPress();
    });
  }

  return { renderer, root, navigation, client, next };
};

const reachReview = async (ctx: Awaited<ReturnType<typeof setup>>) => {
  await act(async () => {
    mockStepProps.lawyers.onChange({ selectedLawyers: [lawyer(1), lawyer(2), lawyer(3)] });
  });
  await act(async () => {
    ctx.next().props.onPress();
  });
  await act(async () => {
    mockStepProps.review.onAgreedChange(true);
  });
  return byTestId(ctx.root, 'submit-case-button');
};

describe('Post Case — Lawyers step and submission', () => {
  beforeEach(() => {
    casesApi.create.mockReset();
    Object.keys(mockStepProps).forEach(key => delete mockStepProps[key]);
  });

  it('keeps Next disabled until exactly three lawyers are selected', async () => {
    const ctx = await setup();

    expect(mockStepProps.lawyers).toBeDefined();
    expect(ctx.next().props.disabled).toBe(true);
    expect(textOf(ctx.root)).toContain('Select exactly 3 lawyers to continue (0 / 3 selected)');

    await act(async () => {
      mockStepProps.lawyers.onChange({ selectedLawyers: [lawyer(1), lawyer(2)] });
    });
    expect(ctx.next().props.disabled).toBe(true);
    expect(textOf(ctx.root)).toContain('(2 / 3 selected)');

    await act(async () => {
      mockStepProps.lawyers.onChange({ selectedLawyers: [lawyer(1), lawyer(2), lawyer(3)] });
    });
    expect(ctx.next().props.disabled).toBe(false);

    ctx.renderer.unmount();
    ctx.client.clear();
  });

  it('shows a loading state, ignores repeat taps, and navigates on success', async () => {
    const ctx = await setup();
    const submit = await reachReview(ctx);

    let resolveCreate!: (value: unknown) => void;
    casesApi.create.mockReturnValue(
      new Promise(resolve => {
        resolveCreate = resolve;
      }),
    );

    await act(async () => {
      submit.props.onPress();
      submit.props.onPress();
      submit.props.onPress();
    });

    expect(casesApi.create).toHaveBeenCalledTimes(1);
    const button = byTestId(ctx.root, 'submit-case-button');
    expect(button.props.loading).toBe(true);
    expect(button.props.disabled).toBe(true);

    const payload = casesApi.create.mock.calls[0][0];
    expect(payload.selectedLawyers).toEqual(['user-1', 'user-2', 'user-3']);
    expect(typeof payload.clientRequestId).toBe('string');

    await act(async () => {
      resolveCreate({ _id: 'case-1', title: 'Money Recovery' });
    });

    expect(ctx.navigation.replace).toHaveBeenCalledWith('CaseDetails', {
      caseId: 'case-1',
      title: 'Money Recovery',
    });

    ctx.renderer.unmount();
    ctx.client.clear();
  });

  it('shows the backend error and lets the client retry with the same request key', async () => {
    const ctx = await setup();
    const submit = await reachReview(ctx);

    casesApi.create.mockRejectedValueOnce(
      conflict('One or more selected lawyers are not available.'),
    );

    await act(async () => {
      submit.props.onPress();
    });

    expect(mockStepProps.review.submitError).toBe(
      'One or more selected lawyers are not available.',
    );
    expect(ctx.navigation.replace).not.toHaveBeenCalled();
    expect(byTestId(ctx.root, 'submit-case-button').props.loading).toBe(false);

    casesApi.create.mockResolvedValueOnce({ _id: 'case-2', title: 'Money Recovery' });
    await act(async () => {
      byTestId(ctx.root, 'submit-case-button').props.onPress();
    });

    expect(casesApi.create).toHaveBeenCalledTimes(2);
    expect(casesApi.create.mock.calls[1][0].clientRequestId).toBe(
      casesApi.create.mock.calls[0][0].clientRequestId,
    );
    expect(ctx.navigation.replace).toHaveBeenCalled();

    ctx.renderer.unmount();
    ctx.client.clear();
  });
});
