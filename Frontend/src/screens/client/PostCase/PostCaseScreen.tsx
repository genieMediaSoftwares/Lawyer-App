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

/**
 * Post Your Case.
 *
 * ── Why the steps are components and not routes ───────────────────────────
 *
 * All five share one state object held here. Nothing unmounts when the client
 * moves between them, so going back to fix a typo and returning cannot lose
 * an answer — which a stack of five screens would have to work to guarantee.
 *
 * ── Where the AI fits ─────────────────────────────────────────────────────
 *
 * Extraction happens inside step 3, and folding its result in can fill steps 1
 * and 2 retroactively. So a client who came here to use the assistant is
 * dropped straight at step 3 (`start: 'ai'`) rather than being made to fill in
 * by hand the very fields the assistant exists to fill.
 *
 * When the analysis finishes, `advanceAfterExtraction` sends them to step 4 if
 * everything needed is now present, and otherwise to the earliest step that is
 * still incomplete. It never skips a gap: a field the model could not read is
 * left empty for the client to fill, never guessed at.
 */

const LAST_STEP: PostCaseStepIndex = 4;

export const PostCaseScreen: React.FC<ClientStackScreenProps<'PostCase'>> = ({
  navigation,
  route,
}) => {
  const insets = useSafeAreaInsets();
  const queryClient = useQueryClient();

  // An analysis handed over by the AI Smart Case Assistant, if the client
  // arrived from there.
  const handoffSessionId = route.params?.sessionId ?? null;
  const startMode = handoffSessionId
    ? 'ai'
    : route.params?.start ?? 'manual';

  // A category tile on Home or All Categories names the area of law. It is
  // resolved against the real taxonomy rather than trusted, so a stale or
  // unknown id simply opens the step unselected instead of seeding a category
  // string the server would reject.
  const presetCategory = route.params?.categoryId
    ? categoryById(route.params.categoryId)
    : undefined;

  const [state, setState] = useState<PostCaseState>(() => ({
    ...initialPostCaseState,
    categoryId: presetCategory?.id ?? '',
    category: presetCategory?.title ?? '',
    // Opening straight into the mode the client picked at the "+" sheet, so
    // step 3 shows that route's panel rather than asking them the same
    // question twice. Both routes stay reachable from inside the step.
    entryMode: startMode === 'ai' ? 'ai' : 'manual',
    // Seeded so the documents step picks the analysis up on its first render
    // and starts polling it, rather than showing an upload prompt for work
    // that is already under way.
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

  /**
   * Whether the client has accepted the terms.
   *
   * Deliberately not part of `PostCaseState`: it is a gate on this screen, not
   * a property of the case, and `POST /cases` has no field for it. Keeping it
   * out of the form state stops it ever being sent as one.
   */
  const [hasAgreed, setHasAgreed] = useState(false);

  // Mirrors `state` so asynchronous work (the extraction hand-off, the
  // submission) reads the current values rather than the ones its closure
  // captured several renders ago.
  const stateRef = useRef(state);
  stateRef.current = state;

  const change = useCallback((patch: Partial<PostCaseState>) => {
    setState(current => ({ ...current, ...patch }));
  }, []);

  /**
   * Drops a field's AI marker once the client edits it.
   *
   * The marker means "still the model's wording", so it has to go the moment
   * that stops being true — otherwise the review step vouches for text the
   * client themselves wrote.
   */
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

  // ── AI hand-off ─────────────────────────────────────────────────────────

  /**
   * Session ids already folded in.
   *
   * This guard lives here, not in the step, because the step unmounts as soon
   * as the flow advances to lawyer selection — a ref inside it resets, and
   * stepping back to Documents would re-apply the extraction over whatever the
   * client had since corrected. This component stays mounted for the whole
   * flow, so the record survives.
   */
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
        // The poll in the step already surfaces its own errors; there is
        // nothing to add here and nothing to advance to.
        return;
      }

      if (!session.extracted) {
        return;
      }

      appliedSessionsRef.current.add(sessionId);

      // Merged against `stateRef`, which always holds the latest state. A
      // `setState` updater could not be used to compute it: React runs the
      // updater during the render that follows, so reading the result back
      // here would read `null` and the step decision below would be wrong.
      const next = applyExtraction(
        stateRef.current,
        session.extracted,
        session.uploadedDocuments ?? [],
        sessionId,
        session.voiceTranscript ?? '',
        session.extractionWarnings ?? [],
      );

      setState(next);

      // Straight on to lawyer selection when the extraction filled everything
      // the earlier steps need; otherwise back to the first gap, so the
      // client completes it instead of the flow guessing.
      const firstGap = ([0, 1, 2] as PostCaseStepIndex[]).find(
        candidate => !isStepComplete(next, candidate),
      );

      goTo(firstGap ?? 3);
    },
    [goTo],
  );

  // ── Submission ──────────────────────────────────────────────────────────

  const submitMutation = useMutation({
    mutationFn: async () => {
      const created = await casesApi.create(toCreatePayload(state));

      // Best-effort: tie the analysis to the case it produced. A failure here
      // does not undo a filed case, so it is swallowed rather than reported
      // as a submission failure.
      if (state.aiSessionId && created?._id) {
        try {
          await aiApi.linkCase(state.aiSessionId, created._id);
        } catch {
          // Intentionally ignored — see above.
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

  // ── Leaving ─────────────────────────────────────────────────────────────

  /**
   * Whether leaving would actually throw work away.
   *
   * Keyed on the **sub-type**, not the category: arriving from a category tile
   * preselects the category before the client has done anything, and treating
   * that as progress would put a "Discard this case?" prompt in front of
   * someone who had only just opened the screen and immediately pressed back.
   * Choosing a sub-type by hand sets both, so real progress is still caught.
   */
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

  /**
   * Android's hardware back follows the same rule as the header's chevron:
   * step by step, and a confirmation before discarding real work.
   *
   * **Native only.** `BackHandler` has no browser equivalent — react-native-web
   * ships a stub that warns "BackHandler is not supported on web and should
   * not be used" the moment a listener is added, and never fires. Registering
   * it there would buy nothing and cost a console warning on every visit to
   * this screen.
   *
   * On web the browser's own Back is React Navigation's to handle: it pops the
   * route through the history integration, exactly as every other screen in
   * this app behaves. The header chevron above still walks the steps.
   */
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

  // ── Render ──────────────────────────────────────────────────────────────

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

        {/* The action bar sits above the system navigation area: the inset is
            a runtime value, so it is the one inline style on this screen. */}
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
