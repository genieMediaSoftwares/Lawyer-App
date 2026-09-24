import React, { useMemo, useState } from 'react';
import { FlatList, TextInput, View } from 'react-native';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieButton,
  GenieEmptyState,
  GenieErrorState,
  GenieFilterTabs,
  GenieHeader,
  GenieNotice,
  GenieRefreshControl,
  GenieSkeletonList,
  GenieStatusBadge,
  GenieText,
} from '../../../components';
import { GenieCard } from '../../../components/ui/GenieCard';
import { issuesApi } from '../../../api/issuesApi';
import { toAppError } from '../../../utils/errors';
import type { Issue } from '../../../types/domain';
import type { ClientStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

type Tab = 'all' | 'pending' | 'assigned' | 'resolved';

const TABS: ReadonlyArray<{ key: Tab; label: string }> = [
  { key: 'all', label: 'All' },
  { key: 'pending', label: 'Pending' },
  { key: 'assigned', label: 'Assigned' },
  { key: 'resolved', label: 'Resolved' },
];

const ISSUE_CATEGORIES = [
  'Consultation Issue',
  'Payment Issue',
  'Lawyer Behavior',
  'Case Issue',
  'Document Issue',
  'Technical Issue',
  'Refund Request',
  'Other',
];

export const DisputesScreen: React.FC<ClientStackScreenProps<'Disputes'>> = ({ navigation }) => {
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<Tab>('all');
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState(ISSUE_CATEGORIES[0]);
  const [formError, setFormError] = useState<string | null>(null);

  const { data: issues, isLoading, error, refetch } = useQuery({
    queryKey: ['issues'],
    queryFn: issuesApi.list,
  });

  const createMutation = useMutation({
    mutationFn: (input: { title: string; description: string; category: string }) =>
      issuesApi.create(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['issues'] });
      setShowForm(false);
      setTitle('');
      setDescription('');
      setCategory(ISSUE_CATEGORIES[0]);
      setFormError(null);
    },
    onError: (err) => setFormError(toAppError(err).message),
  });

  const filtered = useMemo(() => {
    if (!issues) return [];
    if (tab === 'all') return issues;
    return issues.filter((i) => i.status.toLowerCase() === tab);
  }, [issues, tab]);

  const renderItem = ({ item }: { item: Issue }) => (
    <GenieCard className="mb-3">
      <View className="flex-row items-start justify-between">
        <View className="flex-1">
          <GenieText variant="body" className="font-semibold">
            {item.title}
          </GenieText>
          <GenieText variant="caption" tone="muted">
            {item.category}
          </GenieText>
        </View>
        <GenieStatusBadge status={item.status} />
      </View>
      <GenieText variant="body-sm" className="mt-2" numberOfLines={2}>
        {item.description}
      </GenieText>
      <GenieText variant="caption" tone="muted" className="mt-2">
        {new Date(item.createdAt).toLocaleDateString('en-IN')}
      </GenieText>
    </GenieCard>
  );

  if (showForm) {
    return (
      <View className="flex-1 bg-background">
        <GenieHeader title="File Dispute" onBack={() => { setShowForm(false); setFormError(null); }} />
        <View className="px-5 pt-4">
          <GenieText variant="label" className="mb-2">Title</GenieText>
          <TextInput
            value={title}
            onChangeText={setTitle}
            placeholder="Brief title for your dispute"
            maxLength={200}
            className="rounded-control border border-border bg-card px-4 py-3 text-body-md text-white mb-4"
            placeholderTextColor={colors.textMuted}
          />
          <GenieText variant="label" className="mb-2">Description</GenieText>
          <TextInput
            value={description}
            onChangeText={setDescription}
            placeholder="Describe the issue in detail"
            multiline
            textAlignVertical="top"
            numberOfLines={4}
            className="rounded-control border border-border bg-card px-4 py-3 text-body-md text-white mb-4"
            placeholderTextColor={colors.textMuted}
          />
          {formError && <GenieNotice tone="error" message={formError} className="mb-3" />}
          <GenieButton
            label="Submit Dispute"
            loading={createMutation.isPending}
            disabled={!title.trim() || !description.trim()}
            onPress={() => createMutation.mutate({ title: title.trim(), description: description.trim(), category })}
          />
        </View>
      </View>
    );
  }

  return (
    <View className="flex-1 bg-background">
      <GenieHeader
        title="Disputes"
        onBack={() => navigation.goBack()}
        right={
          <GenieButton label="New" onPress={() => setShowForm(true)} variant="secondary" size="sm" />
        }
      />
      <View className="px-5 pt-2">
        <GenieFilterTabs tabs={TABS} value={tab} onChange={setTab} />
      </View>
      {isLoading ? (
        <GenieSkeletonList count={4} />
      ) : error ? (
        <GenieErrorState
          title="Failed to load disputes"
          message={toAppError(error).message}
          onRetry={() => refetch()}
        />
      ) : filtered.length > 0 ? (
        <FlatList
          data={filtered}
          keyExtractor={(item) => item._id}
          renderItem={renderItem}
          refreshControl={<GenieRefreshControl onRefresh={() => refetch()} />}
          contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 24 }}
        />
      ) : (
        <GenieEmptyState
          title="No disputes"
          description="Raise a dispute if you have issues with a consultation or payment."
        />
      )}
    </View>
  );
};
