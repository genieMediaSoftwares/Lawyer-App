import React from 'react';
import { View } from 'react-native';
import { GenieText } from './GenieText';
import { GenieIconButton } from './GenieIconButton';
import { GenieWordmark } from './GenieWordmark';
import { BackIcon } from '../icons/Icons';
import { BellIcon, MenuIcon } from '../icons/ClientIcons';
import { colors } from '../../theme';

export interface GenieHeaderProps {
  title?: string;
  subtitle?: string;
  onBack?: () => void;
  onMenu?: () => void;
  onNotifications?: () => void;
  notificationCount?: number;
  right?: React.ReactNode;
  showBrand?: boolean;
  className?: string;
}

export const GenieHeader: React.FC<GenieHeaderProps> = ({
  title,
  subtitle,
  onBack,
  onMenu,
  onNotifications,
  notificationCount = 0,
  right,
  showBrand = false,
  className = '',
}) => {
  const centreBrand = !title && showBrand;

  return (
    <View className={`h-[56px] w-full flex-row items-center bg-background px-4 ${className}`}>
      <View
        className="absolute left-0 right-0 items-center px-16"
        pointerEvents="none"
      >
        {title ? (
          <>
            <GenieText variant="screenTitle" numberOfLines={1}>
              {title}
            </GenieText>
            {subtitle ? (
              <GenieText variant="caption" tone="secondary" numberOfLines={1}>
                {subtitle}
              </GenieText>
            ) : null}
          </>
        ) : centreBrand ? (
          <GenieWordmark size={24} />
        ) : null}
      </View>

      <View className="flex-row items-center">
        {onBack ? (
          <GenieIconButton
            icon={<BackIcon size={24} color={colors.white} />}
            onPress={onBack}
            accessibilityLabel="Go back"
          />
        ) : onMenu ? (
          <GenieIconButton
            icon={<MenuIcon size={24} color={colors.white} />}
            onPress={onMenu}
            accessibilityLabel="Open menu"
          />
        ) : null}
      </View>

      <View className="flex-1" />

      <View className="flex-row items-center">
        {right}
        {onNotifications ? (
          <GenieIconButton
            icon={<BellIcon size={20} color={colors.gold} />}
            onPress={onNotifications}
            accessibilityLabel="Notifications"
            badgeCount={notificationCount}
          />
        ) : null}
      </View>
    </View>
  );
};
