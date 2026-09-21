import React from 'react';
import { View } from 'react-native';
import { GenieText } from './GenieText';

export interface GenieWordmarkProps {
  /** The mark's size in points (kept for interface compatibility). */
  size?: number;
  /** Stack the wordmark text. */
  stacked?: boolean;
  className?: string;
}

/**
 * The clean GenieLaw typography wordmark ("GENIE" in white, "LAW" in gold).
 */
export const GenieWordmark: React.FC<GenieWordmarkProps> = ({
  stacked = false,
  className = '',
}) => (
  <View
    className={`${stacked ? 'items-center' : 'flex-row items-center'} ${className}`}
    accessibilityRole="header"
    accessibilityLabel="Genie Law"
  >
    <GenieText variant="brand">
      GENIE <GenieText variant="brand" tone="gold">LAW</GenieText>
    </GenieText>
  </View>
);
