import React from 'react';
import { Share } from 'react-native';
import ReactTestRenderer from 'react-test-renderer';

import { ProfileImageViewer } from '../src/components/ui/ProfileImageViewer';

const act = ReactTestRenderer.act;

const textOf = (node: ReactTestRenderer.ReactTestInstance): string =>
  node.children.map(child => (typeof child === 'string' ? child : textOf(child))).join('');

describe('ProfileImageViewer', () => {
  it('shows the signed-in user\'s own name as the title, not a hardcoded label', async () => {
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(
        <ProfileImageViewer
          visible
          onClose={jest.fn()}
          imageUri="/uploads/profiles/a.jpg"
          name="Ajith Kumar"
        />,
      );
    });

    expect(textOf(renderer.root)).toContain('Ajith Kumar');
    expect(textOf(renderer.root)).not.toContain('Profile picture');
    act(() => renderer.unmount());
  });

  it('falls back to a generic label when no name is available', async () => {
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(
        <ProfileImageViewer visible onClose={jest.fn()} imageUri={null} />,
      );
    });

    expect(textOf(renderer.root)).toContain('Profile photo');
    act(() => renderer.unmount());
  });

  it('only shows the edit control when the caller provides onEdit', async () => {
    const onEdit = jest.fn();
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(
        <ProfileImageViewer
          visible
          onClose={jest.fn()}
          imageUri="/uploads/profiles/a.jpg"
          name="Adv. Sneha"
          onEdit={onEdit}
        />,
      );
    });

    const editButton = renderer.root.findByProps({
      accessibilityLabel: 'Change profile photo',
    });
    await act(async () => {
      editButton.props.onPress();
    });
    expect(onEdit).toHaveBeenCalledTimes(1);
    act(() => renderer.unmount());
  });

  it('does not render an edit control when onEdit is not provided', async () => {
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(
        <ProfileImageViewer
          visible
          onClose={jest.fn()}
          imageUri="/uploads/profiles/a.jpg"
          name="Adv. Sneha"
        />,
      );
    });

    expect(() =>
      renderer.root.findByProps({ accessibilityLabel: 'Change profile photo' }),
    ).toThrow();
    act(() => renderer.unmount());
  });

  it('closes when the back control is pressed', async () => {
    const onClose = jest.fn();
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(
        <ProfileImageViewer visible onClose={onClose} imageUri="/uploads/profiles/a.jpg" />,
      );
    });

    const backButton = renderer.root.findByProps({
      accessibilityLabel: 'Close profile photo',
    });
    await act(async () => {
      backButton.props.onPress();
    });
    expect(onClose).toHaveBeenCalledTimes(1);
    act(() => renderer.unmount());
  });

  it('shares the resolved photo url when Share is tapped', async () => {
    const share = jest.spyOn(Share, 'share').mockResolvedValue({ action: 'sharedAction' } as any);
    let renderer!: ReactTestRenderer.ReactTestRenderer;
    await act(async () => {
      renderer = ReactTestRenderer.create(
        <ProfileImageViewer
          visible
          onClose={jest.fn()}
          imageUri="/uploads/profiles/a.jpg"
          name="Adv. Sneha"
        />,
      );
    });

    const shareButton = renderer.root.findByProps({
      accessibilityLabel: 'Share profile photo',
    });
    await act(async () => {
      shareButton.props.onPress();
    });

    expect(share).toHaveBeenCalledTimes(1);
    const arg = share.mock.calls[0][0] as { url: string };
    expect(arg.url).toContain('/uploads/profiles/a.jpg');
    share.mockRestore();
    act(() => renderer.unmount());
  });
});
