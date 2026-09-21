import { pick, types, errorCodes, isErrorWithCode } from '@react-native-documents/picker';

import { UPLOAD_LIMITS } from '../api/aiApi';
import type { PickedFile } from '../types/ai';

/**
 * Document selection on a device.
 *
 * The web build takes `filePicker.web.ts` instead — Metro and Vite both
 * resolve `.web.ts` first — so this module is never bundled for the browser
 * and `@react-native-documents/picker`, which has no web build, never reaches
 * it.
 *
 * A cancelled picker resolves to an empty array rather than throwing. Cancel
 * is a normal outcome, and treating it as an error would put a failure banner
 * on the screen every time somebody changed their mind.
 */

/**
 * The picker's own type constants, matching the backend's allowlist.
 *
 * `types.doc` is deliberately absent: the backend rejects pre-2007 .doc
 * outright, so offering it in the picker would only produce a 415 after the
 * upload.
 */
const DOCUMENT_TYPES = [
  types.pdf,
  types.docx,
  types.images,
  types.plainText,
  types.csv,
];

export const filePicker = {
  /**
   * Opens the system document picker.
   *
   * @param remainingSlots how many more files the caller can accept, so the
   *   ten-document ceiling is enforced at selection rather than after.
   */
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
        // The picker can return a null name for a file from some providers;
        // the backend needs one to build its stored filename.
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

  /** Mirrors the web implementation's shape. Native has no separate path. */
  maxFileBytes: UPLOAD_LIMITS.maxFileBytes,
};
