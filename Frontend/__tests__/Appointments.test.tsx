jest.mock('../src/api/apiClient', () => ({
  apiClient: { get: jest.fn(), post: jest.fn(), put: jest.fn(), delete: jest.fn() },
  unwrap: (response: { data: { data: unknown } }) => response.data.data,
  UPLOAD_TIMEOUT_MS: 120000,
}));

import React from 'react';
import ReactTestRenderer from 'react-test-renderer';

import { apiClient } from '../src/api/apiClient';
import { appointmentsApi } from '../src/api/appointmentsApi';
import { BookConsultationSheet } from '../src/components/appointments/BookConsultationSheet';
import { GenieAiDisclaimer } from '../src/components/ui/GenieAiDisclaimer';

const act = ReactTestRenderer.act;

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children.map(child => (typeof child === 'string' ? child : textOf(child))).join('');

const byLabel = (root: ReactTestRenderer.ReactTestInstance, label: string) =>
  root.findAll(n => n.props.accessibilityLabel === label && typeof n.type !== 'string')[0];

beforeEach(() => jest.clearAllMocks());

describe('appointmentsApi', () => {
  it('books with the advocate id the backend expects', async () => {
    (apiClient.post as jest.Mock).mockResolvedValue({ data: { data: { _id: 'a1' } } });

    await appointmentsApi.book({
      lawyer: 'lawyer-1',
      date: '2026-10-01T00:00:00.000Z',
      timeSlot: '10:00 AM',
      mode: 'Chat',
    });

    expect(apiClient.post).toHaveBeenCalledWith('/appointments', {
      lawyer: 'lawyer-1',
      date: '2026-10-01T00:00:00.000Z',
      timeSlot: '10:00 AM',
      mode: 'Chat',
    });
  });

  it('cancels by id', async () => {
    (apiClient.delete as jest.Mock).mockResolvedValue({ data: { data: null } });

    await appointmentsApi.cancel('a1');

    expect(apiClient.delete).toHaveBeenCalledWith('/appointments/a1');
  });
});

describe('BookConsultationSheet', () => {
  const mount = async (onSubmit = jest.fn()) => {
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(
        <BookConsultationSheet
          visible
          lawyerName="Adv. Sneha"
          isSubmitting={false}
          onClose={jest.fn()}
          onSubmit={onSubmit}
        />,
      );
    });
    return { root: renderer.root, onSubmit, done: () => act(() => renderer.unmount()) };
  };

  it('offers only the two modes the backend accepts', async () => {
    const { root, done } = await mount();

    expect(byLabel(root, 'Chat')).toBeDefined();
    expect(byLabel(root, 'In person')).toBeDefined();
    expect(byLabel(root, 'Video')).toBeUndefined();
    expect(byLabel(root, 'Voice')).toBeUndefined();
    done();
  });

  it('cannot confirm until a time slot is chosen', async () => {
    const { root, onSubmit, done } = await mount();

    expect(byLabel(root, 'Confirm booking').props.accessibilityState.disabled).toBe(true);

    await act(async () => byLabel(root, 'Time 10:00 AM').props.onPress());

    expect(byLabel(root, 'Confirm booking').props.accessibilityState.disabled).toBe(false);

    await act(async () => byLabel(root, 'Confirm booking').props.onPress());

    expect(onSubmit).toHaveBeenCalledTimes(1);
    const [input] = onSubmit.mock.calls[0];
    expect(input.timeSlot).toBe('10:00 AM');
    expect(input.mode).toBe('Chat');
    expect(new Date(input.date).getTime()).not.toBeNaN();
    done();
  });

  it('books the day the user picked, never a past date', async () => {
    const { root, onSubmit, done } = await mount();

    await act(async () => byLabel(root, 'Time 02:00 PM').props.onPress());
    await act(async () => byLabel(root, 'Confirm booking').props.onPress());

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    expect(new Date(onSubmit.mock.calls[0][0].date).getTime()).toBeGreaterThanOrEqual(
      startOfToday.getTime(),
    );
    done();
  });
});

describe('GenieAiDisclaimer', () => {
  it('separates AI information from legal advice', async () => {
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(<GenieAiDisclaimer />);
    });

    const text = textOf(renderer.root);
    expect(text).toContain('not legal advice');
    expect(text).toContain('advocate');
    act(() => renderer.unmount());
  });
});
