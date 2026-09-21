import { Platform } from 'react-native';

/**
 * Platform predicates, named once.
 *
 * These exist because the same three checks were being spelled out inline in
 * animation configs and effect guards, where `Platform.OS !== 'web'` reads as
 * a magic string rather than as the thing it means. A single `Platform.OS`
 * check inside a component is still fine — these are for the cases that repeat.
 */
export const isWeb = Platform.OS === 'web';
export const isNative = !isWeb;
export const isIOS = Platform.OS === 'ios';
export const isAndroid = Platform.OS === 'android';

/**
 * Whether `Animated` may hand an animation to the native driver.
 *
 * ── Why this is false on web ──────────────────────────────────────────────
 *
 * There is no native animated module in a browser. Asking for one there makes
 * React Native Web log
 *
 *   "Animated: `useNativeDriver` is not supported because the native animated
 *    module is missing. Falling back to JS-based animation."
 *
 * on every animation, and then run it on the JS thread anyway. The fallback is
 * the same animation either way — the only difference is the warning — so the
 * driver is simply not requested where it cannot exist.
 *
 * On Android and iOS this stays `true`, which is what keeps opacity and
 * transform animations off the JS thread.
 *
 * **Only for animations the native driver can actually run**: `transform`,
 * `opacity` and other non-layout properties. An animation of `width`, `height`
 * or a colour must pass `useNativeDriver: false` on every platform, and those
 * call sites say so themselves rather than using this constant.
 */
export const USE_NATIVE_DRIVER = isNative;
