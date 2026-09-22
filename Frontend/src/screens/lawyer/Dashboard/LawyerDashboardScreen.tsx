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
  VerifiedBadge,
} from '../../../components';
import {
  BellIcon,
  ChatIcon,
  FileIcon,
  StarIcon,
} from '../../../components/icons/ClientIcons';
import { UserPlusIcon } from '../../../components/icons/LawyerIcons';
import { lawyerApi } from '../../../api/lawyerApi';
import { notificationsApi } from '../../../api/clientApi';
import { isActionableLead } from '../../../types/lawyer';
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

  const notificationsQuery = useQuery({
    queryKey: ['notifications', 1],
    queryFn: () => notificationsApi.list(1, 15),
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
      notificationCount={notificationsQuery.data?.unreadCount ?? 0}
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
        <View className="py-3">
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
        <View className="py-3">
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

  const reviewsVal = profile?.totalReviews ?? 0;
  const ratingVal =
    reviewsVal > 0 && profile?.rating ? profile.rating.toFixed(1) : null;
  const specialization = profile?.specialization || '';

  const newLeadsCount = (leadsQuery.data ?? []).filter(isActionableLead).length;
  const unreadMessagesCount = messagesQuery.data?.unreadCount ?? 0;
  const inProgressCount = clientsQuery.data?.inProgress.length ?? 0;
  const acceptedCount = clientsQuery.data?.accepted.length ?? 0;

  return (
    <GenieScreen
      scrollable
      header={header}
      dismissKeyboardOnTap={false}
      contentContainerClassName="pb-20"
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
        <GenieAvatar
          uri={profile?.user?.profileImage ?? user?.profileImage}
          name={fullName}
          size="profile"
        />

        <View className="ml-4 flex-1">
          <View className="flex-row items-center gap-1.5">
            <GenieText variant="sectionTitle" className="flex-shrink" numberOfLines={1}>
              {displayName}
            </GenieText>
            {profile?.verificationStatus === 'verified' ? (
              <VerifiedBadge size={18} />
            ) : null}
          </View>

          {specialization ? (
            <GenieText variant="secondary" tone="secondary" className="mt-0.5">
              {specialization}
            </GenieText>
          ) : null}

          <View className="mt-1 flex-row items-center gap-1">
            <StarIcon size={14} color={colors.gold} />
            <GenieText variant="caption" tone="secondary" className="font-medium">
              {ratingVal
                ? `${ratingVal} (${reviewsVal} ${reviewsVal === 1 ? 'review' : 'reviews'})`
                : 'No reviews yet'}
            </GenieText>
          </View>
        </View>
      </View>

      <View className="mt-5 rounded-[12px] border border-border bg-card p-4">
        <View className="flex-row items-center gap-2">
          <StarIcon size={16} color={colors.gold} />
          <GenieText variant="cardTitle">
            Premium Plan
          </GenieText>
        </View>

        <View className="mt-2 flex-row items-center justify-between gap-3">
          <GenieText variant="secondary" tone="secondary" className="flex-1">
            Unlock priority case matching, AI legal tools, premium visibility, and exclusive professional features.
          </GenieText>

          <Pressable
            onPress={() => navigation.navigate('Subscription')}
            accessibilityRole="button"
            accessibilityLabel="View Plan"
            className="h-[36px] items-center justify-center rounded-[8px] bg-gold px-4 active:bg-gold-pressed"
          >
            <GenieText variant="button" tone="on-gold">
              View Plan
            </GenieText>
          </Pressable>
        </View>
      </View>

      <GenieText variant="sectionTitle" className="mb-3 mt-6">
        Today's Overview
      </GenieText>

      <View className="rounded-[12px] border border-border bg-card px-4 py-1">
        <View className="flex-row items-center justify-between py-3">
          <View className="flex-row items-center flex-1 pr-3">
            <View className="mr-3 h-10 w-10 items-center justify-center rounded-full bg-surface-secondary">
              <UserPlusIcon size={18} color={colors.gold} />
            </View>
            <View className="flex-1">
              <GenieText variant="body" className="font-medium">
                New Case Requests
              </GenieText>
              <GenieText variant="caption" tone="muted" className="mt-0.5">
                Awaiting response
              </GenieText>
            </View>
          </View>

          <GenieText variant="stat" tone="gold">
            {formatTwoDigits(newLeadsCount)}
          </GenieText>
        </View>

        <View className="h-px bg-border" />

        <View className="flex-row items-center justify-between py-3">
          <View className="flex-row items-center flex-1 pr-3">
            <View className="mr-3 h-10 w-10 items-center justify-center rounded-full bg-surface-secondary">
              <ChatIcon size={18} color={colors.gold} />
            </View>
            <View className="flex-1">
              <GenieText variant="body" className="font-medium">
                Unread Messages
              </GenieText>
              <GenieText variant="caption" tone="muted" className="mt-0.5">
                From active clients
              </GenieText>
            </View>
          </View>

          <GenieText variant="stat" tone="gold">
            {formatTwoDigits(unreadMessagesCount)}
          </GenieText>
        </View>

        <View className="h-px bg-border" />

        <View className="flex-row items-center justify-between py-3">
          <View className="flex-row items-center flex-1 pr-3">
            <View className="mr-3 h-10 w-10 items-center justify-center rounded-full bg-surface-secondary">
              <FileIcon size={18} color={colors.gold} />
            </View>
            <View className="flex-1">
              <GenieText variant="body" className="font-medium">
                Cases In Progress
              </GenieText>
              <GenieText variant="caption" tone="muted" className="mt-0.5">
                Cases you are working on
              </GenieText>
            </View>
          </View>

          <GenieText variant="stat" tone="gold">
            {formatTwoDigits(inProgressCount)}
          </GenieText>
        </View>

        <View className="h-px bg-border" />

        <View className="flex-row items-center justify-between py-3">
          <View className="flex-row items-center flex-1 pr-3">
            <View className="mr-3 h-10 w-10 items-center justify-center rounded-full bg-surface-secondary">
              <BellIcon size={18} color={colors.gold} />
            </View>
            <View className="flex-1">
              <GenieText variant="body" className="font-medium">
                Accepted Cases
              </GenieText>
              <GenieText variant="caption" tone="muted" className="mt-0.5">
                Ready for you to start
              </GenieText>
            </View>
          </View>

          <GenieText variant="stat" tone="gold">
            {formatTwoDigits(acceptedCount)}
          </GenieText>
        </View>
      </View>
    </GenieScreen>
  );
};
