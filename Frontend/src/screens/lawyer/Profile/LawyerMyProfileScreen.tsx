import React, { useState } from 'react';
import { Alert, Pressable, View } from 'react-native';
import { useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieAvatar,
  GenieButton,
  GenieCard,
  GenieErrorState,
  GenieHeader,
  GenieScreen,
  GenieSkeleton,
  GenieText,
  VerifiedBadge,
} from '../../../components';
import { CameraIcon } from '../../../components/icons/ClientIcons';
import { authApi } from '../../../api/authApi';
import { lawyerApi } from '../../../api/lawyerApi';
import { useAuthStore } from '../../../store/authStore';
import type { LawyerStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';
import { isLawyerVerified } from '../../../utils/verification';
import { pickProfilePhoto } from '../../../services/profilePhoto';
import type { ProfilePhotoUpload } from '../../../services/profilePhoto';
import { startTrace } from '../../../utils/perfTrace';
import type { PerfTrace } from '../../../utils/perfTrace';

const InfoRow: React.FC<{ label: string; value: string; isLast?: boolean }> = ({
  label,
  value,
  isLast = false,
}) => (
  <View className={isLast ? 'pt-2' : 'border-b border-border py-2'}>
    <GenieText variant="caption" tone="muted">
      {label}
    </GenieText>
    <GenieText variant="body-sm" className="mt-0.5 font-medium">
      {value}
    </GenieText>
  </View>
);

// The lawyer counterpart of the client's "My Profile" screen: the same
// account-summary layout (photo, Account Summary card, edit button), backed
// by the lawyer's own profile record instead of the client's.
export const LawyerMyProfileScreen: React.FC<
  LawyerStackScreenProps<'LawyerMyProfile'>
> = ({ navigation }) => {
  const authUser = useAuthStore(state => state.user);
  const queryClient = useQueryClient();
  const [isUploading, setIsUploading] = useState(false);

  const profileQuery = useQuery({
    queryKey: ['lawyer', 'profile', authUser?.id],
    queryFn: () => lawyerApi.getProfile(authUser!.id),
    enabled: Boolean(authUser?.id),
  });

  const user = profileQuery.data?.user;

  const uploadFile = async (file: ProfilePhotoUpload, trace?: PerfTrace) => {
    setIsUploading(true);
    try {
      await authApi.uploadProfileImage(file);
      trace?.mark('uploaded');
      trace?.end();
      await queryClient.invalidateQueries({ queryKey: ['lawyer', 'profile', authUser?.id] });
      await queryClient.invalidateQueries({ queryKey: ['auth', 'profile'] });
    } catch (err: any) {
      trace?.end('error');
      Alert.alert(
        'Upload Error',
        err.message || 'Failed to upload profile photo',
      );
    } finally {
      setIsUploading(false);
    }
  };

  const handleSelectImage = async () => {
    try {
      const trace = startTrace('profile-photo');
      const photo = await pickProfilePhoto(trace);
      if (photo) {
        await uploadFile(photo, trace);
      }
    } catch (err: any) {
      Alert.alert('Upload Error', err?.message || 'Could not open the photo picker');
    }
  };

  const header = <GenieHeader title="My Profile" onBack={() => navigation.goBack()} />;

  if (profileQuery.isPending) {
    return (
      <GenieScreen header={header} dismissKeyboardOnTap={false}>
        <View className="items-center">
          <GenieSkeleton className="h-24 w-24 rounded-full" />
          <GenieSkeleton className="mt-6 h-60 w-full rounded-card" />
        </View>
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
    >
      <View className="my-3 items-center">
        <View className="rounded-full border-2 border-border p-1">
          <GenieAvatar uri={user.profileImage} name={user.fullName} size="xl" />

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
          <GenieText variant="heading-md">{user.fullName}</GenieText>
          {isLawyerVerified(profileQuery.data) ? <VerifiedBadge size={18} /> : null}
        </View>

        <GenieText
          variant="caption"
          tone="gold"
          className="mt-0.5 font-medium tracking-widest"
        >
          {(user.role || 'Lawyer').toUpperCase()}
        </GenieText>
      </View>

      <GenieCard tone="surface" className="mt-3 p-5">
        <GenieText
          variant="caption"
          tone="gold"
          className="mb-3 font-bold uppercase tracking-widest"
        >
          Account Summary
        </GenieText>

        <InfoRow label="Full Name" value={user.fullName} />
        <InfoRow label="Email Address" value={user.email} />
        <InfoRow label="Phone Number" value={user.mobile || 'Not set'} />
        <InfoRow label="Location" value={user.location || 'Not set'} isLast />
      </GenieCard>

      <GenieButton
        label="Edit Profile Details"
        onPress={() => navigation.navigate('ProfessionalDetails')}
        className="mt-5"
      />
    </GenieScreen>
  );
};
