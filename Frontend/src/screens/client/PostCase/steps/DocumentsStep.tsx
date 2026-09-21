import React, { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, View } from 'react-native';
import { useQuery } from '@tanstack/react-query';

import {
  GenieButton,
  GenieNotice,
  GenieText,
} from '../../../../components';
import { DocumentViewerModal } from '../../../../components/documents';
import {
  ChevronRightIcon,
  FileIcon,
  RefreshIcon,
  SparkleIcon,
  TrashIcon,
  UploadArrowIcon,
} from '../../../../components/icons/ClientIcons';
import { CheckIcon, EyeIcon } from '../../../../components/icons/Icons';
import {
  AI_MAX_FILE_BYTES,
  UPLOAD_LIMITS,
  aiApi,
  rejectionReasonFor,
} from '../../../../api/aiApi';
import { documentsApi } from '../../../../api/documentsApi';
import { prepareAiFiles, stageLabel } from '../../../../services/aiFileOptimizer';
import { filePicker } from '../../../../services/filePicker';
import { toAppError } from '../../../../utils/errors';
import { formatFileSize } from '../../../../utils/format';
import { AiProcessingPanel } from '../AiProcessingPanel';
import type { PickedFile } from '../../../../types/ai';
import type { AppDocument } from '../../../../types/domain';
import type { PostCaseState } from '../types';
import { colors } from '../../../../theme';

const POLL_INTERVAL_MS = 2000;

const makeRequestId = (): string => {
  let random = '';
  for (let i = 0; i < 12; i += 1) {
    random += Math.floor(Math.random() * 36).toString(36);
  }
  return `pc-${Date.now().toString(36)}-${random}`;
};

interface DocumentsStepProps {
  state: PostCaseState;
  onChange: (patch: Partial<PostCaseState>) => void;
  onExtracted: (sessionId: string) => void;
}

const ModeCard: React.FC<{
  title: string;
  description: string;
  icon: React.ReactNode;
  highlighted?: boolean;
  onPress: () => void;
}> = ({ title, description, icon, highlighted = false, onPress }) => (
  <Pressable
    onPress={onPress}
    accessibilityRole="button"
    accessibilityLabel={`${title}. ${description}`}
    className={`mb-3 flex-row items-center rounded-card border p-4 active:opacity-80 ${
      highlighted ? 'border-gold bg-card' : 'border-border bg-card'
    }`}
  >
    <View
      className={`mr-3 h-11 w-11 items-center justify-center rounded-full ${
        highlighted ? 'bg-gold-muted' : 'bg-surface-alt'
      }`}
    >
      {icon}
    </View>

    <View className="mr-1 flex-1">
      <GenieText
        variant="body-lg"
        tone={highlighted ? 'gold' : 'primary'}
        className="font-bold"
      >
        {title}
      </GenieText>
      <GenieText variant="caption" tone="muted" className="mt-0.5">
        {description}
      </GenieText>
    </View>

    <ChevronRightIcon
      size={18}
      color={highlighted ? colors.gold : colors.textSecondary}
    />
  </Pressable>
);

const ActionButton: React.FC<{
  label: string;
  icon: React.ReactNode;
  tone?: 'gold' | 'error';
  disabled?: boolean;
  onPress: () => void;
}> = ({ label, icon, tone = 'gold', disabled = false, onPress }) => (
  <Pressable
    onPress={onPress}
    disabled={disabled}
    accessibilityRole="button"
    accessibilityLabel={label}
    className={`min-h-touch flex-1 flex-row items-center justify-center gap-2 ${
      disabled ? 'opacity-40' : 'active:opacity-70'
    }`}
  >
    {icon}
    <GenieText
      variant="body-md"
      tone={tone === 'error' ? 'error' : 'gold'}
      className="font-medium"
    >
      {label}
    </GenieText>
  </Pressable>
);

export const DocumentsStep: React.FC<DocumentsStepProps> = ({
  state,
  onChange,
  onExtracted,
}) => {
  const [error, setError] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [isViewerOpen, setIsViewerOpen] = useState(false);

  const [uploadFraction, setUploadFraction] = useState(0);
  const [isStartingAnalysis, setIsStartingAnalysis] = useState(false);
  const [preparingLabel, setPreparingLabel] = useState<string | null>(null);

  const requestId = useRef(makeRequestId());

  const sessionId = state.aiSessionId;

  const sessionQuery = useQuery({
    queryKey: ['ai', 'session', sessionId],
    queryFn: () => aiApi.getSession(sessionId as string),
    enabled: Boolean(sessionId),
    refetchInterval: query =>
      query.state.data?.status === 'processing' ? POLL_INTERVAL_MS : false,
    refetchIntervalInBackground: false,
  });

  const session = sessionQuery.data;

  const deliveredRef = useRef<string | null>(null);
  useEffect(() => {
    if (
      session?.status === 'extracted' &&
      sessionId &&
      deliveredRef.current !== sessionId
    ) {
      deliveredRef.current = sessionId;
      onExtracted(sessionId);
    }
  }, [onExtracted, session?.status, sessionId]);

  const uploadAcknowledgement = useCallback(
    async (replacing: AppDocument | null) => {
      if (isUploading) {
        return;
      }

      setError(null);

      let picked: PickedFile[];
      try {
        picked = await filePicker.pickDocuments(1);
      } catch (pickError) {
        setError(toAppError(pickError).message);
        return;
      }

      const file = picked[0];
      if (!file) {
        return;
      }

      const rejection = rejectionReasonFor(file);
      if (rejection) {
        setError(rejection);
        return;
      }

      setIsUploading(true);
      setUploadFraction(0);
      try {
        const form = new FormData();
        if (file.file) {
          (form.append as (n: string, v: Blob, f?: string) => void)(
            'acknowledgement',
            file.file as Blob,
            file.name,
          );
        } else {
          form.append('acknowledgement', {
            uri: file.uri,
            name: file.name,
            type: file.type || 'application/octet-stream',
          } as unknown as Blob);
        }

        const stored = replacing
          ? await documentsApi.replaceDocument(replacing._id, form)
          : await documentsApi.uploadDocument(form);

        onChange({ document: stored, entryMode: 'manual' });
      } catch (uploadError) {
        setError(toAppError(uploadError).message);
      } finally {
        setIsUploading(false);
        setUploadFraction(0);
      }
    },
    [isUploading, onChange],
  );

  const deleteAcknowledgement = useCallback(async () => {
    const current = state.document;
    if (!current) {
      return;
    }

    onChange({ document: null });
    try {
      await documentsApi.deleteDocument(current._id);
    } catch (deleteError) {
      setError(toAppError(deleteError).message);
    }
  }, [onChange, state.document]);

  const startAnalysis = useCallback(async () => {
    if (isStartingAnalysis) {
      return;
    }

    setError(null);

    let picked: PickedFile[];
    try {
      picked = await filePicker.pickDocuments(UPLOAD_LIMITS.maxDocuments);
    } catch (pickError) {
      setError(toAppError(pickError).message);
      return;
    }

    if (picked.length === 0) {
      return;
    }

    setIsStartingAnalysis(true);
    setUploadFraction(0);

    let accepted: PickedFile[];
    let rejections: string[];
    try {
      ({ ready: accepted, rejections } = await prepareAiFiles(picked, (file, stage) =>
        setPreparingLabel(`${file.name}: ${stageLabel(stage)}`),
      ));
    } finally {
      setPreparingLabel(null);
    }

    if (accepted.length === 0) {
      setIsStartingAnalysis(false);
      setError(rejections.join('\n'));
      return;
    }

    try {
      const accepted202 = await aiApi.analyze({
        documents: accepted,
        issueDescription: state.description,
        requestId: requestId.current,
        onUploadProgress: setUploadFraction,
      });

      onChange({ aiSessionId: accepted202.sessionId, entryMode: 'ai' });
      if (rejections.length > 0) {
        setError(rejections.join('\n'));
      }
    } catch (analyzeError) {
      setError(toAppError(analyzeError).message);
    } finally {
      setIsStartingAnalysis(false);
    }
  }, [isStartingAnalysis, onChange, state.description]);

  const abandonAnalysis = useCallback(() => {
    deliveredRef.current = null;
    requestId.current = makeRequestId();
    onChange({ aiSessionId: null, aiDocuments: [], entryMode: null });
  }, [onChange]);

  const isAnalysisPending =
    Boolean(sessionId) &&
    state.aiDocuments.length === 0 &&
    session?.status !== 'failed' &&
    !sessionQuery.isError;

  if (isAnalysisPending) {
    return (
      <AiProcessingPanel
        percent={session?.progress?.percent ?? 0}
        message={session?.progress?.message || 'Preparing your documents…'}
        current={session?.progress?.current}
        total={session?.progress?.total}
        stage={
          session?.status === 'extracted'
            ? 'completed'
            : session?.progress?.stage
        }
      />
    );
  }

  if (isStartingAnalysis) {
    return (
      <AiProcessingPanel
        percent={preparingLabel ? 0 : Math.round(uploadFraction * 100)}
        message={preparingLabel ?? 'Uploading your documents…'}
        current={null}
        total={null}
        uploading
      />
    );
  }

  if (sessionId && session?.status === 'failed') {
    return (
      <View className="flex-1 items-center justify-center px-6">
        <View className="h-16 w-16 items-center justify-center rounded-full bg-error-surface">
          <SparkleIcon size={28} color={colors.error} />
        </View>
        <GenieText variant="heading-sm" className="mt-4 text-center">
          Analysis failed
        </GenieText>
        <GenieText variant="body-md" tone="secondary" className="mt-2 text-center">
          {session.failureReason ||
            'The analysis could not be completed. Please try again.'}
        </GenieText>
        <View className="mt-6 w-full gap-3">
          <GenieButton label="Try Again" onPress={abandonAnalysis} />
          <GenieButton
            label="Enter Details Manually"
            variant="outline"
            onPress={() => {
              abandonAnalysis();
              onChange({ entryMode: 'manual' });
            }}
          />
        </View>
      </View>
    );
  }

  return (
    <ScrollView
      className="flex-1"
      contentContainerClassName="px-5 pb-6 pt-5"
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      {state.entryMode === null ? (
        <>
          <GenieText variant="heading-lg">Add Your Documents</GenieText>
          <GenieText variant="body-sm" tone="secondary" className="mb-4 mt-1">
            Choose how you would like to provide them.
          </GenieText>

          <ModeCard
            title="Create Case with AI"
            description="Upload your documents and let the assistant read them and fill in your case."
            icon={<SparkleIcon size={22} color={colors.gold} />}
            highlighted
            onPress={startAnalysis}
          />

          <ModeCard
            title="Upload Manually"
            description="Attach one acknowledgement or supporting document yourself."
            icon={<FileIcon size={22} color={colors.textSecondary} />}
            onPress={() => onChange({ entryMode: 'manual' })}
          />
        </>
      ) : state.entryMode === 'ai' && state.aiDocuments.length > 0 ? (
        <>
          <GenieText variant="heading-lg">Documents Read</GenieText>
          <GenieText variant="body-sm" tone="secondary" className="mb-4 mt-1">
            The assistant read these and filled in your case details. You can
            still edit every field before you submit.
          </GenieText>

          {state.aiDocuments.map((document, index) => (
            <View
              key={`${document.originalName}-${index}`}
              className="mb-3 flex-row items-center rounded-card border border-gold bg-card p-4"
            >
              <View className="mr-3 h-11 w-11 items-center justify-center rounded-full bg-gold-muted">
                <FileIcon size={20} color={colors.gold} />
              </View>
              <View className="flex-1">
                <GenieText variant="body-md" numberOfLines={1}>
                  {document.originalName}
                </GenieText>
                <GenieText variant="caption" tone="muted" className="mt-0.5">
                  {formatFileSize(document.size)}
                  {document.ocrQuality && document.ocrQuality !== 'Pending'
                    ? ` · Readability: ${document.ocrQuality}`
                    : ''}
                </GenieText>
              </View>
              <CheckIcon size={18} color={colors.success} />
            </View>
          ))}

          <Pressable
            onPress={abandonAnalysis}
            accessibilityRole="button"
            className="mt-2 min-h-touch items-center justify-center active:opacity-70"
          >
            <GenieText variant="body-sm" tone="secondary">
              Start over with different documents
            </GenieText>
          </Pressable>
        </>
      ) : state.entryMode === 'ai' ? (
        <>
          <GenieText variant="heading-lg">Create Case with AI</GenieText>
          <GenieText variant="body-sm" tone="secondary" className="mb-4 mt-1">
            Upload the documents for your matter. The assistant reads them and
            fills in your case for you to review — it never invents a detail
            that is not in them.
          </GenieText>

          <Pressable
            onPress={startAnalysis}
            accessibilityRole="button"
            accessibilityLabel="Choose documents for the assistant to read"
            className="items-center justify-center rounded-card border border-dashed border-gold bg-card px-5 py-10 active:opacity-80"
          >
            <View className="h-14 w-14 items-center justify-center rounded-full bg-gold-muted">
              <SparkleIcon size={26} color={colors.gold} />
            </View>
            <GenieText variant="body-lg" className="mt-3 font-semibold">
              Choose documents
            </GenieText>
            <GenieText variant="caption" tone="muted" className="mt-1 text-center">
              {`Up to ${UPLOAD_LIMITS.maxDocuments} files · ${UPLOAD_LIMITS.documentExtensions.join(
                ' · ',
              )} · ${formatFileSize(
                AI_MAX_FILE_BYTES,
              )} each (larger images and PDFs are optimized automatically)`}
            </GenieText>
          </Pressable>

          <Pressable
            onPress={() => onChange({ entryMode: 'manual' })}
            accessibilityRole="button"
            className="mt-4 min-h-touch items-center justify-center active:opacity-70"
          >
            <GenieText variant="body-sm" tone="secondary">
              Or upload one document and fill the form yourself
            </GenieText>
          </Pressable>
        </>
      ) : (
        <>
          <View className="flex-row items-center gap-2">
            <GenieText variant="heading-lg">Upload Acknowledgement</GenieText>
            <GenieText variant="heading-lg" tone="error">
              *
            </GenieText>
          </View>
          <GenieText variant="body-sm" tone="secondary" className="mb-4 mt-1">
            Upload one acknowledgement or supporting document related to your
            legal issue.
          </GenieText>

          {state.document ? (
            <View className="rounded-card border border-gold bg-card p-4">
              <View className="flex-row items-center">
                <View className="mr-3 h-14 w-14 items-center justify-center rounded-full bg-error-surface">
                  <FileIcon size={24} color={colors.error} />
                </View>

                <View className="flex-1">
                  <GenieText variant="body-lg" numberOfLines={2}>
                    {state.document.name || state.document.originalName}
                  </GenieText>
                  <GenieText variant="body-sm" tone="muted" className="mt-0.5">
                    {formatFileSize(state.document.fileSize)}
                  </GenieText>
                  <View className="mt-1 flex-row items-center gap-1.5">
                    <CheckIcon size={14} color={colors.success} />
                    <GenieText variant="body-sm" tone="success">
                      Uploaded Successfully
                    </GenieText>
                  </View>
                </View>
              </View>

              <View className="my-3 h-px bg-border" />

              <View className="flex-row">
                <ActionButton
                  label="View"
                  icon={<EyeIcon size={18} color={colors.gold} />}
                  onPress={() => setIsViewerOpen(true)}
                />
                <ActionButton
                  label="Replace"
                  icon={<RefreshIcon size={18} color={colors.gold} />}
                  disabled={isUploading}
                  onPress={() => {
                    void uploadAcknowledgement(state.document);
                  }}
                />
                <ActionButton
                  label="Delete"
                  tone="error"
                  icon={<TrashIcon size={18} color={colors.error} />}
                  disabled={isUploading}
                  onPress={() => {
                    void deleteAcknowledgement();
                  }}
                />
              </View>
            </View>
          ) : (
            <Pressable
              onPress={() => {
                void uploadAcknowledgement(null);
              }}
              disabled={isUploading}
              accessibilityRole="button"
              accessibilityLabel="Choose a document to upload"
              accessibilityState={{ busy: isUploading }}
              className={`items-center justify-center rounded-card border border-dashed border-border bg-card px-5 py-10 ${
                isUploading ? 'opacity-60' : 'active:opacity-80'
              }`}
            >
              {isUploading ? (
                <>
                  <ActivityIndicator size="large" color={colors.gold} />
                  <GenieText variant="body-md" tone="secondary" className="mt-3">
                    {uploadFraction > 0
                      ? `Uploading… ${Math.round(uploadFraction * 100)}%`
                      : 'Uploading…'}
                  </GenieText>
                </>
              ) : (
                <>
                  <View className="h-14 w-14 items-center justify-center rounded-full bg-gold-muted">
                    <UploadArrowIcon size={24} color={colors.gold} />
                  </View>
                  <GenieText variant="body-lg" className="mt-3 font-semibold">
                    Choose a file
                  </GenieText>
                  <GenieText
                    variant="caption"
                    tone="muted"
                    className="mt-1 text-center"
                  >
                    {UPLOAD_LIMITS.documentExtensions.join(' · ')} — up to 10 MB
                  </GenieText>
                </>
              )}
            </Pressable>
          )}

          <Pressable
            onPress={startAnalysis}
            accessibilityRole="button"
            className="mt-4 flex-row items-center justify-center gap-2 rounded-card border border-gold-wash bg-card p-3 active:opacity-80"
          >
            <SparkleIcon size={18} color={colors.gold} />
            <GenieText variant="body-sm" tone="gold" className="font-semibold">
              Or let AI read your documents instead
            </GenieText>
          </Pressable>
        </>
      )}

      {error ? (
        <GenieNotice tone="error" message={error} className="mt-4" />
      ) : null}

      {sessionQuery.isError && sessionId ? (
        <GenieNotice
          tone="error"
          className="mt-4"
          message={sessionQuery.error.message}
        />
      ) : null}

      <DocumentViewerModal
        visible={isViewerOpen}
        document={state.document}
        onClose={() => setIsViewerOpen(false)}
        onDownload={() => setIsViewerOpen(false)}
      />
    </ScrollView>
  );
};
