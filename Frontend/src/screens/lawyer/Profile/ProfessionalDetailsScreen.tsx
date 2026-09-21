import React, { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

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
import { lawyerApi } from '../../../api/lawyerApi';
import { useAuthStore } from '../../../store/authStore';
import { toAppError } from '../../../utils/errors';
import type { LawyerStackScreenProps } from '../../../types/navigation';

export const ProfessionalDetailsScreen: React.FC<
  LawyerStackScreenProps<'ProfessionalDetails'>
> = ({ navigation }) => {
  const user = useAuthStore(state => state.user);
  const queryClient = useQueryClient();

  const profileQuery = useQuery({
    queryKey: ['lawyer', 'profile', user?.id],
    queryFn: () => lawyerApi.getProfile(user!.id),
    enabled: Boolean(user?.id),
  });

  const [specialization, setSpecialization] = useState('');
  const [experience, setExperience] = useState('');
  const [education, setEducation] = useState('');
  const [barCouncilNumber, setBarCouncilNumber] = useState('');
  const [consultationFee, setConsultationFee] = useState('');
  const [officeAddress, setOfficeAddress] = useState('');
  const [workingHours, setWorkingHours] = useState('');
  const [bio, setBio] = useState('');

  const [formError, setFormError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  const profile = profileQuery.data;

  useEffect(() => {
    if (profile) {
      setSpecialization(profile.specialization ?? '');
      setExperience(profile.experience ? String(profile.experience) : '');
      setEducation(profile.education ?? '');
      setBarCouncilNumber(profile.barCouncilNumber ?? '');
      setConsultationFee(
        profile.consultationFee ? String(profile.consultationFee) : '',
      );
      setOfficeAddress(profile.officeAddress ?? '');
      setWorkingHours(profile.workingHours ?? '');
      setBio(profile.bio ?? '');
    }
  }, [profile]);

  const saveMutation = useMutation({
    mutationFn: () =>
      lawyerApi.updateProfile({
        specialization: specialization.trim(),
        experience: experience.trim() ? Number(experience.trim()) : 0,
        education: education.trim(),
        barCouncilNumber: barCouncilNumber.trim(),
        consultationFee: consultationFee.trim()
          ? Number(consultationFee.trim())
          : 0,
        officeAddress: officeAddress.trim(),
        workingHours: workingHours.trim(),
        bio: bio.trim(),
      }),
    onError: error => setFormError(toAppError(error).message),
    onSuccess: async () => {
      setSaved(true);
      await queryClient.invalidateQueries({ queryKey: ['lawyer', 'profile'] });
      setTimeout(() => navigation.goBack(), 900);
    },
  });

  const handleSave = () => {
    setFormError(null);
    setSaved(false);

    if (!specialization.trim()) {
      setFormError('Specialisation is required.');
      return;
    }
    if (experience.trim() && Number.isNaN(Number(experience.trim()))) {
      setFormError('Years of experience must be a number.');
      return;
    }
    if (consultationFee.trim() && Number.isNaN(Number(consultationFee.trim()))) {
      setFormError('Consultation fee must be a number.');
      return;
    }

    saveMutation.mutate();
  };

  const header = (
    <GenieHeader
      title="Professional Details"
      onBack={() => navigation.goBack()}
    />
  );

  if (profileQuery.isPending) {
    return (
      <GenieScreen header={header}>
        {[0, 1, 2, 3, 4].map(i => (
          <GenieSkeleton key={i} className={`h-14 w-full ${i ? 'mt-3' : ''}`} />
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
      <GenieNotice message={formError} className="mb-3" />
      <GenieNotice
        message={saved ? 'Profile updated successfully.' : null}
        tone="success"
        className="mb-3"
      />

      <GenieCard tone="surface" className="p-5">
        <GenieText
          variant="caption"
          tone="gold"
          className="mb-4 font-bold uppercase tracking-widest"
        >
          Practice
        </GenieText>

        <GenieInput
          label="Specialisation"
          value={specialization}
          onChangeText={setSpecialization}
          placeholder="e.g. Criminal Law"
          containerClassName="mb-3"
        />
        <GenieInput
          label="Years of Experience"
          value={experience}
          onChangeText={setExperience}
          placeholder="e.g. 8"
          keyboardType="number-pad"
          containerClassName="mb-3"
        />
        <GenieInput
          label="Bar Council Number"
          value={barCouncilNumber}
          onChangeText={setBarCouncilNumber}
          placeholder="e.g. MAH/1234/2015"
          containerClassName="mb-3"
        />
        <GenieInput
          label="Education"
          value={education}
          onChangeText={setEducation}
          placeholder="e.g. LL.B, University of Delhi"
          containerClassName="mb-3"
        />
        <GenieInput
          label="Consultation Fee"
          value={consultationFee}
          onChangeText={setConsultationFee}
          placeholder="e.g. 1500"
          keyboardType="number-pad"
          helperText="In rupees, per consultation"
        />
      </GenieCard>

      <GenieCard tone="surface" className="mt-4 p-5">
        <GenieText
          variant="caption"
          tone="gold"
          className="mb-4 font-bold uppercase tracking-widest"
        >
          Practice Details
        </GenieText>

        <GenieInput
          label="Office Address"
          value={officeAddress}
          onChangeText={setOfficeAddress}
          placeholder="e.g. 12 High Court Road, Mumbai"
          containerClassName="mb-3"
        />
        <GenieInput
          label="Working Hours"
          value={workingHours}
          onChangeText={setWorkingHours}
          placeholder="e.g. 9:00 AM - 6:00 PM"
          containerClassName="mb-3"
        />
        <GenieInput
          label="About You"
          value={bio}
          onChangeText={setBio}
          placeholder="A short professional summary clients will read."
          multiline
          numberOfLines={4}
          className="h-24"
        />
      </GenieCard>

      <GenieButton
        label="Save Changes"
        loadingLabel="Saving..."
        loading={saveMutation.isPending}
        onPress={handleSave}
        className="mt-5"
      />
    </GenieScreen>
  );
};
