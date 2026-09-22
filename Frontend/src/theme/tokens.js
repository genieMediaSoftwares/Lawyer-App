// GenieLaw design system. Every colour in the app comes from here.
// Solid colours only: no transparent tints, gradients or glass effects.
// The one exception is `overlay`, the dimmed backdrop behind modals.
const accent = '#F5B900';

const colors = {
  background: '#000000',
  black: '#000000',
  surface: '#111111',
  surfaceSecondary: '#161616',
  surfaceAlt: '#161616',
  card: '#111111',
  inputBackground: '#111111',

  accent,
  gold: accent,
  goldBright: '#FFC61A',
  goldPressed: '#D9A400',
  // Formerly translucent gold washes; now solid neutral surfaces so gold is
  // used only for buttons, icons, active states and key numbers.
  goldMuted: '#161616',
  goldWash: '#242424',

  white: '#FFFFFF',
  textPrimary: '#FFFFFF',
  textSecondary: '#A1A1A1',
  textMuted: '#707070',

  border: '#242424',
  // Focus is shown with a lighter neutral border, never gold.
  borderFocused: '#4A4A4A',

  success: '#22C55E',
  warning: '#F59E0B',
  error: '#EF4444',
  info: '#3B82F6',

  // The one lawyer verification badge colour, used everywhere a verified
  // name appears (Instagram-style blue check, never gold/yellow).
  verifiedBadge: '#0095F6',

  // Solid dark tints for status pills and notices.
  successSurface: '#0E2A18',
  warningSurface: '#2B2008',
  errorSurface: '#2B0F0F',
  infoSurface: '#0F1B33',

  onGold: '#000000',
  onAccent: '#000000',

  overlay: 'rgba(0, 0, 0, 0.72)',
  disabled: '#2E2E2E',
  disabledText: '#707070',

  skeleton: '#161616',
  skeletonHighlight: '#1F1F1F',
};

const radius = {
  control: '10px',
  buttonSmall: '8px',
  card: '12px',
  badge: '14px',
  sheet: '20px',
  pill: '9999px',
};

const sizing = {
  control: '48px',
  touch: '44px',
  buttonSmall: '36px',
  iconButton: '40px',
  badgeHeight: '28px',
  tabHeight: '44px',
  bottomNavHeight: '64px',
  headerHeight: '56px',
  screenGutter: '16px',
};

module.exports = { colors, radius, sizing };

