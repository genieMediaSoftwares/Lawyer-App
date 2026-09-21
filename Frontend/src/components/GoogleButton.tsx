import React from 'react';
import { Pressable, View } from 'react-native';

import { GenieText } from './ui';
import { GoogleIcon } from './icons/Icons';
import { colors } from '../theme';

/**
 * "Continue with Google".
 *
 * The Genie Law backend has no Google authentication route — there is no
 * /auth/google, no /auth/google-login, and no id-token exchange anywhere in
 * backend/src/routes. The only Google integration that exists is Calendar sync
 * for lawyers, which is a different feature entirely and requires an account
 * that is already signed in.
 *
 * So this button does not sign anyone in, and it does not pretend to. Pressing
 * it says plainly that the method is unavailable and points the user at the
 * email-and-password form that does work. Nothing here mints a token, invents
 * a user, or calls an endpoint that would 404.
 *
 * When the backend gains a real Google route, this component gets an onPress
 * that calls it and `unavailable` goes away. Until then the honest state is
 * the only correct one.
 */

interface GoogleButtonProps {
  /** Called when the user presses the unavailable button. */
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
