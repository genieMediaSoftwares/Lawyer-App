import React from 'react';
import { Linking } from 'react-native';
import ReactTestRenderer from 'react-test-renderer';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AxiosError, AxiosHeaders } from 'axios';

import { LeadsScreen } from '../src/screens/lawyer/Leads/LeadsScreen';
import { LeadDetailsScreen } from '../src/screens/lawyer/Leads/LeadDetailsScreen';
import { LawyerClientsScreen } from '../src/screens/lawyer/Clients/LawyerClientsScreen';
import { LawyerClientDetailsScreen } from '../src/screens/lawyer/Clients/LawyerClientDetailsScreen';
import { ContactSupportRows } from '../src/components/ContactSupportRows';
import type { LegalCase } from '../src/types/domain';
import type { LawyerClientRow, LawyerLead } from '../src/types/lawyer';

jest.mock('../src/api/lawyerApi', () => ({
  lawyerApi: {
    getLeads: jest.fn(),
    getClients: jest.fn(),
    getClientDetails: jest.fn(),
    acceptLead: jest.fn(),
    rejectLead: jest.fn(),
    startCase: jest.fn(),
    markCaseCompleted: jest.fn(),
  },
}));

jest.mock('../src/api/casesApi', () => ({
  casesApi: { getById: jest.fn(), fetchAttachment: jest.fn() },
}));

jest.mock('../src/api/chatApi', () => ({
  chatApi: { getOrCreateChat: jest.fn() },
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
const { casesApi } = jest.requireMock('../src/api/casesApi');

const act = ReactTestRenderer.act;

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children
    .map(child => (typeof child === 'string' ? child : textOf(child)))
    .join('');

const find = (root: ReactTestRenderer.ReactTestInstance, id: string) =>
  root.findAll(node => node.props.testID === id && typeof node.type !== 'string')[0];

const settle = async () => {
  for (let i = 0; i < 6; i += 1) {
    await act(async () => {
      await new Promise<void>(resolve => setTimeout(resolve, 10));
    });
  }
};

const httpError = (status: number, message: string) => {
  const config = { headers: new AxiosHeaders() };
  return new AxiosError('Request failed', 'ERR_BAD_REQUEST', config, null, {
    status,
    statusText: '',
    data: { success: false, message },
    headers: {},
    config,
  });
};

const mount = async (element: React.ReactElement, wait = true) => {
  const client = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false, gcTime: 0 },
    },
  });
  let renderer!: ReactTestRenderer.ReactTestRenderer;
  await act(async () => {
    renderer = ReactTestRenderer.create(
      <QueryClientProvider client={client}>{element}</QueryClientProvider>,
    );
  });
  if (wait) {
    await settle();
  }
  return {
    root: renderer.root,
    done: () => {
      act(() => renderer.unmount());
      client.clear();
    },
  };
};

const lead = (caseId: string): LawyerLead => ({
  caseId,
  clientName: 'Ajith',
  issueCategory: 'Family & Divorce',
  issueTitle: 'Divorce petition',
  location: 'Visakhapatnam',
  postedTime: '2026-09-20T10:00:00.000Z',
  urgency: 'High',
  documentsCount: 1,
  acknowledgementDocument: '',
  preferredCourt: '',
  caseStatus: 'Awaiting Lawyer Acceptance',
  requestStatus: 'Pending',
  unavailableReason: null,
});

const row = (caseId: string, clientId: string, extra: Partial<LawyerClientRow> = {}): LawyerClientRow => ({
  clientId,
  name: 'Ajith',
  profileImage: '',
  caseId,
  issue: `Case ${caseId}`,
  currentStatus: 'Accepted',
  lastActivity: '2026-09-19T10:00:00.000Z',
  ...extra,
});

const legalCase = (extra: Partial<LegalCase> = {}): LegalCase =>
  ({
    _id: 'case-1',
    client: { _id: 'client-1', fullName: 'Ajith', profileImage: '' },
    title: 'Divorce due to mental cruelty',
    description: 'Seeking divorce on grounds of cruelty.',
    category: 'Family & Divorce',
    subcategory: '',
    location: 'Visakhapatnam',
    locationCity: '',
    preferredCourt: 'Family Court, Visakhapatnam',
    urgency: 'High',
    status: 'Awaiting Lawyer Acceptance',
    documents: [{ name: 'petition.pdf', url: 'uploads/documents/p.pdf', size: '2048' }],
    lawyerRequests: [
      { lawyer: 'me', status: 'Pending', createdAt: '2026-09-20T10:00:00.000Z', respondedAt: null, acceptedAt: null },
    ],
    myRequestStatus: 'Pending',
    assignedLawyer: null,
    selectedLawyer: null,
    milestones: [],
    hearings: [],
    acceptedAt: null,
    createdAt: '2026-09-20T10:00:00.000Z',
    updatedAt: '2026-09-20T10:00:00.000Z',
    ...extra,
  } as unknown as LegalCase);

beforeEach(() => {
  jest.clearAllMocks();
  lawyerApi.getLeads.mockResolvedValue([]);
  lawyerApi.getClients.mockResolvedValue({ accepted: [], inProgress: [], closed: [] });
});

describe('Leads → View Details', () => {
  it('navigates to LeadDetails with the tapped lead case id', async () => {
    lawyerApi.getLeads.mockResolvedValue([lead('case-a'), lead('case-b')]);
    const navigate = jest.fn();
    const { root, done } = await mount(
      <LeadsScreen navigation={{ navigate } as any} route={{} as any} />,
    );

    await act(async () => {
      find(root, 'lead-view-details-case-b').props.onPress();
    });

    expect(navigate).toHaveBeenCalledWith('LeadDetails', { caseId: 'case-b' });
    done();
  });

  it('does not invent a match percentage the backend did not send', async () => {
    lawyerApi.getLeads.mockResolvedValue([lead('case-a')]);
    const { root, done } = await mount(
      <LeadsScreen navigation={{ navigate: jest.fn() } as any} route={{} as any} />,
    );

    expect(textOf(root)).not.toContain('% Match');
    done();
  });
});

describe('LeadDetailsScreen', () => {
  const renderDetails = (caseId = 'case-1', wait = true) =>
    mount(
      <LeadDetailsScreen
        navigation={{ navigate: jest.fn(), goBack: jest.fn() } as any}
        route={{ key: 'k', name: 'LeadDetails', params: { caseId } } as any}
      />,
      wait,
    );

  it('shows a loading state while the case is fetched', async () => {
    casesApi.getById.mockReturnValue(new Promise(() => {}));
    const { root, done } = await renderDetails('case-1', false);

    expect(find(root, 'detail-loading')).toBeDefined();
    done();
  });

  it('loads the lead by its id and shows client, case, documents and request status', async () => {
    casesApi.getById.mockResolvedValue(legalCase());
    const { root, done } = await renderDetails('case-1');

    expect(casesApi.getById).toHaveBeenCalledWith('case-1');
    expect(textOf(find(root, 'lead-client-name'))).toBe('Ajith');
    expect(textOf(find(root, 'lead-case-title'))).toBe('Divorce due to mental cruelty');
    const all = textOf(root);
    expect(all).toContain('Family Court, Visakhapatnam');
    expect(all).toContain('petition.pdf');
    expect(textOf(find(root, 'lead-request-status'))).toContain('Pending');
    expect(find(root, 'lead-details-accept')).toBeDefined();
    done();
  });

  it('does not crash on missing optional fields', async () => {
    casesApi.getById.mockResolvedValue(
      legalCase({
        client: 'client-1',
        description: '',
        preferredCourt: '',
        location: '',
        urgency: '',
        documents: undefined as any,
        lawyerRequests: undefined,
      }),
    );
    const { root, done } = await renderDetails();

    const all = textOf(root);
    expect(all).toContain('Not specified');
    expect(all).toContain('No documents have been uploaded for this case.');
    expect(all).toContain('The client has not added a description.');
    done();
  });

  it.each([
    [403, 'Forbidden', 'Access restricted'],
    [404, 'Case not found.', 'Not found'],
    [409, 'This case has already been accepted by another lawyer.', 'This case has already been accepted by another lawyer.'],
  ])('handles HTTP %s without showing raw errors', async (status, message, expected) => {
    casesApi.getById.mockRejectedValue(httpError(status, message));
    const { root, done } = await renderDetails();

    expect(find(root, 'detail-error')).toBeDefined();
    expect(textOf(root)).toContain(expected);
    expect(find(root, 'lead-details')).toBeUndefined();
    done();
  });

  it('retries a server error, then shows a retryable error state', async () => {
    casesApi.getById.mockRejectedValue(httpError(500, 'boom'));
    const { root, done } = await renderDetails();

    for (let i = 0; i < 40 && !find(root, 'detail-error'); i += 1) {
      await act(async () => {
        await new Promise<void>(resolve => setTimeout(resolve, 100));
      });
    }

    expect(casesApi.getById).toHaveBeenCalledTimes(3);
    expect(textOf(root)).toContain('Something went wrong');
    expect(textOf(root)).toContain('Try');
    done();
  }, 10000);

  it('shows a network failure as a connection problem', async () => {
    const config = { headers: new AxiosHeaders() };
    casesApi.getById.mockRejectedValue(
      new AxiosError('Network Error', 'ERR_NETWORK', config as any, {}),
    );
    const { root, done } = await renderDetails();

    for (let i = 0; i < 40 && !find(root, 'detail-error'); i += 1) {
      await act(async () => {
        await new Promise<void>(resolve => setTimeout(resolve, 100));
      });
    }

    expect(textOf(root)).toContain('Connection problem');
    done();
  }, 10000);

  it('shows a closed lead without accept or decline', async () => {
    casesApi.getById.mockResolvedValue(
      legalCase({ myRequestStatus: 'Unavailable' as any, status: 'Accepted' as any }),
    );
    const { root, done } = await renderDetails();

    expect(find(root, 'lead-details-accept')).toBeUndefined();
    expect(textOf(root)).toContain('no longer available');
    done();
  });
});

describe('Clients → View Client', () => {
  it('navigates with the row client id and case id, not a list index', async () => {
    lawyerApi.getClients.mockResolvedValue({
      accepted: [row('case-1', 'client-1'), row('case-2', 'client-1')],
      inProgress: [],
      closed: [],
    });
    const navigate = jest.fn();
    const { root, done } = await mount(
      <LawyerClientsScreen navigation={{ navigate } as any} route={{} as any} />,
    );

    await act(async () => {
      find(root, 'client-view-case-2').props.onPress();
    });

    expect(navigate).toHaveBeenCalledWith('LawyerClientDetails', {
      clientId: 'client-1',
      caseId: 'case-2',
    });
    done();
  });

  it('shows no fabricated category, location or court', async () => {
    lawyerApi.getClients.mockResolvedValue({
      accepted: [row('case-1', 'client-1')],
      inProgress: [],
      closed: [],
    });
    const { root, done } = await mount(
      <LawyerClientsScreen navigation={{ navigate: jest.fn() } as any} route={{} as any} />,
    );

    const all = textOf(root);
    expect(all).not.toContain('Visakhapatnam');
    expect(all).not.toContain('Any Court');
    expect(all).not.toContain('b4b1cc2f');
    expect(all).toContain('Not specified');
    done();
  });
});

describe('LawyerClientDetailsScreen', () => {
  const renderClient = (clientId: string, caseId: string) =>
    mount(
      <LawyerClientDetailsScreen
        navigation={{ navigate: jest.fn(), goBack: jest.fn(), replace: jest.fn() } as any}
        route={{ key: 'k', name: 'LawyerClientDetails', params: { clientId, caseId } } as any}
      />,
    );

  const detail = {
    client: {
      _id: 'client-1',
      fullName: 'Ajith',
      profileImage: '',
      mobile: '9876543210',
      email: 'ajith@example.test',
    },
    caseHistory: [],
    documents: [],
  };

  it('loads the client and the case by their own ids', async () => {
    lawyerApi.getClientDetails.mockResolvedValue(detail);
    casesApi.getById.mockResolvedValue(
      legalCase({
        status: 'Accepted' as any,
        acceptedAt: '2026-09-19T10:00:00.000Z',
        milestones: [{ title: 'Case Posted', isCompleted: true, date: '2026-09-18T10:00:00.000Z' }],
      }),
    );
    const { root, done } = await renderClient('client-1', 'case-1');

    expect(lawyerApi.getClientDetails).toHaveBeenCalledWith('client-1');
    expect(casesApi.getById).toHaveBeenCalledWith('case-1');
    expect(textOf(find(root, 'client-details-name'))).toBe('Ajith');
    expect(textOf(find(root, 'client-details-case-title'))).toBe('Divorce due to mental cruelty');
    const all = textOf(root);
    expect(all).toContain('9876543210');
    expect(all).toContain('ajith@example.test');
    expect(textOf(find(root, 'client-details-timeline'))).toContain('Case Posted');
    expect(find(root, 'client-details-start')).toBeDefined();
    done();
  });

  it('refuses to show a case that belongs to a different client', async () => {
    lawyerApi.getClientDetails.mockResolvedValue(detail);
    casesApi.getById.mockResolvedValue(
      legalCase({ client: { _id: 'client-2', fullName: 'Someone else' } as any }),
    );
    const { root, done } = await renderClient('client-1', 'case-1');

    expect(find(root, 'client-details')).toBeUndefined();
    expect(textOf(root)).not.toContain('Someone else');
    expect(textOf(root)).toContain('This case does not belong to this client.');
    done();
  });

  it('shows access restricted on 403', async () => {
    lawyerApi.getClientDetails.mockRejectedValue(httpError(403, 'nope'));
    casesApi.getById.mockResolvedValue(legalCase());
    const { root, done } = await renderClient('client-1', 'case-1');

    expect(textOf(root)).toContain('Access restricted');
    done();
  });
});

describe('Contact Support', () => {
  it('dials the support phone number', async () => {
    const open = jest.spyOn(Linking, 'openURL').mockResolvedValue(true);
    const { root, done } = await mount(<ContactSupportRows />);

    expect(textOf(root)).toContain('9966888428');
    await act(async () => {
      find(root, 'support-phone').props.onPress();
    });

    expect(open).toHaveBeenCalledWith('tel:9966888428');
    done();
  });

  it('opens a mail to the support address', async () => {
    const open = jest.spyOn(Linking, 'openURL').mockResolvedValue(true);
    const { root, done } = await mount(<ContactSupportRows />);

    expect(textOf(root)).toContain('kkdigitalteamwork@gmail.com');
    await act(async () => {
      find(root, 'support-email').props.onPress();
    });

    expect(open).toHaveBeenCalledWith('mailto:kkdigitalteamwork@gmail.com');
    done();
  });

  it('explains when no app can handle the link', async () => {
    jest.spyOn(Linking, 'openURL').mockRejectedValue(new Error('no handler'));
    const { root, done } = await mount(<ContactSupportRows />);

    await act(async () => {
      find(root, 'support-email').props.onPress();
    });
    await settle();

    expect(textOf(root)).toContain('No email app is available');
    done();
  });
});
