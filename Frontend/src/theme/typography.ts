import { Platform, TextStyle } from 'react-native';

const family = Platform.select({
  ios: 'System',
  android: 'sans-serif',
  default: 'System',
});

const familyMedium = Platform.select({
  ios: 'System',
  android: 'sans-serif-medium',
  default: 'System',
});

const familyBold = Platform.select({
  ios: 'System',
  android: 'sans-serif-medium',
  default: 'System',
});

export type TypographyVariant =
  | 'display'
  | 'heading-xl'
  | 'heading-lg'
  | 'heading-md'
  | 'heading-sm'
  | 'body-lg'
  | 'body-md'
  | 'body-sm'
  | 'caption'
  | 'label'
  | 'brand'
  | 'title'
  | 'subtitle'
  | 'button'
  | 'link';

export const typographyClasses: Record<TypographyVariant, string> = {
  display: 'text-4xl font-bold tracking-wider',
  'heading-xl': 'text-3xl font-bold tracking-tight',
  'heading-lg': 'text-2xl font-bold tracking-tight',
  'heading-md': 'text-xl font-semibold',
  'heading-sm': 'text-lg font-semibold',
  'body-lg': 'text-base font-normal',
  'body-md': 'text-sm font-normal',
  'body-sm': 'text-xs font-normal',
  caption: 'text-xs font-normal text-textMuted',
  label: 'text-sm font-semibold',
  brand: 'text-3xl font-bold tracking-widest',
  title: 'text-2xl font-bold',
  subtitle: 'text-base font-normal',
  button: 'text-base font-bold tracking-wide',
  link: 'text-sm font-semibold text-gold',
};

export const typography = {
  fontFamily: {
    regular: family,
    medium: familyMedium,
    bold: familyBold,
  },
  fontSize: {
    xs: 12,
    sm: 14,
    base: 16,
    md: 16,
    lg: 18,
    xl: 22,
    '2xl': 24,
    xxl: 28,
    display: 34,
  },
  fontWeight: {
    regular: '400' as const,
    medium: '500' as const,
    semibold: '600' as const,
    bold: '700' as const,
  },
  brand: {
    fontFamily: familyMedium,
    fontSize: 34,
    fontWeight: '700',
    letterSpacing: 4,
  } as TextStyle,

  title: {
    fontFamily: familyMedium,
    fontSize: 28,
    fontWeight: '700',
    letterSpacing: 0.2,
  } as TextStyle,

  subtitle: {
    fontFamily: family,
    fontSize: 15,
    fontWeight: '400',
    letterSpacing: 0.1,
  } as TextStyle,

  label: {
    fontFamily: familyMedium,
    fontSize: 15,
    fontWeight: '600',
    letterSpacing: 0.2,
  } as TextStyle,

  input: {
    fontFamily: family,
    fontSize: 16,
    fontWeight: '400',
  } as TextStyle,

  button: {
    fontFamily: familyMedium,
    fontSize: 17,
    fontWeight: '700',
    letterSpacing: 0.4,
  } as TextStyle,

  caption: {
    fontFamily: family,
    fontSize: 13,
    fontWeight: '400',
    letterSpacing: 0.1,
  } as TextStyle,

  link: {
    fontFamily: familyMedium,
    fontSize: 14,
    fontWeight: '600',
  } as TextStyle,
};
