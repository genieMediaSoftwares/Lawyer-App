import React, { useMemo, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieButton,
  GenieEmptyState,
  GenieErrorState,
  GenieHeader,
  GenieModal,
  GenieNotice,
  GenieSearchInput,
  GenieSkeletonList,
  GenieText,
} from '../../../components';
import {
  ChevronRightIcon,
  ClockIcon,
  FileIcon,
  SparkleIcon,
  TrashIcon,
} from '../../../components/icons/ClientIcons';
import { aiApi } from '../../../api/aiApi';
import { lawyerApi } from '../../../api/lawyerApi';
import { toAppError } from '../../../utils/errors';
import { formatRelative } from '../../../utils/format';
import type { ResearchSession } from '../../../types/lawyer';
import type { LawyerStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

/**
 * Legal Research — the advocate's research workspace.
 *
 * ── What this is built on ─────────────────────────────────────────────────
 *
 * `POST /ai/chat` with `mode: "research"`, which the backend routes to
 * `RESEARCH_SYSTEM_INSTRUCTION` — a prompt written for a practising advocate,
 * separate from the client-facing assistant. Sessions persist as
 * `AiConversation` rows tagged `mode: "research"`, so the history below is
 * real: `GET /ai/conversations?mode=research` lists them and
 * `DELETE /ai/conversations/:id` removes one.
 *
 * ── On authority ──────────────────────────────────────────────────────────
 *
 * The backend prompt states plainly that it has no case-law database, no
 * judgment index and no reporter subscription, and instructs the model never
 * to invent a case name, citation, section number or judgment, and to mark
 * anything it does recall as requiring verification. This screen surfaces
 * that framing rather than dressing the output up as search results — see the
 * standing notice below and the marker on the Authorities section.
 *
 * ── Case context ──────────────────────────────────────────────────────────
 *
 * A research session can be opened against one of the advocate's own matters.
 * The list comes from `GET /lawyers/clients`, which the controller scopes to
 * cases where they are the assigned or selected lawyer, so no other
 * advocate's matter can be picked. The selected case's title and category are
 * sent as the opening context — nothing about the client beyond what the
 * advocate already holds.
 */

export const ResearchScreen: React.FC<LawyerStackScreenProps<'Research'>> = ({
  navigation,
}) => {
  const queryClient = useQueryClient();

  const [search, setSearch] = useState('');
  const [isCasePickerOpen, setIsCasePickerOpen] = useState(false);
  const [pendingDelete, setPendingDelete] = useState<ResearchSession | null>(
    null,
  );
  const [actionError, setActionError] = useState<string | null>(null);

  const sessionsQuery = useQuery({
    queryKey: ['lawyer', 'research', 'sessions'],
    queryFn: aiApi.getResearchSessions,
  });

  const clientsQuery = useQuery({
    queryKey: ['lawyer', 'clients'],
    queryFn: lawyerApi.getClients,
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => aiApi.deleteConversation(id),
    onSuccess: async () => {
      setPendingDelete(null);
      await queryClient.invalidateQueries({
        queryKey: ['lawyer', 'research', 'sessions'],
      });
    },
    onError: error => {
      setPendingDelete(null);
      setActionError(toAppError(error).message);
    },
  });

  /** Every matter this advocate is on, flattened out of the grouped payload. */
  const cases = useMemo(() => {
    const groups = clientsQuery.data;
    if (!groups) {
      return [];
    }
    return [...groups.accepted, ...groups.inProgress, ...groups.closed];
  }, [clientsQuery.data]);

  // Memoised for the same reason as elsewhere: `?? []` is a new array every
  // render, and the filter below depends on it.
  const sessions = useMemo(
    () => sessionsQuery.data ?? [],
    [sessionsQuery.data],
  );

  const filteredSessions = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) {
      return sessions;
    }
    return sessions.filter(
      s =>
        s.title.toLowerCase().includes(q) ||
        s.lastMessage.toLowerCase().includes(q),
    );
  }, [search, sessions]);

  const openBlank = () =>
    navigation.navigate('ResearchSession', { sessionId: undefined });

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      <GenieHeader title="Legal Research" onBack={() => navigation.goBack()} />

      <ScrollView
        className="flex-1"
        contentContainerClassName="px-5 pb-8 pt-3"
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        refreshControl={
          <RefreshControl
            refreshing={sessionsQuery.isRefetching}
            onRefresh={() => {
              void sessionsQuery.refetch();
            }}
            tintColor={colors.gold}
            colors={[colors.gold]}
          />
        }
      >
        {/* ── The workspace card ───────────────────────────────────────── */}
        <View className="rounded-card border border-gold-wash bg-card p-5">
          <View className="flex-row items-center gap-3">
            <View className="h-11 w-11 items-center justify-center rounded-full bg-gold-muted">
              <SparkleIcon size={22} color={colors.gold} />
            </View>
            <View className="flex-1">
              <GenieText variant="heading-md">AI Legal Research</GenieText>
              <GenieText variant="body-sm" tone="secondary" className="mt-0.5">
                Analyse case documents, research relevant law and prepare case
                strategy.
              </GenieText>
            </View>
          </View>

          <View className="mt-4 gap-3">
            <GenieButton
              label="Start Research"
              onPress={openBlank}
              icon={<SparkleIcon size={18} color={colors.onGold} />}
            />

            <GenieButton
              label="Research an Existing Case"
              variant="outline"
              onPress={() => setIsCasePickerOpen(true)}
              icon={<FileIcon size={18} color={colors.gold} />}
            />
          </View>

          <GenieText variant="caption" tone="muted" className="mt-3 leading-4">
            Working from the model&apos;s training data, not a case-law
            database. Every authority it offers is a lead to verify in a
            reporter before you rely on it.
          </GenieText>
        </View>

        {actionError ? (
          <GenieNotice tone="error" message={actionError} className="mt-4" />
        ) : null}

        {/* ── History ──────────────────────────────────────────────────── */}
        <View className="mt-6 flex-row items-end justify-between">
          <GenieText variant="heading-sm">Your Research</GenieText>
          {sessions.length > 0 ? (
            <GenieText variant="caption" tone="muted">
              {`${sessions.length} ${
                sessions.length === 1 ? 'session' : 'sessions'
              }`}
            </GenieText>
          ) : null}
        </View>

        {sessions.length > 0 ? (
          <View className="mt-3">
            <GenieSearchInput
              placeholder="Search your research..."
              value={search}
              onChangeText={setSearch}
              onClear={() => setSearch('')}
            />
          </View>
        ) : null}

        <View className="mt-3">
          {sessionsQuery.isPending ? (
            <GenieSkeletonList count={3} />
          ) : sessionsQuery.isError ? (
            <GenieErrorState
              message={sessionsQuery.error.message}
              onRetry={() => sessionsQuery.refetch()}
            />
          ) : filteredSessions.length === 0 ? (
            <GenieEmptyState
              icon={<SparkleIcon size={28} color={colors.gold} />}
              title={
                search.trim() ? 'No matching research' : 'No research yet'
              }
              description={
                search.trim()
                  ? `Nothing matches "${search}".`
                  : 'Start a session and it will be saved here for you to come back to.'
              }
              actionLabel={search.trim() ? 'Clear search' : 'Start Research'}
              onAction={
                search.trim() ? () => setSearch('') : openBlank
              }
            />
          ) : (
            filteredSessions.map(session => (
              <View
                key={session.id}
                className="mb-3 flex-row items-center rounded-card border border-border bg-card"
              >
                <Pressable
                  onPress={() =>
                    navigation.navigate('ResearchSession', {
                      sessionId: session.id,
                      title: session.title,
                    })
                  }
                  accessibilityRole="button"
                  accessibilityLabel={`Open research: ${session.title}`}
                  className="min-h-touch flex-1 flex-row items-center gap-3 p-4 active:opacity-80"
                >
                  <View className="flex-1">
                    <GenieText variant="body-lg" numberOfLines={1}>
                      {session.title}
                    </GenieText>

                    {session.lastMessage ? (
                      <GenieText
                        variant="body-sm"
                        tone="secondary"
                        numberOfLines={2}
                        className="mt-0.5"
                      >
                        {session.lastMessage}
                      </GenieText>
                    ) : null}

                    <View className="mt-1.5 flex-row items-center gap-1.5">
                      <ClockIcon size={12} color={colors.textMuted} />
                      <GenieText variant="caption" tone="muted">
                        {`Updated ${formatRelative(session.updatedAt)} · ${
                          session.messageCount
                        } ${session.messageCount === 1 ? 'message' : 'messages'}`}
                      </GenieText>
                    </View>
                  </View>

                  <ChevronRightIcon size={18} color={colors.textSecondary} />
                </Pressable>

                <Pressable
                  onPress={() => {
                    setActionError(null);
                    setPendingDelete(session);
                  }}
                  accessibilityRole="button"
                  accessibilityLabel={`Delete research: ${session.title}`}
                  className="min-h-touch min-w-touch items-center justify-center pr-3 active:opacity-70"
                >
                  <TrashIcon size={18} color={colors.error} />
                </Pressable>
              </View>
            ))
          )}
        </View>
      </ScrollView>

      {/* ── Case picker ────────────────────────────────────────────────── */}
      <GenieModal
        visible={isCasePickerOpen}
        onClose={() => setIsCasePickerOpen(false)}
        title="Choose a matter"
      >
        {cases.length === 0 ? (
          <GenieText variant="body-md" tone="secondary">
            You have no matters yet. Research can still be started without
            one.
          </GenieText>
        ) : (
          <ScrollView className="max-h-80" showsVerticalScrollIndicator={false}>
            {cases.map(row => (
              <Pressable
                key={row.caseId}
                onPress={() => {
                  setIsCasePickerOpen(false);
                  navigation.navigate('ResearchSession', {
                    sessionId: undefined,
                    caseId: row.caseId,
                    caseTitle: row.issue,
                    caseCategory: row.category,
                  });
                }}
                accessibilityRole="button"
                accessibilityLabel={row.issue}
                className="mb-2 min-h-touch justify-center rounded-control border border-border bg-card px-4 py-3 active:opacity-80"
              >
                <GenieText variant="body-md" numberOfLines={1}>
                  {row.issue}
                </GenieText>
                <GenieText variant="caption" tone="muted" className="mt-0.5">
                  {[row.name, row.category].filter(Boolean).join(' · ')}
                </GenieText>
              </Pressable>
            ))}
          </ScrollView>
        )}
      </GenieModal>

      {/* ── Delete confirmation ────────────────────────────────────────── */}
      <GenieModal
        visible={Boolean(pendingDelete)}
        onClose={() => setPendingDelete(null)}
        title="Delete this research?"
      >
        <GenieText variant="body-md" tone="secondary">
          {pendingDelete
            ? `"${pendingDelete.title}" and its messages will be removed. This cannot be undone.`
            : ''}
        </GenieText>

        <View className="mt-5 flex-row gap-3">
          <GenieButton
            label="Keep"
            variant="outline"
            onPress={() => setPendingDelete(null)}
            className="flex-1"
          />
          <GenieButton
            label="Delete"
            variant="danger"
            loading={deleteMutation.isPending}
            onPress={() => {
              if (pendingDelete) {
                deleteMutation.mutate(pendingDelete.id);
              }
            }}
            className="flex-1"
          />
        </View>
      </GenieModal>
    </SafeAreaView>
  );
};
