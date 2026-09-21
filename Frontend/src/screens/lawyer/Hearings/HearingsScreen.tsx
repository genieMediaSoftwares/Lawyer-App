import React, { useMemo, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieButton,
  GenieEmptyState,
  GenieErrorState,
  GenieHeader,
  GenieIconButton,
  GenieModal,
  GenieNotice,
  GenieSearchInput,
  GenieSkeletonList,
  GenieStatusBadge,
  GenieText,
} from '../../../components';
import {
  ClockIcon,
  LocationIcon,
  PlusIcon,
  ScalesIcon,
} from '../../../components/icons/ClientIcons';
import { UsersIcon } from '../../../components/icons/LawyerIcons';
import { lawyerApi } from '../../../api/lawyerApi';
import { toAppError } from '../../../utils/errors';
import { formatDate } from '../../../utils/format';
import { HearingFormModal } from './HearingFormModal';
import type { HearingInput, LawyerHearing } from '../../../types/lawyer';
import type { LawyerStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

/**
 * Court hearings across all of this advocate's cases.
 *
 * ── Where the data comes from ─────────────────────────────────────────────
 *
 * `GET /cases/hearings/mine` flattens every hearing out of every case where
 * they are the assigned or selected lawyer, and 403s for any other role — so
 * this list can only ever contain the signed-in advocate's own work. Writes go
 * back through `/cases/:id/hearings`, gated server-side by `canManageHearings`
 * on the same test.
 *
 * ── Freshness ─────────────────────────────────────────────────────────────
 *
 * The backend emits `case_updated` on a `/cases` Socket.IO namespace when a
 * hearing changes, but **this app has no socket client** — `socket.io-client`
 * is not a dependency. Rather than invent a real-time layer, every mutation
 * invalidates the hearings and cases queries, so the list is re-read from the
 * server the moment a write succeeds and can never show a stale row after an
 * action. Pull-to-refresh and refetch-on-focus cover changes made elsewhere.
 * The gap is reported rather than papered over.
 *
 * ── Why cancel and complete are not their own calls ───────────────────────
 *
 * They are a `status` change on the same `PUT`. The schema models the four
 * states as one enum field, so the UI offers four actions over one endpoint
 * rather than pretending to endpoints that do not exist. Delete is the only
 * genuinely separate operation, and it removes the row outright.
 */

type HearingTab = 'today' | 'upcoming' | 'past';

const startOfToday = (): number => {
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  return now.getTime();
};

const endOfToday = (): number => startOfToday() + 24 * 60 * 60 * 1000 - 1;

const bucketOf = (hearing: LawyerHearing): HearingTab => {
  const time = new Date(hearing.date).getTime();
  if (Number.isNaN(time)) {
    return 'upcoming';
  }
  if (time < startOfToday()) {
    return 'past';
  }
  if (time <= endOfToday()) {
    return 'today';
  }
  return 'upcoming';
};

const HearingCard: React.FC<{
  hearing: LawyerHearing;
  onPress: () => void;
}> = ({ hearing, onPress }) => (
  <Pressable
    onPress={onPress}
    accessibilityRole="button"
    accessibilityLabel={`${hearing.caseTitle}, ${formatDate(hearing.date)}`}
    className="mb-3 rounded-card border border-border bg-card p-4 active:opacity-90"
  >
    <View className="flex-row items-start justify-between">
      <GenieText variant="heading-sm" className="flex-1 pr-2" numberOfLines={2}>
        {hearing.caseTitle}
      </GenieText>
      {hearing.status ? <GenieStatusBadge status={hearing.status} /> : null}
    </View>

    <View className="mt-3 gap-1.5">
      <View className="flex-row items-center gap-2">
        <ClockIcon size={14} color={colors.gold} />
        <GenieText variant="body-sm" tone="secondary">
          {[formatDate(hearing.date), hearing.timeSlot]
            .filter(Boolean)
            .join(' · ')}
        </GenieText>
      </View>

      {hearing.clientName ? (
        <View className="flex-row items-center gap-2">
          <UsersIcon size={14} color={colors.textMuted} />
          <GenieText variant="body-sm" tone="secondary" numberOfLines={1}>
            {hearing.clientName}
          </GenieText>
        </View>
      ) : null}

      {hearing.court ? (
        <View className="flex-row items-center gap-2">
          <LocationIcon size={14} color={colors.textMuted} />
          <GenieText variant="body-sm" tone="secondary" numberOfLines={1}>
            {hearing.court}
          </GenieText>
        </View>
      ) : null}

      {hearing.purpose ? (
        <View className="flex-row items-center gap-2">
          <ScalesIcon size={14} color={colors.textMuted} />
          <GenieText variant="body-sm" tone="secondary" numberOfLines={1}>
            {hearing.purpose}
          </GenieText>
        </View>
      ) : null}
    </View>
  </Pressable>
);

export const HearingsScreen: React.FC<LawyerStackScreenProps<'Hearings'>> = ({
  navigation,
}) => {
  const queryClient = useQueryClient();

  const [tab, setTab] = useState<HearingTab>('today');
  const [search, setSearch] = useState('');
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editing, setEditing] = useState<LawyerHearing | null>(null);
  const [detail, setDetail] = useState<LawyerHearing | null>(null);
  const [pendingDelete, setPendingDelete] = useState<LawyerHearing | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const hearingsQuery = useQuery({
    queryKey: ['lawyer', 'hearings'],
    queryFn: lawyerApi.getHearings,
  });

  const clientsQuery = useQuery({
    queryKey: ['lawyer', 'clients'],
    queryFn: lawyerApi.getClients,
  });

  const cases = useMemo(() => {
    const groups = clientsQuery.data;
    if (!groups) {
      return [];
    }
    return [...groups.accepted, ...groups.inProgress, ...groups.closed];
  }, [clientsQuery.data]);

  /**
   * Re-reads the server after every write.
   *
   * Nothing is patched locally, so what the list shows after a mutation is
   * what the server actually holds — including the `nextHearing` the
   * controller re-derives on the case, which is why the cases query goes too.
   */
  const settle = async () => {
    await queryClient.invalidateQueries({ queryKey: ['lawyer', 'hearings'] });
    await queryClient.invalidateQueries({ queryKey: ['lawyer', 'clients'] });
    await queryClient.invalidateQueries({ queryKey: ['lawyer', 'schedule'] });
  };

  const saveMutation = useMutation({
    mutationFn: async (vars: { caseId: string; payload: HearingInput }) => {
      if (editing?._id) {
        await lawyerApi.updateHearing(vars.caseId, editing._id, vars.payload);
      } else {
        await lawyerApi.addHearing(vars.caseId, vars.payload);
      }
    },
    onSuccess: async () => {
      setIsFormOpen(false);
      setEditing(null);
      setFormError(null);
      await settle();
    },
    onError: error => setFormError(toAppError(error).message),
  });

  const statusMutation = useMutation({
    mutationFn: async (vars: {
      hearing: LawyerHearing;
      status: HearingInput['status'];
    }) => {
      if (!vars.hearing._id) {
        throw new Error('This hearing has no id and cannot be updated.');
      }
      await lawyerApi.updateHearing(vars.hearing.caseId, vars.hearing._id, {
        status: vars.status,
      });
    },
    onSuccess: async () => {
      setDetail(null);
      await settle();
    },
    onError: error => setActionError(toAppError(error).message),
  });

  const deleteMutation = useMutation({
    mutationFn: async (hearing: LawyerHearing) => {
      if (!hearing._id) {
        throw new Error('This hearing has no id and cannot be deleted.');
      }
      await lawyerApi.deleteHearing(hearing.caseId, hearing._id);
    },
    onSuccess: async () => {
      setPendingDelete(null);
      setDetail(null);
      await settle();
    },
    onError: error => {
      setPendingDelete(null);
      setActionError(toAppError(error).message);
    },
  });

  // Memoised because `?? []` builds a fresh array on every render, which would
  // make it a changing dependency of the two memos below and defeat both.
  const hearings = useMemo(
    () => hearingsQuery.data ?? [],
    [hearingsQuery.data],
  );

  const counts = useMemo(() => {
    const result = { today: 0, upcoming: 0, past: 0 };
    for (const hearing of hearings) {
      result[bucketOf(hearing)] += 1;
    }
    return result;
  }, [hearings]);

  const visible = useMemo(() => {
    const q = search.trim().toLowerCase();
    return hearings
      .filter(h => bucketOf(h) === tab)
      .filter(
        h =>
          !q ||
          h.caseTitle.toLowerCase().includes(q) ||
          h.clientName.toLowerCase().includes(q) ||
          (h.court ?? '').toLowerCase().includes(q) ||
          (h.purpose ?? '').toLowerCase().includes(q),
      )
      .sort((a, b) => {
        const left = new Date(a.date).getTime();
        const right = new Date(b.date).getTime();
        // Past reads newest-first; the other two read soonest-first.
        return tab === 'past' ? right - left : left - right;
      });
  }, [hearings, search, tab]);

  const renderBody = () => {
    if (hearingsQuery.isPending) {
      return <GenieSkeletonList count={3} />;
    }

    if (hearingsQuery.isError) {
      return (
        <GenieErrorState
          message={hearingsQuery.error.message}
          onRetry={() => hearingsQuery.refetch()}
        />
      );
    }

    if (visible.length === 0) {
      return (
        <GenieEmptyState
          icon={<ScalesIcon size={28} color={colors.gold} />}
          title={
            search.trim()
              ? 'No matching hearings'
              : tab === 'today'
              ? 'Nothing listed today'
              : tab === 'upcoming'
              ? 'No upcoming hearings'
              : 'No past hearings'
          }
          description={
            search.trim()
              ? `Nothing matches "${search}".`
              : 'Hearings you add to your cases appear here.'
          }
          actionLabel={search.trim() ? 'Clear search' : undefined}
          onAction={search.trim() ? () => setSearch('') : undefined}
        />
      );
    }

    return visible.map(hearing => (
      <HearingCard
        key={`${hearing.caseId}-${hearing._id ?? hearing.date}`}
        hearing={hearing}
        onPress={() => {
          setActionError(null);
          setDetail(hearing);
        }}
      />
    ));
  };

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      <GenieHeader
        title="Hearings"
        onBack={() => navigation.goBack()}
        right={
          <GenieIconButton
            icon={<PlusIcon size={22} color={colors.gold} />}
            accessibilityLabel="Add hearing"
            onPress={() => {
              setEditing(null);
              setFormError(null);
              setIsFormOpen(true);
            }}
          />
        }
      />

      <View className="px-5 pb-2 pt-1">
        <GenieSearchInput
          placeholder="Search hearings..."
          value={search}
          onChangeText={setSearch}
          onClear={() => setSearch('')}
        />
      </View>

      <View className="flex-row gap-2 px-5 pb-3">
        {(
          [
            ['today', 'Today', counts.today],
            ['upcoming', 'Upcoming', counts.upcoming],
            ['past', 'Past', counts.past],
          ] as const
        ).map(([key, label, count]) => (
          <View key={key} className="flex-1">
            <GenieButton
              label={`${label} (${count})`}
              variant={tab === key ? 'primary' : 'outline'}
              size="sm"
              onPress={() => setTab(key)}
            />
          </View>
        ))}
      </View>

      {actionError ? (
        <View className="px-5 pb-2">
          <GenieNotice tone="error" message={actionError} />
        </View>
      ) : null}

      <ScrollView
        className="flex-1"
        contentContainerClassName="px-5 pb-8"
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        refreshControl={
          <RefreshControl
            refreshing={hearingsQuery.isRefetching}
            onRefresh={() => {
              void hearingsQuery.refetch();
            }}
            tintColor={colors.gold}
            colors={[colors.gold]}
          />
        }
      >
        {renderBody()}
      </ScrollView>

      {/* ── Add / edit ─────────────────────────────────────────────────── */}
      <HearingFormModal
        visible={isFormOpen}
        onClose={() => {
          setIsFormOpen(false);
          setEditing(null);
        }}
        hearing={editing}
        cases={cases}
        isSaving={saveMutation.isPending}
        error={formError}
        onSubmit={(caseId, payload) =>
          saveMutation.mutate({ caseId, payload })
        }
      />

      {/* ── Details ────────────────────────────────────────────────────── */}
      <GenieModal
        visible={Boolean(detail)}
        onClose={() => setDetail(null)}
        title="Hearing"
      >
        {detail ? (
          <ScrollView className="max-h-[400px]" showsVerticalScrollIndicator={false}>
            <GenieText variant="heading-sm">{detail.caseTitle}</GenieText>

            <View className="mt-3 gap-2">
              {(
                [
                  ['Client', detail.clientName],
                  ['Date', formatDate(detail.date)],
                  ['Time', detail.timeSlot],
                  ['Court', detail.court],
                  ['Purpose', detail.purpose],
                  ['Status', detail.status],
                  ['Case status', detail.caseStatus],
                  ['Category', detail.caseCategory],
                  ['Notes', detail.notes],
                  [
                    'Last updated',
                    detail.updatedAt ? formatDate(detail.updatedAt) : '',
                  ],
                ] as const
              )
                .filter(([, value]) => Boolean(value))
                .map(([label, value]) => (
                  <View key={label} className="border-b border-border pb-2">
                    <GenieText variant="caption" tone="muted">
                      {label}
                    </GenieText>
                    <GenieText variant="body-md" className="mt-0.5">
                      {String(value)}
                    </GenieText>
                  </View>
                ))}
            </View>

            <View className="mt-4 gap-3">
              <GenieButton
                label="Edit / Reschedule"
                variant="outline"
                onPress={() => {
                  setEditing(detail);
                  setDetail(null);
                  setFormError(null);
                  setIsFormOpen(true);
                }}
              />

              {detail.status !== 'completed' ? (
                <GenieButton
                  label="Mark Completed"
                  loading={statusMutation.isPending}
                  onPress={() =>
                    statusMutation.mutate({
                      hearing: detail,
                      status: 'completed',
                    })
                  }
                />
              ) : null}

              {detail.status !== 'cancelled' ? (
                <GenieButton
                  label="Cancel Hearing"
                  variant="outline"
                  disabled={statusMutation.isPending}
                  onPress={() =>
                    statusMutation.mutate({
                      hearing: detail,
                      status: 'cancelled',
                    })
                  }
                />
              ) : null}

              <GenieButton
                label="Delete"
                variant="danger"
                onPress={() => setPendingDelete(detail)}
              />
            </View>
          </ScrollView>
        ) : null}
      </GenieModal>

      {/* ── Delete confirmation ────────────────────────────────────────── */}
      <GenieModal
        visible={Boolean(pendingDelete)}
        onClose={() => setPendingDelete(null)}
        title="Delete this hearing?"
      >
        <GenieText variant="body-md" tone="secondary">
          It will be removed from the case for everyone who can see it. This
          cannot be undone — cancelling instead keeps the record.
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
                deleteMutation.mutate(pendingDelete);
              }
            }}
            className="flex-1"
          />
        </View>
      </GenieModal>
    </SafeAreaView>
  );
};
