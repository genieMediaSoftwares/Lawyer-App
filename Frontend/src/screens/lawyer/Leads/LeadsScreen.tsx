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
import type { LawyerLead } from '../../../types/lawyer';
import type { LawyerTabScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

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

  const leadsQuery = useQuery({
    queryKey: ['lawyer', 'leads'],
    queryFn: lawyerApi.getLeads,
    refetchInterval: 3000,
    refetchOnWindowFocus: true,
    refetchOnMount: true,
    refetchOnReconnect: true,
    staleTime: 0,
  });

  const clientsQuery = useQuery({
    queryKey: ['lawyer', 'clients'],
    queryFn: lawyerApi.getClients,
    refetchInterval: 3000,
    refetchOnWindowFocus: true,
    refetchOnMount: true,
    refetchOnReconnect: true,
    staleTime: 0,
  });

  const notificationsQuery = useQuery({
    queryKey: ['notifications', 1],
    queryFn: () => notificationsApi.list(1, 15),
    refetchInterval: 10000,
  });

  const unreadNotificationsCount = notificationsQuery.data?.unreadCount ?? 0;

  const settle = async () => {
    setBusyCaseId(null);
    await queryClient.invalidateQueries({ queryKey: ['lawyer', 'leads'] });
    await queryClient.invalidateQueries({ queryKey: ['lawyer', 'clients'] });
    await queryClient.invalidateQueries({ queryKey: ['chats'] });
  };

  const acceptMutation = useMutation({
    mutationFn: (caseId: string) => lawyerApi.acceptLead(caseId),
    onError: error => {
      setBusyCaseId(null);
      setActionError(toAppError(error).message);
    },
    onSuccess: settle,
  });

  const newLeads = useMemo(() => leadsQuery.data ?? [], [leadsQuery.data]);
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
    const docCount = item.documentsCount ?? (item.acknowledgementDocument ? 1 : 0);
    const matchPct = item.matchPercentage ?? 90;

    return (
      <View
        key={item.caseId}
        className="mb-4 rounded-2xl border border-border/40 bg-surface-alt p-4"
      >
        <View className="flex-row items-start justify-between">
          <View className="flex-row items-center gap-3 flex-1 pr-2">
            <View className="items-center">
              <GenieAvatar
                uri={item.clientProfileImage}
                name={item.clientName}
                size="lg"
              />
              <View className="mt-1 rounded-md border border-amber-600/40 bg-amber-900/40 px-2 py-0.5">
                <GenieText className="font-bold text-[10px] text-amber-400">
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
            <GenieText className="font-semibold text-xs text-emerald-400">
              {matchPct}% Match
            </GenieText>
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

        <View className="mt-4 flex-row gap-3">
          <Pressable
            onPress={() => (navigation as any).navigate('CaseDetails', { caseId: item.caseId })}
            className="flex-1 items-center justify-center rounded-xl border border-gold py-2.5 active:bg-gold-muted/20"
          >
            <GenieText className="font-semibold text-sm text-gold">
              View Details
            </GenieText>
          </Pressable>

          <Pressable
            disabled={isBusy}
            onPress={() => {
              setActionError(null);
              setBusyCaseId(item.caseId);
              acceptMutation.mutate(item.caseId);
            }}
            className="flex-1 items-center justify-center rounded-xl bg-gold py-2.5 active:bg-gold-hover"
          >
            <GenieText className="font-bold text-sm text-on-gold">
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
            <RefreshControl
              refreshing={leadsQuery.isRefetching}
              onRefresh={() => {
                void leadsQuery.refetch();
                void notificationsQuery.refetch();
              }}
              tintColor={colors.gold}
              colors={[colors.gold]}
            />
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
        renderItem={({ item }) => (
          <View className="mb-3 rounded-2xl border border-border/40 bg-surface-alt p-4">
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
              <View className="rounded-md border border-emerald-500/30 bg-emerald-500/15 px-2.5 py-1">
                <GenieText className="font-semibold text-xs text-emerald-400">
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

      <View className="flex-row border-b border-border/30 px-4 pt-1">
        <Pressable
          onPress={() => setTab('new')}
          className={`mr-6 flex-row items-center gap-2 pb-3 ${
            tab === 'new' ? 'border-b-2 border-gold' : ''
          }`}
        >
          <GenieText
            className={`font-semibold text-base ${
              tab === 'new' ? 'text-gold' : 'text-text-secondary'
            }`}
          >
            New Leads
          </GenieText>
          <View
            className={`h-5 w-5 items-center justify-center rounded-full ${
              tab === 'new' ? 'bg-amber-600/80' : 'bg-surface-alt'
            }`}
          >
            <GenieText className="font-bold text-[11px] text-white">
              {newLeads.length}
            </GenieText>
          </View>
        </Pressable>

        <Pressable
          onPress={() => setTab('accepted')}
          className={`flex-row items-center gap-2 pb-3 ${
            tab === 'accepted' ? 'border-b-2 border-gold' : ''
          }`}
        >
          <GenieText
            className={`font-semibold text-base ${
              tab === 'accepted' ? 'text-gold' : 'text-text-secondary'
            }`}
          >
            Accepted
          </GenieText>
          <View
            className={`h-5 w-5 items-center justify-center rounded-full ${
              tab === 'accepted' ? 'bg-amber-600/80' : 'bg-surface-alt'
            }`}
          >
            <GenieText className="font-bold text-[11px] text-white">
              {acceptedRows.length}
            </GenieText>
          </View>
        </Pressable>
      </View>

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
