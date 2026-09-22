import React, { useCallback, useMemo, useState } from 'react';
import { FlatList, Pressable, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieAdvocateCard,
  GenieEmptyState,
  GenieErrorState,
  GenieFilterTabs,
  GenieHeader,
  GenieIconButton,
  GenieSearchInput,
  GenieSkeleton,
  GenieText,
  GenieRefreshControl,
} from '../../../components';
import { AdvocateSortModal } from '../../../components/advocates/AdvocateSortModal';
import { AdvocateFilterModal } from '../../../components/advocates/AdvocateFilterModal';
import {
  FilterIcon,
  ScalesIcon,
  VerifiedIcon,
} from '../../../components/icons/ClientIcons';
import { ChevronDownIcon } from '../../../components/icons/Icons';
import { advocatesApi, favoritesApi } from '../../../api/advocatesApi';
import { notificationsApi } from '../../../api/clientApi';
import { useDebouncedValue } from '../../../hooks/useDebouncedValue';
import { useUiStore } from '../../../store/uiStore';
import { toAppError } from '../../../utils/errors';
import type { AdvocateFilters, SortOption } from '../../../api/advocatesApi';
import type { FavoriteEntry, LawyerProfile } from '../../../types/domain';
import type { ClientTabScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

type Segment = 'all' | 'verified';

const DEFAULT_SORT = 'Most Relevant';

const CardSkeleton: React.FC = () => (
  <View className="mb-3 flex-row rounded-card border border-border bg-surface p-4">
    <GenieSkeleton className="h-16 w-16 rounded-full" />
    <View className="ml-3 flex-1 gap-2 pt-1">
      <GenieSkeleton className="h-4 w-3/5" />
      <GenieSkeleton className="h-3 w-4/5" />
      <GenieSkeleton className="h-3 w-2/3" />
      <GenieSkeleton className="h-3 w-1/2" />
    </View>
    <GenieSkeleton className="ml-2 mt-9 h-10 w-24 rounded-control" />
  </View>
);

export const AdvocatesScreen: React.FC<ClientTabScreenProps<'Advocates'>> = ({
  navigation,
  route,
}) => {
  const openDrawer = useUiStore(state => state.openDrawer);
  const queryClient = useQueryClient();

  const [search, setSearch] = useState(route.params?.initialSearch ?? '');
  const [segment, setSegment] = useState<Segment>('all');
  const [isSortOpen, setIsSortOpen] = useState(false);
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const [sortBy, setSortBy] = useState<SortOption | typeof DEFAULT_SORT>(DEFAULT_SORT);
  const [filterState, setFilterState] = useState<AdvocateFilters>({});
  const [actionError, setActionError] = useState<string | null>(null);

  const debouncedSearch = useDebouncedValue(search, 350);

  const activeFilters = useMemo<AdvocateFilters>(
    () => ({
      ...filterState,
      search: debouncedSearch || undefined,
      sortBy: sortBy === DEFAULT_SORT ? undefined : sortBy,
    }),
    [filterState, debouncedSearch, sortBy],
  );

  const advocatesQuery = useQuery({
    queryKey: ['advocates', activeFilters],
    queryFn: () => advocatesApi.list(activeFilters),
    placeholderData: previous => previous,
  });

  const favoritesQuery = useQuery({
    queryKey: ['favorites'],
    queryFn: favoritesApi.list,
  });

  const notificationsQuery = useQuery({
    queryKey: ['notifications', 1],
    queryFn: () => notificationsApi.list(1, 15),
  });

  const favoriteUserIds = useMemo(() => {
    const ids = new Set<string>();
    for (const entry of favoritesQuery.data ?? []) {
      if (entry.lawyer?._id) {
        ids.add(entry.lawyer._id);
      }
    }
    return ids;
  }, [favoritesQuery.data]);

  const toggleFavorite = useMutation({
    mutationFn: (userId: string) => favoritesApi.toggle(userId),
    onMutate: async (userId: string) => {
      setActionError(null);
      await queryClient.cancelQueries({ queryKey: ['favorites'] });
      const previous = queryClient.getQueryData<FavoriteEntry[]>(['favorites']);
      // Show the change at once; the refetch below replaces it with the server's list.
      queryClient.setQueryData<FavoriteEntry[]>(['favorites'], current => {
        const list = current ?? [];
        return list.some(entry => entry.lawyer?._id === userId)
          ? list.filter(entry => entry.lawyer?._id !== userId)
          : [
              ...list,
              {
                _id: `pending-${userId}`,
                lawyer: { _id: userId } as FavoriteEntry['lawyer'],
                profile: null,
              },
            ];
      });
      return { previous };
    },
    onError: (error, _userId, context) => {
      if (context?.previous) {
        queryClient.setQueryData(['favorites'], context.previous);
      }
      setActionError(toAppError(error).message);
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['favorites'] });
    },
  });

  const openAdvocate = useCallback(
    (userId: string) => navigation.navigate('AdvocateProfile', { userId }),
    [navigation],
  );

  const onToggleFavorite = useCallback(
    (userId: string) => {
      if (!toggleFavorite.isPending) {
        toggleFavorite.mutate(userId);
      }
    },
    [toggleFavorite],
  );

  const advocates = useMemo(() => advocatesQuery.data ?? [], [advocatesQuery.data]);
  const verifiedCount = useMemo(
    () => advocates.filter(item => item.user?.isVerified).length,
    [advocates],
  );
  const visible = useMemo(
    () => (segment === 'verified' ? advocates.filter(item => item.user?.isVerified) : advocates),
    [advocates, segment],
  );

  const renderItem = useCallback(
    ({ item }: { item: LawyerProfile }) => (
      <GenieAdvocateCard
        item={item}
        onPress={openAdvocate}
        isFavorite={item.user ? favoriteUserIds.has(item.user._id) : false}
        onToggleFavorite={onToggleFavorite}
      />
    ),
    [favoriteUserIds, onToggleFavorite, openAdvocate],
  );

  const keyExtractor = useCallback((item: LawyerProfile) => item._id, []);

  const hasFacetFilters = Boolean(
    filterState.specialization ||
      filterState.location ||
      filterState.experience ||
      filterState.rating ||
      filterState.language ||
      filterState.verifiedOnly ||
      typeof filterState.minFee === 'number' ||
      typeof filterState.maxFee === 'number',
  );

  const hasAppliedFilters = Boolean(
    debouncedSearch || hasFacetFilters || sortBy !== DEFAULT_SORT || segment !== 'all',
  );

  const resetAll = () => {
    setSearch('');
    setSegment('all');
    setSortBy(DEFAULT_SORT);
    setFilterState({});
  };

  const renderBody = () => {
    if (advocatesQuery.isPending) {
      return (
        <View className="px-4 pt-1" testID="advocates-loading">
          <CardSkeleton />
          <CardSkeleton />
          <CardSkeleton />
          <CardSkeleton />
        </View>
      );
    }

    if (advocatesQuery.isError) {
      return (
        <View className="flex-1 justify-center px-5" testID="advocates-error">
          <GenieErrorState
            title="Could not load advocates"
            message={toAppError(advocatesQuery.error).message}
            onRetry={() => advocatesQuery.refetch()}
          />
        </View>
      );
    }

    return (
      <FlatList
        testID="advocates-list"
        data={visible}
        renderItem={renderItem}
        keyExtractor={keyExtractor}
        contentContainerClassName="px-4 pb-28 pt-1"
        contentContainerStyle={
          visible.length === 0 ? { flexGrow: 1, justifyContent: 'center' } : undefined
        }
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode="on-drag"
        initialNumToRender={8}
        windowSize={7}
        removeClippedSubviews
        refreshControl={
          <GenieRefreshControl onRefresh={() => Promise.all([advocatesQuery.refetch(), favoritesQuery.refetch()])} />
        }
        ListEmptyComponent={
          <GenieEmptyState
            icon={<ScalesIcon size={32} color={colors.gold} />}
            title={hasAppliedFilters ? 'No advocates found' : 'No advocates listed yet'}
            description={
              hasAppliedFilters
                ? 'Try a different name, practice area or location, or clear your filters.'
                : 'Advocates will appear here once they join GenieLaw.'
            }
            actionLabel={hasAppliedFilters ? 'Clear search & filters' : undefined}
            onAction={hasAppliedFilters ? resetAll : undefined}
          />
        }
      />
    );
  };

  const loaded = advocatesQuery.isSuccess;

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      <GenieHeader
        title="Advocates"
        onMenu={openDrawer}
        onNotifications={() => navigation.navigate('Notifications')}
        notificationCount={notificationsQuery.data?.unreadCount ?? 0}
      />

      <View className="flex-row items-center gap-3 px-4 pb-3 pt-1">
        <View className="flex-1">
          <GenieSearchInput
            placeholder="Search by name, location or practice area"
            value={search}
            onChangeText={setSearch}
            onClear={() => setSearch('')}
            autoCapitalize="words"
            returnKeyType="search"
          />
        </View>

        <GenieIconButton
          testID="advocates-filter"
          icon={<FilterIcon size={20} color={colors.gold} />}
          onPress={() => setIsFilterOpen(true)}
          accessibilityLabel={hasFacetFilters ? 'Filters, active' : 'Filter advocates'}
          className={`h-[48px] w-[48px] rounded-[10px] border ${
            hasFacetFilters ? 'border-border bg-surface-secondary' : 'border-border bg-surface'
          }`}
        />
      </View>

      <View className="flex-row items-center gap-2 px-4 pb-3">
        <GenieFilterTabs
          layout="inline"
          testIDPrefix="advocates-segment"
          tabs={[
            { key: 'all', label: 'All', count: loaded ? advocates.length : undefined },
            {
              key: 'verified',
              label: 'Verified',
              count: loaded ? verifiedCount : undefined,
              icon: (
                <VerifiedIcon
                  size={14}
                  color={segment === 'verified' ? colors.onGold : colors.gold}
                />
              ),
            },
          ]}
          value={segment}
          onChange={setSegment}
        />
        <View className="flex-1" />
        <Pressable
          testID="advocates-sort"
          onPress={() => setIsSortOpen(true)}
          accessibilityRole="button"
          accessibilityLabel={`Sort, ${sortBy}`}
          className={`h-[44px] flex-row items-center gap-1 rounded-[10px] border px-3.5 ${
            sortBy !== DEFAULT_SORT ? 'border-border bg-surface-secondary' : 'border-border bg-surface'
          }`}
        >
          <GenieText
            variant="button"
            tone={sortBy !== DEFAULT_SORT ? 'gold' : 'secondary'}
            numberOfLines={1}
          >
            {sortBy === DEFAULT_SORT ? 'Sort' : sortBy}
          </GenieText>
          <ChevronDownIcon size={14} color={sortBy !== DEFAULT_SORT ? colors.gold : colors.textSecondary} />
        </Pressable>
      </View>

      {actionError ? (
        <View className="px-4 pb-2">
          <GenieText variant="caption" tone="error" accessibilityRole="alert">
            {actionError}
          </GenieText>
        </View>
      ) : null}

      {renderBody()}

      <AdvocateSortModal
        visible={isSortOpen}
        selectedSort={sortBy}
        onClose={() => setIsSortOpen(false)}
        onApply={sort => setSortBy(sort)}
      />

      <AdvocateFilterModal
        visible={isFilterOpen}
        filters={filterState}
        onClose={() => setIsFilterOpen(false)}
        onApply={filters => setFilterState(filters)}
        onReset={() => setFilterState({})}
      />
    </SafeAreaView>
  );
};
