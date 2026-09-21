import React from 'react';
import { View } from 'react-native';
import { GenieText } from './GenieText';
import { GenieButton } from './GenieButton';

/**
 * A request failed.
 *
 * `message` is the real error from the backend, not a generic apology — a user
 * who can see "Session expired" knows to sign in again, and a developer
 * reading a bug report gets something to go on. Nothing here invents content
 * to paper over the failure.
 */

export interface GenieErrorStateProps {
  title?: string;
  message: string;
  onRetry?: () => void;
  retryLabel?: string;
  className?: string;
}

export const GenieErrorState: React.FC<GenieErrorStateProps> = ({
  title = 'Something went wrong',
  message,
  onRetry,
  retryLabel = 'Try again',
  className = '',
}) => (
  <View
    className={`items-center justify-center rounded-card border border-border bg-surface p-5 ${className}`}
    accessibilityRole="alert"
  >
    <GenieText variant="heading-sm" tone="error" className="text-center">
      {title}
    </GenieText>
    <GenieText variant="body-md" tone="secondary" className="mt-2 text-center">
      {message}
    </GenieText>
    {onRetry ? (
      <GenieButton
        label={retryLabel}
        onPress={onRetry}
        variant="outline"
        fullWidth={false}
        className="mt-4"
      />
    ) : null}
  </View>
);
