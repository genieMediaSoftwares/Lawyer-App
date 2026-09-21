/**
 * Focus hygiene for the web build.
 *
 * ── The problem this solves ───────────────────────────────────────────────
 *
 * `@react-navigation/elements` renders every screen with
 * `aria-hidden={!focused}` (see its `Screen.js`). So the moment you navigate,
 * the screen you came from is marked hidden from assistive technology.
 *
 * But the control you tapped to navigate still holds DOM focus, and it is
 * inside that screen. Chrome refuses to hide a subtree containing the focused
 * element, and logs:
 *
 *   "Blocked aria-hidden on an element because its descendant retained focus.
 *    The focus must not be hidden from assistive technology users."
 *
 * The library is right to hide the inactive screen, and the browser is right
 * to refuse. What is wrong is the focus left behind — which is ours, and is a
 * real bug either way: a screen-reader user who navigates and then presses Tab
 * would otherwise resume from a control that is no longer on screen.
 *
 * ── Why a capture-phase listener and not just `onStateChange` ─────────────
 *
 * Timing. `aria-hidden` is written during the React commit that the press
 * triggers, and the browser evaluates it there and then. `onStateChange` runs
 * in an effect *after* that commit, so blurring from it releases focus a beat
 * too late — the attribute has already been blocked and the warning already
 * logged.
 *
 * Releasing focus in the capture phase of the click puts it before React's own
 * handler, and therefore before the navigation, the re-render and the
 * attribute. By the time the old screen is hidden nothing inside it is
 * focused, so there is nothing to block.
 */

/**
 * Elements whose focus is theirs to keep.
 *
 * Blurring a text field the moment it is clicked would make it impossible to
 * type, so form controls are never touched. Only activation controls —
 * buttons, links, pressables — release focus here.
 */
const isFormField = (element: Element): boolean => {
  const tag = element.tagName;
  return (
    tag === 'INPUT' ||
    tag === 'TEXTAREA' ||
    tag === 'SELECT' ||
    (element as HTMLElement).isContentEditable
  );
};

/**
 * Drops DOM focus from whatever currently holds it.
 *
 * A no-op when focus is already on `<body>`, so it never fights a browser that
 * has nothing focused.
 *
 * Focus is released, not moved. Sending it somewhere is the caller's business,
 * and claiming it here would undo a screen that legitimately focused its own
 * first field.
 */
export const blurActiveElement = (): void => {
  if (typeof document === 'undefined') {
    return;
  }

  const active = document.activeElement;

  if (
    active instanceof HTMLElement &&
    active !== document.body &&
    !isFormField(active)
  ) {
    active.blur();
  }
};

let installed = false;

/**
 * Installs the click-time focus release. Call once, from the app root.
 *
 * Returns its own uninstaller, so the caller can treat it like any other
 * subscription.
 *
 * ── Pointer clicks only ───────────────────────────────────────────────────
 *
 * `event.detail` counts clicks for a real pointer press and is `0` for a click
 * synthesised by pressing Enter or Space on a focused control. Keyboard
 * activation therefore keeps its focus exactly where it was, which is the
 * whole point of keyboard navigation — the focus ring must not vanish under
 * someone who is using it to find their way.
 *
 * For a mouse or a touch this matches what Safari and Firefox already do:
 * neither leaves a button focused after a click. Only Chromium does, which is
 * why only Chromium reports the warning.
 */
export const installWebFocusHygiene = (): (() => void) => {
  if (typeof document === 'undefined' || installed) {
    return () => undefined;
  }

  installed = true;

  const onClickCapture = (event: MouseEvent): void => {
    // Keyboard-synthesised click: leave focus alone.
    if (event.detail === 0) {
      return;
    }
    blurActiveElement();
  };

  document.addEventListener('click', onClickCapture, true);

  return () => {
    document.removeEventListener('click', onClickCapture, true);
    installed = false;
  };
};
