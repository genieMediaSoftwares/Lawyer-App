import React, { useState } from 'react';
import { ActivityIndicator, Modal, Pressable, View } from 'react-native';
import { GenieButton, GenieDivider, GenieText } from '../ui';
import {
  CloseIcon,
  FolderIcon,
  ImageIcon,
  ScanIcon,
  UploadArrowIcon,
} from '../icons/ClientIcons';
import { filePicker } from '../../services/filePicker';
import { formatFileSize } from '../../utils/urls';
import { rejectionReasonFor } from '../../api/aiApi';
import type { PickedFile } from '../../types/ai';
import { colors } from '../../theme';

export interface UploadDocumentModalProps {
  visible: boolean;
  onClose: () => void;
  onUpload: (file: PickedFile) => Promise<void>;
}

export const UploadDocumentModal: React.FC<UploadDocumentModalProps> = ({
  visible,
  onClose,
  onUpload,
}) => {
  const [selectedFile, setSelectedFile] = useState<PickedFile | null>(null);
  const [errorText, setErrorText] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);

  const handlePickFile = async () => {
    setErrorText(null);
    try {
      const files = await filePicker.pickDocuments(1);
      if (files.length > 0) {
        const file = files[0];
        const rejection = rejectionReasonFor(file);
        if (rejection) {
          setErrorText(rejection);
          return;
        }
        setSelectedFile(file);
      }
    } catch (err: any) {
      setErrorText(err.message || 'Failed to select file.');
    }
  };

  const handleStartUpload = async () => {
    if (!selectedFile || isUploading) {
      return;
    }

    setIsUploading(true);
    setErrorText(null);

    try {
      await onUpload(selectedFile);
      setSelectedFile(null);
      onClose();
    } catch (err: any) {
      setErrorText(err.message || 'Failed to upload document.');
    } finally {
      setIsUploading(false);
    }
  };

  const handleClose = () => {
    if (isUploading) return;
    setSelectedFile(null);
    setErrorText(null);
    onClose();
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={handleClose}
      statusBarTranslucent
    >
      <View className="flex-1 justify-end bg-overlay">
        <Pressable className="flex-1" onPress={handleClose} />

        <View className="rounded-t-2xl border-t border-border bg-[#141414] px-5 pb-8 pt-4">
          <View className="mb-4 flex-row items-center justify-between">
            <GenieText variant="heading-md" className="font-bold">
              Upload Document
            </GenieText>
            <Pressable
              onPress={handleClose}
              disabled={isUploading}
              accessibilityRole="button"
              accessibilityLabel="Close modal"
              className="p-1 active:opacity-60"
            >
              <CloseIcon size={20} color={colors.white} />
            </Pressable>
          </View>

          {errorText ? (
            <View className="mb-3 rounded-control border border-error/50 bg-error-surface p-3">
              <GenieText variant="caption" tone="error">
                {errorText}
              </GenieText>
            </View>
          ) : null}

          <Pressable
            onPress={handlePickFile}
            disabled={isUploading}
            accessibilityRole="button"
            accessibilityLabel="Tap to upload document"
            className="mb-4 items-center justify-center rounded-card border-2 border-dashed border-gold/60 bg-[#1A1A1A] p-6 active:bg-[#222]"
          >
            <View className="mb-2 h-12 w-12 items-center justify-center rounded-full bg-gold-muted">
              <UploadArrowIcon size={24} color={colors.gold} />
            </View>

            <GenieText variant="body-lg" className="font-bold">
              Tap to upload
            </GenieText>

            <GenieText variant="caption" tone="secondary" className="mt-1 text-center">
              PDF, DOCX, JPG, PNG, TXT (Max size 10 MB)
            </GenieText>
          </Pressable>

          {selectedFile ? (
            <View className="mb-4 rounded-card border border-gold bg-[#1E1C15] p-3.5">
              <View className="flex-row items-center justify-between">
                <View className="flex-1">
                  <GenieText variant="body-md" className="font-bold" numberOfLines={1}>
                    {selectedFile.name}
                  </GenieText>
                  <GenieText variant="caption" tone="gold" className="mt-0.5">
                    {formatFileSize(selectedFile.size)}
                  </GenieText>
                </View>
                <Pressable
                  onPress={() => setSelectedFile(null)}
                  disabled={isUploading}
                  className="ml-2 rounded-full p-1 active:bg-surface"
                >
                  <CloseIcon size={16} color={colors.textSecondary} />
                </Pressable>
              </View>

              <GenieButton
                label={isUploading ? 'Uploading...' : 'Upload Now'}
                loading={isUploading}
                onPress={handleStartUpload}
                className="mt-3"
              />
            </View>
          ) : null}

          <View className="my-3 flex-row items-center gap-3">
            <View className="flex-1 h-px bg-border" />
            <GenieText variant="caption" tone="muted">
              or
            </GenieText>
            <View className="flex-1 h-px bg-border" />
          </View>

          <View className="gap-2.5">
            <Pressable
              onPress={handlePickFile}
              disabled={isUploading}
              className="h-13 flex-row items-center gap-3 rounded-card border border-border bg-[#1A1A1A] px-4 active:bg-surface-alt"
            >
              <ImageIcon size={20} color={colors.white} />
              <GenieText variant="body-md" className="font-medium">
                Choose from Gallery
              </GenieText>
            </Pressable>

            <Pressable
              onPress={handlePickFile}
              disabled={isUploading}
              className="h-13 flex-row items-center gap-3 rounded-card border border-border bg-[#1A1A1A] px-4 active:bg-surface-alt"
            >
              <FolderIcon size={20} color={colors.white} />
              <GenieText variant="body-md" className="font-medium">
                Choose a File
              </GenieText>
            </Pressable>

            <Pressable
              onPress={handlePickFile}
              disabled={isUploading}
              className="h-13 flex-row items-center gap-3 rounded-card border border-border bg-[#1A1A1A] px-4 active:bg-surface-alt"
            >
              <ScanIcon size={20} color={colors.white} />
              <GenieText variant="body-md" className="font-medium">
                Scan Document
              </GenieText>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
};
