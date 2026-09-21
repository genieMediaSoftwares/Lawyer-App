import React from 'react';
import { Pressable, View } from 'react-native';

import { GenieText } from './ui';

/**
 * The Login / Sign Up pair at the top of both auth screens.
 *
 * It is a navigation control, not a tab view: each side replaces the current
 * screen rather than swapping a panel, so the back stack never accumulates an
 * alternating chain of Login and Signup.
 */

interface AuthTabsProps {
  active: 'login' | 'signup';
  onSelectLogin: () => void;
  onSelectSignup: () => void;
}

const Tab: React.FC<{
  label: string;
  isActive: boolean;
  onPress: () => void;
}> = ({ label, isActive, onPress }) => (
  <Pressable
    onPress={onPress}
    // Not disabled when active: pressing the current tab should do nothing,
    // but a disabled control reads as unavailable to a screen reader.
    accessibilityRole="tab"
    accessibilityState={{ selected: isActive }}
    className="min-h-touch items-center justify-center px-1 py-2"
    hitSlop={8}
  >
    <GenieText
      variant="label"
      tone={isActive ? 'gold' : 'secondary'}
      className="text-base"
    >
      {label}
    </GenieText>
    <View
      className={`mt-2 h-0.5 w-7 rounded-sm ${
        isActive ? 'bg-gold' : 'bg-transparent'
      }`}
    />
  </Pressable>
);

export const AuthTabs: React.FC<AuthTabsProps> = ({
  active,
  onSelectLogin,
  onSelectSignup,
}) => (
  <View
    className="flex-row items-center justify-between pt-2"
    accessibilityRole="tablist"
  >
    <Tab
      label="Login"
      isActive={active === 'login'}
      onPress={active === 'login' ? () => {} : onSelectLogin}
    />
    <Tab
      label="Sign Up"
      isActive={active === 'signup'}
      onPress={active === 'signup' ? () => {} : onSelectSignup}
    />
  </View>
);
