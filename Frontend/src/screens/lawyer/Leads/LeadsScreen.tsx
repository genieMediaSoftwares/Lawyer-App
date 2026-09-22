import React, { useMemo, useState } from 'react';
import { FlatList, Pressable, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieAvatar,
  GenieFilterTabs,
  GenieEmptyState,
  GenieErrorState,
  GenieHeader,
  GenieNotice,
  GenieSearchInput,
  GenieSkeletonList,
  GenieText,
  GenieRefreshControl,
} from '../../../components';
import {
  ClockIcon,
  FileIcon,
  LocationIcon,
  MoreVerticalIcon,
  ScalesIcon,
} from '../../../components/icons/ClientIcons';
import { UserPlusIcon } from '../../../components/icons/LawyerIcons';
import { lawyerApi } from '../../../api/lawyerApi';
import { notificationsApi } from '../../../api/clientApi';
import { useUiStore } from '../../../store/uiStore';
import { toAppError } from '../../../utils/errors';
import { formatDate } from '../../../utils/format';
import { isActionableLead } from '../../../types/lawyer';
import type { LawyerLead } from '../../../types/lawyer';
import type { LawyerTabScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';
import { usePollWhileFocused } from '../../../hooks/useScreenFocused';

type LeadTab = 'new' | 'accepted';

export const LeadsScreen: React.FC<LawyerTabScreenProps<'Leads'>> = ({
  navigation,
}) => {
  const openDrawer = useUiStore(state => state.openDrawer);
  const queryClient = useQueryClient();

  const [tab, setTab] = useState<LeadTab>('new');
  const [search, setSearch] = useState('');
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyCaseId, setBusyCaseId] = useState<string | null>(null);

  // Poll only while this screen is visible (see usePollWhileFocused).
  const pollWhileFocused = usePollWhileFocused();

  const leadsQuery = useQuery({
    queryKey: ['lawyer', 'leads'],
    queryFn: lawyerApi.getLeads,
    refetchInterval: pollWhileFocused(3000),
    refetchOnWindowFocus: true,
    refetchOnMount: true,
    refetchOnReconnect: true,
    staleTime: 0,
  });

  const clientsQuery = useQuery({
    queryKey: ['lawyer', 'clients'],
    queryFn: lawyerApi.getClients,
    refetchInterval: pollWhileFocused(3000),
    refetchOnWindowFocus: true,
    refetchOnMount: true,
    refetchOnReconnect: true,
    staleTime: 0,
  });

  const notificationsQuery = useQuery({
    queryKey: ['notifications', 1],
    queryFn: () => notificationsApi.list(1, 15),
    refetchInterval: pollWhileFocused(10000),
  });

  const unreadNotificationsCount = notificationsQuery.data?.unreadCount ?? 0;

  const settle = async () => {
    setBusyCaseId(null);
    await queryClient.invalidateQueries({ queryKey: ['lawyer', 'leads'] });
    await queryClient.invalidateQueries({ queryKey: ['lawyer', 'clients'] });
    await queryClient.invalidateQueries({ queryKey: ['chats'] });
  };

  const failAndRefresh = async (error: unknown) => {
    setBusyCaseId(null);
    setActionError(toAppError(error).message);
    await queryClient.invalidateQueries({ queryKey: ['lawyer', 'leads'] });
  };

  const acceptMutation = useMutation({
    mutationFn: (caseId: string) => lawyerApi.acceptLead(caseId),
    onError: failAndRefresh,
    onSuccess: settle,
  });

  const declineMutation = useMutation({
    mutationFn: (caseId: string) => lawyerApi.rejectLead(caseId),
    onError: failAndRefresh,
    onSuccess: settle,
  });

  const respond = (caseId: string, action: 'accept' | 'decline') => {
    if (busyCaseId) {
      return;
    }
    setActionError(null);
    setBusyCaseId(caseId);
    if (action === 'accept') {
      acceptMutation.mutate(caseId);
    } else {
      declineMutation.mutate(caseId);
    }
  };

  const newLeads = useMemo(() => leadsQuery.data ?? [], [leadsQuery.data]);
  const pendingLeadCount = useMemo(
    () => newLeads.filter(isActionableLead).length,
    [newLeads],
  );
  const acceptedRows = useMemo(
    () => clientsQuery.data?.accepted ?? [],
    [clientsQuery.data],
  );

  const filteredLeads = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) {
      return newLeads;
    }
    return newLeads.filter(
      l =>
        l.issueTitle.toLowerCase().includes(q) ||
        l.clientName.toLowerCase().includes(q) ||
        l.issueCategory.toLowerCase().includes(q) ||
        l.location.toLowerCase().includes(q),
    );
  }, [newLeads, search]);

  const filteredAccepted = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) {
      return acceptedRows;
    }
    return acceptedRows.filter(
      r =>
        r.issue.toLowerCase().includes(q) || r.name.toLowerCase().includes(q),
    );
  }, [acceptedRows, search]);

  const activeQuery = tab === 'new' ? leadsQuery : clientsQuery;

  const renderLeadCard = (item: LawyerLead) => {
    const isBusy = busyCaseId === item.caseId;
    const isAvailable = isActionableLead(item);
    const docCount = item.documentsCount ?? (item.acknowledgementDocument ? 1 : 0);
    const matchPct =
      typeof item.matchPercentage === 'number' ? item.matchPercentage : null;

    if (!isAvailable) {
      return (
        <View
          key={item.caseId}
          testID={`lead-unavailable-${item.caseId}`}
          className="mb-4 rounded-card border border-border bg-surface p-4"
        >
          <View className="flex-row items-start justify-between">
            <GenieText className="flex-1 pr-2 font-bold text-base text-text-primary" numberOfLines={1}>
              {item.issueTitle}
            </GenieText>
            <View className="rounded-md border border-border bg-surface px-2 py-0.5">
              <GenieText className="font-bold text-small-label text-text-muted">
                Unavailable
              </GenieText>
            </View>
          </View>
          <GenieText className="mt-1 text-xs text-text-secondary" numberOfLines={1}>
            {item.issueCategory || 'General Practice'}
          </GenieText>
          <GenieText className="mt-3 text-sm text-text-secondary">
            {item.unavailableReason || 'This case request is no longer available.'}
          </GenieText>
        </View>
      );
    }

    return (
      <View
        key={item.caseId}
        className="mb-4 rounded-card border border-border bg-surface p-4"
      >
        <View className="flex-row items-start justify-between">
          <View className="flex-row items-center gap-3 flex-1 pr-2">
            <View className="items-center">
              <GenieAvatar
                uri={item.clientProfileImage}
                name={item.clientName}
                size="lg"
              />
              <View className="mt-1 rounded-md border border-border bg-surface-alt px-2 py-0.5">
                <GenieText tone="gold" className="font-bold text-small-label">
                  New
                </GenieText>
              </View>
            </View>

            <View className="flex-1">
              <GenieText className="font-bold text-lg text-text-primary" numberOfLines={1}>
                {item.clientName}
              </GenieText>
              <GenieText className="mt-0.5 text-xs text-text-secondary" numberOfLines={1}>
                Case: {item.issueTitle}
              </GenieText>
            </View>
          </View>

          <View className="flex-row items-center gap-2">
            {matchPct !== null ? (
              <GenieText tone="success" className="font-semibold text-xs">
                {matchPct}% Match
              </GenieText>
            ) : null}
            <Pressable className="p-1">
              <MoreVerticalIcon size={18} color={colors.textMuted} />
            </Pressable>
          </View>
        </View>

        <View className="mt-4 gap-2.5">
          <View className="flex-row items-center justify-between">
            <View className="flex-1 flex-row items-center gap-2">
              <LocationIcon size={14} color={colors.textMuted} />
              <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
                {item.location || 'Not Specified'}
              </GenieText>
            </View>

            <View className="flex-1 flex-row items-center gap-2">
              <ScalesIcon size={14} color={colors.textMuted} />
              <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
                {item.issueCategory || 'General Practice'}
              </GenieText>
            </View>
          </View>

          <View className="flex-row items-center justify-between">
            <View className="flex-1 flex-row items-center gap-2">
              <ClockIcon size={14} color={colors.textMuted} />
              <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
                Urgency: {item.urgency || 'Flexible'}
              </GenieText>
            </View>

            <View className="flex-1 flex-row items-center gap-2">
              <FileIcon size={14} color={colors.textMuted} />
              <GenieText className="text-xs text-text-secondary" numberOfLines={1}>
                {docCount} {docCount === 1 ? 'doc uploaded' : 'docs uploaded'}
              </GenieText>
            </View>
          </View>
        </View>

        <GenieText className="mt-3 text-xs text-text-muted">
          Posted on: {formatDate(item.postedTime)}
        </GenieText>

        <Pressable
          testID={`lead-view-details-${item.caseId}`}
          accessibilityRole="button"
          onPress={() =>
            navigation.navigate('LeadDetails', { caseId: String(item.caseId) })
          }
          className="mt-4 items-center justify-center rounded-control border border-border py-2.5 active:bg-gold-muted"
        >
          <GenieText tone="gold" className="font-semibold text-sm">
            View Details
          </GenieText>
        </Pressable>

        <View className="mt-3 flex-row gap-3">
          <Pressable
            testID={`lead-decline-${item.caseId}`}
            disabled={Boolean(busyCaseId)}
            accessibilityRole="button"
            accessibilityState={{ disabled: Boolean(busyCaseId) }}
            onPress={() => respond(item.caseId, 'decline')}
            className={`flex-1 items-center justify-center rounded-control border border-border py-2.5 active:bg-surface ${
              busyCaseId ? 'opacity-50' : ''
            }`}
          >
            <GenieText className="font-semibold text-sm text-text-secondary">
              Decline
            </GenieText>
          </Pressable>

          <Pressable
            testID={`lead-accept-${item.caseId}`}
            disabled={Boolean(busyCaseId)}
            accessibilityRole="button"
            accessibilityState={{ disabled: Boolean(busyCaseId), busy: isBusy }}
            onPress={() => respond(item.caseId, 'accept')}
            className={`flex-1 items-center justify-center rounded-control bg-gold py-2.5 active:bg-gold-hover ${
              busyCaseId ? 'opacity-50' : ''
            }`}
          >
            <GenieText tone="on-gold" className="font-bold text-sm">
              {isBusy ? 'Processing...' : 'Accept Case'}
            </GenieText>
          </Pressable>
        </View>
      </View>
    );
  };

  const renderBody = () => {
    if (activeQuery.isPending) {
      return (
        <View className="px-4">
          <GenieSkeletonList count={3} />
        </View>
      );
    }

    if (activeQuery.isError) {
      return (
        <View className="px-4">
          <GenieErrorState
            message={activeQuery.error.message}
            onRetry={() => activeQuery.refetch()}
          />
        </View>
      );
    }

    if (tab === 'new') {
      return (
        <FlatList
          data={filteredLeads}
          keyExtractor={item => item.caseId}
          contentContainerClassName="px-4 pb-12 pt-1"
          contentContainerStyle={
            filteredLeads.length === 0
              ? { flexGrow: 1, justifyContent: 'center' }
              : undefined
          }
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
          refreshControl={
            <GenieRefreshControl onRefresh={() => Promise.all([leadsQuery.refetch(), notificationsQuery.refetch()])} />
          }
          renderItem={({ item }) => renderLeadCard(item)}
          ListHeaderComponent={
            filteredLeads.length > 0 ? (
              <GenieText className="mb-3 font-bold text-lg text-text-primary">
                New Leads
              </GenieText>
            ) : undefined
          }
          ListEmptyComponent={
            <GenieEmptyState
              icon={<UserPlusIcon size={28} color={colors.gold} />}
              title={search.trim() ? 'No matching leads' : 'No new leads'}
              description={
                search.trim()
                  ? `Nothing matches "${search}".`
                  : 'New case requests from clients will appear here.'
              }
              actionLabel={search.trim() ? 'Clear search' : undefined}
              onAction={search.trim() ? () => setSearch('') : undefined}
            />
          }
        />
      );
    }

    return (
      <FlatList
        data={filteredAccepted}
        keyExtractor={item => item.caseId}
        contentContainerClassName="px-4 pb-12 pt-1"
        contentContainerStyle={
          filteredAccepted.length === 0
            ? { flexGrow: 1, justifyContent: 'center' }
            : undefined
        }
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        refreshControl={
          <GenieRefreshControl onRefresh={() => Promise.all([clientsQuery.refetch(), notificationsQuery.refetch()])} />
        }
        renderItem={({ item }) => (
          <View className="mb-3 rounded-card border border-border bg-surface p-4">
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
              <View className="rounded-md border border-success bg-success-surface px-2.5 py-1">
                <GenieText tone="success" className="font-semibold text-xs">
                  Accepted
                </GenieText>
              </View>
            </View>
            <GenieText className="mt-3 text-xs text-text-muted">
              Accepted on: {formatDate(item.acceptedAt || item.lastActivity)}
            </GenieText>
          </View>
        )}
        ListEmptyComponent={
          <GenieEmptyState
            icon={<UserPlusIcon size={28} color={colors.gold} />}
            title="No accepted leads"
            description="Leads you accept will appear here, and in Clients."
          />
        }
      />
    );
  };

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      <GenieHeader
        title="Leads"
        onMenu={openDrawer}
        onNotifications={() => (navigation as any).navigate('Notifications')}
        notificationCount={unreadNotificationsCount}
      />

      <GenieFilterTabs
        className="px-4 pt-2"
        testIDPrefix="leads-tab"
        tabs={[
          { key: 'new', label: 'New Leads', count: pendingLeadCount },
          { key: 'accepted', label: 'Accepted', count: acceptedRows.length },
        ]}
        value={tab}
        onChange={setTab}
      />

      <View className="px-4 pb-2 pt-3">
        <GenieSearchInput
          placeholder="Search new leads..."
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
