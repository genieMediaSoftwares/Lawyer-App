import React from 'react';
import { Pressable, View } from 'react-native';

import { GenieText } from './ui';

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
