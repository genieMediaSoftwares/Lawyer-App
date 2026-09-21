import React, { useState } from 'react';

import {
  GenieButton,
  GenieCard,
  GenieHeader,
  GenieNotice,
  GeniePasswordInput,
  GenieScreen,
  GenieText,
} from '../../../components';
import { authApi } from '../../../api/authApi';
import type { ClientStackScreenProps } from '../../../types/navigation';

export const ChangePasswordScreen: React.FC<
  ClientStackScreenProps<'ChangePassword'>
> = ({ navigation }) => {
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const [isLoading, setIsLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  const handleSubmit = async () => {
    setErrorMsg(null);
    setSuccessMsg(null);

    if (!currentPassword) {
      setErrorMsg('Please enter your current password.');
      return;
    }

    if (!newPassword || newPassword.length < 6) {
      setErrorMsg('New password must be at least 6 characters long.');
      return;
    }

    if (newPassword !== confirmPassword) {
      setErrorMsg('New password and confirm password do not match.');
      return;
    }

    setIsLoading(true);
    try {
      await authApi.changePassword({
        currentPassword,
        oldPassword: currentPassword,
        newPassword,
      });

      setSuccessMsg('Password updated successfully!');
      setTimeout(() => {
        navigation.goBack();
      }, 1200);
    } catch (err: any) {
      setErrorMsg(
        err.message ||
          'Failed to change password. Please verify current password.',
      );
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <GenieScreen
      scrollable
      header={
        <GenieHeader title="Change Password" onBack={() => navigation.goBack()} />
      }
      contentContainerClassName="pb-10"
      scrollViewProps={{ keyboardShouldPersistTaps: 'handled' }}
    >
      <GenieNotice message={errorMsg} className="mb-3" />
      <GenieNotice message={successMsg} tone="success" className="mb-3" />

      <GenieCard tone="surface" className="p-5">
        <GenieText
          variant="caption"
          tone="gold"
          className="mb-4 font-bold uppercase tracking-widest"
        >
          Security Credentials
        </GenieText>

        <GeniePasswordInput
          label="Current Password"
          value={currentPassword}
          onChangeText={setCurrentPassword}
          placeholder="Enter current password"
          containerClassName="mb-3"
        />

        <GeniePasswordInput
          label="New Password"
          value={newPassword}
          onChangeText={setNewPassword}
          placeholder="Minimum 6 characters"
          containerClassName="mb-3"
        />

        <GeniePasswordInput
          label="Confirm New Password"
          value={confirmPassword}
          onChangeText={setConfirmPassword}
          placeholder="Re-enter new password"
        />
      </GenieCard>

      <GenieButton
        label="Update Password"
        loadingLabel="Updating Password..."
        loading={isLoading}
        onPress={handleSubmit}
        className="mt-5"
      />
    </GenieScreen>
  );
};
