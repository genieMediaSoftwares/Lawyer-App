import React from 'react';
import {
  Image,
  Modal,
  Pressable,
  View,
  useWindowDimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { GenieAvatar, GenieIconButton, GenieText } from './';
import { CloseIcon } from '../icons/ClientIcons';
import { getUploadUrl } from '../../utils/urls';
import { colors } from '../../theme';

export interface ProfileImageModalProps {
  visible: boolean;
  onClose: () => void;
  imageUri?: string | null;
  name?: string;
}

/**
 * A WhatsApp-style full-screen profile photo viewer.
 * Displays a high-resolution dark preview overlay with smooth dismiss.
 */
export const ProfileImageModal: React.FC<ProfileImageModalProps> = ({
  visible,
  onClose,
  imageUri,
  name,
}) => {
  const { width } = useWindowDimensions();
  const fullUrl = getUploadUrl(imageUri);
  const size = Math.min(width * 0.85, 360);

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <View className="flex-1 justify-between bg-black/95">
        {/* Top Header */}
        <SafeAreaView edges={['top']} className="z-10 flex-row items-center justify-between px-4 py-3">
          <GenieText variant="heading-md" tone="primary" className="flex-1 font-semibold" numberOfLines={1}>
            {name || 'Profile Photo'}
          </GenieText>
          <GenieIconButton
            icon={<CloseIcon size={24} color={colors.white} />}
            onPress={onClose}
            accessibilityLabel="Close image preview"
          />
        </SafeAreaView>

        {/* Backdrop Tap to close & Center Content */}
        <Pressable
          onPress={onClose}
          className="flex-1 items-center justify-center p-4"
        >
          <Pressable onPress={e => e.stopPropagation()} className="items-center justify-center">
            {fullUrl ? (
              <Image
                source={{ uri: fullUrl }}
                style={{ width: size, height: size, borderRadius: size / 2 }}
                className="border-2 border-gold/40 shadow-2xl"
                resizeMode="cover"
              />
            ) : (
              <View className="items-center justify-center">
                <GenieAvatar
                  uri={null}
                  name={name || 'User'}
                  size="xl"
                  ring
                />
              </View>
            )}
          </Pressable>
        </Pressable>

        {/* Bottom space */}
        <SafeAreaView edges={['bottom']} className="py-2" />
      </View>
    </Modal>
  );
};
