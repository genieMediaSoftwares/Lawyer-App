import React, { useState } from 'react';
import { Alert, Platform, Pressable, RefreshControl, View } from 'react-native';
import { useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieAvatar,
  GenieCard,
  GenieErrorState,
  GenieHeader,
  GenieScreen,
  GenieSettingsRow,
  GenieSkeleton,
  GenieText,
  VerifiedBadge,
} from '../../../components';
import {
  CameraIcon,
  FileIcon,
  InfoCircleIcon,
  ScalesIcon,
  SettingsIcon,
  StarIcon,
} from '../../../components/icons/ClientIcons';
import { UserIcon } from '../../../components/icons/Icons';
import { CrownIcon } from '../../../components/icons/LawyerIcons';
import { authApi } from '../../../api/authApi';
import { lawyerApi } from '../../../api/lawyerApi';
import { useAuthStore } from '../../../store/authStore';
import { useUiStore } from '../../../store/uiStore';
import type { LawyerVerificationStatus } from '../../../types/lawyer';
import type { LawyerTabScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

const VERIFICATION: Record<
  LawyerVerificationStatus,
  { label: string; surface: string; tone: 'success' | 'warning' | 'error' }
> = {
  verified: { label: 'Verified', surface: 'bg-success-surface', tone: 'success' },
  pending: { label: 'Verification pending', surface: 'bg-warning-surface', tone: 'warning' },
  rejected: { label: 'Verification rejected', surface: 'bg-error-surface', tone: 'error' },
};

const Stat: React.FC<{ label: string; value: string | null }> = ({
  label,
  value,
}) =>
  value ? (
    <View className="flex-1 items-center">
      <GenieText variant="heading-md" tone="gold">
        {value}
      </GenieText>
      <GenieText variant="caption" tone="muted" className="mt-0.5 text-center">
        {label}
      </GenieText>
    </View>
  ) : null;

export const LawyerProfileScreen: React.FC<
  LawyerTabScreenProps<'LawyerProfile'>
> = ({ navigation }) => {
  const user = useAuthStore(state => state.user);
  const openDrawer = useUiStore(state => state.openDrawer);
  const queryClient = useQueryClient();
  const [isUploading, setIsUploading] = useState(false);

  const profileQuery = useQuery({
    queryKey: ['lawyer', 'profile', user?.id],
    queryFn: () => lawyerApi.getProfile(user!.id),
    enabled: Boolean(user?.id),
  });

  const uploadFile = async (file: File) => {
    setIsUploading(true);
    try {
      await authApi.uploadProfileImage(file);
      await queryClient.invalidateQueries({ queryKey: ['lawyer', 'profile', user?.id] });
      await queryClient.invalidateQueries({ queryKey: ['auth', 'profile'] });
    } catch (err: any) {
      Alert.alert(
        'Upload Error',
        err.message || 'Failed to upload profile photo',
      );
    } finally {
      setIsUploading(false);
    }
  };

  const handleSelectImage = () => {
    if (
      Platform.OS === 'web' &&
      typeof globalThis !== 'undefined' &&
      (globalThis as any).document
    ) {
      const doc = (globalThis as any).document;
      const input = doc.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.onchange = async (e: any) => {
        const file = e.target?.files?.[0];
        if (file) {
          await uploadFile(file);
        }
      };
      input.click();
    } else {
      Alert.alert('Upload Photo', 'Photo upload is available on web browser.');
    }
  };

  const header = (
    <GenieHeader
      title="Profile"
      onMenu={openDrawer}
      onNotifications={() => navigation.navigate('Notifications')}
    />
  );

  if (profileQuery.isPending) {
    return (
      <GenieScreen header={header} dismissKeyboardOnTap={false}>
        <View className="items-center">
          <GenieSkeleton className="h-24 w-24 rounded-full" />
          <GenieSkeleton className="mt-4 h-5 w-40" />
          <GenieSkeleton className="mt-2 h-3 w-28" />
        </View>
        <GenieSkeleton className="mt-6 h-64 w-full rounded-card" />
      </GenieScreen>
    );
  }

  if (profileQuery.isError) {
    return (
      <GenieScreen header={header} dismissKeyboardOnTap={false}>
        <GenieErrorState
          message={profileQuery.error.message}
          onRetry={() => profileQuery.refetch()}
        />
      </GenieScreen>
    );
  }

  const profile = profileQuery.data;
  const verification =
    VERIFICATION[profile.verificationStatus] ?? VERIFICATION.pending;

  const hasRecord =
    profile.rating > 0 || profile.casesHandled > 0 || profile.winPercentage > 0;

  return (
    <GenieScreen
      scrollable
      header={header}
      dismissKeyboardOnTap={false}
      contentContainerClassName="pb-8"
      scrollViewProps={{
        refreshControl: (
          <RefreshControl
            refreshing={profileQuery.isRefetching}
            onRefresh={() => {
              void profileQuery.refetch();
            }}
            tintColor={colors.gold}
            colors={[colors.gold]}
          />
        ),
      }}
    >
      <View className="my-3 items-center">
        <View className="relative">
          <GenieAvatar
            uri={profile.user?.profileImage}
            name={profile.user?.fullName ?? user?.fullName}
            size="xl"
            ring={profile.verificationStatus === 'verified'}
          />

          <Pressable
            onPress={handleSelectImage}
            disabled={isUploading}
            accessibilityRole="button"
            accessibilityLabel="Change profile photo"
            accessibilityState={{ disabled: isUploading, busy: isUploading }}
            className={`absolute bottom-0 right-0 h-8 w-8 items-center justify-center rounded-full border-2 border-background bg-gold active:opacity-80 ${
              isUploading ? 'opacity-50' : ''
            }`}
          >
            <CameraIcon size={16} color={colors.onGold} />
          </Pressable>
        </View>

        <View className="mt-3 flex-row items-center gap-1">
          <GenieText variant="heading-md">
            {profile.user?.fullName ?? user?.fullName ?? 'Advocate'}
          </GenieText>
          {profile.verificationStatus === 'verified' ? (
            <VerifiedBadge size={18} />
          ) : null}
        </View>

        {profile.specialization ? (
          <GenieText variant="body-sm" tone="gold" className="mt-1">
            {profile.specialization}
          </GenieText>
        ) : null}

        <View className={`mt-2 rounded-pill px-3 py-1 ${verification.surface}`}>
          <GenieText variant="caption" tone={verification.tone} className="font-bold">
            {verification.label}
          </GenieText>
        </View>
      </View>

      {hasRecord ? (
        <GenieCard tone="surface" className="flex-row">
          <Stat
            label={
              profile.totalReviews === 1
                ? '1 review'
                : `${profile.totalReviews} reviews`
            }
            value={profile.rating > 0 ? profile.rating.toFixed(1) : null}
          />
          <Stat
            label="Cases handled"
            value={profile.casesHandled > 0 ? String(profile.casesHandled) : null}
          />
          <Stat
            label="Win rate"
            value={profile.winPercentage > 0 ? `${profile.winPercentage}%` : null}
          />
        </GenieCard>
      ) : (
        <GenieCard tone="surface" className="flex-row items-center gap-2">
          <StarIcon size={16} color={colors.textMuted} />
          <GenieText variant="caption" tone="muted" className="flex-1">
            No ratings, cases or win rate recorded yet.
          </GenieText>
        </GenieCard>
      )}

      <GenieText
        variant="caption"
        tone="muted"
        className="mb-2 ml-1 mt-6 font-bold tracking-widest"
      >
        ACCOUNT &amp; PROFESSIONAL DETAILS
      </GenieText>

      <View className="overflow-hidden rounded-card border border-border bg-surface">
        <GenieSettingsRow
          label="My Profile"
          subtitle={profile.user?.email ?? undefined}
          icon={<UserIcon size={18} color={colors.white} />}
          onPress={() => navigation.navigate('LawyerMyProfile')}
        />
        <View className="ml-4 h-px bg-border" />
        <GenieSettingsRow
          label="Professional Details"
          subtitle="Specialisation, experience, fee, bar number"
          icon={<InfoCircleIcon size={18} color={colors.white} />}
          onPress={() => navigation.navigate('ProfessionalDetails')}
        />
        <View className="ml-4 h-px bg-border" />
        <GenieSettingsRow
          label="My Documents"
          subtitle="Files you have uploaded"
          icon={<FileIcon size={18} color={colors.white} />}
          onPress={() => navigation.navigate('Documents')}
        />
        <View className="ml-4 h-px bg-border" />
        <GenieSettingsRow
          label="Hearings"
          subtitle="Scheduled court hearings"
          icon={<ScalesIcon size={18} color={colors.white} />}
          onPress={() => navigation.navigate('Hearings')}
        />
        <View className="ml-4 h-px bg-border" />
        <GenieSettingsRow
          label="Subscription"
          subtitle={`${profile.subscriptionPlan} plan`}
          icon={<CrownIcon size={18} color={colors.white} />}
          onPress={() => navigation.navigate('Subscription')}
        />
        <View className="ml-4 h-px bg-border" />
        <GenieSettingsRow
          label="Settings"
          subtitle="Security, preferences, legal & account"
          icon={<SettingsIcon size={18} color={colors.white} />}
          onPress={() => navigation.navigate('Settings')}
        />
      </View>
    </GenieScreen>
  );
};
