import React from 'react';
import { View } from 'react-native';
import { GenieAvatar, GenieButton, GenieCard, GenieText } from './ui';
import { LocationIcon, StarIcon, VerifiedIcon } from './icons/ClientIcons';
import type { LawyerProfile } from '../types/domain';
import { colors } from '../theme';

export interface GenieAdvocateCardProps {
  item: LawyerProfile;
  onPress: (userId: string) => void;
  isFavorite?: boolean;
  onToggleFavorite?: (userId: string) => void;
}

export const GenieAdvocateCard: React.FC<GenieAdvocateCardProps> = ({
  item,
  onPress,
}) => {
  const user = item.user;
  const userId = user?._id || (user as any)?.id || (item as any)?.userId || item._id;
  const name = user?.fullName || (item as any)?.fullName || 'Advocate';
  const profileImage =
    user?.profileImage ||
    (user as any)?.avatar ||
    (item as any)?.profileImage ||
    (item as any)?.avatar;

  const specialization = Array.isArray(item.specialization)
    ? item.specialization[0] || 'General Practice'
    : item.specialization || 'General Practice';

  const locationText =
    user?.location || item.officeAddress || item.district || 'Location not specified';

  const rating = item.rating || 0;
  const reviewCount = item.totalReviews || 0;

  return (
    <GenieCard
      tone="surface"
      onPress={() => onPress(userId)}
      accessibilityLabel={`${name}, ${specialization}`}
      className="mb-2"
    >
      <View className="flex-row items-center">
        <GenieAvatar
          uri={profileImage}
          name={name}
          size="sm"
          ring={Boolean(user?.isVerified)}
        />

        <View className="ml-2 mr-1 flex-1">
          <View className="flex-row items-center gap-1">
            <GenieText variant="body-lg" className="font-bold" numberOfLines={1}>
              {name}
            </GenieText>
            {user?.isVerified ? <VerifiedIcon size={16} color={colors.gold} /> : null}
          </View>

          <GenieText
            variant="caption"
            tone="secondary"
            className="mt-0.5 font-medium"
            numberOfLines={1}
          >
            {specialization}
          </GenieText>

          <View className="mt-0.5 flex-row items-center gap-1">
            <LocationIcon size={13} color={colors.textSecondary} />
            <GenieText variant="caption" tone="secondary" className="flex-1" numberOfLines={1}>
              {locationText}
            </GenieText>
          </View>

          <View
            className="mt-1 flex-row items-center gap-0.5"
            accessibilityLabel={`Rated ${rating} out of 5 from ${reviewCount} reviews`}
          >
            {[1, 2, 3, 4, 5].map(star => (
              <StarIcon
                key={star}
                size={14}
                color={star <= Math.round(rating) ? colors.gold : colors.border}
              />
            ))}
            <GenieText variant="caption" tone="secondary" className="ml-1">
              ({reviewCount})
            </GenieText>
          </View>
        </View>

        <GenieButton
          label="View Profile"
          variant="outline"
          size="sm"
          fullWidth={false}
          onPress={() => onPress(userId)}
        />
      </View>
    </GenieCard>
  );
};
