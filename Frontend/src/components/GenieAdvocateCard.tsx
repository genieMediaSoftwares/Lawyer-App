import React, { memo } from 'react';
import { Pressable, View } from 'react-native';
import { GenieAvatar, GenieText, VerifiedBadge } from './ui';
import {
  BookmarkIcon,
  BriefcaseIcon,
  ChevronRightIcon,
  LocationIcon,
  StarIcon,
} from './icons/ClientIcons';
import type { LawyerProfile } from '../types/domain';
import { colors } from '../theme';

export interface GenieAdvocateCardProps {
  item: LawyerProfile;
  onPress: (userId: string) => void;
  isFavorite?: boolean;
  onToggleFavorite?: (userId: string) => void;
}

// The backend fills a missing office address with this literal placeholder.
const PLACEHOLDER_ADDRESS = 'office address';

const firstText = (...values: Array<string | null | undefined>): string =>
  values.map(value => (value ?? '').trim()).find(Boolean) ?? '';

export const advocateSummary = (item: LawyerProfile) => {
  const user = item.user;
  const officeAddress =
    item.officeAddress?.trim().toLowerCase() === PLACEHOLDER_ADDRESS ? '' : item.officeAddress;

  return {
    // The profile endpoint accepts either id; saving needs the user id.
    userId: user?._id ?? '',
    profileId: user?._id || item._id || '',
    name: firstText(user?.fullName) || 'Advocate',
    profileImage: user?.profileImage ?? null,
    isVerified: Boolean(user?.isVerified),
    specialization: firstText(item.specialization, item.practiceAreas?.[0]),
    location: firstText(user?.location, item.district, officeAddress),
    rating: Number.isFinite(item.rating) ? Math.max(0, Math.min(5, item.rating)) : 0,
    reviewCount: Number.isFinite(item.totalReviews) ? Math.max(0, item.totalReviews) : 0,
  };
};

const Stars: React.FC<{ rating: number }> = ({ rating }) => (
  <View className="flex-row items-center gap-0.5">
    {[1, 2, 3, 4, 5].map(star => (
      <StarIcon
        key={star}
        size={13}
        color={star <= Math.round(rating) ? colors.gold : colors.border}
      />
    ))}
  </View>
);

const GenieAdvocateCardBase: React.FC<GenieAdvocateCardProps> = ({
  item,
  onPress,
  isFavorite = false,
  onToggleFavorite,
}) => {
  const advocate = advocateSummary(item);
  const { userId, profileId, name, reviewCount, rating } = advocate;
  if (!profileId) {
    return null;
  }

  const open = () => onPress(profileId);
  const ratingLabel =
    reviewCount > 0
      ? `Rated ${rating.toFixed(1)} out of 5 from ${reviewCount} ${
          reviewCount === 1 ? 'review' : 'reviews'
        }`
      : 'No reviews yet';

  return (
    <Pressable
      testID={`advocate-card-${profileId}`}
      onPress={open}
      accessibilityRole="button"
      accessibilityLabel={[
        name,
        advocate.isVerified ? 'verified' : '',
        advocate.specialization,
        advocate.location,
        ratingLabel,
      ]
        .filter(Boolean)
        .join(', ')}
      className="mb-3 flex-row rounded-[12px] border border-border bg-card p-4 active:bg-surface-secondary"
    >
      <GenieAvatar uri={advocate.profileImage} name={name} size="card" />

      <View className="ml-3 flex-1 justify-center">
        <View className="flex-row items-center gap-1 pr-1">
          <GenieText variant="cardTitle" className="flex-shrink" numberOfLines={1}>
            {name}
          </GenieText>
          {advocate.isVerified ? (
            <View accessibilityLabel="Verified advocate">
              <VerifiedBadge size={15} />
            </View>
          ) : null}
        </View>

        <View className="mt-1 flex-row items-center gap-1.5">
          <BriefcaseIcon size={13} color={colors.textMuted} />
          <GenieText
            variant="secondary"
            tone={advocate.specialization ? 'secondary' : 'muted'}
            className="flex-1"
            numberOfLines={1}
          >
            {advocate.specialization || 'Practice area not specified'}
          </GenieText>
        </View>

        <View className="mt-1 flex-row items-center gap-1.5">
          <LocationIcon size={13} color={colors.textMuted} />
          <GenieText
            variant="secondary"
            tone={advocate.location ? 'secondary' : 'muted'}
            className="flex-1"
            numberOfLines={1}
          >
            {advocate.location || 'Location not specified'}
          </GenieText>
        </View>

        <View className="mt-1.5 flex-row items-center gap-1.5" accessibilityLabel={ratingLabel}>
          <Stars rating={reviewCount > 0 ? rating : 0} />
          <GenieText variant="caption" tone="muted" numberOfLines={1}>
            {reviewCount > 0 ? `${rating.toFixed(1)} (${reviewCount})` : 'No reviews yet'}
          </GenieText>
        </View>
      </View>

      <View className="ml-2 items-end justify-between">
        {onToggleFavorite && userId ? (
          <Pressable
            testID={`advocate-bookmark-${userId}`}
            onPress={() => onToggleFavorite(userId)}
            hitSlop={10}
            accessibilityRole="button"
            accessibilityLabel={isFavorite ? `Remove ${name} from saved` : `Save ${name}`}
            accessibilityState={{ selected: isFavorite }}
            className="h-9 w-9 items-center justify-center rounded-full active:bg-surface-alt"
          >
            <BookmarkIcon
              size={20}
              filled={isFavorite}
              color={isFavorite ? colors.gold : colors.textSecondary}
            />
          </Pressable>
        ) : (
          <View className="h-9" />
        )}

        <Pressable
          testID={`advocate-view-${profileId}`}
          onPress={open}
          accessibilityRole="button"
          accessibilityLabel={`View ${name}'s profile`}
          className="h-[44px] flex-row items-center gap-1 rounded-[10px] bg-surface-secondary px-3.5 active:bg-border"
        >
          <GenieText variant="button" tone="primary">
            View Profile
          </GenieText>
          <ChevronRightIcon size={14} color={colors.white} />
        </Pressable>
      </View>
    </Pressable>
  );
};

export const GenieAdvocateCard = memo(GenieAdvocateCardBase);
