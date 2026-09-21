/**
 * Focus hygiene — the native half.
 *
 * There is no DOM on a device, so there is no focus to release and both of
 * these are no-ops. Metro and Vite resolve `webFocus.web.ts` ahead of this
 * file for the browser build, exactly as they do for `filePicker`,
 * `secureStorage` and `voiceRecorder`, so the browser-only code never reaches
 * a device bundle and never needs a runtime platform check.
 *
 * The browser half carries the explanation of what this is for.
 */

export const blurActiveElement = (): void => {
  // Intentionally empty. See webFocus.web.ts.
};

export const installWebFocusHygiene = (): (() => void) => {
  // Intentionally empty. See webFocus.web.ts.
  return () => undefined;
};
