/**
 * The Genie Law design tokens. THE single source of truth.
 *
 * This file is plain CommonJS on purpose: `tailwind.config.js` is loaded by
 * Node (via Metro and via PostCSS) and cannot require a `.ts` file, while the
 * TypeScript sources need the same values for the handful of props that take a
 * raw colour rather than a class name — `react-native-svg` fills,
 * `placeholderTextColor`, the React Navigation theme, `StatusBar`.
 *
 * So both halves of the app read from here:
 *
 *   tailwind.config.js  -> every `bg-*` / `text-*` / `border-*` class
 *   src/theme/colors.ts -> the typed export the .tsx files import
 *
 * Change a value here and it propagates to both. Nothing else defines a colour.
 */

/**
 * The palette: black, gold, white, plus four semantic hues.
 *
 * The semantic four are the only colours outside the identity. They carry
 * meaning that must not be mistaken for decoration — a failed request, an
 * overdue hearing, a live case — and are never used as accents.
 */
const colors = {
  /** Page background. Not pure black: #080808 keeps elevation readable. */
  background: '#080808',
  black: '#000000',
  /** Primary surface: sheets, headers, the tab bar. */
  surface: '#111111',
  /** Secondary surface: nested panels, chips, inactive segments. */
  surfaceAlt: '#171717',
  surfaceSecondary: '#171717',
  /** Cards. One step above the page, so a list reads as stacked objects. */
  card: '#1A1A1A',
  /** Input wells — darker than the card they sit on. */
  inputBackground: '#0B0B0B',

  /** The accent. Buttons, active navigation, selected states, the logo. */
  gold: '#DFA928',
  /** The lighter gold, for gradient tops and hover/press highlights. */
  goldBright: '#E7B735',
  /** Pressed state for gold surfaces. */
  goldPressed: '#C6931F',
  /** Gold at low opacity: focus rings, selected chips, AI accents. */
  goldMuted: 'rgba(223, 169, 40, 0.14)',
  /** A slightly stronger wash, for the AI card and progress tracks. */
  goldWash: 'rgba(223, 169, 40, 0.22)',

  /** Primary type. */
  white: '#FFFFFF',
  /** Supporting copy, helper text, placeholders. */
  textSecondary: '#BDBDBD',
  /** Type that must recede further: metadata, disabled labels, fine print. */
  textMuted: '#777777',

  /** Hairlines, input outlines, card edges. */
  border: '#2A2A2A',
  /** An input's outline once it has focus. */
  borderFocused: '#DFA928',

  /** Semantic. Meaning only — never used as an accent. */
  success: '#22C55E',
  warning: '#F59E0B',
  error: '#EF4444',
  info: '#3B82F6',

  /** Tinted surfaces for the semantic colours. */
  successSurface: 'rgba(34, 197, 94, 0.12)',
  warningSurface: 'rgba(245, 158, 11, 0.12)',
  errorSurface: 'rgba(239, 68, 68, 0.12)',
  infoSurface: 'rgba(59, 130, 246, 0.12)',

  /** Text drawn on top of gold. Always black — gold on white fails contrast. */
  onGold: '#000000',

  /** Scrims and disabled states. */
  overlay: 'rgba(0, 0, 0, 0.62)',
  disabled: '#3A3A3A',
  disabledText: '#8A8A8A',

  /** The base a skeleton shimmer runs over. */
  skeleton: '#1E1E1E',
  skeletonHighlight: '#262626',
};

/**
 * Named radii, layered on top of Tailwind's numeric scale rather than
 * replacing it. `rounded-xl` still means 12 — these add the intent:
 * `rounded-card` is the one to change when "all cards should be rounder".
 */
const radius = {
  control: '14px',
  card: '20px',
  sheet: '28px',
  pill: '9999px',
};

/**
 * Fixed dimensions the form controls share. Inputs and buttons are the same
 * height on purpose, so stacked controls align.
 */
const sizing = {
  control: '56px',
  /** The floor for anything tappable. */
  touch: '44px',
  screenGutter: '20px',
};

module.exports = { colors, radius, sizing };
