import React from 'react';
import { Text, TextProps } from 'react-native';

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
