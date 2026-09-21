import React from 'react';
import { Text, TextProps } from 'react-native';

/**
 * Every piece of type in the app.
 *
 * The variant picks a size and weight from the scale in `tailwind.config.js`;
 * `tone` picks a colour from the palette. Splitting the two is deliberate — a
 * heading in gold and a heading in white are the same heading, so they should
 * not be two variants.
 *
 * Anything else (alignment, margin, `flex-1`) goes through `className`, which
 * is merged last and therefore wins.
 */

export type GenieTextVariant =
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
  | 'button'
  | 'brand';

export type GenieTextTone =
  | 'primary'
  | 'secondary'
  | 'muted'
  | 'gold'
  | 'on-gold'
  | 'success'
  | 'warning'
  | 'error'
  | 'info';

const VARIANTS: Record<GenieTextVariant, string> = {
  display: 'text-display font-bold',
  'heading-xl': 'text-head-xl font-bold',
  'heading-lg': 'text-head-lg font-bold',
  'heading-md': 'text-head-md font-semibold',
  'heading-sm': 'text-head-sm font-semibold',
  'body-lg': 'text-body-lg font-normal',
  'body-md': 'text-body-md font-normal',
  'body-sm': 'text-body-sm font-normal',
  caption: 'text-caption font-normal',
  label: 'text-body-sm font-semibold',
  button: 'text-body-lg font-bold tracking-wide',
  // The wordmark. Letter-spaced, and the only variant that is a brand asset
  // rather than a reading size.
  brand: 'text-head-md font-bold tracking-[2px]',
};

const TONES: Record<GenieTextTone, string> = {
  primary: 'text-white',
  secondary: 'text-secondary',
  muted: 'text-muted',
  gold: 'text-gold',
  'on-gold': 'text-on-gold',
  success: 'text-success',
  warning: 'text-warning',
  error: 'text-error',
  info: 'text-info',
};

export interface GenieTextProps extends TextProps {
  variant?: GenieTextVariant;
  tone?: GenieTextTone;
  className?: string;
}

export const GenieText: React.FC<GenieTextProps> = ({
  variant = 'body-md',
  tone = 'primary',
  className = '',
  ...rest
}) => (
  <Text className={`${VARIANTS[variant]} ${TONES[tone]} ${className}`} {...rest} />
);
