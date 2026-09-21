import React from 'react';
import { Pressable } from 'react-native';
import { GenieText } from './GenieText';

/**
 * A selectable pill: category filters, sort options, tag lists.
 *
 * Selection is carried by gold — background wash plus a gold border — rather
 * than by a tick, so a row of chips reads at a glance.
 */

export interface GenieChipProps {
  label: string;
  selected?: boolean;
  onPress?: () => void;
  icon?: React.ReactNode;
  className?: string;
}

export const GenieChip: React.FC<GenieChipProps> = ({
  label,
  selected = false,
  onPress,
  icon,
  className = '',
}) => (
  <Pressable
    onPress={onPress}
    disabled={!onPress}
    accessibilityRole={onPress ? 'button' : undefined}
    accessibilityState={{ selected }}
    accessibilityLabel={label}
    className={[
      'min-h-touch flex-row items-center justify-center rounded-pill border px-4 py-2',
      selected
        ? 'border-gold bg-gold-muted'
        : 'border-border bg-surface-alt active:bg-surface',
      className,
    ].join(' ')}
  >
    {icon ? <>{icon}</> : null}
    <GenieText
      variant="body-sm"
      tone={selected ? 'gold' : 'secondary'}
      className={`font-semibold ${icon ? 'ml-1.5' : ''}`}
    >
      {label}
    </GenieText>
  </Pressable>
);
