import React from 'react';
import ReactTestRenderer from 'react-test-renderer';

import { RelevantCasesSection } from '../src/screens/lawyer/Research/RelevantCasesSection';
import type { RelevantCasesState } from '../src/types/lawyer';

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children.map(c => (typeof c === 'string' ? c : textOf(c))).join('');

const find = (root: ReactTestRenderer.ReactTestInstance, id: string) =>
  root.findAll(n => n.props.testID === id && typeof n.type !== 'string')[0];

const base: RelevantCasesState = {
  status: 'idle',
  query: '',
  jurisdiction: '',
  searchedAt: null,
  message: '',
  results: [],
};

const render = async (state: RelevantCasesState, onSearch = jest.fn(), canSearch = true) => {
  let renderer!: ReactTestRenderer.ReactTestRenderer;
  await ReactTestRenderer.act(async () => {
    renderer = ReactTestRenderer.create(
      <RelevantCasesSection state={state} canSearch={canSearch} isStarting={false} onSearch={onSearch} />,
    );
  });
  return renderer;
};

describe('RelevantCasesSection', () => {
  it('shows the failure message and no case cards when the search failed', async () => {
    const renderer = await render({
      ...base,
      status: 'failed',
      message: 'The case search could not be completed.',
    });
    const text = textOf(renderer.root);

    expect(text).toContain('The case search could not be completed.');
    expect(text).toContain('Retry Search');
    expect(text).not.toContain('Open source');
  });

  it('shows source, verification label and an unconfirmed-citation note', async () => {
    const renderer = await render({
      ...base,
      status: 'completed',
      results: [
        {
          caseTitle: 'A v B',
          citation: '',
          court: 'High Court',
          jurisdiction: 'India',
          decisionDate: '',
          relevanceSummary: 'May bear on the separation period.',
          legalPrinciple: '',
          sources: [{ url: 'https://example.org/a', name: 'example.org' }],
          verificationStatus: 'Search Result — Not Yet Verified',
          retrievedAt: new Date().toISOString(),
        },
      ],
    });
    const text = textOf(renderer.root);

    expect(text).toContain('A v B');
    expect(text).toContain('Official citation not confirmed.');
    expect(text).toContain('Search Result — Not Yet Verified');
    expect(text).toContain('Open source · example.org');
  });

  it('sends the refinement when searching again', async () => {
    const onSearch = jest.fn();
    const renderer = await render({ ...base, status: 'completed' }, onSearch);

    const inputs = renderer.root.findAll(n => n.props.accessibilityLabel === 'Refine case search' && typeof n.type !== 'string');
    await ReactTestRenderer.act(async () => {
      inputs[0].props.onChangeText('Supreme Court only');
    });
    await ReactTestRenderer.act(async () => {
      find(renderer.root, 'relevant-cases-search').props.onPress();
    });

    expect(onSearch).toHaveBeenCalledWith({ query: 'Supreme Court only', jurisdiction: undefined });
  });

  it('disables searching until an answer exists', async () => {
    const renderer = await render(base, jest.fn(), false);
    await ReactTestRenderer.act(async () => {
      renderer.root.findAll(n => n.props.accessibilityLabel === 'Relevant Cases' && typeof n.type !== 'string')[0].props.onPress();
    });

    expect(find(renderer.root, 'relevant-cases-search').props.disabled).toBe(true);
  });
});
