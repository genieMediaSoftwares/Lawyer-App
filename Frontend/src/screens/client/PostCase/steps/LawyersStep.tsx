import React, { useState } from 'react';
import { Image, Pressable, ScrollView, View } from 'react-native';
import { useQuery } from '@tanstack/react-query';

import {
  GenieButton,
  GenieEmptyState,
  GenieErrorState,
  GenieSkeletonList,
  GenieText,
} from '../../../../components';
import {
  LocationIcon,
  ClockIcon,
  ScalesIcon,
  StarIcon,
  VerifiedIcon,
} from '../../../../components/icons/ClientIcons';
import { CheckIcon } from '../../../../components/icons/Icons';
import { advocatesApi } from '../../../../api/advocatesApi';
import { resolveFileUrl } from '../../../../utils/urls';
import type { RecommendedLawyer } from '../../../../types/domain';
import type { PostCaseState } from '../types';
import { colors } from '../../../../theme';

const SORT_OPTIONS = [
  'Best Match',
  'Experience',
  'Rating',
  'Fees: Low to High',
] as const;

type SortOption = (typeof SORT_OPTIONS)[number];

interface LawyersStepProps {
  state: PostCaseState;
  onChange: (patch: Partial<PostCaseState>) => void;
  onViewProfile: (userId: string, name: string) => void;
}

const LawyerCard: React.FC<{
  lawyer: RecommendedLawyer;
  isSelected: boolean;
  onSelect: () => void;
  onViewProfile: () => void;
}> = ({ lawyer, isSelected, onSelect, onViewProfile }) => {
  const photo = resolveFileUrl(lawyer.profileImage);

  return (
    <Pressable
      onPress={onSelect}
      accessibilityRole="radio"
      accessibilityState={{ selected: isSelected }}
      accessibilityLabel={`Select ${lawyer.fullName}${
        lawyer.specialization ? `, ${lawyer.specialization}` : ''
      }`}
      className={`mb-3 rounded-card border p-4 active:opacity-90 ${
        isSelected ? 'border-gold bg-gold-muted' : 'border-border bg-card'
      }`}
    >
      <View className="flex-row">
        <View className="mr-3">
          {photo ? (
            <Image
              source={{ uri: photo }}
              className="h-20 w-16 rounded-control bg-surface-alt"
              resizeMode="cover"
              accessibilityLabel={`${lawyer.fullName}'s photo`}
            />
          ) : (
            <View className="h-20 w-16 items-center justify-center rounded-control bg-surface-alt">
              <ScalesIcon size={24} color={colors.textMuted} />
            </View>
          )}

          {lawyer.onlineStatus ? (
            <View className="mt-1 flex-row items-center gap-1">
              <View className="h-2 w-2 rounded-full bg-success" />
              <GenieText variant="caption" tone="success" className="text-[10px]">
                Online
              </GenieText>
            </View>
          ) : null}
        </View>

        <View className="flex-1">
          <View className="flex-row items-start justify-between">
            <View className="flex-1 flex-row items-center gap-1.5 pr-2">
              <GenieText variant="heading-sm" numberOfLines={1}>
                {lawyer.fullName}
              </GenieText>
              {lawyer.verified ? (
                <VerifiedIcon size={15} color={colors.gold} />
              ) : null}
            </View>

            <View
              className={`h-6 w-6 items-center justify-center rounded-full border-2 ${
                isSelected ? 'border-gold bg-gold' : 'border-border'
              }`}
            >
              {isSelected ? (
                <CheckIcon size={13} color={colors.background} />
              ) : null}
            </View>
          </View>

          {lawyer.specialization ? (
            <GenieText variant="body-sm" tone="gold" className="mt-0.5">
              {lawyer.specialization}
            </GenieText>
          ) : null}

          {lawyer.location ? (
            <View className="mt-1 flex-row items-center gap-1.5">
              <LocationIcon size={13} color={colors.textMuted} />
              <GenieText variant="body-sm" tone="secondary" numberOfLines={1} className="flex-1">
                {lawyer.location}
              </GenieText>
            </View>
          ) : null}

          {lawyer.rating > 0 ? (
            <View className="mt-1 flex-row items-center gap-1.5">
              <StarIcon size={13} color={colors.gold} />
              <GenieText variant="body-sm">
                {lawyer.rating.toFixed(1)}
              </GenieText>
              <GenieText variant="body-sm" tone="muted">
                {`(${lawyer.reviewCount} ${
                  lawyer.reviewCount === 1 ? 'Review' : 'Reviews'
                })`}
              </GenieText>
            </View>
          ) : null}

          {lawyer.experience > 0 || lawyer.casesHandled > 0 ? (
            <GenieText variant="body-sm" tone="secondary" className="mt-1">
              {[
                lawyer.experience > 0 ? `${lawyer.experience}+ Years Exp` : '',
                lawyer.casesHandled > 0 ? `${lawyer.casesHandled}+ Cases` : '',
              ]
                .filter(Boolean)
                .join('  ·  ')}
            </GenieText>
          ) : null}

          <GenieText variant="body-sm" tone="success" className="mt-1 font-semibold">
            {`${lawyer.matchPercentage}% Match`}
          </GenieText>

          {lawyer.responseTime ? (
            <View className="mt-1 flex-row items-center gap-1.5">
              <ClockIcon size={13} color={colors.textMuted} />
              <GenieText variant="body-sm" tone="muted" numberOfLines={1}>
                {lawyer.responseTime}
              </GenieText>
            </View>
          ) : null}
        </View>
      </View>

      {lawyer.languages?.length ? (
        <View className="mt-3 flex-row flex-wrap gap-2">
          {lawyer.languages.map(language => (
            <View
              key={language}
              className="rounded-pill border border-border bg-card px-3 py-1"
            >
              <GenieText variant="caption" tone="secondary">
                {language}
              </GenieText>
            </View>
          ))}
        </View>
      ) : null}

      <View className="mt-3 flex-row gap-3">
        <GenieButton
          label="View Profile"
          variant="outline"
          size="sm"
          onPress={onViewProfile}
          className="flex-1"
        />
        <GenieButton
          label={isSelected ? 'Selected' : 'Select Lawyer'}
          size="sm"
          onPress={onSelect}
          className="flex-1"
        />
      </View>
    </Pressable>
  );
};

export const LawyersStep: React.FC<LawyersStepProps> = ({
  state,
  onChange,
  onViewProfile,
}) => {
  const [sortBy, setSortBy] = useState<SortOption>('Best Match');

  const recommendationQuery = useQuery({
    queryKey: [
      'lawyers',
      'recommend',
      state.category,
      state.subcategory,
      state.location,
      state.state,
      sortBy,
    ],
    queryFn: () =>
      advocatesApi.recommend({
        category: state.category,
        ...(state.subcategory ? { subcategory: state.subcategory } : {}),
        ...(state.location ? { city: state.location } : {}),
        ...(state.state ? { state: state.state } : {}),
        sortBy,
        limit: '20',
      }),
    enabled: Boolean(state.category),
  });

  const lawyers = recommendationQuery.data ?? [];

  const select = (lawyer: RecommendedLawyer) => {
    onChange({
      selectedLawyer: lawyer,
    });
  };

  return (
    <ScrollView
      className="flex-1"
      contentContainerClassName="px-5 pb-6 pt-5"
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      <GenieText variant="heading-lg">Recommended Lawyers</GenieText>
      <GenieText variant="body-sm" tone="secondary" className="mt-1">
        {state.location
          ? `Matched for your ${state.subcategory || state.category} matter in ${
              state.location
            }.`
          : `Matched for your ${state.subcategory || state.category} matter.`}
      </GenieText>

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        className="-mx-5 mt-4"
        contentContainerClassName="px-5 gap-2"
      >
        {SORT_OPTIONS.map(option => {
          const active = sortBy === option;
          return (
            <Pressable
              key={option}
              onPress={() => setSortBy(option)}
              accessibilityRole="button"
              accessibilityState={{ selected: active }}
              className={`min-h-touch justify-center rounded-pill border px-4 ${
                active
                  ? 'border-gold bg-gold'
                  : 'border-border bg-surface active:opacity-80'
              }`}
            >
              <View className="flex-row items-center gap-1.5">
                {option === 'Best Match' ? (
                  <StarIcon
                    size={14}
                    color={active ? colors.background : colors.textSecondary}
                  />
                ) : null}
                <GenieText
                  variant="body-sm"
                  tone={active ? 'on-gold' : 'secondary'}
                  className={active ? 'font-bold' : ''}
                >
                  {option}
                </GenieText>
              </View>
            </Pressable>
          );
        })}
      </ScrollView>

      <View className="mt-4">
        {recommendationQuery.isPending ? (
          <GenieSkeletonList count={3} />
        ) : recommendationQuery.isError ? (
          <GenieErrorState
            message={recommendationQuery.error.message}
            onRetry={() => recommendationQuery.refetch()}
          />
        ) : lawyers.length === 0 ? (
          <GenieEmptyState
            icon={<ScalesIcon size={28} color={colors.gold} />}
            title="No lawyers matched yet"
            description={`No advocate currently practises ${
              state.category
            }${state.location ? ` near ${state.location}` : ''}. Try a broader location, or check back soon.`}
          />
        ) : (
          lawyers.map(lawyer => (
            <LawyerCard
              key={lawyer.lawyerId}
              lawyer={lawyer}
              isSelected={state.selectedLawyer?.userId === lawyer.userId}
              onSelect={() => select(lawyer)}
              onViewProfile={() =>
                onViewProfile(lawyer.userId, lawyer.fullName)
              }
            />
          ))
        )}
      </View>
    </ScrollView>
  );
};
