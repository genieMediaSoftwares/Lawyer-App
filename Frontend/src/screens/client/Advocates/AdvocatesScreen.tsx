import React, { useCallback, useMemo, useState } from 'react';
import { FlatList, RefreshControl, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';

import {
  GenieAdvocateCard,
  GenieEmptyState,
  GenieErrorState,
  GenieHeader,
  GenieIconButton,
  GenieSearchInput,
  GenieSkeleton,
} from '../../../components';
import { AdvocateSortModal } from '../../../components/advocates/AdvocateSortModal';
import { AdvocateFilterModal } from '../../../components/advocates/AdvocateFilterModal';
import {
  FilterIcon,
  ScalesIcon,
  SortLinesIcon,
} from '../../../components/icons/ClientIcons';
import { advocatesApi, favoritesApi } from '../../../api/advocatesApi';
import { useDebouncedValue } from '../../../hooks/useDebouncedValue';
import { useUiStore } from '../../../store/uiStore';
import type { AdvocateFilters, SortOption } from '../../../api/advocatesApi';
import type { LawyerProfile } from '../../../types/domain';
import type { ClientTabScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

export const AdvocatesScreen: React.FC<ClientTabScreenProps<'Advocates'>> = ({
  navigation,
  route,
}) => {
  const openDrawer = useUiStore(state => state.openDrawer);

  const [search, setSearch] = useState(route.params?.initialSearch ?? '');
  const [isSortOpen, setIsSortOpen] = useState(false);
  const [isFilterOpen, setIsFilterOpen] = useState(false);

  const [sortBy, setSortBy] = useState<SortOption | 'Most Relevant'>(
    'Most Relevant',
  );
  const [filterState, setFilterState] = useState<AdvocateFilters>({});

  const debouncedSearch = useDebouncedValue(search, 350);

  const activeFilters = useMemo<AdvocateFilters>(
    () => ({
      ...filterState,
      search: debouncedSearch || undefined,
      sortBy: sortBy === 'Most Relevant' ? undefined : (sortBy as SortOption),
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

  const favoriteUserIds = useMemo(() => {
    const ids = new Set<string>();
    for (const entry of favoritesQuery.data ?? []) {
      if (entry.lawyer?._id) {
        ids.add(entry.lawyer._id);
      }
    }
    return ids;
  }, [favoritesQuery.data]);

  const openAdvocate = useCallback(
    (userId: string) => navigation.navigate('AdvocateProfile', { userId }),
    [navigation],
  );

  const renderItem = useCallback(
    ({ item }: { item: LawyerProfile }) => (
      <GenieAdvocateCard
        item={item}
        onPress={openAdvocate}
        isFavorite={item.user ? favoriteUserIds.has(item.user._id) : false}
      />
    ),
    [favoriteUserIds, openAdvocate],
  );

  const keyExtractor = useCallback((item: LawyerProfile) => item._id, []);

  const hasFacetFilters = Boolean(
    filterState.specialization ||
      filterState.location ||
      filterState.experience ||
      filterState.rating,
  );

  const hasAppliedFilters = Boolean(
    debouncedSearch ||
      hasFacetFilters ||
      filterState.minFee ||
      filterState.maxFee ||
      (sortBy && sortBy !== 'Most Relevant'),
  );

  const advocates = advocatesQuery.data ?? [];

  const renderBody = () => {
    if (advocatesQuery.isPending) {
      return (
        <View className="gap-3 px-3">
          <GenieSkeleton className="h-24 w-full rounded-card" />
          <GenieSkeleton className="h-24 w-full rounded-card" />
          <GenieSkeleton className="h-24 w-full rounded-card" />
        </View>
      );
    }

    if (advocatesQuery.isError) {
      return (
        <View className="px-5">
          <GenieErrorState
            message={advocatesQuery.error.message}
            onRetry={() => advocatesQuery.refetch()}
          />
        </View>
      );
    }

    const isEmpty = advocates.length === 0;

    return (
      <FlatList
        data={advocates}
        renderItem={renderItem}
        keyExtractor={keyExtractor}
        contentContainerClassName="px-3 pb-16"
        contentContainerStyle={
          isEmpty ? { flexGrow: 1, justifyContent: 'center' } : undefined
        }
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        refreshControl={
          <RefreshControl
            refreshing={advocatesQuery.isRefetching}
            onRefresh={() => {
              void advocatesQuery.refetch();
            }}
            tintColor={colors.gold}
            colors={[colors.gold]}
          />
        }
        ListEmptyComponent={
          <GenieEmptyState
            icon={<ScalesIcon size={32} color={colors.gold} />}
            title={
              hasAppliedFilters ? 'No advocates found' : 'No advocates listed yet'
            }
            description={
              hasAppliedFilters
                ? 'Try changing your search or filters.'
                : 'Advocates will appear here once they join GenieLaw.'
            }
            actionLabel={hasAppliedFilters ? 'Reset Filters' : undefined}
            onAction={
              hasAppliedFilters
                ? () => {
                    setSearch('');
                    setSortBy('Most Relevant');
                    setFilterState({});
                  }
                : undefined
            }
          />
        }
      />
    );
  };

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      <GenieHeader title="Advocates" onMenu={openDrawer} />

      <View className="flex-row items-center gap-2 px-5 pb-3 pt-1">
        <View className="flex-1">
          <GenieSearchInput
            placeholder="Search advocate..."
            value={search}
            onChangeText={setSearch}
            onClear={() => setSearch('')}
            autoCapitalize="words"
          />
        </View>

        <GenieIconButton
          icon={<SortLinesIcon size={20} color={colors.gold} />}
          onPress={() => setIsSortOpen(true)}
          accessibilityLabel="Sort advocates"
          className="h-control w-control rounded-control border border-border bg-surface"
        />

        <GenieIconButton
          icon={<FilterIcon size={20} color={colors.gold} />}
          onPress={() => setIsFilterOpen(true)}
          accessibilityLabel="Filter advocates"
          className={`h-control w-control rounded-control border bg-surface ${
            hasFacetFilters ? 'border-gold bg-gold-muted' : 'border-border'
          }`}
        />
      </View>

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
