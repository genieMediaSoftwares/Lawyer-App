import React, { useCallback } from 'react';
import { Pressable, RefreshControl, View } from 'react-native';
import { useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieCard,
  GenieHeroCarousel,
  GenieIconButton,
  GenieScreen,
  GenieSectionHeader,
  GenieText,
  GenieWordmark,
} from '../../../components';
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

/** One numbered step in "How It Works". */
const Step: React.FC<{ n: number; title: string; description: string }> = ({
  n,
  title,
  description,
}) => (
  <View className="flex-row items-start">
    <View className="h-8 w-8 items-center justify-center rounded-full bg-gold">
      <GenieText variant="body-sm" tone="on-gold" className="font-bold">
        {String(n)}
      </GenieText>
    </View>
    <View className="ml-3 flex-1">
      <GenieText variant="body-lg" className="font-semibold">
        {title}
      </GenieText>
      <GenieText variant="body-sm" tone="secondary" className="mt-0.5">
        {description}
      </GenieText>
    </View>
  </View>
);

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

  const onRefresh = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ['notifications'] });
  }, [queryClient]);

  const unreadCount = notificationsQuery.data?.unreadCount ?? 0;

  // Home keeps its own header rather than using GenieHeader: it is the only
  // screen that shows the wordmark instead of a title, and its bell is white
  // rather than gold because there is no title competing for attention.
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
      contentContainerClassName="pb-8"
      scrollViewProps={{
        refreshControl: (
          <RefreshControl
            refreshing={notificationsQuery.isRefetching}
            onRefresh={onRefresh}
            tintColor={colors.gold}
            colors={[colors.gold]}
          />
        ),
      }}
    >
      <View className="mb-4 mt-1">
        <GenieText variant="heading-lg">
          {user ? `Hello, ${user.fullName.split(' ')[0]}` : 'Hello'}
        </GenieText>
        <GenieText variant="body-md" tone="secondary" className="mt-1">
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
        tone="gold"
        className="mt-5 p-5"
        onPress={() => navigation.navigate('AiAssistant')}
        accessibilityLabel="AI Smart Case Assistant"
      >
        <View className="flex-row items-center self-start rounded-pill bg-gold-muted px-2 py-1">
          <SparkleIcon size={12} color={colors.gold} />
          <GenieText
            variant="caption"
            tone="gold"
            className="ml-1 font-bold tracking-widest"
          >
            AI POWERED
          </GenieText>
        </View>

        <GenieText variant="heading-md" className="mt-3">
          AI Smart Case Assistant
        </GenieText>
        <GenieText variant="body-md" tone="gold" className="mt-1">
          {'Don’t know how to post your legal case?'}
        </GenieText>
        <GenieText variant="body-sm" tone="secondary" className="mt-2">
          Upload your documents — add a voice note for extra detail if you like
          — and AI fills in your case for you, ready to find a lawyer.
        </GenieText>

        <View className="mt-4 h-control flex-row items-center justify-center rounded-control bg-gold px-4">
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

      <View className="mt-3 flex-row flex-wrap">
        {popularCategories().map(category => {
          const IconComponent = getCategoryIcon(category.id);

          return (
            <View key={category.id} className="w-1/3 p-1">
              <Pressable
                onPress={() =>
                  navigation.navigate('PostCase', {
                    start: 'manual',
                    categoryId: category.id,
                  })
                }
                accessibilityRole="button"
                accessibilityLabel={category.title}
                className="min-h-touch items-center rounded-card border border-border bg-surface p-3 active:bg-surface-alt"
              >
                <View className="h-11 w-11 items-center justify-center rounded-full bg-gold-muted">
                  <IconComponent size={22} color={colors.gold} />
                </View>
                <GenieText
                  variant="caption"
                  className="mt-2 text-center font-medium"
                  numberOfLines={2}
                >
                  {category.title}
                </GenieText>
              </Pressable>
            </View>
          );
        })}
      </View>

      <GenieCard
        tone="surface"
        className="mt-6 border-info p-5"
        onPress={() => navigation.navigate('AiChat')}
        accessibilityLabel="AI Legal Assistant"
      >
        <View className="flex-row items-center self-start rounded-pill bg-info-surface px-2 py-1">
          <SparkleIcon size={12} color={colors.info} />
          <GenieText
            variant="caption"
            tone="info"
            className="ml-1 font-bold tracking-widest"
          >
            AI POWERED
          </GenieText>
        </View>

        <GenieText variant="heading-md" className="mt-3">
          AI Legal Assistant
        </GenieText>
        <GenieText variant="body-sm" tone="secondary" className="mt-1">
          Get instant answers to your legal questions.
        </GenieText>

        <View className="mt-4 flex-row items-center">
          <GenieText variant="label" tone="gold">
            Ask Now
          </GenieText>
          <View className="ml-1">
            <ChevronRightIcon size={16} color={colors.gold} />
          </View>
        </View>
      </GenieCard>

      <View className="mt-6">
        <GenieText variant="heading-md" className="mb-4">
          How It Works?
        </GenieText>

        <Step
          n={1}
          title="Select Issue"
          description="Choose your legal issue category."
        />
        {/* The line joining one step to the next. Indented so it sits under the
            centre of the numbered badge above it. */}
        <View className="my-2 ml-4 h-5 w-px bg-border" />

        <Step
          n={2}
          title="Case Details"
          description="Add your issue description, location, court preference and urgency."
        />
        <View className="my-2 ml-4 h-5 w-px bg-border" />

        <Step
          n={3}
          title="Connect Advocate"
          description="Connect with verified lawyers for expert guidance."
        />
      </View>
    </GenieScreen>
  );
};
