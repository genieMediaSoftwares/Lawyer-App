import React from 'react';
import { View } from 'react-native';
import { GenieText } from './GenieText';
import { GenieButton } from './GenieButton';

/**
 * Nothing to show, and that is not an error.
 *
 * Distinct from GenieErrorState on purpose: an empty list is a normal outcome
 * and should not be dressed as a failure. It takes an icon rather than drawing
 * one, so each screen can show the icon for the thing that is missing.
 */

export interface GenieEmptyStateProps {
  title: string;
  description?: string;
  actionLabel?: string;
  onAction?: () => void;
  icon?: React.ReactNode;
  className?: string;
}

export const GenieEmptyState: React.FC<GenieEmptyStateProps> = ({
  title,
  description,
  actionLabel,
  onAction,
  icon,
  className = '',
}) => (
  <View className={`items-center justify-center px-6 py-10 ${className}`}>
    {icon ? (
      <View className="mb-4 h-16 w-16 items-center justify-center rounded-full bg-surface-alt">
        {icon}
      </View>
    ) : null}
    <GenieText variant="heading-sm" className="text-center">
      {title}
    </GenieText>
    {description ? (
      <GenieText variant="body-md" tone="secondary" className="mt-2 text-center">
        {description}
      </GenieText>
    ) : null}
    {actionLabel && onAction ? (
      <GenieButton
        label={actionLabel}
        onPress={onAction}
        fullWidth={false}
        className="mt-5"
      />
    ) : null}
  </View>
);
