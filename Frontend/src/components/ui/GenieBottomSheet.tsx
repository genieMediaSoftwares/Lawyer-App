import React from 'react';
import { Modal, Pressable, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { GenieText } from './GenieText';
import { GenieIconButton } from './GenieIconButton';
import { CloseIcon } from '../icons/ClientIcons';
import { colors } from '../../theme';

/**
 * A panel that rises from the bottom: filters, sorts, pickers.
 *
 * ON THE INVISIBLE OVERLAY
 *
 * A sheet built as an always-mounted absolutely-positioned View leaves a
 * transparent layer over the screen when it is "closed", and that layer goes
 * on eating taps — which is one of the ways a button stops responding for no
 * visible reason. React Native's `Modal` does not have that failure mode: when
 * `visible` is false nothing is mounted at all, so there is nothing left to
 * block. That is why this is a Modal rather than a positioned View.
 *
 * The backdrop is a sibling behind the panel rather than its parent, so a tap
 * inside the sheet cannot bubble out and dismiss it.
 */

export interface GenieBottomSheetProps {
  visible: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  /** A pinned action row below the content, e.g. Apply / Reset. */
  footer?: React.ReactNode;
  className?: string;
}

export const GenieBottomSheet: React.FC<GenieBottomSheetProps> = ({
  visible,
  onClose,
  title,
  children,
  footer,
  className = '',
}) => (
  <Modal
    visible={visible}
    transparent
    animationType="slide"
    onRequestClose={onClose}
    statusBarTranslucent
  >
    <View className="flex-1 justify-end">
      <Pressable
        className="absolute inset-0 bg-overlay"
        onPress={onClose}
        accessibilityRole="button"
        accessibilityLabel="Close"
      />

      <SafeAreaView edges={['bottom']} className={`rounded-t-sheet bg-surface ${className}`}>
        {/* The drag handle. Decorative — dismissal is the backdrop and the
            close button, both of which are reachable without a gesture. */}
        <View className="items-center pt-3">
          <View className="h-1 w-10 rounded-pill bg-border" />
        </View>

        {title ? (
          <View className="flex-row items-center justify-between px-5 pb-2 pt-4">
            <GenieText variant="heading-md">{title}</GenieText>
            <GenieIconButton
              icon={<CloseIcon size={20} color={colors.textSecondary} />}
              onPress={onClose}
              accessibilityLabel="Close"
            />
          </View>
        ) : null}

        <View className="px-5 pb-2">{children}</View>

        {footer ? (
          <View className="border-t border-border px-5 pb-2 pt-4">{footer}</View>
        ) : null}
      </SafeAreaView>
    </View>
  </Modal>
);
