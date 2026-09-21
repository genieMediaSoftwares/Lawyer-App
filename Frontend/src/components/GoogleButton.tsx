import React from 'react';
import { Pressable, View } from 'react-native';

import { GenieText } from './ui';
import { GoogleIcon } from './icons/Icons';
import { colors } from '../theme';

interface GoogleButtonProps {
  onUnavailable: (message: string) => void;
  disabled?: boolean;
}

const UNAVAILABLE_MESSAGE =
  'Google sign-in is not available yet. Please sign in with your email and password.';

export const GoogleButton: React.FC<GoogleButtonProps> = ({
  onUnavailable,
  disabled = false,
}) => (
  <Pressable
    onPress={() => onUnavailable(UNAVAILABLE_MESSAGE)}
    disabled={disabled}
    accessibilityRole="button"
    accessibilityLabel="Continue with Google"
    accessibilityHint="Not available yet. Use email and password to sign in."
    className="h-control items-center justify-center rounded-control border border-border bg-surface active:bg-input"
  >
    <View className="flex-row items-center">
      <GoogleIcon size={20} color={colors.textSecondary} />
      <GenieText variant="label" tone="secondary" className="ml-3 text-base">
        Continue with Google
      </GenieText>
    </View>
  </Pressable>
);
