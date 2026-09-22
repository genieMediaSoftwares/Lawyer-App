import React, { useCallback } from 'react';
import { Image, Modal, Pressable, Share, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { GenieAvatar, GenieIconButton, GenieText } from './';
import { BackIcon } from '../icons/Icons';
import { EditIcon, ShareIcon } from '../icons/ClientIcons';
import { getUploadUrl } from '../../utils/urls';
import { colors } from '../../theme';

export interface ProfileImageViewerProps {
  visible: boolean;
  onClose: () => void;
  imageUri?: string | null;
  // Whoever's photo this is — the signed-in user, a client, a lawyer, or a
  // chat participant. Shown as the title, never a hardcoded label.
  name?: string;
  // Only offered when the caller can actually change this photo (the
  // viewer's own profile). Omit it entirely when viewing someone else's
  // photo, rather than showing a pencil that goes nowhere.
  onEdit?: () => void;
}

/**
 * The one WhatsApp-style, full-screen photo viewer used everywhere a small
 * avatar in the app is tappable: a lawyer viewing a client's photo, a client
 * viewing a lawyer's photo, a chat header avatar, or the signed-in user's own
 * profile photo (drawer). Dark background, the real backend image shown large
 * and centered, a back control, and share — with edit added only for one's
 * own photo. Never introduces mock imagery: with no real photo it falls back
 * to the app's existing default avatar (initials/placeholder), just larger.
 */
export const ProfileImageViewer: React.FC<ProfileImageViewerProps> = ({
  visible,
  onClose,
  imageUri,
  name,
  onEdit,
}) => {
  const fullUrl = getUploadUrl(imageUri);

  const handleShare = useCallback(async () => {
    if (!fullUrl) return;
    try {
      await Share.share({ url: fullUrl, message: fullUrl });
    } catch (err) {
      console.warn('Share profile photo error:', err);
    }
  }, [fullUrl]);

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <View className="flex-1 bg-background">
        <SafeAreaView edges={['top']} className="z-10 flex-row items-center px-1 py-1">
          <GenieIconButton
            icon={<BackIcon size={24} color={colors.white} />}
            onPress={onClose}
            accessibilityLabel="Close profile photo"
          />
          <GenieText
            variant="heading-sm"
            tone="primary"
            className="ml-1 flex-1 font-semibold"
            numberOfLines={1}
          >
            {name || 'Profile photo'}
          </GenieText>
          {onEdit ? (
            <GenieIconButton
              icon={<EditIcon size={20} color={colors.white} />}
              onPress={onEdit}
              accessibilityLabel="Change profile photo"
            />
          ) : null}
          {fullUrl ? (
            <GenieIconButton
              icon={<ShareIcon size={20} color={colors.white} />}
              onPress={handleShare}
              accessibilityLabel="Share profile photo"
            />
          ) : null}
        </SafeAreaView>

        <Pressable onPress={onClose} className="flex-1 items-center justify-center">
          {fullUrl ? (
            <Image
              source={{ uri: fullUrl }}
              className="h-full w-full"
              resizeMode="contain"
            />
          ) : (
            <View className="items-center gap-3">
              <GenieAvatar uri={null} name={name || 'User'} size="xl" />
              <GenieText variant="body-md" tone="muted">
                No profile photo yet
              </GenieText>
            </View>
          )}
        </Pressable>
      </View>
    </Modal>
  );
};
