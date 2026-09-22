import React, { useMemo, useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieButton,
  GenieEmptyState,
  GenieErrorState,
  GenieHeader,
  GenieNotice,
  GenieSkeletonList,
  GenieText,
} from '../../../components';
import { FileIcon } from '../../../components/icons/ClientIcons';
import { CheckIcon } from '../../../components/icons/Icons';
import { aiApi } from '../../../api/aiApi';
import { toAppError } from '../../../utils/errors';
import { formatFileSize } from '../../../utils/urls';
import type { ResearchCaseDocument } from '../../../types/lawyer';
import type { LawyerStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

const MAX_SELECTED = 10;

const DocumentRow: React.FC<{
  document: ResearchCaseDocument;
  selected: boolean;
  onToggle: () => void;
}> = ({ document, selected, onToggle }) => (
  <Pressable
    testID={`research-doc-${document.id}`}
    onPress={onToggle}
    disabled={!document.selectable}
    accessibilityRole="checkbox"
    accessibilityState={{ checked: selected, disabled: !document.selectable }}
    accessibilityLabel={`${document.name}${document.selectable ? '' : `, ${document.note}`}`}
    className={`mb-2 flex-row items-center gap-3 rounded-card border p-4 ${
      selected ? 'border-border bg-gold-muted' : 'border-border bg-card'
    } ${document.selectable ? 'active:opacity-80' : 'opacity-60'}`}
  >
    <View
      className={`h-6 w-6 items-center justify-center rounded-control border-2 ${
        selected ? 'border-border bg-gold' : 'border-border'
      }`}
    >
      {selected ? <CheckIcon size={13} color={colors.background} /> : null}
    </View>
    <FileIcon size={20} color={colors.gold} />
    <View className="flex-1">
      <GenieText variant="body-md" numberOfLines={1}>
        {document.name}
      </GenieText>
      <GenieText variant="caption" tone="muted">
        {[document.type, formatFileSize(document.size)].filter(Boolean).join(' · ')}
      </GenieText>
      {document.selectable ? (
        <GenieText variant="caption" tone="success">
          Ready to analyse
        </GenieText>
      ) : (
        <GenieText variant="caption" tone="warning">
          {document.note}
        </GenieText>
      )}
    </View>
  </Pressable>
);

export const ResearchDocumentsScreen: React.FC<
  LawyerStackScreenProps<'ResearchDocuments'>
> = ({ navigation, route }) => {
  const { caseId, caseTitle } = route.params;
  const insets = useSafeAreaInsets();
  const queryClient = useQueryClient();

  const [selected, setSelected] = useState<string[]>([]);
  const [question, setQuestion] = useState('');
  const [jurisdiction, setJurisdiction] = useState('');
  const [error, setError] = useState<string | null>(null);

  const documentsQuery = useQuery({
    queryKey: ['lawyer', 'research', 'documents', caseId],
    queryFn: () => aiApi.getResearchCaseDocuments(caseId),
  });

  const documents = useMemo(
    () => documentsQuery.data?.documents ?? [],
    [documentsQuery.data],
  );
  const selectable = documents.filter(d => d.selectable);
  const info = documentsQuery.data?.case;

  const startMutation = useMutation({
    mutationFn: () =>
      aiApi.startCaseResearch({
        caseId,
        documentIds: selected,
        question: question.trim() || undefined,
        jurisdiction: jurisdiction.trim() || undefined,
      }),
    onSuccess: async started => {
      await queryClient.invalidateQueries({ queryKey: ['lawyer', 'research', 'sessions'] });
      navigation.replace('ResearchSession', {
        sessionId: started.conversationId,
        title: caseTitle,
      });
    },
    onError: startError => setError(toAppError(startError).message),
  });

  const toggle = (id: string) => {
    setError(null);
    setSelected(current => {
      if (current.includes(id)) {
        return current.filter(item => item !== id);
      }
      if (current.length >= MAX_SELECTED) {
        setError(`Select up to ${MAX_SELECTED} documents for one research request.`);
        return current;
      }
      return [...current, id];
    });
  };

  const start = () => {
    if (startMutation.isPending) {
      return;
    }
    setError(null);
    startMutation.mutate();
  };

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      <GenieHeader title="Legal Research" subtitle={caseTitle} onBack={() => navigation.goBack()} />

      <KeyboardAvoidingView
        className="flex-1"
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView
          className="flex-1"
          contentContainerClassName="px-5 pb-6 pt-3"
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <View className="rounded-card border border-border bg-card p-4">
            <GenieText variant="heading-sm" numberOfLines={2}>
              {info?.title ?? caseTitle}
            </GenieText>
            {info ? (
              <GenieText variant="body-sm" tone="gold" className="mt-0.5">
                {[info.category, info.court, info.status].filter(Boolean).join(' · ')}
              </GenieText>
            ) : null}
            <GenieText variant="body-sm" tone="secondary" className="mt-2 leading-5">
              Select documents from this case to provide context for your legal
              research. Only the documents you select are read.
            </GenieText>
          </View>

          <View className="mt-5 flex-row items-center justify-between">
            <GenieText variant="heading-sm">Case documents</GenieText>
            {selectable.length > 0 ? (
              <View className="flex-row gap-4">
                <Pressable
                  onPress={() => setSelected(selectable.slice(0, MAX_SELECTED).map(d => d.id))}
                  accessibilityRole="button"
                  className="min-h-touch justify-center"
                >
                  <GenieText variant="body-sm" tone="gold" className="font-bold">
                    Select all
                  </GenieText>
                </Pressable>
                <Pressable
                  onPress={() => setSelected([])}
                  accessibilityRole="button"
                  className="min-h-touch justify-center"
                >
                  <GenieText variant="body-sm" tone="secondary">
                    Clear
                  </GenieText>
                </Pressable>
              </View>
            ) : null}
          </View>

          <View className="mt-2">
            {documentsQuery.isPending ? (
              <GenieSkeletonList count={3} />
            ) : documentsQuery.isError ? (
              <GenieErrorState
                message={documentsQuery.error.message}
                onRetry={() => documentsQuery.refetch()}
              />
            ) : documents.length === 0 ? (
              <GenieEmptyState
                icon={<FileIcon size={28} color={colors.gold} />}
                title="No documents in this case"
                description="You can still research the matter from your question alone."
              />
            ) : (
              <>
                {selectable.length === 0 ? (
                  <GenieNotice
                    tone="warning"
                    message="None of this case's documents can be read. You can still research from your question."
                    className="mb-2"
                  />
                ) : null}
                {documents.map(document => (
                  <DocumentRow
                    key={document.id}
                    document={document}
                    selected={selected.includes(document.id)}
                    onToggle={() => toggle(document.id)}
                  />
                ))}
              </>
            )}
          </View>

          <GenieText variant="caption" tone="muted" className="mb-2 mt-5 font-bold uppercase tracking-widest">
            Research question (optional)
          </GenieText>
          <View className="rounded-control border border-border bg-card px-4 py-2">
            <TextInput
              value={question}
              onChangeText={setQuestion}
              placeholder="e.g. Is the separation period requirement met?"
              placeholderTextColor={colors.textMuted}
              multiline
              className="min-h-[56px] text-body-md text-white"
              accessibilityLabel="Research question"
            />
          </View>

          <GenieText variant="caption" tone="muted" className="mb-2 mt-4 font-bold uppercase tracking-widest">
            Jurisdiction (optional)
          </GenieText>
          <View className="rounded-control border border-border bg-card px-4 py-2">
            <TextInput
              value={jurisdiction}
              onChangeText={setJurisdiction}
              placeholder="e.g. Telangana High Court, India"
              placeholderTextColor={colors.textMuted}
              className="min-h-[28px] text-body-md text-white"
              accessibilityLabel="Jurisdiction"
            />
          </View>

          {error ? <GenieNotice tone="error" message={error} className="mt-4" /> : null}
        </ScrollView>

        <View
          className="border-t border-border bg-surface px-5 pt-3"
          style={{ paddingBottom: Math.max(insets.bottom, 12) }}
        >
          <GenieText testID="research-selected-count" variant="caption" tone="secondary" className="mb-2 text-center">
            {selected.length === 0
              ? 'No documents selected — research will use your question only'
              : `${selected.length} ${selected.length === 1 ? 'document' : 'documents'} selected`}
          </GenieText>
          <View className="flex-row gap-3">
            <GenieButton
              label="Back"
              variant="outline"
              onPress={() => navigation.goBack()}
              disabled={startMutation.isPending}
              className="flex-1"
            />
            <View className="flex-[2]">
              <GenieButton
                testID="research-start-button"
                label={selected.length > 0 ? 'Analyse Selected Documents' : 'Start Research'}
                loadingLabel="Starting..."
                loading={startMutation.isPending}
                disabled={documentsQuery.isPending}
                onPress={start}
              />
            </View>
          </View>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};
