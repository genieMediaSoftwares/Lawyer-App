import React, { useEffect, useRef } from 'react';
import {
  Animated,
  Easing,
  Modal,
  Pressable,
  ScrollView,
  View,
  useWindowDimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { GenieAvatar, GenieDivider, GenieText } from '../ui';
import {
  ChevronRightIcon,
  LogoutIcon,
  SettingsIcon,
  StarIcon,
  VerifiedIcon,
} from '../icons/ClientIcons';
import { colors } from '../../theme';
import { USE_NATIVE_DRIVER } from '../../utils/platform';

/**
 * The navigation drawer.
 *
 * LAYERING
 *
 * Three layers inside one Modal, in this order:
 *
 *   App content   — the screen behind, owned by the navigator
 *   Backdrop      — absolutely positioned, fills the Modal, z-10
 *   Drawer panel  — absolutely positioned on the left, z-20, fully opaque
 *
 * The panel is opaque `bg-surface` (#111111) with no opacity anywhere on it.
 * Only the backdrop is translucent; the panel sits above it and covers the
 * screen completely across its own width. Because the whole thing is a
 * `Modal`, it renders above everything the navigator draws — including the tab
 * bar and its raised centre button — and when `visible` is false nothing is
 * mounted at all, so no invisible layer is left behind eating taps.
 *
 * WHY THE PANEL IS NOT AN Animated.View WITH CLASSES
 *
 * It is, now. `Animated.View` is not one of the components NativeWind
 * registers by default, so until `src/nativewind-interop.ts` registered it
 * every `className` here was dropped — which is why this panel previously had
 * no background and the Home screen showed through it.
 *
 * IT OPENS FROM THE LEFT
 *
 * `left-0` plus a slide from `-width` to `0`. Both halves have to agree; flip
 * one and the panel comes in from the wrong edge or starts on-screen.
 */

/** Matches `w-[82%]` below — the two must stay in step. */
const DRAWER_WIDTH_FRACTION = 0.82;

export interface GenieDrawerItem {
  key?: string;
  id?: string;
  label: string;
  Icon?: React.ComponentType<{ size?: number; color?: string }>;
  icon?: React.ReactNode;
  onPress?: () => void;
  badge?: string | number;
  /** A screen that is not built yet renders dimmed and does not respond. */
  available?: boolean;
}

export interface GenieDrawerProps {
  isOpen?: boolean;
  visible?: boolean;
  onClose: () => void;
  items: GenieDrawerItem[];
  user?: {
    fullName?: string;
    name?: string;
    email?: string;
    profileImage?: string | null;
    avatar?: string | null;
    isVerified?: boolean;
    role?: string;
  } | null;
  onSettingsPress?: () => void;
  onSignOut?: () => void;
  onLogout?: () => void;
  isSigningOut?: boolean;
  onAvatarPress?: () => void;
  onSubscriptionPress?: () => void;
}

/**
 * One row: [icon] label … [badge] [chevron].
 *
 * A fixed `h-14` rather than padding-driven height is what keeps the rows
 * evenly spaced whatever their contents — a row with a badge is the same
 * height as one without. The icon sits in a fixed-width box so every label
 * starts at the same x.
 */
const DrawerRow: React.FC<{
  label: string;
  icon: React.ReactNode;
  onPress: () => void;
  disabled?: boolean;
  destructive?: boolean;
  badge?: string | number;
}> = ({ label, icon, onPress, disabled = false, destructive = false, badge }) => (
  <Pressable
    onPress={onPress}
    disabled={disabled}
    accessibilityRole="button"
    accessibilityLabel={label}
    accessibilityState={{ disabled }}
    className={[
      'h-14 flex-row items-center gap-3 rounded-control px-3',
      destructive ? 'active:bg-error-surface' : 'active:bg-surface-alt',
      disabled ? 'opacity-50' : '',
    ].join(' ')}
  >
    <View className="w-6 items-center justify-center">{icon}</View>

    <GenieText
      variant="body-lg"
      tone={destructive ? 'error' : disabled ? 'muted' : 'primary'}
      className="flex-1"
      numberOfLines={1}
    >
      {label}
    </GenieText>

    {badge ? (
      <View className="h-5 min-w-5 items-center justify-center rounded-pill bg-gold px-1.5">
        <GenieText variant="caption" tone="on-gold" className="font-bold">
          {String(badge)}
        </GenieText>
      </View>
    ) : null}

    <ChevronRightIcon
      size={16}
      color={destructive ? colors.error : colors.textMuted}
    />
  </Pressable>
);

export const GenieDrawer: React.FC<GenieDrawerProps> = ({
  isOpen,
  visible,
  onClose,
  items,
  user,
  onSettingsPress,
  onSignOut,
  onLogout,
  isSigningOut = false,
  onAvatarPress,
  onSubscriptionPress,
}) => {
  const isVisible = isOpen ?? visible ?? false;
  const handleLogout = onSignOut ?? onLogout;
  const userName = user?.fullName || user?.name;

  // Read live rather than once, so the slide distance stays correct after a
  // rotation or a browser resize.
  const { width } = useWindowDimensions();
  const drawerWidth = width * DRAWER_WIDTH_FRACTION;

  const anim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(anim, {
      toValue: isVisible ? 1 : 0,
      duration: isVisible ? 250 : 200,
      easing: isVisible ? Easing.out(Easing.cubic) : Easing.in(Easing.cubic),
      useNativeDriver: USE_NATIVE_DRIVER,
    }).start();
  }, [anim, isVisible]);

  // Off the left edge to flush against it. A driven value, so it is the one
  // thing here that stays in a style prop.
  const translateX = anim.interpolate({
    inputRange: [0, 1],
    outputRange: [-drawerWidth, 0],
  });

  const menuItems = items.filter(i => (i.key ?? i.id) !== 'settings');
  const settingsItem = items.find(i => (i.key ?? i.id) === 'settings');

  const handleSettings = () => {
    onClose();
    if (settingsItem?.onPress) {
      settingsItem.onPress();
    } else {
      onSettingsPress?.();
    }
  };

  return (
    <Modal
      visible={isVisible}
      transparent
      animationType="none"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <View className="flex-1">
        {/* Layer 1 — the backdrop. Covers the whole screen and fades with the
            panel; the panel is drawn on top of it. */}
        <Animated.View
          style={{ opacity: anim }}
          className="absolute bottom-0 left-0 right-0 top-0 z-10 bg-overlay"
        >
          <Pressable
            onPress={onClose}
            accessibilityRole="button"
            accessibilityLabel="Close menu"
            className="flex-1"
          />
        </Animated.View>

        {/* Layer 2 — the panel. Opaque, above the backdrop, pinned left. */}
        <Animated.View
          style={{ transform: [{ translateX }] }}
          className="absolute bottom-0 left-0 top-0 z-20 w-[82%] border-r border-border bg-surface"
        >
          <SafeAreaView edges={['top', 'bottom']} className="flex-1">
            <View className="relative items-center border-b border-border px-4 pb-4 pt-3">
              {onSubscriptionPress ? (
                <Pressable
                  onPress={() => {
                    onClose();
                    onSubscriptionPress();
                  }}
                  accessibilityRole="button"
                  accessibilityLabel="Subscription plans"
                  className="absolute right-3 top-3 h-8 w-8 items-center justify-center rounded-full border border-gold/40 bg-gold/15 active:opacity-70"
                >
                  <StarIcon size={16} color={colors.gold} />
                </Pressable>
              ) : null}

              <Pressable
                onPress={() => {
                  if (onAvatarPress) {
                    onClose();
                    onAvatarPress();
                  }
                }}
                disabled={!onAvatarPress}
                accessibilityRole="button"
                accessibilityLabel="View profile photo"
                className="mb-2 active:opacity-80"
              >
                <GenieAvatar
                  uri={user?.profileImage || user?.avatar}
                  name={userName}
                  size="lg"
                  ring
                />
              </Pressable>

              {userName ? (
                <View className="mt-1 flex-row items-center justify-center gap-1.5">
                  <GenieText
                    variant="body-lg"
                    tone="gold"
                    className="font-semibold"
                    numberOfLines={1}
                  >
                    {userName}
                  </GenieText>
                  {user?.isVerified ? (
                    <VerifiedIcon size={16} color={colors.gold} />
                  ) : null}
                </View>
              ) : null}

              {user?.email ? (
                <GenieText
                  variant="body-sm"
                  tone="secondary"
                  className="mt-0.5"
                  numberOfLines={1}
                >
                  {user.email}
                </GenieText>
              ) : null}
            </View>

            <ScrollView
              className="flex-1"
              contentContainerClassName="px-2 py-2"
              showsVerticalScrollIndicator={false}
            >
              {menuItems.map(item => {
                const IconComp = item.Icon;
                const isAvailable = item.available !== false;

                return (
                  <DrawerRow
                    key={item.key ?? item.id ?? item.label}
                    label={item.label}
                    disabled={!isAvailable}
                    badge={item.badge}
                    icon={
                      IconComp ? (
                        <IconComp
                          size={20}
                          color={isAvailable ? colors.white : colors.textMuted}
                        />
                      ) : (
                        item.icon ?? null
                      )
                    }
                    onPress={() => {
                      if (item.onPress) {
                        onClose();
                        item.onPress();
                      }
                    }}
                  />
                );
              })}
            </ScrollView>

            {/* Pinned footer. Settings and Sign Out are two full-width rows of
                the same shape as the list above, not a button pair — Sign Out
                is destructive and must not sit beside an unrelated control. */}
            <View className="shrink-0 px-2 pb-2">
              <GenieDivider className="mb-1" />

              <DrawerRow
                label="Settings"
                icon={<SettingsIcon size={20} color={colors.white} />}
                onPress={handleSettings}
              />

              {handleLogout ? (
                <DrawerRow
                  label={isSigningOut ? 'Signing out...' : 'Sign Out'}
                  destructive
                  disabled={isSigningOut}
                  icon={<LogoutIcon size={20} color={colors.error} />}
                  onPress={() => {
                    onClose();
                    handleLogout();
                  }}
                />
              ) : null}
            </View>
          </SafeAreaView>
        </Animated.View>
      </View>
    </Modal>
  );
};
