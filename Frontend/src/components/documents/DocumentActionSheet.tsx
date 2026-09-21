import React from 'react';
import { Modal, Pressable, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { GenieDivider, GenieText } from '../ui';
import {
  DownloadIcon,
  EditIcon,
  EyeIcon,
  FileIcon,
  ImageIcon,
  ShareIcon,
  TrashIcon,
  UploadArrowIcon,
} from '../icons/ClientIcons';
import { formatDocumentMeta, getDocumentBadgeInfo } from './documentUtils';
import type { AppDocument } from '../../types/domain';
import { colors } from '../../theme';

export interface DocumentActionSheetProps {
  visible: boolean;
  document: AppDocument | null;
  onClose: () => void;
  onView: (document: AppDocument) => void;
  onRename: (document: AppDocument) => void;
  onReplace: (document: AppDocument) => void;
  onDownload: (document: AppDocument) => void;
  onShare: (document: AppDocument) => void;
  onDelete: (document: AppDocument) => void;
}

const ActionRow: React.FC<{
  label: string;
  icon: React.ReactNode;
  onPress: () => void;
  destructive?: boolean;
}> = ({ label, icon, onPress, destructive = false }) => (
  <Pressable
    onPress={onPress}
    accessibilityRole="button"
    className="h-14 flex-row items-center gap-3 rounded-control px-3 active:bg-surface-alt"
  >
    <View className="w-6 items-center justify-center">{icon}</View>
    <GenieText
      variant="body-lg"
      tone={destructive ? 'error' : 'primary'}
      className="flex-1 font-medium"
    >
      {label}
    </GenieText>
  </Pressable>
);

export const DocumentActionSheet: React.FC<DocumentActionSheetProps> = ({
  visible,
  document,
  onClose,
  onView,
  onRename,
  onReplace,
  onDownload,
  onShare,
  onDelete,
}) => {
  if (!document) {
    return null;
  }

  const badge = getDocumentBadgeInfo(document);
  const displayName = document.name || document.originalName || 'Untitled Document';
  const metaText = formatDocumentMeta(document);

  const renderBadgeIcon = () => {
    if (badge.category === 'image') {
      return <ImageIcon size={20} color="#34D399" />;
    }
    return (
      <FileIcon
        size={20}
        color={
          badge.category === 'pdf'
            ? '#EF4444'
            : badge.category === 'docx'
            ? '#60A5FA'
            : colors.textSecondary
        }
      />
    );
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <View className="flex-1 justify-end bg-overlay">
        <Pressable className="flex-1" onPress={onClose} />

        <View className="rounded-t-2xl border-t border-border bg-[#141414] px-4 pb-6 pt-3">
          {/* Handle indicator */}
          <View className="mb-4 h-1 w-10 self-center rounded-full bg-border" />

          {/* Header Preview Row */}
          <View className="mb-3 flex-row items-center rounded-card border border-border bg-[#1A1A1A] p-3">
            <View
              className={`h-12 w-12 items-center justify-center rounded-lg border ${badge.bgColor} ${badge.borderColor}`}
            >
              {renderBadgeIcon()}
            </View>

            <View className="ml-3 flex-1">
              <GenieText variant="body-lg" className="font-bold" numberOfLines={1}>
                {displayName}
              </GenieText>

              <GenieText variant="caption" tone="secondary" className="mt-0.5" numberOfLines={1}>
                {metaText}
              </GenieText>
            </View>
          </View>

          <GenieDivider className="mb-2" />

          {/* Action List */}
          <ScrollView className="max-h-[380px]" showsVerticalScrollIndicator={false}>
            <ActionRow
              label="View"
              icon={<EyeIcon size={20} color={colors.textSecondary} />}
              onPress={() => {
                onClose();
                onView(document);
              }}
            />

            <ActionRow
              label="Rename"
              icon={<EditIcon size={20} color={colors.textSecondary} />}
              onPress={() => {
                onClose();
                onRename(document);
              }}
            />

            <ActionRow
              label="Replace"
              icon={<UploadArrowIcon size={20} color={colors.gold} />}
              onPress={() => {
                onClose();
                onReplace(document);
              }}
            />

            <ActionRow
              label="Download"
              icon={<DownloadIcon size={20} color={colors.textSecondary} />}
              onPress={() => {
                onClose();
                onDownload(document);
              }}
            />

            <ActionRow
              label="Share"
              icon={<ShareIcon size={20} color={colors.textSecondary} />}
              onPress={() => {
                onClose();
                onShare(document);
              }}
            />

            <ActionRow
              label="Delete"
              destructive
              icon={<TrashIcon size={20} color={colors.error} />}
              onPress={() => {
                onClose();
                onDelete(document);
              }}
            />
          </ScrollView>

          <Pressable
            onPress={onClose}
            className="mt-3 h-12 items-center justify-center rounded-control border border-border bg-[#1A1A1A] active:bg-surface-alt"
          >
            <GenieText variant="button" tone="secondary">
              Cancel
            </GenieText>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
};
