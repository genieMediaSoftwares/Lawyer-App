import React from 'react';
import ReactTestRenderer from 'react-test-renderer';

import {
  HOW_IT_WORKS_STEPS,
  HowItWorksCarousel,
} from '../src/components/HowItWorksCarousel';

const act = ReactTestRenderer.act;

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children.map(child => (typeof child === 'string' ? child : textOf(child))).join('');

const find = (root: ReactTestRenderer.ReactTestInstance, id: string) =>
  root.findAll(node => node.props.testID === id && typeof node.type !== 'string')[0];

const render = async () => {
  let renderer!: ReactTestRenderer.ReactTestRenderer;
  await act(async () => {
    renderer = ReactTestRenderer.create(<HowItWorksCarousel />);
  });
  return renderer;
};

const listOf = (root: ReactTestRenderer.ReactTestInstance) =>
  root.findAll(node => node.props.horizontal === true)[0];

describe('How It Works carousel', () => {
  it('has the five steps in order, each with its full text and number', async () => {
    const renderer = await render();
    const root = renderer.root;

    expect(HOW_IT_WORKS_STEPS.map(step => step.title)).toEqual([
      'Select Issue',
      'Case Details',
      'Upload Document',
      'Recommended Lawyer',
      'Review',
    ]);

    HOW_IT_WORKS_STEPS.forEach((step, index) => {
      const slide = find(root, `how-it-works-slide-${index}`);
      expect(textOf(slide)).toContain(step.title);
      expect(textOf(slide)).toContain(step.description);
      expect(textOf(slide)).toContain(String(index + 1));
    });

    act(() => renderer.unmount());
  });

  it('renders a single horizontal scroll view containing all steps side-by-side', async () => {
    const renderer = await render();
    const list = listOf(renderer.root);

    expect(list.props.horizontal).toBe(true);
    expect(list.props.showsHorizontalScrollIndicator).toBe(false);
    act(() => renderer.unmount());
  });
});
