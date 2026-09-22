import React from 'react';
import { Pressable, View } from 'react-native';

import { GenieBottomSheet, GenieText } from './ui';
import { ChevronRightIcon, FileIcon, SparkleIcon } from './icons/ClientIcons';
import { colors } from '../theme';

interface CreateCaseSheetProps {
  visible: boolean;
  onClose: () => void;
  onStartManual: () => void;
  onStartAi: () => void;
}

export const CreateCaseSheet: React.FC<CreateCaseSheetProps> = ({
  visible,
  onClose,
  onStartManual,
  onStartAi,
}) => (
  <GenieBottomSheet visible={visible} onClose={onClose}>
    <View className="pb-4">
      <GenieText variant="heading-lg">Start a new case</GenieText>
      <GenieText variant="body-sm" tone="secondary" className="mb-4 mt-1">
        Choose how you would like to begin.
      </GenieText>

      <Pressable
        onPress={onStartAi}
        accessibilityRole="button"
        accessibilityLabel="Create Case with AI"
        className="mb-3 flex-row items-center rounded-card border border-border bg-card p-3 active:opacity-80"
      >
        <View className="mr-3 h-10 w-10 items-center justify-center rounded-full bg-gold-muted">
          <SparkleIcon size={20} color={colors.gold} />
        </View>

        <View className="mr-1 flex-1">
          <GenieText variant="body-sm" className="font-bold">
            Create Case with AI
          </GenieText>
          <GenieText variant="caption" tone="muted" className="mt-0.5">
            Upload your documents and let the assistant read them and fill in
            your case.
          </GenieText>
        </View>

        <ChevronRightIcon size={18} color={colors.gold} />
      </Pressable>

      <Pressable
        onPress={onStartManual}
        accessibilityRole="button"
        accessibilityLabel="Post a Case Manually"
        className="mb-3 flex-row items-center rounded-card border border-border bg-card p-3 active:opacity-80"
      >
        <View className="mr-3 h-10 w-10 items-center justify-center rounded-full bg-surface-alt">
          <FileIcon size={20} color={colors.textSecondary} />
        </View>

        <View className="mr-1 flex-1">
          <GenieText variant="body-sm" className="font-bold">
            Post a Case Manually
          </GenieText>
          <GenieText variant="caption" tone="muted" className="mt-0.5">
            Fill in the case details yourself, step by step.
          </GenieText>
        </View>

        <ChevronRightIcon size={18} color={colors.textSecondary} />
      </Pressable>

      <Pressable
        onPress={onClose}
        accessibilityRole="button"
        accessibilityLabel="Close"
        className="mt-1 min-h-touch items-center justify-center active:opacity-80"
      >
        <GenieText variant="body-sm" tone="secondary">
          Close
        </GenieText>
      </Pressable>
    </View>
  </GenieBottomSheet>
);
