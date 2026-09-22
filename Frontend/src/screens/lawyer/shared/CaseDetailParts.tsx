import React, { useCallback, useMemo, useState } from 'react';
import { Pressable, View } from 'react-native';

import { GenieErrorState, GenieNotice, GenieText } from '../../../components';
import { DocumentViewerModal } from '../../../components/documents';
import { EyeIcon, FileIcon } from '../../../components/icons/ClientIcons';
import { casesApi } from '../../../api/casesApi';
import { toAppError } from '../../../utils/errors';
import { formatFileSize } from '../../../utils/urls';
import type { AppDocument, CaseDocument, PopulatedUser } from '../../../types/domain';
import { colors } from '../../../theme';

export const NOT_SPECIFIED = 'Not specified';

export const DetailSection: React.FC<{
  title: string;
  children: React.ReactNode;
  testID?: string;
}> = ({ title, children, testID }) => (
  <View className="mt-5" testID={testID}>
    <GenieText
      variant="caption"
      tone="gold"
      className="mb-2 font-bold uppercase tracking-widest"
    >
      {title}
    </GenieText>
    <View className="rounded-card border border-border bg-surface p-4">
      {children}
    </View>
  </View>
);

export const DetailRow: React.FC<{
  label: string;
  value?: string | number | null;
  icon?: React.ReactNode;
  testID?: string;
}> = ({ label, value, icon, testID }) => {
  const text = value === null || value === undefined ? '' : String(value).trim();
  return (
    <View className="mb-3 flex-row items-start" testID={testID}>
      {icon ? <View className="mr-2 mt-0.5">{icon}</View> : null}
      <View className="flex-1">
        <GenieText variant="caption" tone="muted">
          {label}
        </GenieText>
        <GenieText
          variant="body-sm"
          tone={text ? 'primary' : 'muted'}
          className="mt-0.5"
        >
          {text || NOT_SPECIFIED}
        </GenieText>
      </View>
    </View>
  );
};

export const clientOf = (
  value: PopulatedUser | string | null | undefined,
): Partial<PopulatedUser> & { _id: string } | null => {
  if (!value) {
    return null;
  }
  return typeof value === 'object' ? value : { _id: value };
};

// Short display form of a record id; the full id is never needed on screen.
export const shortId = (id?: string | null): string =>
  id ? String(id).slice(-8) : '';

const describeFailure = (error: unknown): { title: string; message: string; retry: boolean } => {
  const info = toAppError(error);
  if (info.isNetworkError) {
    return { title: 'Connection problem', message: info.message, retry: true };
  }
  switch (info.status) {
    case 401:
      return { title: 'Session ended', message: 'Please sign in again to continue.', retry: false };
    case 403:
      return {
        title: 'Access restricted',
        message: 'You are not authorized to view this record.',
        retry: false,
      };
    case 404:
      return {
        title: 'Not found',
        message: 'This record does not exist or has been removed.',
        retry: false,
      };
    case 409:
      return { title: 'No longer available', message: info.message, retry: false };
    default:
      return { title: 'Something went wrong', message: info.message, retry: true };
  }
};

export const DetailError: React.FC<{
  error: unknown;
  onRetry: () => void;
}> = ({ error, onRetry }) => {
  const { title, message, retry } = describeFailure(error);
  return (
    <View className="flex-1 justify-center px-4" testID="detail-error">
      <GenieErrorState
        title={title}
        message={message}
        onRetry={retry ? onRetry : undefined}
      />
    </View>
  );
};

const MIME_BY_EXT: Record<string, string> = {
  pdf: 'application/pdf',
  doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  gif: 'image/gif',
  txt: 'text/plain',
};

const fileNameOf = (doc: CaseDocument): string => {
  const fromUrl = String(doc.url || '').split(/[\\/]/).pop() || '';
  return doc.name?.trim() || fromUrl || 'Untitled document';
};

const asViewerDocument = (doc: CaseDocument, index: number): AppDocument => {
  const name = fileNameOf(doc);
  const ext = (/\.([a-z0-9]+)$/i.exec(name)?.[1] ?? '').toLowerCase();
  const size = Number(doc.size);
  return {
    _id: `case-attachment-${index}`,
    clientId: '',
    originalName: name,
    name,
    fileName: name,
    filePath: doc.url,
    mimeType: MIME_BY_EXT[ext] ?? '',
    fileSize: Number.isFinite(size) ? size : 0,
    uploadedAt: '',
    createdAt: '',
    updatedAt: '',
  };
};

export const CaseDocumentsSection: React.FC<{ documents?: CaseDocument[] | null }> = ({
  documents,
}) => {
  const list = (documents ?? []).filter(doc => doc && doc.url);
  const [openIndex, setOpenIndex] = useState<number | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const open = openIndex === null ? null : list[openIndex] ?? null;
  const openUrl = open?.url ?? null;
  const openName = open?.name ?? '';
  const openSize = open?.size ?? '';

  // Stable across refetches: the viewer reloads whenever this object changes.
  const viewerDocument = useMemo(
    () =>
      openUrl !== null && openIndex !== null
        ? asViewerDocument({ url: openUrl, name: openName, size: openSize }, openIndex)
        : null,
    [openIndex, openUrl, openName, openSize],
  );

  const loadBlob = useCallback(
    () =>
      openUrl
        ? casesApi.fetchAttachment(openUrl)
        : Promise.reject(new Error('No document selected.')),
    [openUrl],
  );

  const download = async (doc: AppDocument) => {
    setNotice(null);
    const globalWin = (globalThis as any).window;
    const globalDoc = (globalThis as any).document;
    if (!globalWin?.URL?.createObjectURL || !globalDoc?.createElement) {
      setNotice('Downloading is not available on this device. Use View to read the document.');
      return;
    }
    try {
      const blob = await casesApi.fetchAttachment(doc.filePath);
      const url = globalWin.URL.createObjectURL(blob);
      const anchor = globalDoc.createElement('a');
      anchor.href = url;
      anchor.download = doc.name || 'document';
      globalDoc.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      setTimeout(() => globalWin.URL.revokeObjectURL(url), 1000);
    } catch (error) {
      setNotice(toAppError(error).message);
    }
  };

  return (
    <DetailSection title={`Documents (${list.length})`} testID="case-documents">
      {list.length === 0 ? (
        <GenieText variant="body-sm" tone="muted">
          No documents have been uploaded for this case.
        </GenieText>
      ) : (
        list.map((doc, index) => {
          const size = formatFileSize(doc.size);
          return (
            <View
              key={`${doc.url}-${index}`}
              className={`flex-row items-center gap-3 py-2 ${
                index > 0 ? 'border-t border-border' : ''
              }`}
            >
              <FileIcon size={18} color={colors.gold} />
              <View className="flex-1">
                <GenieText variant="body-sm" numberOfLines={2}>
                  {fileNameOf(doc)}
                </GenieText>
                {size ? (
                  <GenieText variant="caption" tone="muted">
                    {size}
                  </GenieText>
                ) : null}
              </View>
              <Pressable
                testID={`case-document-view-${index}`}
                accessibilityRole="button"
                accessibilityLabel={`View ${fileNameOf(doc)}`}
                onPress={() => {
                  setNotice(null);
                  setOpenIndex(index);
                }}
                className="min-h-touch flex-row items-center gap-1.5 rounded-control border border-border px-3 active:bg-gold-muted"
              >
                <EyeIcon size={16} color={colors.gold} />
                <GenieText variant="label" tone="gold">
                  View
                </GenieText>
              </Pressable>
            </View>
          );
        })
      )}

      {notice ? <GenieNotice tone="warning" message={notice} className="mt-3" /> : null}

      <DocumentViewerModal
        visible={viewerDocument !== null}
        document={viewerDocument}
        onClose={() => setOpenIndex(null)}
        onDownload={doc => void download(doc)}
        loadBlob={loadBlob}
      />
    </DetailSection>
  );
};
