import React, { useState } from 'react';
import { Switch, View } from 'react-native';
import { useQueryClient } from '@tanstack/react-query';

import {
  ContactSupportRows,
  GenieNotice,
  GenieButton,
  GenieHeader,
  GenieInput,
  GenieModal,
  GenieScreen,
  GenieSettingsGroup,
  GenieSettingsRow,
  GenieText,
} from '../../../components';
import {
  BellIcon,
  InfoCircleIcon,
  LogoutIcon,
  SettingsIcon,
  ShieldIcon,
  TrashIcon,
} from '../../../components/icons/ClientIcons';
import { LockIcon } from '../../../components/icons/Icons';
import { authApi } from '../../../api/authApi';
import { useAuthStore } from '../../../store/authStore';
import { useUiStore } from '../../../store/uiStore';
import type { ClientStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

export const SettingsScreen: React.FC<ClientStackScreenProps<'Settings'>> = ({
  navigation,
}) => {
  const logout = useAuthStore(state => state.logout);
  const openDrawer = useUiStore(state => state.openDrawer);
  const queryClient = useQueryClient();

  const [pushNotifications, setPushNotifications] = useState(true);
  const [isSigningOut, setIsSigningOut] = useState(false);

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isDeleting, setIsDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const handleSignOut = async () => {
    if (isSigningOut) {
      return;
    }
    setIsSigningOut(true);
    try {
      queryClient.clear();
      await logout();
    } finally {
      setIsSigningOut(false);
    }
  };

  const handleDeleteAccount = async () => {
    setDeleteError(null);
    if (!confirmPassword) {
      setDeleteError('Please enter your password to confirm account deletion.');
      return;
    }

    setIsDeleting(true);
    try {
      await authApi.deleteAccount(confirmPassword);
      setShowDeleteModal(false);
      queryClient.clear();
      await logout();
    } catch (err: any) {
      setDeleteError(
        err.message || 'Failed to delete account. Please verify password.',
      );
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <GenieScreen
      scrollable
      dismissKeyboardOnTap={false}
      header={
        <GenieHeader
          title="Settings"
          onMenu={openDrawer}
          onBack={
            navigation.canGoBack() ? () => navigation.goBack() : undefined
          }
        />
      }
      contentContainerClassName="pb-10"
    >
      <GenieSettingsGroup title="PREFERENCES" className="mb-5">
        <GenieSettingsRow
          label="Push Notifications"
          icon={<BellIcon size={18} color={colors.white} />}
          trailing={
            <Switch
              value={pushNotifications}
              onValueChange={setPushNotifications}
              accessibilityLabel="Push notifications"
              trackColor={{ false: colors.disabled, true: colors.gold }}
              thumbColor={pushNotifications ? colors.white : colors.textMuted}
            />
          }
        />
        <GenieSettingsRow
          label="App Theme"
          icon={<SettingsIcon size={18} color={colors.white} />}
          value="Black (Default)"
        />
        <GenieSettingsRow
          label="Language"
          icon={<InfoCircleIcon size={18} color={colors.white} />}
          value="English (IN)"
        />
      </GenieSettingsGroup>

      <GenieSettingsGroup title="SUPPORT & LEGAL" className="mb-5">
        <ContactSupportRows />
        <GenieSettingsRow
          label="About GenieLaw"
          icon={<InfoCircleIcon size={18} color={colors.white} />}
          onPress={() => navigation.navigate('AboutUs')}
        />
        <GenieSettingsRow
          label="Privacy Policy"
          icon={<ShieldIcon size={18} color={colors.white} />}
          onPress={() => navigation.navigate('PrivacyPolicy')}
        />
        <GenieSettingsRow
          label="Terms & Conditions"
          icon={<ShieldIcon size={18} color={colors.white} />}
          onPress={() => navigation.navigate('TermsConditions')}
        />
      </GenieSettingsGroup>

      <GenieSettingsGroup title="ACCOUNT">
        <GenieSettingsRow
          label="Change Password"
          icon={<LockIcon size={18} color={colors.white} />}
          onPress={() => navigation.navigate('ChangePassword')}
        />
        <GenieSettingsRow
          label={isSigningOut ? 'Signing out...' : 'Sign Out'}
          icon={<LogoutIcon size={18} color={colors.warning} />}
          tone="warning"
          disabled={isSigningOut}
          onPress={handleSignOut}
        />
        <GenieSettingsRow
          label="Delete Account"
          icon={<TrashIcon size={18} color={colors.error} />}
          tone="danger"
          onPress={() => {
            setDeleteError(null);
            setConfirmPassword('');
            setShowDeleteModal(true);
          }}
        />
      </GenieSettingsGroup>

      <GenieModal
        visible={showDeleteModal}
        onClose={() => setShowDeleteModal(false)}
        title="Delete Account"
        dismissOnBackdropPress={false}
        footer={
          <View className="flex-row gap-3">
            <GenieButton
              label="Cancel"
              variant="ghost"
              disabled={isDeleting}
              onPress={() => setShowDeleteModal(false)}
              className="flex-1"
            />
            <GenieButton
              label="Permanently Delete"
              loadingLabel="Deleting..."
              variant="danger"
              loading={isDeleting}
              onPress={handleDeleteAccount}
              className="flex-1"
            />
          </View>
        }
      >
        <GenieText variant="body-md" tone="secondary" className="mb-4">
          Warning: This action is permanent and cannot be undone. All your case
          history, documents, and messages will be permanently removed.
        </GenieText>

        {deleteError ? (
          <View className="mb-3">
            <GenieNotice message={deleteError} />
          </View>
        ) : null}

        <GenieInput
          label="Enter Password to Confirm"
          value={confirmPassword}
          onChangeText={setConfirmPassword}
          placeholder="Your password"
          secureTextEntry
        />
      </GenieModal>
    </GenieScreen>
  );
};
