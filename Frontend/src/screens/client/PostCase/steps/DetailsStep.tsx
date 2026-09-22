import React, { useCallback, useState } from 'react';
import { Pressable, ScrollView, TextInput, View } from 'react-native';

import { GenieMicButton, GenieNotice, GenieText } from '../../../../components';
import {
  CourtIcon,
  LocationIcon,
  SparkleIcon,
} from '../../../../components/icons/ClientIcons';
import { aiApi } from '../../../../api/aiApi';
import { voiceRecorder } from '../../../../services/voiceRecorder';
import { toAppError } from '../../../../utils/errors';
import { AiBadge } from '../AiBadge';
import { shortenDescription, type PostCaseState } from '../types';
import { colors } from '../../../../theme';
import { startTrace } from '../../../../utils/perfTrace';

const MAX_DESCRIPTION = 5000;

interface DetailsStepProps {
  state: PostCaseState;
  onChange: (patch: Partial<PostCaseState>) => void;
  onFieldEdited: (field: string) => void;
}

const Label: React.FC<{
  text: string;
  required?: boolean;
  aiFilled?: boolean;
}> = ({ text, required = false, aiFilled = false }) => (
  <View className="mb-2 flex-row items-center gap-2">
    <GenieText variant="body-md" className="font-medium">
      {text}
      {required ? (
        <GenieText variant="body-md" tone="error">
          {' *'}
        </GenieText>
      ) : null}
    </GenieText>
    {aiFilled ? <AiBadge /> : null}
  </View>
);

export const DetailsStep: React.FC<DetailsStepProps> = ({
  state,
  onChange,
  onFieldEdited,
}) => {
  const [isRecording, setIsRecording] = useState(false);
  const [isTranscribing, setIsTranscribing] = useState(false);
  const [voiceError, setVoiceError] = useState<string | null>(null);

  const aiFields = new Set(state.aiFields);

  const edit = useCallback(
    (field: keyof PostCaseState, value: string) => {
      onChange({ [field]: value } as Partial<PostCaseState>);
      onFieldEdited(field);
    },
    [onChange, onFieldEdited],
  );

  const toggleDictation = useCallback(async () => {
    setVoiceError(null);

    if (isTranscribing) {
      return;
    }

    if (isRecording) {
      setIsRecording(false);
      setIsTranscribing(true);
      const trace = startTrace('voice-dictation');
      try {
        const audio = await voiceRecorder.stop();
        trace.mark('recorder-stopped');
        const result = await aiApi.transcribe(audio);
        trace.mark('transcribed');
        trace.end();
        const text = (result.transcript || '').trim();

        if (!text) {
          setVoiceError('Nothing could be heard in that recording.');
          return;
        }

        const existing = state.description.trim();
        const combined = existing ? `${existing} ${text}` : text;
        edit('description', combined.slice(0, MAX_DESCRIPTION));
      } catch (error) {
        trace.end('error');
        setVoiceError(toAppError(error).message);
      } finally {
        setIsTranscribing(false);
      }
      return;
    }

    try {
      const granted = await voiceRecorder.requestPermission();
      if (!granted) {
        setVoiceError('Microphone access is needed to dictate.');
        return;
      }
      await voiceRecorder.start(() => {});
      setIsRecording(true);
    } catch (error) {
      setVoiceError(toAppError(error).message);
    }
  }, [edit, isRecording, isTranscribing, state.description]);

  const titlePlaceholder = state.subcategory
    ? `Leave blank to use "${state.subcategory}"`
    : 'Give your case a short title';

  return (
    <ScrollView
      className="flex-1"
      contentContainerClassName="px-5 pb-6 pt-5"
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      <GenieText variant="heading-lg" className="mb-4">
        Case Details
      </GenieText>

      <Label text="Case Title" aiFilled={aiFields.has('title')} />
      <TextInput
        value={state.title}
        onChangeText={value => edit('title', value)}
        placeholder={titlePlaceholder}
        placeholderTextColor={colors.textMuted}
        className="min-h-control rounded-control border border-border bg-surface px-4 py-3 text-body-lg text-white"
        returnKeyType="next"
        maxLength={200}
      />

      <View className="mt-5">
        <Label
          text="Brief Description of Your Case"
          required
          aiFilled={aiFields.has('description')}
        />

        <View className="rounded-control border border-border bg-surface">
          <TextInput
            value={state.description}
            onChangeText={value => edit('description', value)}
            placeholder="Briefly explain your legal issue..."
            placeholderTextColor={colors.textMuted}
            multiline
            textAlignVertical="top"
            maxLength={MAX_DESCRIPTION}
            className="min-h-[160px] px-4 py-3 pb-14 text-body-lg text-white"
          />

          <GenieMicButton
            onPress={toggleDictation}
            accessibilityLabel={
              isRecording ? 'Stop dictation' : 'Dictate your description'
            }
            isRecording={isRecording}
            isBusy={isTranscribing}
            disabled={isTranscribing || !voiceRecorder.isSupported}
            className="absolute bottom-3 right-3"
          />
        </View>

        <View className="mt-1.5 flex-row items-center justify-between">
          <GenieText variant="caption" tone="muted">
            {isRecording
              ? 'Listening — tap the microphone to finish.'
              : isTranscribing
              ? 'Transcribing your recording…'
              : ''}
          </GenieText>
          <GenieText variant="caption" tone="muted">
            {`${state.description.length}/${MAX_DESCRIPTION}`}
          </GenieText>
        </View>

        {state.aiFullDescription ? (
          <Pressable
            onPress={() => {
              const isShowingFull =
                state.description.trim() === state.aiFullDescription.trim();

              onChange({
                description: isShowingFull
                  ? shortenDescription(state.aiFullDescription)
                  : state.aiFullDescription,
              });
            }}
            accessibilityRole="button"
            className="mt-2 min-h-touch flex-row items-center gap-1.5 active:opacity-70"
          >
            <SparkleIcon size={14} color={colors.gold} />
            <GenieText variant="body-sm" tone="gold">
              {state.description.trim() === state.aiFullDescription.trim()
                ? 'Shorten this again'
                : 'Show the full text from your document'}
            </GenieText>
          </Pressable>
        ) : null}

        {voiceError ? (
          <GenieNotice tone="error" message={voiceError} className="mt-2" />
        ) : null}
      </View>

      <View className="mt-5">
        <Label
          text="City / Location"
          required
          aiFilled={aiFields.has('location')}
        />
        <View className="min-h-control flex-row items-center rounded-control border border-border bg-surface px-4">
          <LocationIcon size={20} color={colors.gold} />
          <TextInput
            value={state.location}
            onChangeText={value => edit('location', value)}
            placeholder="Enter your city or location"
            placeholderTextColor={colors.textMuted}
            className="ml-3 flex-1 py-3 text-body-lg text-white"
            maxLength={120}
          />
        </View>
      </View>

      <View className="mt-5">
        <Label
          text="Preferred Court Location (Optional)"
          aiFilled={aiFields.has('preferredCourt')}
        />
        <View className="min-h-control flex-row items-center rounded-control border border-border bg-surface px-4">
          <CourtIcon size={20} color={colors.gold} />
          <TextInput
            value={state.preferredCourt}
            onChangeText={value => edit('preferredCourt', value)}
            placeholder="Enter your preferred court location"
            placeholderTextColor={colors.textMuted}
            className="ml-3 flex-1 py-3 text-body-lg text-white"
            maxLength={120}
          />
        </View>
      </View>

      {state.aiWarnings.length > 0 ? (
        <GenieNotice
          tone="warning"
          className="mt-5"
          message={state.aiWarnings.join('\n')}
        />
      ) : null}
    </ScrollView>
  );
};
