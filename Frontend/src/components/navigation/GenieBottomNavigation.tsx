import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { GenieText } from '../ui';
import {
  BriefcaseIcon,
  HomeIcon,
  PlusIcon,
  ScalesIcon,
} from '../icons/ClientIcons';
import { UserIcon } from '../icons/Icons';
import { useUiStore } from '../../store/uiStore';
import { colors } from '../../theme';

const ICONS: Record<string, React.FC<{ size?: number; color?: string }>> = {
  Home: HomeIcon,
  Cases: BriefcaseIcon,
  Advocates: ScalesIcon,
  Profile: UserIcon,
};

export const GenieBottomNavigation: React.FC<BottomTabBarProps> = ({
  state,
  descriptors,
  navigation,
}) => {
  const openCreateSheet = useUiStore(s => s.openCreateSheet);
  const insets = useSafeAreaInsets();

  const renderTab = (route: (typeof state.routes)[number]) => {
    const index = state.routes.findIndex(r => r.key === route.key);
    const { options } = descriptors[route.key];
    const isFocused = state.index === index;

    const rawLabel = options.tabBarLabel ?? options.title ?? route.name;
    const label = typeof rawLabel === 'string' ? rawLabel : route.name;

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

    const Icon = ICONS[route.name] ?? HomeIcon;

    return (
      <Pressable
        key={route.key}
        onPress={onPress}
        accessibilityRole="tab"
        accessibilityState={{ selected: isFocused }}
        accessibilityLabel={options.tabBarAccessibilityLabel ?? label}
        className="min-h-touch flex-1 items-center justify-center py-1"
      >
        <Icon size={22} color={isFocused ? colors.gold : colors.textMuted} />
        <GenieText
          variant="caption"
          tone={isFocused ? 'gold' : 'muted'}
          className={`mt-0.5 text-[11px] ${isFocused ? 'font-bold' : 'font-medium'}`}
        >
          {label}
        </GenieText>
      </Pressable>
    );
  };

  return (
    <View className="relative z-10 bg-surface" style={{ paddingBottom: insets.bottom }}>
      <View className="h-[60px] flex-row items-center border-t border-border">
        <View className="flex-1 flex-row items-center justify-around">
          {state.routes.slice(0, 2).map(renderTab)}
        </View>

        <View className="w-16" pointerEvents="none" />

        <View className="flex-1 flex-row items-center justify-around">
          {state.routes.slice(2).map(renderTab)}
        </View>
      </View>

      <Pressable
        onPress={openCreateSheet}
        accessibilityRole="button"
        accessibilityLabel="Post your case"
        className="absolute left-1/2 h-14 w-14 items-center justify-center rounded-full bg-gold active:bg-gold-pressed"
        style={[styles.centreButton, { bottom: insets.bottom + 32 }]}
      >
        <PlusIcon size={26} color={colors.onGold} />
      </Pressable>
    </View>
  );
};

const styles = StyleSheet.create({
  centreButton: {
    transform: [{ translateX: -28 }],
    elevation: 8,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 6,
    zIndex: 20,
  },
});
