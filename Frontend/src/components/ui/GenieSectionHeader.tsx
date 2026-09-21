import React from 'react';
import { Pressable, View } from 'react-native';
import { GenieText } from './GenieText';

/**
 * The line above a group of content: a title, optionally a subtitle, and
 * optionally an action on the right ("See all").
 */

export interface GenieSectionHeaderProps {
  title: string;
  subtitle?: string;
  actionLabel?: string;
  onAction?: () => void;
  className?: string;
}

export const GenieSectionHeader: React.FC<GenieSectionHeaderProps> = ({
  title,
  subtitle,
  actionLabel,
  onAction,
  className = '',
}) => (
  <View className={`flex-row items-center justify-between ${className}`}>
    <View className="flex-1 pr-3">
      <GenieText variant="heading-md">{title}</GenieText>
      {subtitle ? (
        <GenieText variant="body-sm" tone="secondary" className="mt-0.5">
          {subtitle}
        </GenieText>
      ) : null}
    </View>
    {actionLabel && onAction ? (
      <Pressable
        onPress={onAction}
        accessibilityRole="button"
        accessibilityLabel={actionLabel}
        className="min-h-touch justify-center active:opacity-70"
      >
        <GenieText variant="label" tone="gold">
          {actionLabel}
        </GenieText>
      </Pressable>
    ) : null}
  </View>
);
