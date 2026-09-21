import { UPLOAD_LIMITS } from '../api/aiApi';
import type { PickedFile } from '../types/ai';

const ACCEPT = [
  ...UPLOAD_LIMITS.documentExtensions,
  ...UPLOAD_LIMITS.documentMimeTypes,
].join(',');

const CANCEL_GRACE_MS = 1200;

let input: HTMLInputElement | null = null;

const ensureInput = (): HTMLInputElement => {
  if (input && input.isConnected) {
    return input;
  }

  input = document.createElement('input');
  input.type = 'file';
  input.accept = ACCEPT;
  input.style.position = 'fixed';
  input.style.left = '-9999px';
  input.style.opacity = '0';

  input.tabIndex = -1;
  input.setAttribute('aria-label', 'Choose documents to upload');

  document.body.appendChild(input);
  return input;
};

const toPickedFiles = (files: FileList | null, limit: number): PickedFile[] =>
  Array.from(files ?? [])
    .slice(0, limit)
    .map(file => ({
      uri: '',
      name: file.name,
      type: file.type || null,
      size: file.size,
      file,
    }));

export const filePicker = {
  async pickDocuments(remainingSlots: number): Promise<PickedFile[]> {
    if (remainingSlots <= 0) {
      return [];
    }

    const element = ensureInput();
    element.multiple = remainingSlots > 1;
    element.value = '';

    return new Promise<PickedFile[]>(resolve => {
      let settled = false;

      const finish = (files: PickedFile[]) => {
        if (settled) {
          return;
        }
        settled = true;

        element.removeEventListener('change', onChange);
        element.removeEventListener('cancel', onCancel);
        window.removeEventListener('focus', onFocus);

        element.blur();

        resolve(files);
      };

      const onChange = () => finish(toPickedFiles(element.files, remainingSlots));

      const onCancel = () => finish([]);

      const onFocus = () => {
        setTimeout(() => {
          if ((element.files?.length ?? 0) === 0) {
            finish([]);
          }
        }, CANCEL_GRACE_MS);
      };

      element.addEventListener('change', onChange);
      element.addEventListener('cancel', onCancel);
      window.addEventListener('focus', onFocus);

      element.click();
    });
  },

  maxFileBytes: UPLOAD_LIMITS.maxFileBytes,
};
