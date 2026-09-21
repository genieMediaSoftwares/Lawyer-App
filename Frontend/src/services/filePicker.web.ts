import { UPLOAD_LIMITS } from '../api/aiApi';
import type { PickedFile } from '../types/ai';

/**
 * Document selection in a browser.
 *
 * A hidden `<input type="file">`, which is the only way a page may open a file
 * dialog — and it must be triggered inside a user gesture, so this is called
 * straight from the button's press handler.
 *
 * The real `File` object is carried on `PickedFile.file`, because the
 * browser's FormData needs the Blob itself; a `{uri, name, type}` object
 * serialises to "[object Object]" and uploads nothing. `aiApi.appendFile`
 * branches on exactly that.
 *
 * ── Why the input is reused rather than recreated ─────────────────────────
 *
 * One element is created on first use and kept in the DOM. Building a fresh
 * one per call meant the element could be removed while the dialog was still
 * open — and detaching a file input cancels its pending selection, so a chosen
 * file was silently dropped. Reusing one element removes that race entirely;
 * `value` is cleared before each open so picking the same file twice still
 * fires `change`.
 */

const ACCEPT = [
  ...UPLOAD_LIMITS.documentExtensions,
  ...UPLOAD_LIMITS.documentMimeTypes,
].join(',');

/**
 * How long after the window regains focus to conclude the dialog was
 * dismissed.
 *
 * This is the fallback for browsers without the `cancel` event. It has to be
 * generous: `focus` can arrive *before* `change` on a real selection, and
 * resolving first would throw the file away. The guard below also checks that
 * nothing was actually selected, so a slow `change` cannot lose a race it has
 * already won.
 */
const CANCEL_GRACE_MS = 1200;

let input: HTMLInputElement | null = null;

const ensureInput = (): HTMLInputElement => {
  if (input && input.isConnected) {
    return input;
  }

  input = document.createElement('input');
  input.type = 'file';
  input.accept = ACCEPT;
  // Off-screen rather than display:none — a hidden input is ignored by some
  // browsers when clicked programmatically.
  input.style.position = 'fixed';
  input.style.left = '-9999px';
  input.style.opacity = '0';

  /**
   * Out of the tab order, but **not** `aria-hidden`.
   *
   * It used to carry `aria-hidden="true"`, which was wrong on its own terms:
   * clicking a file input focuses it, so the element holding focus was also
   * the element declared invisible to assistive technology. Chrome refuses
   * that and logs "Blocked aria-hidden on an element because its descendant
   * retained focus."
   *
   * `tabIndex = -1` already keeps it out of keyboard traversal, which is all
   * that was actually wanted — nobody should reach this by tabbing, because
   * the visible button in the UI is the real control. The label is there so
   * that if a screen reader does land on it during the file dialog, it says
   * something meaningful rather than "unlabelled file input".
   */
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
    // Without this, choosing the same file twice in a row fires no `change`.
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

        // The browser focuses a file input when its dialog is opened, and
        // leaves focus there afterwards. Releasing it means no off-screen
        // element holds focus once the picker is done — which is what stops
        // the next navigation tripping the aria-hidden focus rule.
        element.blur();

        resolve(files);
      };

      const onChange = () => finish(toPickedFiles(element.files, remainingSlots));

      // Supported in current Chrome, Firefox and Safari. The focus fallback
      // below covers anything older.
      const onCancel = () => finish([]);

      const onFocus = () => {
        setTimeout(() => {
          // Only conclude "cancelled" if nothing was in fact selected. A
          // `change` that lands during the grace period has already settled
          // this, and the length check catches the rest.
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
