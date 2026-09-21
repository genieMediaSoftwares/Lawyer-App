import React, { useEffect, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieButton,
  GenieCard,
  GenieErrorState,
  GenieHeader,
  GenieInput,
  GenieNotice,
  GenieScreen,
  GenieSkeleton,
  GenieText,
} from '../../../components';
import { clientApi } from '../../../api/clientApi';
import type { ClientStackScreenProps } from '../../../types/navigation';

export const PersonalInformationScreen: React.FC<
  ClientStackScreenProps<'PersonalInformation'>
> = ({ navigation }) => {
  const queryClient = useQueryClient();

  const profileQuery = useQuery({
    queryKey: ['client', 'profile'],
    queryFn: clientApi.getProfile,
  });

  const user = profileQuery.data?.user;

  const [fullName, setFullName] = useState('');
  const [mobile, setMobile] = useState('');
  const [location, setLocation] = useState('');
  const [dob, setDob] = useState('');
  const [gender, setGender] = useState('');
  const [languagesStr, setLanguagesStr] = useState('');

  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saveSuccess, setSaveSuccess] = useState(false);

  useEffect(() => {
    if (user) {
      setFullName(user.fullName || '');
      setMobile(user.mobile || '');
      setLocation(user.location || '');
      setDob(user.dob || '');
      setGender(user.gender || '');
      setLanguagesStr(user.languages?.join(', ') || '');
    }
  }, [user]);

  const handleSave = async () => {
    setSaveError(null);
    setSaveSuccess(false);

    if (!fullName.trim()) {
      setSaveError('Full Name is required');
      return;
    }

    setIsSaving(true);
    try {
      const languagesArray = languagesStr
        .split(',')
        .map(s => s.trim())
        .filter(Boolean);

      await clientApi.updateProfile({
        fullName: fullName.trim(),
        mobile: mobile.trim(),
        location: location.trim(),
        dob: dob.trim(),
        gender: gender.trim().toLowerCase(),
        languages: languagesArray,
      });

      await queryClient.invalidateQueries({ queryKey: ['client', 'profile'] });
      await queryClient.invalidateQueries({ queryKey: ['auth', 'profile'] });

      setSaveSuccess(true);
      setTimeout(() => {
        navigation.goBack();
      }, 1000);
    } catch (err: any) {
      setSaveError(err.message || 'Failed to update personal information');
    } finally {
      setIsSaving(false);
    }
  };

  const header = (
    <GenieHeader
      title="Personal Information"
      onBack={() => navigation.goBack()}
    />
  );

  if (profileQuery.isPending) {
    return (
      <GenieScreen header={header}>
        {[0, 1, 2, 3].map(i => (
          <GenieSkeleton key={i} className={`h-14 w-full ${i > 0 ? 'mt-3' : ''}`} />
        ))}
      </GenieScreen>
    );
  }

  if (profileQuery.isError) {
    return (
      <GenieScreen header={header}>
        <GenieErrorState
          message={profileQuery.error.message}
          onRetry={() => profileQuery.refetch()}
        />
      </GenieScreen>
    );
  }

  return (
    <GenieScreen
      scrollable
      header={header}
      contentContainerClassName="pb-10"
      scrollViewProps={{ keyboardShouldPersistTaps: 'handled' }}
    >
      <GenieNotice message={saveError} className="mb-3" />
      <GenieNotice
        message={saveSuccess ? 'Information updated successfully!' : null}
        tone="success"
        className="mb-3"
      />

      <GenieCard tone="surface" className="p-5">
        <GenieText
          variant="caption"
          tone="gold"
          className="mb-4 font-bold uppercase tracking-widest"
        >
          Edit Personal Details
        </GenieText>

        <GenieInput
          label="Full Name"
          value={fullName}
          onChangeText={setFullName}
          placeholder="e.g. John Doe"
          containerClassName="mb-3"
        />

        <GenieInput
          label="Phone / Mobile Number"
          value={mobile}
          onChangeText={setMobile}
          placeholder="e.g. +91 9876543210"
          keyboardType="phone-pad"
          containerClassName="mb-3"
        />

        <GenieInput
          label="City / Location"
          value={location}
          onChangeText={setLocation}
          placeholder="e.g. Mumbai, India"
          containerClassName="mb-3"
        />

        <GenieInput
          label="Date of Birth"
          value={dob}
          onChangeText={setDob}
          placeholder="YYYY-MM-DD"
          containerClassName="mb-3"
        />

        <GenieInput
          label="Gender"
          value={gender}
          onChangeText={setGender}
          placeholder="e.g. Male / Female / Other"
          containerClassName="mb-3"
        />

        <GenieInput
          label="Languages Spoken"
          value={languagesStr}
          onChangeText={setLanguagesStr}
          placeholder="e.g. English, Hindi, Marathi"
          helperText="Separate multiple languages with commas"
        />
      </GenieCard>

      <GenieButton
        label="Save Changes"
        loadingLabel="Saving Changes..."
        loading={isSaving}
        onPress={handleSave}
        className="mt-5"
      />
    </GenieScreen>
  );
};
