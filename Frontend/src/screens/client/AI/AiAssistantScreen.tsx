import React, { useCallback, useRef, useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import {
  GenieButton,
  GenieHeader,
  GenieNotice,
  GenieText,
} from '../../../components';
import {
  ChevronRightIcon,
  CloudUploadIcon,
  FileIcon,
  GlobeIcon,
  MicIcon,
  SparkleIcon,
  TrashIcon,
} from '../../../components/icons/ClientIcons';
import {
  UPLOAD_LIMITS,
  aiApi,
  knownTotalBytes,
  maxAiFileBytes,
  maxAiUploadBytes,
  rejectionReasonFor,
  uploadTooLargeReason,
} from '../../../api/aiApi';
import { filePicker } from '../../../services/filePicker';
import { voiceRecorder } from '../../../services/voiceRecorder';
import { toAppError } from '../../../utils/errors';
import { formatFileSize } from '../../../utils/format';
import type { PickedFile } from '../../../types/ai';
import type { ClientStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

const MAX_NOTES = 5000;

const LANGUAGES = [
  { code: '', label: 'Auto' },
  { code: 'en', label: 'English' },
  { code: 'te', label: 'తెలుగు' },
  { code: 'hi', label: 'हिन्दी' },
] as const;

const makeRequestId = (): string => {
  let random = '';
  for (let i = 0; i < 12; i += 1) {
    random += Math.floor(Math.random() * 36).toString(36);
  }
  return `ai-${Date.now().toString(36)}-${random}`;
};

const formatDuration = (ms: number): string => {
  const total = Math.floor(ms / 1000);
  const minutes = Math.floor(total / 60);
  const seconds = total % 60;
  return `${minutes}:${String(seconds).padStart(2, '0')}`;
};

const SectionTitle: React.FC<{
  title: string;
  subtitle?: string;
  required?: boolean;
}> = ({ title, subtitle, required = false }) => (
  <View className="mb-3 mt-6">
    <GenieText variant="heading-md">
      {title}
      {required ? (
        <GenieText variant="heading-md" tone="error">
          {' *'}
        </GenieText>
      ) : null}
    </GenieText>
    {subtitle ? (
      <GenieText variant="body-sm" tone="secondary" className="mt-1">
        {subtitle}
      </GenieText>
    ) : null}
  </View>
);

export const AiAssistantScreen: React.FC<
  ClientStackScreenProps<'AiAssistant'>
> = ({ navigation }) => {
  const [documents, setDocuments] = useState<PickedFile[]>([]);
  const [notes, setNotes] = useState('');

  const [voice, setVoice] = useState<PickedFile | null>(null);
  const [transcript, setTranscript] = useState('');
  const [language, setLanguage] = useState<string>('');
  const [detectedLanguage, setDetectedLanguage] = useState('');

  const [isRecording, setIsRecording] = useState(false);
  const [recordedMs, setRecordedMs] = useState(0);
  const [isTranscribing, setIsTranscribing] = useState(false);

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [uploadFraction, setUploadFraction] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const requestId = useRef(makeRequestId());

  const remainingSlots = UPLOAD_LIMITS.maxDocuments - documents.length;

  const addDocuments = useCallback(async () => {
    setError(null);

    try {
      const picked = await filePicker.pickDocuments(remainingSlots);
      if (picked.length === 0) {
        return;
      }

      const accepted: PickedFile[] = [];
      const rejections: string[] = [];

      for (const file of picked) {
        const reason = rejectionReasonFor(file);
        if (reason) {
          rejections.push(reason);
        } else {
          accepted.push(file);
        }
      }

      const maxTotal = maxAiUploadBytes();
      let runningTotal = knownTotalBytes([...documents, voice]);
      const fitting: PickedFile[] = [];
      for (const file of accepted) {
        const next = runningTotal + (file.size ?? 0);
        if (maxTotal !== null && next > maxTotal) {
          rejections.push(
            `${file.name} was not added: it would take the upload to ${formatFileSize(
              next,
            )}, over the ${formatFileSize(maxTotal)} limit. Please reduce its size first.`,
          );
        } else {
          fitting.push(file);
          runningTotal = next;
        }
      }

      if (fitting.length > 0) {
        setDocuments(current => [...current, ...fitting]);
      }
      if (rejections.length > 0) {
        setError(rejections.join('\n'));
      }
    } catch (pickError) {
      setError(toAppError(pickError).message);
    }
  }, [documents, remainingSlots, voice]);

  const removeDocument = useCallback((index: number) => {
    setDocuments(current => current.filter((_, i) => i !== index));
  }, []);

  const startRecording = useCallback(async () => {
    setError(null);

    try {
      const granted = await voiceRecorder.requestPermission();
      if (!granted) {
        setError(
          'Microphone access was not granted, so a voice note cannot be recorded.',
        );
        return;
      }

      setRecordedMs(0);
      setIsRecording(true);
      await voiceRecorder.start(state => setRecordedMs(state.durationMs));
    } catch (recordError) {
      setIsRecording(false);
      setError(toAppError(recordError).message);
    }
  }, []);

  const stopRecording = useCallback(async () => {
    setIsRecording(false);

    let file: PickedFile;
    try {
      file = await voiceRecorder.stop();
    } catch (stopError) {
      setError(toAppError(stopError).message);
      return;
    }

    setVoice(file);
    setIsTranscribing(true);

    try {
      const result = await aiApi.transcribe(file, language || undefined);
      const text = (result.transcript || '').trim();

      if (!text) {
        setError(
          'Nothing could be heard in that recording. You can record again, or type the detail in the notes below.',
        );
      } else {
        setTranscript(text);
        setDetectedLanguage(result.language || '');
      }
    } catch (transcribeError) {
      setError(
        `${
          toAppError(transcribeError).message
        } Your recording was kept and will still be sent with the analysis.`,
      );
    } finally {
      setIsTranscribing(false);
    }
  }, [language]);

  const discardVoice = useCallback(async () => {
    await voiceRecorder.cancel();
    setVoice(null);
    setTranscript('');
    setDetectedLanguage('');
    setRecordedMs(0);
    setIsRecording(false);
  }, []);

  const submit = useCallback(async () => {
    if (isSubmitting) {
      return;
    }

    if (documents.length === 0) {
      setError(
        'Please attach at least one document. The assistant reads your documents to draft the case.',
      );
      return;
    }

    const tooLarge = uploadTooLargeReason([...documents, voice]);
    if (tooLarge) {
      setError(tooLarge);
      return;
    }

    setError(null);
    setIsSubmitting(true);
    setUploadFraction(0);

    try {
      const accepted = await aiApi.analyze({
        documents,
        voice,
        issueDescription: notes,
        voiceTranscript: transcript,
        voiceLanguage: language || detectedLanguage || undefined,
        requestId: requestId.current,
        onUploadProgress: setUploadFraction,
      });

      navigation.replace('PostCase', { sessionId: accepted.sessionId });
    } catch (submitError) {
      setError(toAppError(submitError).message);
    } finally {
      setIsSubmitting(false);
    }
  }, [
    detectedLanguage,
    documents,
    isSubmitting,
    language,
    navigation,
    notes,
    transcript,
    voice,
  ]);

  const uploadDisabled = isSubmitting || remainingSlots <= 0;

  const maxUploadBytes = maxAiUploadBytes();
  const usedBytes = knownTotalBytes([...documents, voice]);
  const uploadLimitNotice =
    maxUploadBytes === null
      ? null
      : `Before uploading, make sure all your files together (documents plus voice note) are no more than ${formatFileSize(
          maxUploadBytes,
        )}. Please reduce large files first — for example, compress the PDF, scan or photograph pages at a lower resolution, or upload only the pages that matter.`;

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      <GenieHeader
        title="AI Smart Case Assistant"
        onBack={() => navigation.goBack()}
      />

      <KeyboardAvoidingView
        className="flex-1"
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView
          className="flex-1"
          contentContainerClassName="px-5 pb-10"
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <View className="mt-3 flex-row items-center gap-4 rounded-card border border-gold-wash bg-card p-5">
            <SparkleIcon size={30} color={colors.gold} />
            <View className="flex-1">
              <GenieText variant="heading-md">Smart Document Intake</GenieText>
              <GenieText variant="body-sm" tone="secondary" className="mt-1">
                Upload FIRs, Agreements, Notices or Court Orders — add a voice
                note to explain further, if you&apos;d like.
              </GenieText>
            </View>
          </View>

          {error ? (
            <GenieNotice tone="error" message={error} className="mt-4" />
          ) : null}

          <SectionTitle
            title="Upload Supporting Documents"
            required
            subtitle={`Supported formats: PDF, PNG, JPG, WEBP, DOCX, TXT (Multiple allowed) · up to ${
              UPLOAD_LIMITS.maxDocuments
            } files, ${formatFileSize(maxAiFileBytes())} each`}
          />

          {uploadLimitNotice ? (
            <GenieNotice tone="warning" message={uploadLimitNotice} className="mb-3" />
          ) : null}

          {documents.map((file, index) => (
            <View
              key={`${file.name}-${index}`}
              className="mb-2 flex-row items-center rounded-card border border-border bg-card p-3"
            >
              <View className="mr-3 h-10 w-10 items-center justify-center rounded-full bg-gold-muted">
                <FileIcon size={18} color={colors.gold} />
              </View>

              <View className="flex-1">
                <GenieText variant="body-md" numberOfLines={1}>
                  {file.name}
                </GenieText>
                <GenieText variant="caption" tone="muted" className="mt-0.5">
                  {[
                    file.size !== null ? formatFileSize(file.size) : '',
                    'Ready to upload',
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                </GenieText>
              </View>

              {!isSubmitting ? (
                <Pressable
                  onPress={() => removeDocument(index)}
                  accessibilityRole="button"
                  accessibilityLabel={`Remove ${file.name}`}
                  className="min-h-touch min-w-touch items-center justify-center active:opacity-70"
                >
                  <TrashIcon size={18} color={colors.error} />
                </Pressable>
              ) : null}
            </View>
          ))}

          <Pressable
            onPress={addDocuments}
            disabled={uploadDisabled}
            accessibilityRole="button"
            accessibilityLabel="Tap to browse and select documents"
            accessibilityState={{ disabled: uploadDisabled }}
            className={`items-center rounded-card border border-dashed border-gold bg-card px-5 py-8 ${
              uploadDisabled ? 'opacity-50' : 'active:opacity-80'
            }`}
          >
            <CloudUploadIcon size={42} color={colors.gold} />
            <GenieText variant="body-lg" className="mt-3 font-bold">
              {remainingSlots <= 0
                ? 'Maximum of 10 documents attached'
                : documents.length === 0
                ? 'Tap to browse & select documents'
                : 'Add another document'}
            </GenieText>
            <GenieText variant="body-sm" tone="muted" className="mt-1 text-center">
              Select FIR, Agreements, Property Docs, Notices
            </GenieText>
          </Pressable>

          {maxUploadBytes !== null && (documents.length > 0 || voice) ? (
            <GenieText
              variant="caption"
              tone={usedBytes > maxUploadBytes ? 'error' : 'muted'}
              className="mt-2 text-center"
            >
              {`Upload size: ${formatFileSize(usedBytes) || '0 B'} of ${formatFileSize(
                maxUploadBytes,
              )} allowed`}
            </GenieText>
          ) : null}

          <SectionTitle
            title="Add a Voice Note (Optional)"
            subtitle="Explain anything the documents don't cover. Your recording is transcribed when you stop, and you can edit the text before submitting."
          />

          {!voiceRecorder.isSupported ? (
            <GenieText variant="body-sm" tone="muted">
              This browser cannot record audio, so a voice note is unavailable
              here. Written notes below work the same way.
            </GenieText>
          ) : (
            <View className="rounded-card border border-border bg-card p-4">
              <View className="flex-row items-center gap-2">
                <GlobeIcon size={20} color={colors.textSecondary} />
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerClassName="gap-2"
                >
                  {LANGUAGES.map(option => {
                    const active = language === option.code;
                    return (
                      <Pressable
                        key={option.code || 'auto'}
                        onPress={() => setLanguage(option.code)}
                        disabled={isRecording || isTranscribing}
                        accessibilityRole="button"
                        accessibilityState={{ selected: active }}
                        accessibilityLabel={`Transcribe in ${option.label}`}
                        className={`min-h-touch justify-center rounded-pill border px-4 ${
                          active
                            ? 'border-gold bg-gold-muted'
                            : 'border-border active:opacity-80'
                        }`}
                      >
                        <GenieText
                          variant="body-md"
                          tone={active ? 'gold' : 'secondary'}
                          className={active ? 'font-semibold' : ''}
                        >
                          {option.label}
                        </GenieText>
                      </Pressable>
                    );
                  })}
                </ScrollView>
              </View>

              <View className="mt-4 flex-row items-center gap-3">
                <Pressable
                  onPress={isRecording ? stopRecording : startRecording}
                  disabled={isSubmitting || isTranscribing}
                  accessibilityRole="button"
                  accessibilityLabel={
                    isRecording ? 'Stop recording' : 'Tap mic and start speaking'
                  }
                  accessibilityState={{ busy: isTranscribing }}
                  className={`h-14 w-14 items-center justify-center rounded-full ${
                    isRecording ? 'bg-error' : 'bg-gold'
                  } ${isSubmitting || isTranscribing ? 'opacity-50' : 'active:opacity-80'}`}
                >
                  {isTranscribing ? (
                    <ActivityIndicator size="small" color={colors.background} />
                  ) : (
                    <MicIcon size={24} color={colors.background} />
                  )}
                </Pressable>

                <View className="flex-1">
                  <GenieText variant="heading-sm">
                    {isRecording
                      ? `Recording… ${formatDuration(recordedMs)}`
                      : isTranscribing
                      ? 'Transcribing…'
                      : voice
                      ? 'Voice note recorded'
                      : 'Tap mic and start speaking'}
                  </GenieText>
                  <GenieText variant="body-sm" tone="muted" className="mt-0.5">
                    {isRecording
                      ? 'Tap again to stop and transcribe.'
                      : isTranscribing
                      ? 'Reading your recording — this takes a moment.'
                      : voice
                      ? 'Review the transcript below before submitting.'
                      : 'Your recording is transcribed when you stop.'}
                  </GenieText>
                </View>

                {voice && !isRecording && !isTranscribing ? (
                  <Pressable
                    onPress={discardVoice}
                    accessibilityRole="button"
                    accessibilityLabel="Discard voice note"
                    className="min-h-touch min-w-touch items-center justify-center active:opacity-70"
                  >
                    <TrashIcon size={18} color={colors.error} />
                  </Pressable>
                ) : null}
              </View>

              {transcript || (voice && !isTranscribing) ? (
                <View className="mt-4">
                  <View className="mb-2 flex-row items-center justify-between">
                    <GenieText variant="body-sm" tone="gold" className="font-semibold">
                      Transcript
                    </GenieText>
                    {detectedLanguage ? (
                      <GenieText variant="caption" tone="muted">
                        {`Detected: ${
                          LANGUAGES.find(l => l.code === detectedLanguage)
                            ?.label ?? detectedLanguage
                        }`}
                      </GenieText>
                    ) : null}
                  </View>

                  <TextInput
                    value={transcript}
                    onChangeText={setTranscript}
                    placeholder="Your transcript appears here. Edit it if anything was misheard."
                    placeholderTextColor={colors.textMuted}
                    multiline
                    textAlignVertical="top"
                    editable={!isSubmitting}
                    className="min-h-[90px] rounded-control border border-border bg-surface px-4 py-3 text-body-lg text-white"
                    accessibilityLabel="Voice transcript, editable"
                  />
                </View>
              ) : null}
            </View>
          )}

          <SectionTitle title="Additional Written Notes (Optional)" />

          <View className="rounded-card border border-border bg-card p-3">
            <TextInput
              className="min-h-[110px] text-body-lg text-white"
              value={notes}
              onChangeText={text => setNotes(text.slice(0, MAX_NOTES))}
              placeholder="Add any extra details or dates if not mentioned in documents..."
              placeholderTextColor={colors.textMuted}
              multiline
              textAlignVertical="top"
              maxLength={MAX_NOTES}
              editable={!isSubmitting}
              accessibilityLabel="Additional written notes"
            />
            <GenieText variant="caption" tone="muted" className="mt-1 self-end">
              {`${notes.length} / ${MAX_NOTES}`}
            </GenieText>
          </View>

          {isSubmitting ? (
            <View className="mt-4">
              <View className="h-1.5 w-full overflow-hidden rounded-pill bg-surface-alt">
                <View
                  className="h-full rounded-pill bg-gold"
                  style={{ width: `${Math.round(uploadFraction * 100)}%` }}
                />
              </View>
              <GenieText variant="caption" tone="muted" className="mt-1">
                {`Uploading ${Math.round(uploadFraction * 100)}%`}
              </GenieText>
            </View>
          ) : null}

          <View className="mt-6">
            <GenieButton
              label="Analyse & Generate Case with AI"
              loadingLabel="Uploading…"
              loading={isSubmitting}
              disabled={documents.length === 0}
              onPress={submit}
              icon={
                <ChevronRightIcon
                  size={18}
                  color={
                    documents.length === 0 ? colors.textMuted : colors.onGold
                  }
                />
              }
              iconPosition="right"
            />
            <GenieText variant="caption" tone="muted" className="mt-2 text-center">
              Your case details are filled in automatically, and you review
              every field before anything is filed.
            </GenieText>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};
