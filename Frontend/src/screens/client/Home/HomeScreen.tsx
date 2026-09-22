import React, { useCallback } from 'react';
import { Pressable, View } from 'react-native';
import { useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieCard,
  GenieGrid,
  GenieHeroCarousel,
  GenieIconButton,
  GenieScreen,
  GenieSectionHeader,
  GenieText,
  GenieWordmark,
  GenieRefreshControl,
} from '../../../components';
import { HowItWorksCarousel } from '../../../components/HowItWorksCarousel';
import { getCategoryIcon } from '../../../components/icons/CategoryIcons';
import {
  BellIcon,
  ChevronRightIcon,
  MenuIcon,
  SparkleIcon,
} from '../../../components/icons/ClientIcons';
import { notificationsApi } from '../../../api/clientApi';
import { popularCategories } from '../../../constants/categories';
import { useAuthStore } from '../../../store/authStore';
import { useUiStore } from '../../../store/uiStore';
import type { ClientTabScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

export const HomeScreen: React.FC<ClientTabScreenProps<'Home'>> = ({
  navigation,
}) => {
  const user = useAuthStore(state => state.user);
  const openDrawer = useUiStore(state => state.openDrawer);
  const queryClient = useQueryClient();

  const notificationsQuery = useQuery({
    queryKey: ['notifications', 1],
    queryFn: () => notificationsApi.list(1, 15),
  });

  const onRefresh = useCallback(
    () => queryClient.invalidateQueries({ queryKey: ['notifications'] }),
    [queryClient],
  );

  const unreadCount = notificationsQuery.data?.unreadCount ?? 0;

  const header = (
    <View className="h-14 w-full flex-row items-center justify-between border-b border-border bg-background px-2">
      <GenieIconButton
        icon={<MenuIcon size={24} color={colors.white} />}
        onPress={openDrawer}
        accessibilityLabel="Open menu"
      />

      <GenieWordmark size={28} />

      <GenieIconButton
        icon={<BellIcon size={22} color={colors.white} />}
        onPress={() => navigation.navigate('Notifications')}
        accessibilityLabel="Notifications"
        badgeCount={unreadCount}
      />
    </View>
  );

  return (
    <GenieScreen
      scrollable
      header={header}
      dismissKeyboardOnTap={false}
      contentContainerClassName="pb-20"
      scrollViewProps={{
        refreshControl: (
          <GenieRefreshControl onRefresh={onRefresh} />
        ),
      }}
    >
      <View className="mb-4 mt-1">
        <GenieText variant="screenTitle">
          {user ? `Hello, ${user.fullName.split(' ')[0]}` : 'Hello'}
        </GenieText>
        <GenieText variant="secondary" tone="secondary" className="mt-1">
          How can we help with your legal matter today?
        </GenieText>
      </View>

      <GenieHeroCarousel
        onSlidePress={slide => {
          if (slide.actionType === 'advocates') {
            (navigation as any).navigate('Tabs', { screen: 'Advocates' });
          } else {
            navigation.navigate('AiAssistant');
          }
        }}
      />

      <GenieCard
        tone="card"
        className="mt-5 p-4"
        onPress={() => navigation.navigate('AiAssistant')}
        accessibilityLabel="AI Smart Case Assistant"
      >
        <View className="flex-row items-center self-start rounded-pill bg-surface-secondary px-2.5 py-1">
          <SparkleIcon size={12} color={colors.gold} />
          <GenieText
            variant="smallLabel"
            tone="gold"
            className="ml-1 font-bold tracking-widest"
          >
            AI POWERED
          </GenieText>
        </View>

        <GenieText variant="cardTitle" className="mt-3">
          AI Smart Case Assistant
        </GenieText>
        <GenieText variant="body" tone="gold" className="mt-1">
          {'Don’t know how to post your legal case?'}
        </GenieText>
        <GenieText variant="secondary" tone="secondary" className="mt-2">
          Upload your documents — add a voice note for extra detail if you like
          — and AI fills in your case for you, ready to find a lawyer.
        </GenieText>

        <View className="mt-4 h-[44px] flex-row items-center justify-center rounded-[10px] bg-gold px-4">
          <GenieText variant="button" tone="on-gold">
            Upload Documents & Create Case
          </GenieText>
          <View className="ml-1">
            <ChevronRightIcon size={18} color={colors.onGold} />
          </View>
        </View>
      </GenieCard>

      <GenieSectionHeader
        title="Categories"
        actionLabel="View All"
        onAction={() => navigation.navigate('AllCategories')}
        className="mt-6"
      />

      <GenieGrid
        className="mt-3"
        data={popularCategories()}
        keyExtractor={category => category.id}
        numColumns={4}
        gap={10}
        renderItem={category => {
          const IconComponent = getCategoryIcon(category.id);

          return (
            <Pressable
              onPress={() =>
                navigation.navigate('PostCase', {
                  start: 'manual',
                  categoryId: category.id,
                })
              }
              accessibilityRole="button"
              accessibilityLabel={category.title}
              className="items-center"
            >
              {/* Icon card: the icon lives inside this square card only. */}
              <View className="aspect-square w-full items-center justify-center rounded-card border border-border bg-card active:bg-surface-secondary">
                <IconComponent size={18} color={colors.gold} />
              </View>

              {/* Category text sits outside/below the card, not inside it. */}
              <GenieText variant="caption" className="mt-2 w-full text-center font-medium">
                {category.title}
              </GenieText>
            </Pressable>
          );
        }}
      />

      <GenieCard
        tone="card"
        className="mt-6 p-4"
        onPress={() => navigation.navigate('AiChat')}
        accessibilityLabel="AI Legal Assistant"
      >
        <View className="flex-row items-center self-start rounded-pill bg-info-surface px-2.5 py-1">
          <SparkleIcon size={12} color={colors.info} />
          <GenieText
            variant="smallLabel"
            tone="info"
            className="ml-1 font-bold tracking-widest"
          >
            AI POWERED
          </GenieText>
        </View>

        <GenieText variant="cardTitle" className="mt-3">
          AI Legal Assistant
        </GenieText>
        <GenieText variant="secondary" tone="secondary" className="mt-1">
          Get instant answers to your legal questions.
        </GenieText>

        <View className="mt-4 flex-row items-center">
          <GenieText variant="button" tone="gold">
            Ask Now
          </GenieText>
          <View className="ml-1">
            <ChevronRightIcon size={16} color={colors.gold} />
          </View>
        </View>
      </GenieCard>

      <View className="mt-6">
        <View className="mb-3 flex-row items-baseline justify-between">
          <GenieText variant="sectionTitle">How It Works?</GenieText>
          <GenieText variant="caption" tone="muted" className="ml-3">
            Simple. Secure. Effective.
          </GenieText>
        </View>

        <HowItWorksCarousel />
      </View>
    </GenieScreen>
  );
};
