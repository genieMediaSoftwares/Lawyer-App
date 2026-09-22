import React, { useState } from 'react';
import { Modal, Pressable, View } from 'react-native';
import { GenieButton, GenieText } from '../ui';
import { TrashIcon } from '../icons/ClientIcons';
import type { AppDocument } from '../../types/domain';
import { colors } from '../../theme';

export interface DeleteDocumentModalProps {
  visible: boolean;
  document: AppDocument | null;
  onClose: () => void;
  onConfirmDelete: (document: AppDocument) => Promise<void>;
}

export const DeleteDocumentModal: React.FC<DeleteDocumentModalProps> = ({
  visible,
  document,
  onClose,
  onConfirmDelete,
}) => {
  const [isDeleting, setIsDeleting] = useState(false);
  const [errorText, setErrorText] = useState<string | null>(null);

  if (!document) {
    return null;
  }

  const displayName = document.name || document.originalName || 'this document';

  const handleDelete = async () => {
    setIsDeleting(true);
    setErrorText(null);

    try {
      await onConfirmDelete(document);
      onClose();
    } catch (err: any) {
      setErrorText(err.message || 'Failed to delete document.');
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <View className="flex-1 items-center justify-center bg-overlay px-5">
        <View className="w-full max-w-md rounded-card border border-border bg-surface p-5">
          <View className="mb-3 h-12 w-12 items-center justify-center rounded-full bg-error-surface self-center">
            <TrashIcon size={24} color={colors.error} />
          </View>

          <GenieText variant="heading-sm" className="font-bold text-center">
            Delete Document
          </GenieText>

          <GenieText variant="body-sm" tone="secondary" className="mt-2 text-center">
            Are you sure you want to delete &quot;{displayName}&quot;? This action cannot be undone.
          </GenieText>

          {errorText ? (
            <View className="mt-3 rounded-control border border-error bg-error-surface p-2.5">
              <GenieText variant="caption" tone="error" className="text-center">
                {errorText}
              </GenieText>
            </View>
          ) : null}

          <View className="mt-6 flex-row items-center gap-3">
            <Pressable
              onPress={onClose}
              disabled={isDeleting}
              className="h-12 flex-1 items-center justify-center rounded-control border border-border bg-surface-alt active:bg-surface-alt"
            >
              <GenieText variant="button" tone="secondary">
                Cancel
              </GenieText>
            </Pressable>

            <View className="flex-1">
              <GenieButton
                label="Delete"
                variant="danger"
                loading={isDeleting}
                onPress={handleDelete}
              />
            </View>
          </View>
        </View>
      </View>
    </Modal>
  );
};
