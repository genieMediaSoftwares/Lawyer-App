import React from 'react';
import { Pressable, View, ViewProps } from 'react-native';

export type GenieCardTone = 'card' | 'surface' | 'alt' | 'gold';

const TONES: Record<GenieCardTone, string> = {
  card: 'bg-card border border-border',
  surface: 'bg-surface border border-border',
  alt: 'bg-surface-alt border border-border',
  gold: 'bg-gold-muted border border-gold',
};

export interface GenieCardProps extends ViewProps {
  children: React.ReactNode;
  tone?: GenieCardTone;
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
