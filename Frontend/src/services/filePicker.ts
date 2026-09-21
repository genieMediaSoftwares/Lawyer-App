import { pick, types, errorCodes, isErrorWithCode } from '@react-native-documents/picker';

import { UPLOAD_LIMITS } from '../api/aiApi';
import type { PickedFile } from '../types/ai';

const DOCUMENT_TYPES = [
  types.pdf,
  types.docx,
  types.images,
  types.plainText,
  types.csv,
];

export const filePicker = {
  async pickDocuments(remainingSlots: number): Promise<PickedFile[]> {
    if (remainingSlots <= 0) {
      return [];
    }

    try {
      const results = await pick({
        allowMultiSelection: remainingSlots > 1,
        type: DOCUMENT_TYPES,
      });

      return results.slice(0, remainingSlots).map(result => ({
        uri: result.uri,
        name: result.name ?? 'document',
        type: result.type ?? null,
        size: result.size ?? null,
      }));
    } catch (error) {
      if (isErrorWithCode(error) && error.code === errorCodes.OPERATION_CANCELED) {
        return [];
      }
      throw error;
    }
  },

  maxFileBytes: UPLOAD_LIMITS.maxFileBytes,
};
