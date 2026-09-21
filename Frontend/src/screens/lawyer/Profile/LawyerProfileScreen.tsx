import React from 'react';
import { RefreshControl, View } from 'react-native';
import { useQuery } from '@tanstack/react-query';

import {
  GenieAvatar,
  GenieCard,
  GenieErrorState,
  GenieHeader,
  GenieScreen,
  GenieSettingsRow,
  GenieSkeleton,
  GenieText,
} from '../../../components';
import {
  FileIcon,
  InfoCircleIcon,
  ScalesIcon,
  SettingsIcon,
  StarIcon,
  VerifiedIcon,
} from '../../../components/icons/ClientIcons';
import { UserIcon } from '../../../components/icons/Icons';
import { CrownIcon } from '../../../components/icons/LawyerIcons';
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

  const profileQuery = useQuery({
    queryKey: ['lawyer', 'profile', user?.id],
    queryFn: () => lawyerApi.getProfile(user!.id),
    enabled: Boolean(user?.id),
  });

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
        <GenieAvatar
          uri={profile.user?.profileImage}
          name={profile.user?.fullName ?? user?.fullName}
          size="xl"
          ring={profile.verificationStatus === 'verified'}
        />

        <View className="mt-3 flex-row items-center gap-1">
          <GenieText variant="heading-md">
            {profile.user?.fullName ?? user?.fullName ?? 'Advocate'}
          </GenieText>
          {profile.verificationStatus === 'verified' ? (
            <VerifiedIcon size={18} color={colors.gold} />
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
          icon={<UserIcon size={18} color={colors.gold} />}
          onPress={() => navigation.navigate('ProfessionalDetails')}
        />
        <View className="ml-4 h-px bg-border" />
        <GenieSettingsRow
          label="Professional Details"
          subtitle="Specialisation, experience, fee, bar number"
          icon={<InfoCircleIcon size={18} color={colors.gold} />}
          onPress={() => navigation.navigate('ProfessionalDetails')}
        />
        <View className="ml-4 h-px bg-border" />
        <GenieSettingsRow
          label="My Documents"
          subtitle="Files you have uploaded"
          icon={<FileIcon size={18} color={colors.gold} />}
          onPress={() => navigation.navigate('Documents')}
        />
        <View className="ml-4 h-px bg-border" />
        <GenieSettingsRow
          label="Hearings"
          subtitle="Scheduled court hearings"
          icon={<ScalesIcon size={18} color={colors.gold} />}
          onPress={() => navigation.navigate('Hearings')}
        />
        <View className="ml-4 h-px bg-border" />
        <GenieSettingsRow
          label="Subscription"
          subtitle={`${profile.subscriptionPlan} plan`}
          icon={<CrownIcon size={18} color={colors.gold} />}
          onPress={() => navigation.navigate('Subscription')}
        />
        <View className="ml-4 h-px bg-border" />
        <GenieSettingsRow
          label="Settings"
          subtitle="Security, preferences, legal & account"
          icon={<SettingsIcon size={18} color={colors.gold} />}
          onPress={() => navigation.navigate('Settings')}
        />
      </View>
    </GenieScreen>
  );
};
