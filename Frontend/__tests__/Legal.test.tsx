jest.mock('../src/api/apiClient', () => ({
  apiClient: { get: jest.fn(), post: jest.fn() },
  unwrap: (response: { data: { data: unknown } }) => response.data.data,
  UPLOAD_TIMEOUT_MS: 120000,
}));

import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

import { apiClient } from '../src/api/apiClient';
import { legalApi } from '../src/api/legalApi';
import { LegalAcceptanceGate } from '../src/components/legal/LegalAcceptanceGate';
import { LegalDocumentView } from '../src/components/legal/LegalDocumentView';
import type { LegalDocument } from '../src/types/legal';

const act = ReactTestRenderer.act;

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children.map(child => (typeof child === 'string' ? child : textOf(child))).join('');

const settle = async () => {
  for (let i = 0; i < 4; i += 1) {
    await act(async () => {
      await new Promise<void>(resolve => setTimeout(resolve, 10));
    });
  }
};

const doc = (extra: Partial<LegalDocument> = {}): LegalDocument =>
  ({
    _id: 'doc-1',
    type: 'client_terms',
    version: '1.0',
    title: 'Client Terms',
    content: 'The published terms text.',
    effectiveDate: '2026-10-01T00:00:00.000Z',
    audience: 'client',
    requiresAcceptance: true,
    legallyReviewed: true,
    updatedAt: '2026-09-20T00:00:00.000Z',
    ...extra,
  } as LegalDocument);

const mount = async (ui: React.ReactElement) => {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false, gcTime: 0 } },
  });
  let renderer!: ReactTestRenderer.ReactTestRenderer;
  await act(async () => {
    renderer = ReactTestRenderer.create(
      <QueryClientProvider client={client}>{ui}</QueryClientProvider>,
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

beforeEach(() => jest.clearAllMocks());

describe('legalApi', () => {
  it('records acceptance of a specific version', async () => {
    (apiClient.post as jest.Mock).mockResolvedValue({ data: { data: {} } });

    await legalApi.accept('client_terms', '1.0');

    const [url, body] = (apiClient.post as jest.Mock).mock.calls[0];
    expect(url).toBe('/legal/accept');
    expect(body.type).toBe('client_terms');
    expect(body.version).toBe('1.0');
  });
});

describe('LegalDocumentView', () => {
  it('shows the published version and its effective date', async () => {
    (apiClient.get as jest.Mock).mockResolvedValue({ data: { data: doc() } });

    const { root, done } = await mount(<LegalDocumentView type="client_terms" />);

    const text = textOf(root);
    expect(text).toContain('The published terms text.');
    expect(text).toContain('Version 1.0');
    done();
  });

  it('says so when nothing is published instead of showing invented text', async () => {
    (apiClient.get as jest.Mock).mockRejectedValue({
      isAxiosError: true,
      response: {
        status: 404,
        data: { success: false, message: 'That document has not been published yet.' },
      },
    });

    const { root, done } = await mount(<LegalDocumentView type="privacy_policy" />);

    expect(textOf(root)).toContain('Not published yet');
    done();
  });

  it('marks text that has not been through legal review', async () => {
    (apiClient.get as jest.Mock).mockResolvedValue({
      data: { data: doc({ legallyReviewed: false }) },
    });

    const { root, done } = await mount(<LegalDocumentView type="client_terms" />);

    expect(textOf(root)).toContain('awaiting legal review');
    done();
  });
});

describe('LegalAcceptanceGate', () => {
  it('shows nothing when there is nothing to accept', async () => {
    (apiClient.get as jest.Mock).mockResolvedValue({ data: { data: [] } });

    const { root, done } = await mount(<LegalAcceptanceGate />);

    expect(textOf(root)).toBe('');
    done();
  });

  it('never blocks the app when the legal service cannot be reached', async () => {
    (apiClient.get as jest.Mock).mockRejectedValue(new Error('offline'));

    const { root, done } = await mount(<LegalAcceptanceGate />);

    expect(textOf(root)).toBe('');
    done();
  });

  it('asks for acceptance and records the pending version', async () => {
    (apiClient.get as jest.Mock).mockResolvedValue({ data: { data: [doc()] } });
    (apiClient.post as jest.Mock).mockResolvedValue({ data: { data: {} } });

    const { root, done } = await mount(<LegalAcceptanceGate />);

    expect(textOf(root)).toContain('Client Terms');

    const button = root.findAll(
      n => n.props.accessibilityLabel === 'Accept and continue' && typeof n.type !== 'string',
    )[0];
    await act(async () => button.props.onPress());
    await settle();

    expect(apiClient.post).toHaveBeenCalledWith(
      '/legal/accept',
      expect.objectContaining({ type: 'client_terms', version: '1.0' }),
    );
    done();
  });
});
