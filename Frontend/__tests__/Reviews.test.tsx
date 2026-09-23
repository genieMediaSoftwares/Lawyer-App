jest.mock('../src/api/apiClient', () => ({
  apiClient: { get: jest.fn(), post: jest.fn(), put: jest.fn() },
  unwrap: (response: { data: { data: unknown } }) => response.data.data,
  UPLOAD_TIMEOUT_MS: 120000,
}));

import React from 'react';
import ReactTestRenderer from 'react-test-renderer';

import { apiClient } from '../src/api/apiClient';
import { reviewsApi } from '../src/api/reviewsApi';
import { ReviewCard } from '../src/components/reviews/ReviewCard';
import { WriteReviewSheet } from '../src/components/reviews/WriteReviewSheet';
import type { LawyerReview } from '../src/types/domain';

const act = ReactTestRenderer.act;

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children.map(child => (typeof child === 'string' ? child : textOf(child))).join('');

const byLabel = (root: ReactTestRenderer.ReactTestInstance, label: string) =>
  root.findAll(n => n.props.accessibilityLabel === label && typeof n.type !== 'string')[0];

const review = (extra: Partial<LawyerReview> = {}): LawyerReview =>
  ({
    _id: 'r1',
    lawyer: 'lawyer-1',
    client: { _id: 'client-1', fullName: 'Ajith', profileImage: '' },
    rating: 4,
    review: 'Clear and patient advice.',
    createdAt: '2026-09-01T10:00:00.000Z',
    updatedAt: '2026-09-01T10:00:00.000Z',
    ...extra,
  } as LawyerReview);

beforeEach(() => jest.clearAllMocks());

describe('reviewsApi', () => {
  it('posts a review in the shape the backend expects', async () => {
    (apiClient.post as jest.Mock).mockResolvedValue({ data: { data: review() } });

    await reviewsApi.create({ lawyerId: 'lawyer-1', rating: 5, review: 'Excellent' });

    expect(apiClient.post).toHaveBeenCalledWith('/reviews', {
      lawyerId: 'lawyer-1',
      rating: 5,
      review: 'Excellent',
    });
  });

  it('asks for one advocate\'s reviews by id', async () => {
    (apiClient.get as jest.Mock).mockResolvedValue({ data: { data: [review()] } });

    const result = await reviewsApi.listForLawyer('lawyer-1');

    expect(apiClient.get).toHaveBeenCalledWith('/reviews', {
      params: { lawyerId: 'lawyer-1' },
    });
    expect(result).toHaveLength(1);
  });

  it('sends a reply to the review it belongs to', async () => {
    (apiClient.put as jest.Mock).mockResolvedValue({ data: { data: review() } });

    await reviewsApi.reply('r1', 'Thank you');

    expect(apiClient.put).toHaveBeenCalledWith('/reviews/r1/reply', { reply: 'Thank you' });
  });
});

describe('WriteReviewSheet', () => {
  const mount = async (onSubmit = jest.fn()) => {
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(
        <WriteReviewSheet
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

  it('keeps submit disabled until a rating and text are given', async () => {
    const { root, done } = await mount();

    expect(byLabel(root, 'Submit review').props.accessibilityState.disabled).toBe(true);

    await act(async () => byLabel(root, 'Rate 4 stars').props.onPress());
    await act(async () => byLabel(root, 'Your review').props.onChangeText('  Helpful  '));

    expect(byLabel(root, 'Submit review').props.accessibilityState.disabled).toBe(false);
    done();
  });

  it('submits the rating with trimmed text', async () => {
    const { root, onSubmit, done } = await mount();

    await act(async () => byLabel(root, 'Rate 5 stars').props.onPress());
    await act(async () => byLabel(root, 'Your review').props.onChangeText('  Great  '));
    await act(async () => byLabel(root, 'Submit review').props.onPress());

    expect(onSubmit).toHaveBeenCalledWith({ rating: 5, review: 'Great' });
    done();
  });
});

describe('ReviewCard', () => {
  it('shows the advocate reply and hides the reply action once answered', async () => {
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(
        <ReviewCard
          review={review({ reply: 'Thank you for the kind words.' })}
          onReply={jest.fn()}
        />,
      );
    });

    expect(textOf(renderer.root)).toContain('Thank you for the kind words.');
    expect(byLabel(renderer.root, "Reply to Ajith's review")).toBeUndefined();
    act(() => renderer.unmount());
  });

  it('offers a reply action on an unanswered review', async () => {
    const onReply = jest.fn();
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(<ReviewCard review={review()} onReply={onReply} />);
    });

    await act(async () => byLabel(renderer.root, "Reply to Ajith's review").props.onPress());

    expect(onReply).toHaveBeenCalledTimes(1);
    act(() => renderer.unmount());
  });
});
