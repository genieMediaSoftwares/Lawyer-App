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
  ClockIcon,
  FileIcon,
  InfoCircleIcon,
  SettingsIcon,
  VerifiedIcon,
} from '../../../components/icons/ClientIcons';
import { UserIcon } from '../../../components/icons/Icons';
import { clientApi } from '../../../api/clientApi';
import { useUiStore } from '../../../store/uiStore';
import type { ClientTabScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

export const ProfileScreen: React.FC<ClientTabScreenProps<'Profile'>> = ({
  navigation,
}) => {
  const openDrawer = useUiStore(state => state.openDrawer);

  const profileQuery = useQuery({
    queryKey: ['client', 'profile'],
    queryFn: clientApi.getProfile,
  });

  const user = profileQuery.data?.user;

  const menuItems = [
    {
      id: 'my-profile',
      title: 'My Profile',
      subtitle: 'View your account summary & details',
      icon: <UserIcon size={18} color={colors.gold} />,
      onPress: () => navigation.navigate('MyProfileDetail'),
    },
    {
      id: 'personal-info',
      title: 'Personal Information',
      subtitle: 'DOB, Gender, Languages, Phone & Location',
      icon: <InfoCircleIcon size={18} color={colors.gold} />,
      onPress: () => navigation.navigate('PersonalInformation'),
    },
    {
      id: 'my-documents',
      title: 'My Documents',
      subtitle: 'Manage uploaded legal files',
      icon: <FileIcon size={18} color={colors.gold} />,
      onPress: () => navigation.navigate('Documents'),
    },
    {
      id: 'recent-activity',
      title: 'Recent Activity',
      subtitle: 'View case and account activity log',
      icon: <ClockIcon size={18} color={colors.gold} />,
      onPress: () => navigation.navigate('RecentActivity'),
    },
    {
      id: 'settings',
      title: 'Settings',
      subtitle: 'Security, preferences, legal & account',
      icon: <SettingsIcon size={18} color={colors.gold} />,
      onPress: () => navigation.navigate('Settings'),
    },
  ];

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
        <GenieSkeleton className="h-24 w-full rounded-card" />
        <GenieSkeleton className="mt-4 h-80 w-full rounded-card" />
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

  if (!user) {
    return <GenieScreen header={header} dismissKeyboardOnTap={false}>{null}</GenieScreen>;
  }

  return (
    <GenieScreen
      scrollable
      header={header}
      dismissKeyboardOnTap={false}
      contentContainerClassName="pb-10"
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
      <GenieCard tone="surface" className="mb-4 flex-row items-center border-gold-wash p-5">
        <GenieAvatar uri={user.profileImage} name={user.fullName} size="lg" ring />

        <View className="ml-4 flex-1">
          <View className="flex-row items-center gap-1">
            <GenieText variant="heading-sm" numberOfLines={1}>
              {user.fullName}
            </GenieText>
            {user.isVerified ? <VerifiedIcon size={16} color={colors.gold} /> : null}
          </View>

          <GenieText variant="body-sm" tone="secondary" numberOfLines={1} className="mt-0.5">
            {user.email}
          </GenieText>

          <View className="mt-2 self-start rounded-lg bg-gold-muted px-2 py-0.5">
            <GenieText variant="caption" tone="gold" className="font-bold tracking-widest">
              {(user.role || 'CLIENT').toUpperCase()}
            </GenieText>
          </View>
        </View>
      </GenieCard>

      <View className="overflow-hidden rounded-card border border-border bg-surface">
        {menuItems.map((item, index) => (
          <React.Fragment key={item.id}>
            {index > 0 ? <View className="ml-4 h-px bg-border" /> : null}
            <GenieSettingsRow
              label={item.title}
              subtitle={item.subtitle}
              icon={item.icon}
              onPress={item.onPress}
            />
          </React.Fragment>
        ))}
      </View>
    </GenieScreen>
  );
};
