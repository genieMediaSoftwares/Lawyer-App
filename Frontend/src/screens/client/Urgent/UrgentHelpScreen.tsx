import React, { useState } from 'react';
import { FlatList, TextInput, View } from 'react-native';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieButton,
  GenieCard,
  GenieEmptyState,
  GenieErrorState,
  GenieHeader,
  GenieNotice,
  GenieRefreshControl,
  GenieSkeletonList,
  GenieStatusBadge,
  GenieText,
} from '../../../components';
import { ClockIcon } from '../../../components/icons/ClientIcons';
import { casesApi } from '../../../api/casesApi';
import { toAppError } from '../../../utils/errors';
import type { LegalCase } from '../../../types/domain';
import type { ClientStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

const URGENCY_REASONS = [
  'Arrest / Police matter',
  'Bail',
  'Domestic violence',
  'Immediate court deadline',
  'Cybercrime',
  'Property emergency',
  'Other',
];

export const UrgentHelpScreen: React.FC<ClientStackScreenProps<'UrgentHelp'>> = ({ navigation }) => {
  const queryClient = useQueryClient();
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [urgencyReason, setUrgencyReason] = useState(URGENCY_REASONS[0]);
  const [location, setLocation] = useState('');
  const [formError, setFormError] = useState<string | null>(null);

  const { data: urgentCases, isLoading, error, refetch } = useQuery({
    queryKey: ['cases', 'urgent'],
    queryFn: async () => {
      try {
        const response = await casesApi.list();
        return Array.isArray(response) ? response : [];
      } catch {
        return [];
      }
    },
  });

  const submitMutation = useMutation({
    mutationFn: async () => {
      return casesApi.create({
        title: title.trim() || urgencyReason,
        description: description.trim(),
        category: 'Urgent Legal Help',
        location: location.trim() || 'Not specified',
        urgency: 'Urgent',
      } as any);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cases'] });
      setTitle('');
      setDescription('');
      setLocation('');
      setUrgencyReason(URGENCY_REASONS[0]);
      setFormError(null);
    },
    onError: (err) => setFormError(toAppError(err).message),
  });

  const renderCaseItem = ({ item }: { item: LegalCase }) => (
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
      <GenieText variant="caption" tone="muted" className="mt-2">
        Filed: {new Date(item.createdAt).toLocaleDateString('en-IN')}
      </GenieText>
    </GenieCard>
  );

  const renderSubmitForm = () => (
    <View className="px-5 pt-4">
      <GenieText variant="label" className="mb-2">Urgency Reason</GenieText>
      <View className="flex-row flex-wrap gap-2 mb-4">
        {URGENCY_REASONS.map((reason) => (
          <GenieButton
            key={reason}
            label={reason}
            variant={urgencyReason === reason ? 'primary' : 'outline'}
            size="sm"
            onPress={() => setUrgencyReason(reason)}
          />
        ))}
      </View>
      <GenieText variant="label" className="mb-2">Brief Title</GenieText>
      <TextInput
        value={title}
        onChangeText={setTitle}
        placeholder="Describe your situation briefly"
        className="rounded-control border border-border bg-card px-4 py-3 text-body-md text-white mb-4"
        placeholderTextColor={colors.textMuted}
      />
      <GenieText variant="label" className="mb-2">Description</GenieText>
      <TextInput
        value={description}
        onChangeText={setDescription}
        placeholder="Provide details about your urgent legal situation"
        multiline
        textAlignVertical="top"
        numberOfLines={5}
        className="rounded-control border border-border bg-card px-4 py-3 text-body-md text-white mb-4"
        placeholderTextColor={colors.textMuted}
      />
      <GenieText variant="label" className="mb-2">Location (optional)</GenieText>
      <TextInput
        value={location}
        onChangeText={setLocation}
        placeholder="City / District"
        className="rounded-control border border-border bg-card px-4 py-3 text-body-md text-white mb-4"
        placeholderTextColor={colors.textMuted}
      />
      {formError && <GenieNotice tone="error" message={formError} className="mb-3" />}
      <GenieButton
        label="Submit Urgent Request"
        loading={submitMutation.isPending}
        disabled={!description.trim()}
        onPress={() => submitMutation.mutate()}
      />
    </View>
  );

  return (
    <View className="flex-1 bg-background">
      <GenieHeader title="Urgent Legal Help" onBack={() => navigation.goBack()} />
      {isLoading ? (
        <GenieSkeletonList count={4} />
      ) : error ? (
        <GenieErrorState
          title="Failed to load urgent cases"
          message={toAppError(error).message}
          onRetry={() => refetch()}
        />
      ) : (
        <FlatList
          ListHeaderComponent={renderSubmitForm()}
          data={urgentCases ?? []}
          keyExtractor={(item) => item._id}
          renderItem={renderCaseItem}
          ListEmptyComponent={
            <View className="px-5 pt-4">
              <GenieEmptyState
                icon={<ClockIcon size={48} color={colors.textMuted} />}
                title="No urgent cases"
                description="Submit an urgent request if you need immediate legal assistance."
              />
            </View>
          }
          refreshControl={<GenieRefreshControl onRefresh={() => refetch()} />}
          contentContainerStyle={{ paddingBottom: 24 }}
        />
      )}
    </View>
  );
};
