import React from 'react';
import { Pressable, View } from 'react-native';
import { GenieText } from '../ui';
import { FileIcon, UploadArrowIcon } from '../icons/ClientIcons';
import { colors } from '../../theme';

export interface DocumentEmptyStateProps {
  isFiltered?: boolean;
  onUpload: () => void;
}

export const DocumentEmptyState: React.FC<DocumentEmptyStateProps> = ({
  isFiltered = false,
  onUpload,
}) => {
  return (
    <View className="flex-1 items-center justify-center px-6 py-12">
      <View className="mb-5 h-28 w-28 items-center justify-center rounded-full border border-border bg-[#141414]">
        <FileIcon size={44} color={colors.gold} />
      </View>

      <GenieText variant="heading-md" className="font-bold text-center">
        {isFiltered ? 'No matching documents' : 'No documents yet'}
      </GenieText>

      <GenieText
        variant="body-sm"
        tone="secondary"
        className="mt-2.5 max-w-[290px] text-center leading-relaxed"
      >
        {isFiltered
          ? 'Try selecting another file type or clearing your search filter.'
          : 'Upload your legal documents to keep them organized and accessible anytime, anywhere.'}
      </GenieText>

      <Pressable
        onPress={onUpload}
        accessibilityRole="button"
        accessibilityLabel="Upload document"
        className="mt-6 h-13 min-w-[220px] flex-row items-center justify-center gap-2 rounded-control bg-gold px-6 active:bg-gold-bright"
      >
        <UploadArrowIcon size={20} color={colors.onGold} />
        <GenieText variant="button" tone="on-gold">
          Upload Document
        </GenieText>
      </Pressable>
    </View>
  );
};
