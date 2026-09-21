import React from 'react';
import { Pressable, RefreshControl, View } from 'react-native';
import { useQuery } from '@tanstack/react-query';

import {
  GenieErrorState,
  GenieHeader,
  GenieScreen,
  GenieSectionHeader,
  GenieSkeleton,
  GenieText,
} from '../../../components';
import {
  ChatIcon,
  ClockIcon,
  FileIcon,
  ScalesIcon,
  SearchIcon,
  SparkleIcon,
  VerifiedIcon,
} from '../../../components/icons/ClientIcons';
import { UserPlusIcon, UsersIcon } from '../../../components/icons/LawyerIcons';
import { lawyerApi } from '../../../api/lawyerApi';
import { useAuthStore } from '../../../store/authStore';
import { useUiStore } from '../../../store/uiStore';
import type { LawyerTabScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

interface WorkspaceCardProps {
  title: string;
  icon: React.ReactNode;
  count?: number;
  caption?: string;
  showBadge?: boolean;
  onPress?: () => void;
  unavailable?: boolean;
  unavailableReason?: string;
}

const WorkspaceCard: React.FC<WorkspaceCardProps> = ({
  title,
  icon,
  count,
  caption,
  showBadge = false,
  onPress,
  unavailable = false,
  unavailableReason,
}) => (
  <View className="w-1/2 p-1.5">
    <Pressable
      onPress={unavailable ? undefined : onPress}
      disabled={unavailable || !onPress}
      accessibilityRole="button"
      accessibilityLabel={
        unavailable ? `${title}. ${unavailableReason ?? 'Not available'}` : title
      }
      accessibilityState={{ disabled: unavailable }}
      className={`min-h-[124px] justify-between rounded-card border border-border bg-card p-4 ${
        unavailable ? 'opacity-50' : 'active:bg-surface-alt'
      }`}
    >
      <View className="flex-row items-center justify-between">
        <View className="h-10 w-10 items-center justify-center rounded-full bg-gold-muted border border-gold/20">
          {icon}
        </View>

        <View className="flex-row items-center gap-1.5">
          {showBadge && (
            <View className="h-2.5 w-2.5 rounded-full bg-gold shadow-sm" />
          )}

          {typeof count === 'number' ? (
            <GenieText variant="heading-sm" tone="gold" className="font-bold">
              {String(count)}
            </GenieText>
          ) : null}
        </View>
      </View>

      <View className="mt-3">
        <GenieText variant="body-md" className="font-semibold text-white" numberOfLines={1}>
          {title}
        </GenieText>

        {unavailable ? (
          <GenieText variant="caption" tone="muted" className="mt-0.5" numberOfLines={1}>
            {unavailableReason ?? 'Not available'}
          </GenieText>
        ) : caption ? (
          <GenieText variant="caption" tone="muted" className="mt-0.5" numberOfLines={1}>
            {caption}
          </GenieText>
        ) : null}
      </View>
    </Pressable>
  </View>
);

export const WorkspaceScreen: React.FC<LawyerTabScreenProps<'Workspace'>> = ({
  navigation,
}) => {
  const user = useAuthStore(state => state.user);
  const openDrawer = useUiStore(state => state.openDrawer);

  const leadsQuery = useQuery({
    queryKey: ['lawyer', 'leads'],
    queryFn: lawyerApi.getLeads,
  });

  const clientsQuery = useQuery({
    queryKey: ['lawyer', 'clients'],
    queryFn: lawyerApi.getClients,
  });

  const scheduleQuery = useQuery({
    queryKey: ['lawyer', 'schedule', 'today'],
    queryFn: lawyerApi.getScheduleToday,
  });

  const messagesQuery = useQuery({
    queryKey: ['lawyer', 'messages', 'unread'],
    queryFn: lawyerApi.getUnreadMessages,
  });

  const profileQuery = useQuery({
    queryKey: ['lawyer', 'profile', user?.id],
    queryFn: () => lawyerApi.getProfile(user!.id),
    enabled: Boolean(user?.id),
  });

  const clientCount = clientsQuery.data
    ? clientsQuery.data.accepted.length +
      clientsQuery.data.inProgress.length +
      clientsQuery.data.closed.length
    : undefined;

  const hasPendingClientData = clientsQuery.data
    ? clientsQuery.data.accepted.length > 0
    : false;

  const isLoading =
    leadsQuery.isLoading ||
    clientsQuery.isLoading ||
    scheduleQuery.isLoading ||
    messagesQuery.isLoading ||
    profileQuery.isLoading;

  const isError =
    leadsQuery.isError ||
    clientsQuery.isError ||
    scheduleQuery.isError ||
    messagesQuery.isError ||
    profileQuery.isError;

  const errorMessage =
    (leadsQuery.error as Error)?.message ||
    (clientsQuery.error as Error)?.message ||
    (scheduleQuery.error as Error)?.message ||
    (messagesQuery.error as Error)?.message ||
    (profileQuery.error as Error)?.message ||
    'Unable to load workspace data';

  const isRefreshing =
    leadsQuery.isRefetching ||
    clientsQuery.isRefetching ||
    scheduleQuery.isRefetching ||
    messagesQuery.isRefetching ||
    profileQuery.isRefetching;

  const refreshAll = () => {
    void leadsQuery.refetch();
    void clientsQuery.refetch();
    void scheduleQuery.refetch();
    void messagesQuery.refetch();
    void profileQuery.refetch();
  };

  const profile = profileQuery.data;
  const realName = profile?.user?.fullName || user?.fullName || 'Advocate';

  const scheduleCaption = scheduleQuery.data
    ? scheduleQuery.data.length === 0
      ? 'No Events Today'
      : `${scheduleQuery.data.length} scheduled today`
    : 'No Events Today';

  const messagesCaption = messagesQuery.data
    ? messagesQuery.data.unreadCount === 0
      ? "You're all caught up"
      : `${messagesQuery.data.unreadCount} unread`
    : "You're all caught up";

  return (
    <GenieScreen
      scrollable
      dismissKeyboardOnTap={false}
      header={
        <GenieHeader
          onMenu={openDrawer}
          onNotifications={() => navigation.navigate('Notifications')}
        />
      }
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
      <View className="mt-2 mb-6 rounded-card border border-border bg-surface p-5">
        <GenieText variant="body-md" tone="secondary" className="font-medium">
          Welcome, Advocate
        </GenieText>

        <View className="mt-1 flex-row items-center gap-1.5">
          <GenieText variant="heading-lg" tone="gold" className="font-bold flex-1" numberOfLines={1}>
            {realName}
          </GenieText>
          {profile?.verificationStatus === 'verified' ? (
            <VerifiedIcon size={20} color={colors.gold} />
          ) : null}
        </View>

        <GenieText variant="body-sm" tone="secondary" className="mt-3 leading-5">
          Manage client cases, review legal inquiries, respond to consultation requests, and organize your schedule—all from one secure workspace.
        </GenieText>
      </View>

      {isError ? (
        <GenieErrorState
          title="Workspace Unavailable"
          message={errorMessage}
          onRetry={refreshAll}
          retryLabel="Retry"
          className="mb-6"
        />
      ) : null}

      <GenieSectionHeader title="Workspace Tools" />

      {isLoading ? (
        <View className="mt-2 flex-row flex-wrap -mx-1.5">
          <View className="w-1/2 p-1.5"><GenieSkeleton className="h-[124px] rounded-card" /></View>
          <View className="w-1/2 p-1.5"><GenieSkeleton className="h-[124px] rounded-card" /></View>
          <View className="w-1/2 p-1.5"><GenieSkeleton className="h-[124px] rounded-card" /></View>
          <View className="w-1/2 p-1.5"><GenieSkeleton className="h-[124px] rounded-card" /></View>
        </View>
      ) : (
        <View className="mt-2 flex-row flex-wrap -mx-1.5">
          <WorkspaceCard
            title="New Leads"
            icon={<UserPlusIcon size={20} color={colors.gold} />}
            count={leadsQuery.data?.length}
            caption="Waiting for your response"
            onPress={() => navigation.navigate('Leads')}
          />
          <WorkspaceCard
            title="Clients"
            icon={<UsersIcon size={20} color={colors.gold} />}
            count={clientCount}
            caption="Across all stages"
            showBadge={hasPendingClientData}
            onPress={() => navigation.navigate('Clients')}
          />
          <WorkspaceCard
            title="Today's Schedule"
            icon={<ClockIcon size={20} color={colors.gold} />}
            count={scheduleQuery.data?.length}
            caption={scheduleCaption}
            onPress={() => navigation.navigate('Calendar')}
          />
          <WorkspaceCard
            title="Messages"
            icon={<ChatIcon size={20} color={colors.gold} />}
            count={messagesQuery.data?.unreadCount}
            caption={messagesCaption}
            onPress={() => navigation.navigate('Messages')}
          />
        </View>
      )}

      <View className="mt-6">
        <GenieText variant="heading-sm" className="font-bold text-white">
          My Practice
        </GenieText>
        <GenieText variant="caption" tone="secondary" className="mt-0.5">
          Documents, research, hearings and notes in one place.
        </GenieText>
      </View>

      <View className="mt-3 flex-row flex-wrap -mx-1.5">
        <WorkspaceCard
          title="Documents"
          icon={<FileIcon size={20} color={colors.gold} />}
          onPress={() => navigation.navigate('Documents')}
        />
        <WorkspaceCard
          title="Research"
          icon={<SearchIcon size={20} color={colors.gold} />}
          caption="AI legal research"
          onPress={() => navigation.navigate('Research')}
        />
        <WorkspaceCard
          title="Hearings"
          icon={<ScalesIcon size={20} color={colors.gold} />}
          onPress={() => navigation.navigate('Hearings')}
        />
        <WorkspaceCard
          title="Notes"
          icon={<FileIcon size={20} color={colors.gold} />}
          caption="Your private notebook"
          onPress={() => navigation.navigate('Notes')}
        />
      </View>

      <View className="mt-6 mb-4 rounded-card border border-gold/30 bg-card p-4">
        <View className="flex-row items-center gap-2">
          <View className="h-7 w-7 items-center justify-center rounded-full bg-gold-muted border border-gold/20">
            <SparkleIcon size={16} color={colors.gold} />
          </View>
          <GenieText variant="body-md" tone="gold" className="font-bold">
            Client Success Tip
          </GenieText>
        </View>

        <GenieText variant="body-sm" tone="secondary" className="mt-2 leading-5">
          Prompt responses to initial client inquiries significantly increase consultation conversion rates. Keep your calendar updated to ensure seamless appointment booking.
        </GenieText>
      </View>
    </GenieScreen>
  );
};
