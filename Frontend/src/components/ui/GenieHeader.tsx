import React from 'react';
import { View } from 'react-native';
import { GenieText } from './GenieText';
import { GenieIconButton } from './GenieIconButton';
import { GenieWordmark } from './GenieWordmark';
import { BackIcon } from '../icons/Icons';
import { BellIcon, MenuIcon } from '../icons/ClientIcons';
import { colors } from '../../theme';

/**
 * The bar at the top of every screen.
 *
 * ON CENTRING THE TITLE
 *
 * A header laid out as three flex children centres the title between its
 * neighbours, not on the screen — so the title slides left or right depending
 * on whether there is a bell on the right, and by how much. Nudging it back
 * with a margin only fixes the one case it was measured against.
 *
 * Instead the title is absolutely positioned across the full width and centred
 * there, with the two icon slots drawn over it. Because every icon slot is
 * exactly `min-w-touch` wide, the title is padded clear of them by a fixed
 * amount on both sides and stays centred on the screen no matter which
 * controls are present.
 */

export interface GenieHeaderProps {
  title?: string;
  subtitle?: string;
  /** Shows a back chevron. Takes precedence over `onMenu`. */
  onBack?: () => void;
  /** Shows the hamburger, which opens the drawer. */
  onMenu?: () => void;
  onNotifications?: () => void;
  notificationCount?: number;
  /** An extra control in the right slot, left of the bell. */
  right?: React.ReactNode;
  /** With no title, the header shows the wordmark instead. */
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
    <View className={`h-14 w-full flex-row items-center bg-background px-2 ${className}`}>
      {/* The centred layer. `pointer-events-none` so it cannot swallow a tap
          meant for the buttons drawn on top of it. */}
      <View
        className="absolute left-0 right-0 items-center px-14"
        pointerEvents="none"
      >
        {title ? (
          <>
            <GenieText variant="heading-sm" numberOfLines={1}>
              {title}
            </GenieText>
            {subtitle ? (
              <GenieText variant="caption" tone="secondary" numberOfLines={1}>
                {subtitle}
              </GenieText>
            ) : null}
          </>
        ) : centreBrand ? (
          <GenieWordmark size={28} />
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
            icon={<BellIcon size={22} color={colors.gold} />}
            onPress={onNotifications}
            accessibilityLabel="Notifications"
            badgeCount={notificationCount}
          />
        ) : null}
      </View>
    </View>
  );
};
