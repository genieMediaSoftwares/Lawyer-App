import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AxiosError, AxiosHeaders } from 'axios';

import { LeadsScreen } from '../src/screens/lawyer/Leads/LeadsScreen';
import type { LawyerLead } from '../src/types/lawyer';

jest.mock('../src/api/lawyerApi', () => ({
  lawyerApi: {
    getLeads: jest.fn(),
    getClients: jest.fn(),
    acceptLead: jest.fn(),
    rejectLead: jest.fn(),
  },
}));

jest.mock('../src/api/clientApi', () => {
  const actual = jest.requireActual('../src/api/clientApi');
  return {
    ...actual,
    notificationsApi: {
      ...actual.notificationsApi,
      list: jest.fn(() => Promise.resolve({ items: [], unreadCount: 0 })),
    },
  };
});

const { lawyerApi } = jest.requireMock('../src/api/lawyerApi');

const TAKEN = 'This case has already been accepted by another lawyer.';

const lead = (caseId: string, extra: Partial<LawyerLead> = {}): LawyerLead => ({
  caseId,
  clientName: 'Client One',
  issueCategory: 'Civil Cases',
  issueTitle: `Case ${caseId}`,
  location: 'Hyderabad',
  postedTime: new Date().toISOString(),
  urgency: 'Flexible',
  acknowledgementDocument: '',
  preferredCourt: '',
  caseStatus: 'Awaiting Lawyer Acceptance',
  requestStatus: 'Pending',
  unavailableReason: null,
  ...extra,
});

const conflict = (message: string) => {
  const config = { headers: new AxiosHeaders() };
  return new AxiosError('Request failed', 'ERR_BAD_REQUEST', config, null, {
    status: 409,
    statusText: 'Conflict',
    data: { success: false, message },
    headers: {},
    config,
  });
};

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children
    .map(child => (typeof child === 'string' ? child : textOf(child)))
    .join('');

const find = (root: ReactTestRenderer.ReactTestInstance, id: string) =>
  root.findAll(node => node.props.testID === id && typeof node.type !== 'string')[0];

const act = ReactTestRenderer.act;

const settle = async () => {
  for (let i = 0; i < 5; i += 1) {
    await act(async () => {
      await new Promise<void>(resolve => setTimeout(resolve, 10));
    });
  }
};

const renderLeads = async () => {
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
        <LeadsScreen navigation={{ navigate: jest.fn() } as any} route={{} as any} />
      </QueryClientProvider>,
    );
  });
  await settle();
  return { renderer, client };
};

describe('Lawyer leads — shared case requests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    lawyerApi.getClients.mockResolvedValue({ accepted: [], inProgress: [], closed: [] });
  });

  it('shows an unavailable request with the reason and no Accept button', async () => {
    lawyerApi.getLeads.mockResolvedValue([
      lead('open-1'),
      lead('taken-1', { requestStatus: 'Unavailable', unavailableReason: TAKEN }),
    ]);

    const { renderer, client } = await renderLeads();
    const root = renderer.root;

    const unavailable = find(root, 'lead-unavailable-taken-1');
    expect(unavailable).toBeDefined();
    expect(textOf(unavailable)).toContain('Unavailable');
    expect(textOf(unavailable)).toContain(TAKEN);
    expect(find(root, 'lead-accept-taken-1')).toBeUndefined();
    expect(find(root, 'lead-decline-taken-1')).toBeUndefined();

    expect(find(root, 'lead-accept-open-1')).toBeDefined();
    expect(find(root, 'lead-decline-open-1')).toBeDefined();

    renderer.unmount();
    client.clear();
  });

  it('counts only requests that can still be accepted', async () => {
    lawyerApi.getLeads.mockResolvedValue([
      lead('open-1'),
      lead('taken-1', { requestStatus: 'Unavailable', unavailableReason: TAKEN }),
      lead('taken-2', { requestStatus: 'Unavailable', unavailableReason: TAKEN }),
    ]);

    const { renderer, client } = await renderLeads();

    expect(textOf(find(renderer.root, 'new-leads-count'))).toBe('1');

    renderer.unmount();
    client.clear();
  });

  it('when another lawyer wins the race, shows the conflict and refreshes the lead to unavailable', async () => {
    lawyerApi.getLeads
      .mockResolvedValueOnce([lead('race-1')])
      .mockResolvedValue([
        lead('race-1', { requestStatus: 'Unavailable', unavailableReason: TAKEN }),
      ]);
    lawyerApi.acceptLead.mockRejectedValue(conflict(TAKEN));

    const { renderer, client } = await renderLeads();
    const root = renderer.root;

    await act(async () => {
      find(root, 'lead-accept-race-1').props.onPress();
    });
    await settle();

    expect(lawyerApi.acceptLead).toHaveBeenCalledTimes(1);
    expect(textOf(root)).toContain(TAKEN);
    expect(find(root, 'lead-accept-race-1')).toBeUndefined();
    expect(find(root, 'lead-unavailable-race-1')).toBeDefined();

    renderer.unmount();
    client.clear();
  });

  it('ignores a second tap while a response is in flight', async () => {
    lawyerApi.getLeads.mockResolvedValue([lead('busy-1')]);
    lawyerApi.acceptLead.mockReturnValue(new Promise(() => {}));

    const { renderer, client } = await renderLeads();
    const root = renderer.root;

    await act(async () => {
      find(root, 'lead-accept-busy-1').props.onPress();
    });
    await act(async () => {
      find(root, 'lead-accept-busy-1').props.onPress();
      find(root, 'lead-decline-busy-1').props.onPress();
    });

    expect(lawyerApi.acceptLead).toHaveBeenCalledTimes(1);
    expect(lawyerApi.rejectLead).not.toHaveBeenCalled();
    expect(find(root, 'lead-accept-busy-1').props.disabled).toBe(true);

    renderer.unmount();
    client.clear();
  });
});
