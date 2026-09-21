import React from 'react';
import { Pressable, View, ViewProps } from 'react-native';

/**
 * The card surface. One definition, so "make the cards rounder" is one edit.
 *
 * `tone` is about elevation, not decoration: `card` sits above the page,
 * `surface` is for sheets and headers, `alt` for a panel nested inside a card.
 * Keeping them one step apart is what stops a dark screen reading as flat.
 */

export type GenieCardTone = 'card' | 'surface' | 'alt' | 'gold';

const TONES: Record<GenieCardTone, string> = {
  card: 'bg-card border border-border',
  surface: 'bg-surface border border-border',
  alt: 'bg-surface-alt border border-border',
  // The accented card: AI panels, the selected plan, anything being offered.
  gold: 'bg-gold-muted border border-gold',
};

export interface GenieCardProps extends ViewProps {
  children: React.ReactNode;
  tone?: GenieCardTone;
  /** Turn off when the card's content manages its own padding, e.g. a full-bleed image. */
  padded?: boolean;
  onPress?: () => void;
  className?: string;
  accessibilityLabel?: string;
}

export const GenieCard: React.FC<GenieCardProps> = ({
  children,
  tone = 'card',
  padded = true,
  onPress,
  className = '',
  accessibilityLabel,
  ...rest
}) => {
  const classes = `rounded-card ${TONES[tone]} ${padded ? 'p-4' : ''} ${className}`;

  if (onPress) {
    return (
      <Pressable
        onPress={onPress}
        accessibilityRole="button"
        accessibilityLabel={accessibilityLabel}
        className={`${classes} active:opacity-80`}
        {...rest}
      >
        {children}
      </Pressable>
    );
  }

  return (
    <View className={classes} {...rest}>
      {children}
    </View>
  );
};
