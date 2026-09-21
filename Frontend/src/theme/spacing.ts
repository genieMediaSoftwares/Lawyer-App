/**
 * A 4pt scale. Every margin and padding in the app is one of these, which is
 * what keeps spacing consistent across screens written at different times.
 */
export const spacing = {
  xxs: 2,
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
  huge: 40,
} as const;

/** Fixed dimensions shared by the form components. */
export const sizing = {
  /** Input and button height. Identical on purpose so stacked controls align. */
  controlHeight: 56,
  /** Corner radius for inputs, buttons and cards. */
  radius: 14,
  radiusSmall: 10,
  radiusPill: 999,
  /** Hairline borders. */
  borderWidth: 1,
  /** Leading icon inside an input. */
  iconSize: 20,
  /** Horizontal page gutter. */
  screenPadding: 24,
} as const;

export const radius = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  full: 9999,
} as const;
