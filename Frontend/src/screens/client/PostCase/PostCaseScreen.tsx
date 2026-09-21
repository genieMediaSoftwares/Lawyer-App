import React, { useCallback, useRef, useState } from 'react';
import { BackHandler, KeyboardAvoidingView, Platform, View } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useFocusEffect } from '@react-navigation/native';
import { useMutation, useQueryClient } from '@tanstack/react-query';

import { GenieButton, GenieHeader, GenieModal, GenieText } from '../../../components';
import { aiApi } from '../../../api/aiApi';
import { casesApi } from '../../../api/casesApi';
import { categoryById } from '../../../constants/categories';
import { toAppError } from '../../../utils/errors';
import { isWeb } from '../../../utils/platform';
import { PostCaseStepper } from './PostCaseStepper';
import { CategoryStep } from './steps/CategoryStep';
import { DetailsStep } from './steps/DetailsStep';
import { DocumentsStep } from './steps/DocumentsStep';
import { LawyersStep } from './steps/LawyersStep';
import { ReviewStep } from './steps/ReviewStep';
import {
  applyExtraction,
  initialPostCaseState,
  isStepComplete,
  toCreatePayload,
  type PostCaseState,
  type PostCaseStepIndex,
} from './types';
import type { ClientStackScreenProps } from '../../../types/navigation';

const LAST_STEP: PostCaseStepIndex = 4;

export const PostCaseScreen: React.FC<ClientStackScreenProps<'PostCase'>> = ({
  navigation,
  route,
}) => {
  const insets = useSafeAreaInsets();
  const queryClient = useQueryClient();

  const handoffSessionId = route.params?.sessionId ?? null;
  const startMode = handoffSessionId
    ? 'ai'
    : route.params?.start ?? 'manual';

  const presetCategory = route.params?.categoryId
    ? categoryById(route.params.categoryId)
    : undefined;

  const [state, setState] = useState<PostCaseState>(() => ({
    ...initialPostCaseState,
    categoryId: presetCategory?.id ?? '',
    category: presetCategory?.title ?? '',
    entryMode: startMode === 'ai' ? 'ai' : 'manual',
    aiSessionId: handoffSessionId,
  }));

  const [step, setStep] = useState<PostCaseStepIndex>(
    startMode === 'ai' ? 2 : 0,
  );
  const [furthest, setFurthest] = useState<PostCaseStepIndex>(
    startMode === 'ai' ? 2 : 0,
  );
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [isExitPromptOpen, setIsExitPromptOpen] = useState(false);

  const [hasAgreed, setHasAgreed] = useState(false);

  const stateRef = useRef(state);
  stateRef.current = state;

  const change = useCallback((patch: Partial<PostCaseState>) => {
    setState(current => ({ ...current, ...patch }));
  }, []);

  const markEdited = useCallback((field: string) => {
    setState(current =>
      current.aiFields.includes(field)
        ? {
            ...current,
            aiFields: current.aiFields.filter(f => f !== field),
            aiNeedsReview: current.aiNeedsReview.filter(f => f !== field),
          }
        : current,
    );
  }, []);

  const goTo = useCallback((next: PostCaseStepIndex) => {
    setStep(next);
    setFurthest(current => (next > current ? next : current));
  }, []);

  const appliedSessionsRef = useRef<Set<string>>(new Set());

  const advanceAfterExtraction = useCallback(
    async (sessionId: string) => {
      if (appliedSessionsRef.current.has(sessionId)) {
        return;
      }

      let session;
      try {
        session = await aiApi.getSession(sessionId);
      } catch {
        return;
      }

      if (!session.extracted) {
        return;
      }

      appliedSessionsRef.current.add(sessionId);

      const next = applyExtraction(
        stateRef.current,
        session.extracted,
        session.uploadedDocuments ?? [],
        sessionId,
        session.voiceTranscript ?? '',
        session.extractionWarnings ?? [],
      );

      setState(next);

      const firstGap = ([0, 1, 2] as PostCaseStepIndex[]).find(
        candidate => !isStepComplete(next, candidate),
      );

      goTo(firstGap ?? 3);
    },
    [goTo],
  );

  const submitMutation = useMutation({
    mutationFn: async () => {
      const created = await casesApi.create(toCreatePayload(state));

      if (state.aiSessionId && created?._id) {
        try {
          await aiApi.linkCase(state.aiSessionId, created._id);
        } catch {
        }
      }

      return created;
    },
    onSuccess: async created => {
      await queryClient.invalidateQueries({ queryKey: ['cases'] });
      await queryClient.invalidateQueries({ queryKey: ['notifications'] });

      navigation.replace('CaseDetails', {
        caseId: created._id,
        title: created.title,
      });
    },
    onError: error => {
      setSubmitError(toAppError(error).message);
    },
  });

  const hasProgress =
    Boolean(state.subcategory) ||
    Boolean(state.description.trim()) ||
    Boolean(state.document) ||
    Boolean(state.aiSessionId);

  const attemptExit = useCallback(() => {
    if (submitMutation.isPending) {
      return true;
    }
    if (hasProgress) {
      setIsExitPromptOpen(true);
      return true;
    }
    navigation.goBack();
    return true;
  }, [hasProgress, navigation, submitMutation.isPending]);

  const back = useCallback(() => {
    if (step === 0) {
      attemptExit();
      return;
    }
    setStep(current => (current - 1) as PostCaseStepIndex);
  }, [attemptExit, step]);

  const backRef = useRef(back);
  backRef.current = back;

  useFocusEffect(
    useCallback(() => {
      if (isWeb) {
        return undefined;
      }

      const subscription = BackHandler.addEventListener(
        'hardwareBackPress',
        () => {
          backRef.current();
          return true;
        },
      );
      return () => subscription.remove();
    }, []),
  );

  const canContinue = isStepComplete(state, step);

  const nextHint = (): string => {
    switch (step) {
      case 0:
        return state.category
          ? 'Choose a sub-type to continue'
          : 'Select a category to continue';
      case 1:
        return 'Add a description and location';
      case 2:
        return 'Add a document to continue';
      case 3:
        return 'Select a lawyer to continue';
      default:
        return '';
    }
  };

  const renderStep = () => {
    switch (step) {
      case 0:
        return <CategoryStep state={state} onChange={change} />;
      case 1:
        return (
          <DetailsStep
            state={state}
            onChange={change}
            onFieldEdited={markEdited}
          />
        );
      case 2:
        return (
          <DocumentsStep
            state={state}
            onChange={change}
            onExtracted={sessionId => {
              void advanceAfterExtraction(sessionId);
            }}
          />
        );
      case 3:
        return (
          <LawyersStep
            state={state}
            onChange={change}
            onViewProfile={(userId, name) =>
              navigation.navigate('AdvocateProfile', { userId, name })
            }
          />
        );
      case 4:
        return (
          <ReviewStep
            state={state}
            onEditStep={goTo}
            onViewLawyerProfile={(userId, name) =>
              navigation.navigate('AdvocateProfile', { userId, name })
            }
            submitError={submitError}
            hasAgreed={hasAgreed}
            onAgreedChange={setHasAgreed}
            onOpenTerms={() => navigation.navigate('TermsConditions')}
            onOpenPrivacy={() => navigation.navigate('PrivacyPolicy')}
          />
        );
      default:
        return null;
    }
  };

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      <GenieHeader title="Post Your Case" onBack={back} />

      <PostCaseStepper currentIndex={step} furthestIndex={furthest} />

      <KeyboardAvoidingView
        className="flex-1"
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 8 : 0}
      >
        {renderStep()}

        <View
          className="border-t border-border bg-surface px-5 pt-3"
          style={{ paddingBottom: Math.max(insets.bottom, 12) }}
        >
          <View className="flex-row gap-3">
            {step > 0 ? (
              <GenieButton
                label="Back"
                variant="outline"
                onPress={back}
                disabled={submitMutation.isPending}
                className="flex-1"
              />
            ) : null}

            {step === LAST_STEP ? (
              <View className="flex-1">
                <GenieButton
                  label="Submit Case"
                  loading={submitMutation.isPending}
                  disabled={!hasAgreed}
                  onPress={() => {
                    setSubmitError(null);
                    submitMutation.mutate();
                  }}
                />
                {!hasAgreed ? (
                  <GenieText
                    variant="caption"
                    tone="muted"
                    className="mt-1 text-center"
                  >
                    Accept the terms above to submit
                  </GenieText>
                ) : null}
              </View>
            ) : (
              <View className="flex-1">
                <GenieButton
                  label="Next"
                  disabled={!canContinue}
                  onPress={() => goTo((step + 1) as PostCaseStepIndex)}
                />
                {!canContinue ? (
                  <GenieText
                    variant="caption"
                    tone="muted"
                    className="mt-1 text-center"
                  >
                    {nextHint()}
                  </GenieText>
                ) : null}
              </View>
            )}
          </View>
        </View>
      </KeyboardAvoidingView>

      <GenieModal
        visible={isExitPromptOpen}
        onClose={() => setIsExitPromptOpen(false)}
        title="Discard this case?"
      >
        <GenieText variant="body-md" tone="secondary">
          Everything you have entered so far will be lost. Any document you
          already uploaded stays in My Documents.
        </GenieText>

        <View className="mt-5 flex-row gap-3">
          <GenieButton
            label="Keep Editing"
            variant="outline"
            onPress={() => setIsExitPromptOpen(false)}
            className="flex-1"
          />
          <GenieButton
            label="Discard"
            variant="danger"
            onPress={() => {
              setIsExitPromptOpen(false);
              navigation.goBack();
            }}
            className="flex-1"
          />
        </View>
      </GenieModal>
    </SafeAreaView>
  );
};
