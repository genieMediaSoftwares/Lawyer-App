import React from 'react';
import { Pressable, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';

import { GenieText } from '../ui';
import { UserIcon } from '../icons/Icons';
import {
  CalendarIcon,
  ChartIcon,
  GridIcon,
  UserPlusIcon,
  UsersIcon,
} from '../icons/LawyerIcons';
import { colors } from '../../theme';

/**
 * The lawyer tab bar: Workspace, Dashboard, Leads, Clients, Calendar, Profile.
 *
 * Six equal-width tabs and no raised centre button — unlike the client, a
 * lawyer has no single "create" action, so there is nothing to promote out of
 * the row. That also means no absolute positioning here at all: the tabs are
 * six flex children of an ordinary row, which is what keeps them evenly
 * spaced at any screen width.
 *
 * The bar consumes the bottom safe-area inset itself, so screens under it pass
 * `edges={['top']}` — taking it in both places leaves a gap above the bar.
 */

const ICONS: Record<string, React.FC<{ size?: number; color?: string }>> = {
  Workspace: GridIcon,
  Dashboard: ChartIcon,
  Leads: UserPlusIcon,
  Clients: UsersIcon,
  Calendar: CalendarIcon,
  LawyerProfile: UserIcon,
};

const LABELS: Record<string, string> = {
  Workspace: 'Workspace',
  Dashboard: 'Dashboard',
  Leads: 'Leads',
  Clients: 'Clients',
  Calendar: 'Calendar',
  LawyerProfile: 'Profile',
};

export const LawyerBottomNavigation: React.FC<BottomTabBarProps> = ({
  state,
  descriptors,
  navigation,
}) => {
  const insets = useSafeAreaInsets();

  return (
    <View
      className="bg-surface"
      // The inset is a runtime measurement, so it cannot be a class.
      style={{ paddingBottom: insets.bottom }}
    >
      <View className="h-[62px] flex-row items-center border-t border-border">
        {state.routes.map((route, index) => {
          const { options } = descriptors[route.key];
          const isFocused = state.index === index;
          const label = LABELS[route.name] ?? route.name;
          const Icon = ICONS[route.name] ?? GridIcon;

          const onPress = () => {
            const event = navigation.emit({
              type: 'tabPress',
              target: route.key,
              canPreventDefault: true,
            });
            if (!isFocused && !event.defaultPrevented) {
              navigation.navigate(route.name, route.params);
            }
          };

          return (
            <Pressable
              key={route.key}
              onPress={onPress}
              accessibilityRole="tab"
              accessibilityState={{ selected: isFocused }}
              accessibilityLabel={options.tabBarAccessibilityLabel ?? label}
              className="min-h-touch flex-1 items-center justify-center px-0.5 py-1"
            >
              <Icon size={20} color={isFocused ? colors.gold : colors.textMuted} />
              <GenieText
                variant="caption"
                tone={isFocused ? 'gold' : 'muted'}
                className={`mt-0.5 text-[10px] ${
                  isFocused ? 'font-bold' : 'font-medium'
                }`}
                numberOfLines={1}
              >
                {label}
              </GenieText>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
};
