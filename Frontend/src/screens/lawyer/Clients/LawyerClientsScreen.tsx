import React, { useMemo, useState } from 'react';
import { FlatList, Pressable, RefreshControl, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieAvatar,
  GenieEmptyState,
  GenieErrorState,
  GenieHeader,
  GenieNotice,
  GenieSearchInput,
  GenieSkeletonList,
  GenieText,
} from '../../../components';
import {
  ClockIcon,
  LocationIcon,
  ScalesIcon,
} from '../../../components/icons/ClientIcons';
import {
  CalendarIcon,
  CheckCircleIcon,
  UsersIcon,
} from '../../../components/icons/LawyerIcons';
import { lawyerApi } from '../../../api/lawyerApi';
import { notificationsApi } from '../../../api/clientApi';
import { chatApi } from '../../../api/chatApi';
import { useUiStore } from '../../../store/uiStore';
import { toAppError } from '../../../utils/errors';
import { formatDate } from '../../../utils/format';
import type { LawyerClientRow } from '../../../types/lawyer';
import type { LawyerTabScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

type ClientTab = 'active' | 'inProgress' | 'completed';

export const LawyerClientsScreen: React.FC<
  LawyerTabScreenProps<'Clients'>
> = ({ navigation }) => {
  const openDrawer = useUiStore(state => state.openDrawer);
  const queryClient = useQueryClient();

  const [tab, setTab] = useState<ClientTab>('active');
  const [search, setSearch] = useState('');
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyCaseId, setBusyCaseId] = useState<string | null>(null);

  // Real-time polling for clients (3s) with zero stale time
  const clientsQuery = useQuery({
    queryKey: ['lawyer', 'clients'],
    queryFn: lawyerApi.getClients,
    refetchInterval: 3000,
    refetchOnWindowFocus: true,
    refetchOnMount: true,
    refetchOnReconnect: true,
    staleTime: 0,
  });

  // Fetch notifications count for header bell
  const notificationsQuery = useQuery({
    queryKey: ['notifications', 1],
    queryFn: () => notificationsApi.list(1, 15),
    refetchInterval: 10000,
  });

  const unreadNotificationsCount = notificationsQuery.data?.unreadCount ?? 0;

  const settle = async () => {
    setBusyCaseId(null);
    await queryClient.invalidateQueries({ queryKey: ['lawyer', 'clients'] });
    await queryClient.invalidateQueries({ queryKey: ['lawyer', 'leads'] });
  };

  const startCaseMutation = useMutation({
    mutationFn: (caseId: string) => lawyerApi.startCase(caseId),
    onError: error => {
      setBusyCaseId(null);
      setActionError(toAppError(error).message);
    },
    onSuccess: settle,
  });

  const completeCaseMutation = useMutation({
    mutationFn: (caseId: string) => lawyerApi.markCaseCompleted(caseId),
    onError: error => {
      setBusyCaseId(null);
      setActionError(toAppError(error).message);
    },
    onSuccess: settle,
  });

  const openChat = async (row: LawyerClientRow) => {
    setActionError(null);
    try {
      const chat = await chatApi.getOrCreateChat(row.clientId);
      (navigation as any).navigate('Chat', {
        chatId: chat._id,
        name: row.name,
        avatar: row.profileImage,
      });
    } catch (error) {
      setActionError(toAppError(error).message);
    }
  };

  const groups = clientsQuery.data;

  const rows: LawyerClientRow[] = useMemo(() => {
    if (!groups) {
      return [];
    }
    const source =
      tab === 'active'
        ? groups.accepted
        : tab === 'inProgress'
        ? groups.inProgress
        : groups.closed;

    const q = search.trim().toLowerCase();
    if (!q) {
      return source;
    }
    return source.filter(
      r =>
        r.name.toLowerCase().includes(q) ||
        r.issue.toLowerCase().includes(q) ||
        (r.category && r.category.toLowerCase().includes(q)),
    );
  }, [groups, tab, search]);

  const countFor = (key: ClientTab): number => {
    if (!groups) {
      return 0;
    }
    return key === 'active'
      ? groups.accepted.length
      : key === 'inProgress'
      ? groups.inProgress.length
      : groups.closed.length;
  };

  const renderActiveCard = (item: LawyerClientRow) => {
    const isBusy = busyCaseId === item.caseId;
    const shortId = item.clientId ? item.clientId.slice(-8) : 'b4b1cc2f';

    return (
      <View
        key={item.caseId}
        className="mb-4 rounded-2xl border border-border/40 bg-surface-alt p-4"
      >
        {/* Header Row */}
        <View className="flex-row items-center justify-between">
          <View className="flex-row items-center gap-3 flex-1 pr-2">
            <GenieAvatar uri={item.profileImage} name={item.name} size="md" />
            <View className="flex-1">
              <GenieText className="font-bold text-base text-text-primary" numberOfLines={1}>
                {item.name}
              </GenieText>
              <GenieText className="mt-0.5 text-xs text-text-muted font-medium">
                ID: {shortId}
              </GenieText>
            </View>
          </View>

          <View className="rounded-lg border border-blue-500/40 bg-blue-500/15 px-3 py-1">
            <GenieText className="font-semibold text-xs text-blue-400">
              Accepted
            </GenieText>
          </View>
        </View>

        <View className="my-3 border-t border-border/40" />

        {/* Details List */}
        <View className="gap-2.5">
          <View className="flex-row items-center gap-2.5">
            <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
              Category: <GenieText className="font-medium text-text-primary">{item.category || 'Family & Divorce'}</GenieText>
            </GenieText>
          </View>

          <View className="flex-row items-center gap-2.5">
            <GenieText className="flex-1 text-xs text-text-secondary" numberOfLines={1}>
              Title: <GenieText className="font-medium text-text-primary">{item.issue}</GenieText>
            </GenieText>
          </View>

          <View className="flex-row items-center gap-2.5">
            <LocationIcon size={14} color={colors.textMuted} />
            <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
              Location: <GenieText className="font-medium text-text-primary">{item.location || 'Visakhapatnam'}</GenieText>
            </GenieText>
          </View>

          <View className="flex-row items-center gap-2.5">
            <ScalesIcon size={14} color={colors.textMuted} />
            <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
              Court: <GenieText className="font-medium text-text-primary">{item.preferredCourt || 'Any Court'}</GenieText>
            </GenieText>
          </View>

          <View className="flex-row items-center gap-2.5">
            <CalendarIcon size={14} color={colors.textMuted} />
            <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
              Accepted: <GenieText className="font-medium text-text-primary">{formatDate(item.acceptedAt || item.lastActivity)}</GenieText>
            </GenieText>
          </View>
        </View>

        {/* Action Buttons */}
        <View className="mt-4 flex-row gap-3">
          <Pressable
            onPress={() => (navigation as any).navigate('CaseDetails', { caseId: item.caseId })}
            className="flex-1 items-center justify-center rounded-xl border border-gold py-2.5 active:bg-gold-muted/20"
          >
            <GenieText className="font-semibold text-sm text-gold">
              View Client
            </GenieText>
          </Pressable>

          <Pressable
            disabled={isBusy}
            onPress={() => {
              setActionError(null);
              setBusyCaseId(item.caseId);
              startCaseMutation.mutate(item.caseId);
            }}
            className="flex-1 items-center justify-center rounded-xl bg-gold py-2.5 active:bg-gold-hover"
          >
            <GenieText className="font-bold text-sm text-on-gold">
              {isBusy ? 'Starting...' : 'Start Case'}
            </GenieText>
          </Pressable>
        </View>
      </View>
    );
  };

  const renderInProgressCard = (item: LawyerClientRow) => {
    const isBusy = busyCaseId === item.caseId;
    const tasksCount = item.tasksRemaining ?? 2;

    return (
      <View
        key={item.caseId}
        className="mb-4 rounded-2xl border border-border/40 bg-surface-alt p-4"
      >
        {/* Header Row */}
        <View className="flex-row items-center justify-between">
          <View className="flex-row items-center gap-3 flex-1 pr-2">
            <GenieAvatar uri={item.profileImage} name={item.name} size="md" />
            <View className="flex-1">
              <GenieText className="font-bold text-base text-text-primary" numberOfLines={1}>
                {item.name}
              </GenieText>
              <GenieText className="mt-0.5 text-xs text-text-secondary" numberOfLines={1}>
                Case: {item.issue}
              </GenieText>
            </View>
          </View>

          <View className="rounded-lg border border-amber-500/40 bg-amber-500/15 px-3 py-1">
            <GenieText className="font-semibold text-xs text-amber-400">
              In Progress
            </GenieText>
          </View>
        </View>

        <View className="my-3 border-t border-border/40" />

        {/* Details List */}
        <View className="gap-2.5">
          <View className="flex-row items-center gap-2.5">
            <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
              Category: <GenieText className="font-medium text-text-primary">{item.category || 'Family & Divorce'}</GenieText>
            </GenieText>
          </View>

          <View className="flex-row items-center gap-2.5">
            <ClockIcon size={14} color={colors.textMuted} />
            <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
              Last Updated: <GenieText className="font-medium text-text-primary">{formatDate(item.lastActivity)}</GenieText>
            </GenieText>
          </View>

          <View className="flex-row items-center gap-2.5">
            <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
              Tasks: <GenieText className="font-medium text-text-primary">{tasksCount} tasks remaining</GenieText>
            </GenieText>
          </View>
        </View>

        {/* Action Buttons Top Row */}
        <View className="mt-4 flex-row gap-3">
          <Pressable
            onPress={() => (navigation as any).navigate('CaseDetails', { caseId: item.caseId })}
            className="flex-1 items-center justify-center rounded-xl border border-gold py-2.5 active:bg-gold-muted/20"
          >
            <GenieText className="font-semibold text-sm text-gold">
              View Case
            </GenieText>
          </Pressable>

          <Pressable
            onPress={() => void openChat(item)}
            className="flex-1 items-center justify-center rounded-xl border border-gold py-2.5 active:bg-gold-muted/20"
          >
            <GenieText className="font-semibold text-sm text-gold">
              Chat
            </GenieText>
          </Pressable>
        </View>

        {/* Full-width Mark Case Completed Green Button */}
        <Pressable
          disabled={isBusy}
          onPress={() => {
            setActionError(null);
            setBusyCaseId(item.caseId);
            completeCaseMutation.mutate(item.caseId);
          }}
          className="mt-3 flex-row items-center justify-center gap-2 rounded-xl bg-emerald-600 py-3 active:bg-emerald-700"
        >
          <GenieText className="font-bold text-sm text-white">
            {isBusy ? 'Completing...' : 'Mark Case Completed'}
          </GenieText>
        </Pressable>
      </View>
    );
  };

  const renderCompletedCard = (item: LawyerClientRow) => {
    return (
      <View
        key={item.caseId}
        className="mb-4 rounded-2xl border border-border/40 bg-surface-alt p-4"
      >
        <View className="flex-row items-center justify-between">
          <View className="flex-row items-center gap-3 flex-1 pr-2">
            <GenieAvatar uri={item.profileImage} name={item.name} size="md" />
            <View className="flex-1">
              <GenieText className="font-bold text-base text-text-primary" numberOfLines={1}>
                {item.name}
              </GenieText>
              <GenieText className="mt-0.5 text-xs text-text-secondary" numberOfLines={1}>
                {item.issue}
              </GenieText>
            </View>
          </View>

          <View className="rounded-lg border border-blue-500/40 bg-blue-500/15 px-3 py-1">
            <GenieText className="font-semibold text-xs text-blue-400">
              Completed
            </GenieText>
          </View>
        </View>

        <View className="my-3 border-t border-border/40" />

        <GenieText className="text-xs text-text-muted">
          Completed on: {formatDate(item.lastActivity)}
        </GenieText>

        <View className="mt-3 flex-row gap-3">
          <Pressable
            onPress={() => (navigation as any).navigate('CaseDetails', { caseId: item.caseId })}
            className="flex-1 items-center justify-center rounded-xl border border-border py-2"
          >
            <GenieText className="font-semibold text-xs text-text-secondary">
              View Case
            </GenieText>
          </Pressable>

          <Pressable
            onPress={() => void openChat(item)}
            className="flex-1 items-center justify-center rounded-xl border border-border py-2"
          >
            <GenieText className="font-semibold text-xs text-text-secondary">
              Chat
            </GenieText>
          </Pressable>
        </View>
      </View>
    );
  };

  const renderBody = () => {
    if (clientsQuery.isPending) {
      return (
        <View className="px-4">
          <GenieSkeletonList count={3} />
        </View>
      );
    }

    if (clientsQuery.isError) {
      return (
        <View className="px-4">
          <GenieErrorState
            message={clientsQuery.error.message}
            onRetry={() => clientsQuery.refetch()}
          />
        </View>
      );
    }

    return (
      <FlatList
        data={rows}
        keyExtractor={item => item.caseId}
        contentContainerClassName="px-4 pb-12 pt-1"
        contentContainerStyle={
          rows.length === 0 ? { flexGrow: 1, justifyContent: 'center' } : undefined
        }
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        refreshControl={
          <RefreshControl
            refreshing={clientsQuery.isRefetching}
            onRefresh={() => {
              void clientsQuery.refetch();
              void notificationsQuery.refetch();
            }}
            tintColor={colors.gold}
            colors={[colors.gold]}
          />
        }
        renderItem={({ item }) =>
          tab === 'active'
            ? renderActiveCard(item)
            : tab === 'inProgress'
            ? renderInProgressCard(item)
            : renderCompletedCard(item)
        }
        ListEmptyComponent={
          <GenieEmptyState
            icon={<UsersIcon size={28} color={colors.gold} />}
            title={
              search.trim()
                ? 'No matching clients'
                : tab === 'active'
                ? 'No active clients'
                : tab === 'inProgress'
                ? 'No cases in progress'
                : 'No completed cases'
            }
            description={
              search.trim()
                ? `Nothing matches "${search}".`
                : tab === 'active'
                ? 'Leads you accept appear here, ready to start.'
                : tab === 'inProgress'
                ? 'Cases you have started appear here.'
                : 'Closed or completed cases appear here.'
            }
            actionLabel={search.trim() ? 'Clear search' : undefined}
            onAction={search.trim() ? () => setSearch('') : undefined}
          />
        }
      />
    );
  };

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      {/* Header: Menu Icon + Title + Notifications Icon */}
      <GenieHeader
        title="Clients"
        onMenu={openDrawer}
        onNotifications={() => (navigation as any).navigate('Notifications')}
        notificationCount={unreadNotificationsCount}
      />

      {/* Tabs Header with Underline & Count Badges */}
      <View className="flex-row border-b border-border/30 px-4 pt-1">
        {(
          [
            ['active', 'Active', countFor('active')],
            ['inProgress', 'In Progress', countFor('inProgress')],
            ['completed', 'Completed', countFor('completed')],
          ] as const
        ).map(([key, label, count]) => {
          const isActive = tab === key;
          return (
            <Pressable
              key={key}
              onPress={() => setTab(key)}
              className={`mr-5 flex-row items-center gap-1.5 pb-3 ${
                isActive ? 'border-b-2 border-gold' : ''
              }`}
            >
              <GenieText
                className={`font-semibold text-base ${
                  isActive ? 'text-gold' : 'text-text-secondary'
                }`}
              >
                {label}
              </GenieText>
              <View
                className={`h-5 w-5 items-center justify-center rounded-full ${
                  isActive ? 'bg-amber-600/80' : 'bg-surface-alt'
                }`}
              >
                <GenieText className="font-bold text-[11px] text-white">
                  {count}
                </GenieText>
              </View>
            </Pressable>
          );
        })}
      </View>

      {/* Search Bar */}
      <View className="px-4 pb-2 pt-3">
        <GenieSearchInput
          placeholder="Search clients..."
          value={search}
          onChangeText={setSearch}
          onClear={() => setSearch('')}
        />
      </View>

      {actionError ? (
        <View className="px-4 pb-2">
          <GenieNotice message={actionError} />
        </View>
      ) : null}

      {renderBody()}
    </SafeAreaView>
  );
};
