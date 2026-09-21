import React from 'react';
import { Pressable, RefreshControl, View } from 'react-native';
import { useQuery } from '@tanstack/react-query';

import {
  GenieAvatar,
  GenieErrorState,
  GenieHeader,
  GenieScreen,
  GenieSkeleton,
  GenieText,
} from '../../../components';
import {
  BellIcon,
  ChatIcon,
  ClockIcon,
  FileIcon,
  StarIcon,
  VerifiedIcon,
} from '../../../components/icons/ClientIcons';
import { UserPlusIcon } from '../../../components/icons/LawyerIcons';
import { lawyerApi } from '../../../api/lawyerApi';
import { useAuthStore } from '../../../store/authStore';
import { useUiStore } from '../../../store/uiStore';
import type { LawyerTabScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

const formatTwoDigits = (num?: number): string => {
  if (typeof num !== 'number') return '00';
  return String(num).padStart(2, '0');
};

export const LawyerDashboardScreen: React.FC<
  LawyerTabScreenProps<'Dashboard'>
> = ({ navigation }) => {
  const user = useAuthStore(state => state.user);
  const openDrawer = useUiStore(state => state.openDrawer);

  const profileQuery = useQuery({
    queryKey: ['lawyer', 'profile', user?.id],
    queryFn: () => lawyerApi.getProfile(user!.id),
    enabled: Boolean(user?.id),
  });

  const leadsQuery = useQuery({
    queryKey: ['lawyer', 'leads'],
    queryFn: lawyerApi.getLeads,
  });

  const clientsQuery = useQuery({
    queryKey: ['lawyer', 'clients'],
    queryFn: lawyerApi.getClients,
  });

  const messagesQuery = useQuery({
    queryKey: ['lawyer', 'messages', 'unread'],
    queryFn: lawyerApi.getUnreadMessages,
  });

  const subscriptionQuery = useQuery({
    queryKey: ['subscription'],
    queryFn: lawyerApi.getSubscription,
  });

  const header = (
    <GenieHeader
      title="Dashboard"
      onMenu={openDrawer}
      onNotifications={() => navigation.navigate('Notifications')}
    />
  );

  const isLoading =
    profileQuery.isLoading ||
    leadsQuery.isLoading ||
    clientsQuery.isLoading ||
    messagesQuery.isLoading ||
    subscriptionQuery.isLoading;

  const isError =
    profileQuery.isError ||
    leadsQuery.isError ||
    clientsQuery.isError ||
    messagesQuery.isError;

  const errorMessage =
    (profileQuery.error as Error)?.message ||
    (leadsQuery.error as Error)?.message ||
    (clientsQuery.error as Error)?.message ||
    (messagesQuery.error as Error)?.message ||
    'Unable to load dashboard details';

  const isRefreshing =
    profileQuery.isRefetching ||
    leadsQuery.isRefetching ||
    clientsQuery.isRefetching ||
    messagesQuery.isRefetching ||
    subscriptionQuery.isRefetching;

  const refreshAll = () => {
    void profileQuery.refetch();
    void leadsQuery.refetch();
    void clientsQuery.refetch();
    void messagesQuery.refetch();
    void subscriptionQuery.refetch();
  };

  if (isLoading) {
    return (
      <GenieScreen header={header} dismissKeyboardOnTap={false}>
        <View className="px-5 py-3">
          <GenieSkeleton className="h-24 w-full rounded-card" />
          <GenieSkeleton className="mt-4 h-32 w-full rounded-card" />
          <GenieSkeleton className="mt-6 h-64 w-full rounded-card" />
        </View>
      </GenieScreen>
    );
  }

  if (isError) {
    return (
      <GenieScreen header={header} dismissKeyboardOnTap={false}>
        <View className="px-5 py-3">
          <GenieErrorState
            title="Dashboard Unavailable"
            message={errorMessage}
            onRetry={refreshAll}
            retryLabel="Try Again"
          />
        </View>
      </GenieScreen>
    );
  }

  const profile = profileQuery.data;
  const fullName = profile?.user?.fullName || user?.fullName || 'Advocate';
  const displayName = fullName.toLowerCase().startsWith('adv.')
    ? fullName
    : `Adv. ${fullName}`;

  const ratingVal = profile?.rating && profile.rating > 0 ? profile.rating.toFixed(1) : '0.0';
  const reviewsVal = profile?.totalReviews ?? 0;
  const specialization = profile?.specialization || 'General Practice';

  const newLeadsCount = leadsQuery.data?.length ?? 0;
  const unreadMessagesCount = messagesQuery.data?.unreadCount ?? 0;
  const pendingDocsCount = clientsQuery.data?.inProgress.length ?? 0;
  const pendingResponsesCount = clientsQuery.data?.accepted.length ?? 0;

  return (
    <GenieScreen
      scrollable
      header={header}
      dismissKeyboardOnTap={false}
      contentContainerClassName="pb-20 px-5"
      scrollViewProps={{
        refreshControl: (
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={refreshAll}
            tintColor={colors.gold}
            colors={[colors.gold]}
          />
        ),
      }}
    >
      <View className="mt-2 flex-row items-center">
        <View className="rounded-full border-2 border-gold p-0.5">
          <GenieAvatar
            uri={profile?.user?.profileImage ?? user?.profileImage}
            name={fullName}
            size="lg"
          />
        </View>

        <View className="ml-4 flex-1">
          <View className="flex-row items-center gap-1.5">
            <GenieText variant="heading-md" className="font-bold text-white" numberOfLines={1}>
              {displayName}
            </GenieText>
            {profile?.verificationStatus === 'verified' ? (
              <VerifiedIcon size={18} color={colors.gold} />
            ) : (
              <VerifiedIcon size={18} color={colors.gold} />
            )}
          </View>

          <GenieText variant="body-sm" tone="secondary" className="mt-0.5 font-normal">
            {specialization}
          </GenieText>

          <View className="mt-1 flex-row items-center gap-1">
            <StarIcon size={14} color={colors.gold} />
            <GenieText variant="caption" tone="secondary" className="font-medium">
              {ratingVal} ({reviewsVal} Reviews)
            </GenieText>
          </View>
        </View>
      </View>

      <View className="mt-5 rounded-card border border-gold/40 bg-card p-4">
        <View className="flex-row items-center gap-2">
          <StarIcon size={16} color={colors.gold} />
          <GenieText variant="heading-sm" className="font-bold text-white">
            Premium Plan
          </GenieText>
        </View>

        <View className="mt-2 flex-row items-center justify-between gap-3">
          <GenieText variant="body-sm" tone="secondary" className="flex-1 leading-5">
            Unlock priority case matching, AI legal tools, premium visibility, and exclusive professional features.
          </GenieText>

          <Pressable
            onPress={() => navigation.navigate('Subscription')}
            accessibilityRole="button"
            accessibilityLabel="View Plan"
            className="rounded-xl border border-gold px-4 py-2.5 active:bg-gold-muted"
          >
            <GenieText variant="body-sm" tone="gold" className="font-bold text-center">
              View Plan
            </GenieText>
          </Pressable>
        </View>
      </View>

      <GenieText variant="heading-sm" className="mt-6 mb-3 font-bold text-white">
        Today's Overview
      </GenieText>

      <View className="rounded-card border border-border bg-card p-4">
        <View className="flex-row items-center justify-between py-2">
          <View className="flex-row items-center flex-1 pr-3">
            <View className="mr-3.5 h-10 w-10 items-center justify-center rounded-full bg-gold-muted border border-gold/20">
              <UserPlusIcon size={18} color={colors.gold} />
            </View>
            <View className="flex-1">
              <GenieText variant="body-md" className="font-semibold text-white">
                New Case Requests
              </GenieText>
              <GenieText variant="caption" tone="muted" className="mt-0.5">
                Awaiting response
              </GenieText>
            </View>
          </View>

          <GenieText variant="heading-md" tone="gold" className="font-bold">
            {formatTwoDigits(newLeadsCount)}
          </GenieText>
        </View>

        <View className="h-px bg-border/50 my-2" />

        <View className="flex-row items-center justify-between py-2">
          <View className="flex-row items-center flex-1 pr-3">
            <View className="mr-3.5 h-10 w-10 items-center justify-center rounded-full bg-gold-muted border border-gold/20">
              <ChatIcon size={18} color={colors.gold} />
            </View>
            <View className="flex-1">
              <GenieText variant="body-md" className="font-semibold text-white">
                Unread Messages
              </GenieText>
              <GenieText variant="caption" tone="muted" className="mt-0.5">
                From active clients
              </GenieText>
            </View>
          </View>

          <GenieText variant="heading-md" tone="gold" className="font-bold">
            {formatTwoDigits(unreadMessagesCount)}
          </GenieText>
        </View>

        <View className="h-px bg-border/50 my-2" />

        <View className="flex-row items-center justify-between py-2">
          <View className="flex-row items-center flex-1 pr-3">
            <View className="mr-3.5 h-10 w-10 items-center justify-center rounded-full bg-gold-muted border border-gold/20">
              <FileIcon size={18} color={colors.gold} />
            </View>
            <View className="flex-1">
              <GenieText variant="body-md" className="font-semibold text-white">
                Pending Document Reviews
              </GenieText>
              <GenieText variant="caption" tone="muted" className="mt-0.5">
                Docs waiting for review
              </GenieText>
            </View>
          </View>

          <GenieText variant="heading-md" tone="gold" className="font-bold">
            {formatTwoDigits(pendingDocsCount)}
          </GenieText>
        </View>

        <View className="h-px bg-border/50 my-2" />

        <View className="flex-row items-center justify-between py-2">
          <View className="flex-row items-center flex-1 pr-3">
            <View className="mr-3.5 h-10 w-10 items-center justify-center rounded-full bg-gold-muted border border-gold/20">
              <BellIcon size={18} color={colors.gold} />
            </View>
            <View className="flex-1">
              <GenieText variant="body-md" className="font-semibold text-white">
                Pending Client Responses
              </GenieText>
              <GenieText variant="caption" tone="muted" className="mt-0.5">
                Waiting for lawyer action
              </GenieText>
            </View>
          </View>

          <GenieText variant="heading-md" tone="gold" className="font-bold">
            {formatTwoDigits(pendingResponsesCount)}
          </GenieText>
        </View>
      </View>
    </GenieScreen>
  );
};
