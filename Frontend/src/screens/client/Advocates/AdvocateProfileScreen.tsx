import React, { useMemo, useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieAvatar,
  GenieButton,
  GenieChip,
  GenieErrorState,
  GenieHeader,
  GenieIconButton,
  GenieSkeleton,
  GenieText,
  ProfileImageViewer,
  VerifiedBadge,
  GenieRefreshControl,
} from '../../../components';
import {
  BriefcaseIcon,
  HeartIcon,
  LocationIcon,
  StarIcon,
} from '../../../components/icons/ClientIcons';
import { advocatesApi, favoritesApi } from '../../../api/advocatesApi';
import { chatApi } from '../../../api/chatApi';
import { formatExperience, formatRating } from '../../../utils/format';
import type { FavoriteEntry } from '../../../types/domain';
import type { ClientStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

const Section: React.FC<{ title: string; children: React.ReactNode }> = ({
  title,
  children,
}) => (
  <View className="mt-6">
    <GenieText variant="heading-sm" className="mb-2">
      {title}
    </GenieText>
    {children}
  </View>
);

export const AdvocateProfileScreen: React.FC<
  ClientStackScreenProps<'AdvocateProfile'>
> = ({ navigation, route }) => {
  const { userId } = route.params;
  const queryClient = useQueryClient();
  const [isStartingChat, setIsStartingChat] = useState(false);
  const [isPhotoOpen, setIsPhotoOpen] = useState(false);

  const profileQuery = useQuery({
    queryKey: ['advocate', userId],
    queryFn: () => advocatesApi.getById(userId),
  });

  const favoritesQuery = useQuery({
    queryKey: ['favorites'],
    queryFn: favoritesApi.list,
  });

  const isFavorite = useMemo(
    () =>
      (favoritesQuery.data ?? []).some(entry => entry.lawyer?._id === userId),
    [favoritesQuery.data, userId],
  );

  const toggleFavorite = useMutation({
    mutationFn: () => favoritesApi.toggle(userId),
    onMutate: async () => {
      await queryClient.cancelQueries({ queryKey: ['favorites'] });
      const previous = queryClient.getQueryData<FavoriteEntry[]>(['favorites']);

      queryClient.setQueryData<FavoriteEntry[]>(['favorites'], current => {
        const list = current ?? [];
        return list.some(entry => entry.lawyer?._id === userId)
          ? list.filter(entry => entry.lawyer?._id !== userId)
          : [
              ...list,
              {
                _id: `pending:${userId}`,
                lawyer: {
                  _id: userId,
                  fullName: '',
                  email: '',
                  mobile: '',
                  profileImage: '',
                },
                profile: null,
              },
            ];
      });

      return { previous };
    },
    onError: (_error, _variables, context) => {
      if (context?.previous) {
        queryClient.setQueryData(['favorites'], context.previous);
      }
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['favorites'] });
    },
  });

  const profile = profileQuery.data;
  const user = profile?.user;

  const handleChatNow = async () => {
    if (isStartingChat) {
      return;
    }
    setIsStartingChat(true);
    try {
      const chat = await chatApi.getOrCreateChat(userId);
      navigation.navigate('Chat', {
        chatId: chat._id,
        name: user?.fullName,
        avatar: user?.profileImage,
      });
    } catch {
      navigation.navigate('Messages');
    } finally {
      setIsStartingChat(false);
    }
  };

  const ratingStr = formatRating(profile?.rating);
  const reviewCount = profile?.totalReviews || 0;
  const expStr = formatExperience(profile?.experience) || 'Experience not listed';

  const expertiseList = useMemo(() => {
    if (!profile) {
      return [];
    }
    if (
      Array.isArray(profile.practiceAreas) &&
      profile.practiceAreas.length > 0
    ) {
      return profile.practiceAreas;
    }
    if (
      Array.isArray(profile.specialization) &&
      profile.specialization.length > 0
    ) {
      return profile.specialization;
    }
    if (
      typeof profile.specialization === 'string' &&
      profile.specialization.trim().length > 0
    ) {
      return [profile.specialization.trim()];
    }
    return [];
  }, [profile]);

  const header = (
    <GenieHeader
      title="Lawyer Profile"
      onBack={() => navigation.goBack()}
      right={
        <GenieIconButton
          icon={
            <HeartIcon
              size={22}
              color={isFavorite ? colors.gold : colors.textMuted}
              filled={isFavorite}
            />
          }
          onPress={() => toggleFavorite.mutate()}
          accessibilityLabel={
            isFavorite ? 'Remove from favourites' : 'Add to favourites'
          }
        />
      }
    />
  );

  const renderBody = () => {
    if (profileQuery.isPending) {
      return (
        <View className="items-center gap-3 px-5 pt-5">
          <GenieSkeleton className="h-24 w-24 rounded-full" />
          <GenieSkeleton className="h-6 w-3/5 rounded-lg" />
          <GenieSkeleton className="h-4 w-2/5 rounded-lg" />
          <GenieSkeleton className="mt-6 h-28 w-full rounded-card" />
        </View>
      );
    }

    if (profileQuery.isError) {
      return (
        <View className="px-5">
          <GenieErrorState
            message={profileQuery.error.message}
            onRetry={() => profileQuery.refetch()}
          />
        </View>
      );
    }

    if (!profile || !user) {
      return null;
    }

    return (
      <View className="flex-1 justify-between">
        <ScrollView
          className="flex-1"
          contentContainerClassName="px-5 pb-6"
          showsVerticalScrollIndicator={false}
          refreshControl={
            <GenieRefreshControl onRefresh={() => profileQuery.refetch()} />
          }
        >
          <View className="items-center pt-2">
            <Pressable
              onPress={() => setIsPhotoOpen(true)}
              accessibilityRole="button"
              accessibilityLabel={`View ${user.fullName}'s profile photo`}
            >
              <GenieAvatar
                uri={user.profileImage}
                name={user.fullName}
                size="xl"
                ring={Boolean(user.isVerified)}
              />
            </Pressable>

            <View className="mt-3 flex-row items-center gap-1">
              <GenieText variant="heading-md">{user.fullName}</GenieText>
              {user.isVerified ? (
                <VerifiedBadge size={20} />
              ) : null}
            </View>

            <GenieText variant="body-sm" tone="gold" className="mt-1 text-center">
              {Array.isArray(profile.specialization)
                ? profile.specialization.join(', ')
                : profile.specialization || 'General Practice'}
            </GenieText>

            <View className="mt-1 flex-row items-center gap-1">
              <LocationIcon size={14} color={colors.textSecondary} />
              <GenieText variant="body-sm" tone="secondary">
                {user.location || profile.officeAddress || profile.district || 'Location not specified'}
              </GenieText>
            </View>

            <View className="mt-3 flex-row items-center gap-3 rounded-card border border-border bg-surface px-4 py-2">
              <View className="flex-row items-center gap-1">
                <StarIcon size={14} color={colors.gold} />
                <GenieText variant="body-sm" tone="secondary">
                  {ratingStr && reviewCount > 0
                    ? `${ratingStr} (${reviewCount} ${
                        reviewCount === 1 ? 'Review' : 'Reviews'
                      })`
                    : 'No reviews yet'}
                </GenieText>
              </View>

              <View className="h-4 w-px bg-border" />

              <View className="flex-row items-center gap-1">
                <BriefcaseIcon size={14} color={colors.gold} />
                <GenieText variant="body-sm" tone="secondary">
                  {expStr}
                </GenieText>
              </View>
            </View>
          </View>

          <Section title="About Me">
            <GenieText variant="body-md" tone="secondary">
              {profile.bio && profile.bio.trim().length > 0
                ? profile.bio
                : 'No bio available for this lawyer.'}
            </GenieText>
          </Section>

          <Section title="Expertise">
            {expertiseList.length > 0 ? (
              <View className="flex-row flex-wrap gap-2">
                {expertiseList.map((area, idx) => (
                  <GenieChip key={`${area}-${idx}`} label={area} />
                ))}
              </View>
            ) : (
              <GenieText variant="body-sm" tone="secondary">
                No specific expertise listed.
              </GenieText>
            )}
          </Section>
        </ScrollView>

        <View className="border-t border-border bg-surface px-5 py-3">
          <GenieButton
            label="Chat Now"
            loadingLabel="Opening chat..."
            loading={isStartingChat}
            onPress={handleChatNow}
          />
        </View>
      </View>
    );
  };

  return (
    <SafeAreaView edges={['top', 'bottom']} className="flex-1 bg-background">
      {header}
      {renderBody()}

      <ProfileImageViewer
        visible={isPhotoOpen}
        onClose={() => setIsPhotoOpen(false)}
        imageUri={user?.profileImage}
        name={user?.fullName}
      />
    </SafeAreaView>
  );
};
