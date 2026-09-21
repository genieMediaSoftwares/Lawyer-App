import React from 'react';
import { Pressable, PressableProps, View } from 'react-native';
import { GenieText } from './GenieText';

/**
 * A tappable icon.
 *
 * Fixed at `min-h-touch min-w-touch` so every icon control in the app has the
 * same hit area whatever the glyph inside measures. That fixed size is also
 * what lets a header centre its title honestly — see GenieHeader.
 */

export interface GenieIconButtonProps extends Omit<PressableProps, 'children' | 'style'> {
  icon: React.ReactNode;
  onPress: () => void;
  /** Required: an icon with no label is invisible to a screen reader. */
  accessibilityLabel: string;
  /** A count drawn over the icon, as on the notifications bell. */
  badgeCount?: number;
  className?: string;
}

export const GenieIconButton: React.FC<GenieIconButtonProps> = ({
  icon,
  onPress,
  accessibilityLabel,
  badgeCount = 0,
  className = '',
  ...rest
}) => (
  <Pressable
    onPress={onPress}
    accessibilityRole="button"
    accessibilityLabel={accessibilityLabel}
    className={`min-h-touch min-w-touch items-center justify-center rounded-full active:bg-surface-alt ${className}`}
    {...rest}
  >
    {icon}
    {badgeCount > 0 ? (
      <View className="absolute right-1.5 top-1.5 h-4 min-w-4 items-center justify-center rounded-full bg-error px-1">
        <GenieText variant="caption" className="text-[9px] font-bold">
          {badgeCount > 99 ? '99+' : String(badgeCount)}
        </GenieText>
      </View>
    ) : null}
  </Pressable>
);
