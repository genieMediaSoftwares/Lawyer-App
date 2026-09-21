import React from 'react';
import { Pressable, ScrollView, View } from 'react-native';
import { GenieText } from '../ui/GenieText';
import {
  BellIcon,
  BriefcaseIcon,
  ChatIcon,
  FileIcon,
} from '../icons/ClientIcons';
import { colors } from '../../theme';

export type NotificationCategory =
  | 'All'
  | 'Cases'
  | 'Messages'
  | 'Documents'
  | 'Updates';

interface NotificationCategoryTabsProps {
  selectedTab: NotificationCategory;
  onSelectTab: (tab: NotificationCategory) => void;
  counts: Record<NotificationCategory, number>;
}

const TABS: { key: NotificationCategory; label: string; icon: React.FC<{ size?: number; color?: string }> }[] = [
  { key: 'All', label: 'All', icon: BellIcon },
  { key: 'Cases', label: 'Cases', icon: BriefcaseIcon },
  { key: 'Messages', label: 'Messages', icon: ChatIcon },
  { key: 'Documents', label: 'Documents', icon: FileIcon },
  { key: 'Updates', label: 'Updates', icon: BellIcon },
];

export const NotificationCategoryTabs: React.FC<NotificationCategoryTabsProps> = ({
  selectedTab,
  onSelectTab,
  counts,
}) => {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerClassName="px-4 py-2 gap-2"
    >
      {TABS.map(({ key, label, icon: IconComponent }) => {
        const isSelected = selectedTab === key;
        const count = counts[key] || 0;

        return (
          <Pressable
            key={key}
            onPress={() => onSelectTab(key)}
            className={`flex-row items-center gap-2 rounded-xl border px-3 py-2 ${
              isSelected
                ? 'border-gold/60 bg-amber-950/40'
                : 'border-border/40 bg-surface-alt/80'
            }`}
          >
            <IconComponent
              size={16}
              color={isSelected ? colors.gold : colors.textMuted}
            />

            <GenieText
              className={`font-semibold text-xs ${
                isSelected ? 'text-gold' : 'text-text-secondary'
              }`}
            >
              {label}
            </GenieText>

            {count > 0 ? (
              <View
                className={`h-4 min-w-[16px] items-center justify-center rounded-full px-1 ${
                  isSelected ? 'bg-amber-600/80' : 'bg-amber-600/60'
                }`}
              >
                <GenieText className="font-bold text-[10px] text-white">
                  {count}
                </GenieText>
              </View>
            ) : null}
          </Pressable>
        );
      })}
    </ScrollView>
  );
};
