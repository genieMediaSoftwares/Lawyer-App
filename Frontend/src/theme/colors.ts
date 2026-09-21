/**
 * The typed view of the palette.
 *
 * The values live in `tokens.js`, which `tailwind.config.js` also reads. This
 * file exists so TypeScript sources can reach them for the props that take a
 * colour rather than a class name — `react-native-svg` fills, React
 * Navigation's theme, `placeholderTextColor`, `StatusBar`, an Animated
 * interpolation's output range.
 *
 * Reaching for a colour here to build a StyleSheet is the thing this migration
 * removed. If a `className` can express it, use the class.
 */
import tokens from './tokens.js';

export const colors = tokens.colors;

export type AppColors = typeof colors;
