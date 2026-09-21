import React from 'react';
import { Image, Pressable, ScrollView, View } from 'react-native';

import { GenieButton, GenieNotice, GenieText } from '../../../../components';
import {
  ClockIcon,
  EditIcon,
  FileIcon,
  LocationIcon,
  ScalesIcon,
  SparkleIcon,
  StarIcon,
  VerifiedIcon,
} from '../../../../components/icons/ClientIcons';
import { CheckIcon } from '../../../../components/icons/Icons';
import { formatDate, formatFileSize } from '../../../../utils/format';
import { resolveFileUrl } from '../../../../utils/urls';
import { CheckBadge } from '../AiBadge';
import type { PostCaseStepIndex, PostCaseState } from '../types';
import { colors } from '../../../../theme';

interface ReviewStepProps {
  state: PostCaseState;
  onEditStep: (step: PostCaseStepIndex) => void;
  onViewLawyerProfile: (userId: string, name: string) => void;
  submitError: string | null;
  hasAgreed: boolean;
  onAgreedChange: (agreed: boolean) => void;
  onOpenTerms: () => void;
  onOpenPrivacy: () => void;
}

const Section: React.FC<{
  title: string;
  onEdit?: () => void;
  children: React.ReactNode;
}> = ({ title, onEdit, children }) => (
  <View className="mt-4">
    <View className="mb-2 flex-row items-center justify-between">
      <GenieText
        variant="caption"
        tone="gold"
        className="font-bold uppercase tracking-widest"
      >
        {title}
      </GenieText>

      {onEdit ? (
        <Pressable
          onPress={onEdit}
          accessibilityRole="button"
          accessibilityLabel={`Edit ${title}`}
          className="min-h-touch flex-row items-center gap-1.5 px-1 active:opacity-70"
        >
          <EditIcon size={15} color={colors.gold} />
          <GenieText variant="body-sm" tone="gold">
            Edit
          </GenieText>
        </Pressable>
      ) : null}
    </View>

    <View className="rounded-card border border-border bg-surface px-4 py-2">
      {children}
    </View>
  </View>
);

const Row: React.FC<{
  label: string;
  value?: string | null;
  needsCheck?: boolean;
  last?: boolean;
}> = ({ label, value, needsCheck = false, last = false }) => {
  if (!value) {
    return null;
  }

  return (
    <View className={last ? 'py-3' : 'border-b border-border py-3'}>
      <View className="mb-1 flex-row items-center gap-2">
        <GenieText variant="caption" tone="muted">
          {label}
        </GenieText>
        {needsCheck ? <CheckBadge /> : null}
      </View>
      <GenieText variant="body-md">{value}</GenieText>
    </View>
  );
};

const SelectedLawyerCard: React.FC<{
  state: PostCaseState;
  onViewProfile: () => void;
}> = ({ state, onViewProfile }) => {
  const lawyer = state.selectedLawyer;

  if (!lawyer) {
    return (
      <View className="py-3">
        <GenieText variant="body-md" tone="secondary">
          No lawyer selected.
        </GenieText>
      </View>
    );
  }

  const photo = resolveFileUrl(lawyer.profileImage);

  return (
    <View className="py-3">
      <View className="flex-row">
        <View className="mr-3">
          {photo ? (
            <Image
              source={{ uri: photo }}
              className="h-20 w-16 rounded-control bg-surface-alt"
              resizeMode="cover"
              accessibilityLabel={`${lawyer.fullName}'s photo`}
            />
          ) : (
            <View className="h-20 w-16 items-center justify-center rounded-control bg-surface-alt">
              <ScalesIcon size={24} color={colors.textMuted} />
            </View>
          )}

          {lawyer.onlineStatus ? (
            <View className="mt-1 flex-row items-center gap-1">
              <View className="h-2 w-2 rounded-full bg-success" />
              <GenieText
                variant="caption"
                tone="success"
                className="text-[10px]"
              >
                Online
              </GenieText>
            </View>
          ) : null}
        </View>

        <View className="flex-1">
          <View className="flex-row items-center gap-1.5">
            <GenieText variant="heading-sm" numberOfLines={1} className="flex-1">
              {lawyer.fullName}
            </GenieText>
            {lawyer.verified ? (
              <VerifiedIcon size={15} color={colors.gold} />
            ) : null}
          </View>

          {lawyer.specialization ? (
            <GenieText variant="body-sm" tone="gold" className="mt-0.5">
              {lawyer.specialization}
            </GenieText>
          ) : null}

          {lawyer.location ? (
            <View className="mt-1 flex-row items-center gap-1.5">
              <LocationIcon size={13} color={colors.textMuted} />
              <GenieText
                variant="body-sm"
                tone="secondary"
                numberOfLines={1}
                className="flex-1"
              >
                {lawyer.location}
              </GenieText>
            </View>
          ) : null}

          {lawyer.rating > 0 ? (
            <View className="mt-1 flex-row items-center gap-1.5">
              <StarIcon size={13} color={colors.gold} />
              <GenieText variant="body-sm">{lawyer.rating.toFixed(1)}</GenieText>
              <GenieText variant="body-sm" tone="muted">
                {`(${lawyer.reviewCount} ${
                  lawyer.reviewCount === 1 ? 'Review' : 'Reviews'
                })`}
              </GenieText>
            </View>
          ) : null}

          {lawyer.experience > 0 || lawyer.casesHandled > 0 ? (
            <GenieText variant="body-sm" tone="secondary" className="mt-1">
              {[
                lawyer.experience > 0 ? `${lawyer.experience}+ Years Exp` : '',
                lawyer.casesHandled > 0 ? `${lawyer.casesHandled}+ Cases` : '',
              ]
                .filter(Boolean)
                .join('  ·  ')}
            </GenieText>
          ) : null}

          <GenieText
            variant="body-sm"
            tone="success"
            className="mt-1 font-semibold"
          >
            {`${lawyer.matchPercentage}% Match`}
          </GenieText>

          {lawyer.responseTime ? (
            <View className="mt-1 flex-row items-center gap-1.5">
              <ClockIcon size={13} color={colors.textMuted} />
              <GenieText variant="body-sm" tone="muted" numberOfLines={1}>
                {lawyer.responseTime}
              </GenieText>
            </View>
          ) : null}
        </View>
      </View>

      {lawyer.languages?.length ? (
        <View className="mt-3 flex-row flex-wrap gap-2">
          {lawyer.languages.map(language => (
            <View
              key={language}
              className="rounded-pill border border-border bg-card px-3 py-1"
            >
              <GenieText variant="caption" tone="secondary">
                {language}
              </GenieText>
            </View>
          ))}
        </View>
      ) : null}

      <View className="mt-3">
        <GenieButton
          label="View Full Profile"
          variant="outline"
          size="sm"
          onPress={onViewProfile}
        />
      </View>

      <GenieText variant="caption" tone="muted" className="mt-3">
        They will be notified as soon as you submit, and the case stays awaiting
        their acceptance until they answer.
      </GenieText>
    </View>
  );
};

export const ReviewStep: React.FC<ReviewStepProps> = ({
  state,
  onEditStep,
  onViewLawyerProfile,
  submitError,
  hasAgreed,
  onAgreedChange,
  onOpenTerms,
  onOpenPrivacy,
}) => {
  const check = new Set(state.aiNeedsReview);

  const title =
    state.title.trim() || state.subcategory.trim() || state.category.trim();

  const categoryLine = state.subcategory
    ? `${state.category} - ${state.subcategory}`
    : state.category;

  const totalDocuments = (state.document ? 1 : 0) + state.aiDocuments.length;

  return (
    <ScrollView
      className="flex-1"
      contentContainerClassName="px-5 pb-6 pt-5"
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      <GenieText variant="heading-lg">Review &amp; Submit</GenieText>
      <GenieText variant="body-sm" tone="secondary" className="mt-1">
        Check everything below. You can still edit any part before filing.
      </GenieText>

      {state.aiSessionId ? (
        <View className="mt-4 flex-row items-center gap-2 rounded-card border border-gold-wash bg-gold-muted px-3 py-2.5">
          <SparkleIcon size={16} color={colors.gold} />
          <View className="flex-1">
            <GenieText variant="body-sm" tone="gold" className="font-bold">
              AI extracted
            </GenieText>
            <GenieText variant="caption" tone="secondary" className="mt-0.5">
              These details were read from your documents. Check them before you
              file — anything you change becomes your own wording.
            </GenieText>
          </View>
        </View>
      ) : null}

      {check.size > 0 ? (
        <GenieNotice
          tone="warning"
          className="mt-3"
          message={
            check.size === 1
              ? 'One field was read with low confidence and is marked "Check" below.'
              : `${check.size} fields were read with low confidence and are marked "Check" below.`
          }
        />
      ) : null}

      {state.aiWarnings.length > 0 ? (
        <GenieNotice
          tone="warning"
          className="mt-3"
          message={state.aiWarnings.join('\n')}
        />
      ) : null}

      <Section title="Case" onEdit={() => onEditStep(1)}>
        <Row label="Title" value={title} />
        <Row
          label="Category"
          value={categoryLine}
          needsCheck={check.has('category') || check.has('subType')}
        />
        <Row label="Description" value={state.description} />
        <Row
          label="Location"
          value={state.location}
          needsCheck={check.has('city')}
        />
        <Row label="State" value={state.state} />
        <Row
          label="Preferred Court"
          value={state.preferredCourt}
          needsCheck={check.has('court')}
        />
        <Row
          label="Urgency"
          value={state.urgency}
          needsCheck={check.has('urgency')}
          last
        />
      </Section>

      {state.incidentDate ||
      state.opposingParty ||
      state.firNumber ||
      state.policeStation ||
      state.bailDetails ||
      state.claimAmount ? (
        <Section title="Further detail">
          <Row
            label="Incident date"
            value={formatDate(state.incidentDate)}
            needsCheck={check.has('incidentDate')}
          />
          <Row
            label="Other party"
            value={state.opposingParty}
            needsCheck={check.has('opposingParty')}
          />
          <Row
            label="Claim amount"
            value={
              typeof state.claimAmount === 'number'
                ? String(state.claimAmount)
                : ''
            }
          />
          <Row label="FIR number" value={state.firNumber} />
          <Row label="Police station" value={state.policeStation} />
          <Row label="Bail details" value={state.bailDetails} last />
        </Section>
      ) : null}

      {state.aiSummary ? (
        <Section title="What the assistant understood">
          <View className="py-3">
            <GenieText variant="body-sm" tone="secondary">
              {state.aiSummary}
            </GenieText>
            <GenieText variant="caption" tone="muted" className="mt-2">
              Shown for your reference. It is not filed with the case.
            </GenieText>
          </View>
        </Section>
      ) : null}

      {state.voiceTranscript ? (
        <Section title="Your voice note">
          <View className="py-3">
            <GenieText variant="body-sm" tone="secondary">
              {state.voiceTranscript}
            </GenieText>
            <GenieText variant="caption" tone="muted" className="mt-2">
              Sent with your documents so the assistant could use it. It is
              filed with the case as the voice transcript.
            </GenieText>
          </View>
        </Section>
      ) : null}

      {state.aiParties.length > 0 ? (
        <Section title="Parties named">
          {state.aiParties.map((party, index) => (
            <View
              key={`${party.name}-${index}`}
              className={
                index === state.aiParties.length - 1
                  ? 'py-3'
                  : 'border-b border-border py-3'
              }
            >
              <GenieText variant="body-md">{party.name}</GenieText>
              {party.role ? (
                <GenieText variant="caption" tone="muted" className="mt-0.5">
                  {party.role}
                </GenieText>
              ) : null}
            </View>
          ))}
        </Section>
      ) : null}

      <Section
        title={`Documents (${totalDocuments})`}
        onEdit={() => onEditStep(2)}
      >
        {state.document ? (
          <View className="flex-row items-center gap-3 py-3">
            <FileIcon size={20} color={colors.gold} />
            <View className="flex-1">
              <GenieText variant="body-md" numberOfLines={1}>
                {state.document.name || state.document.originalName}
              </GenieText>
              <GenieText variant="caption" tone="muted">
                {formatFileSize(state.document.fileSize)}
              </GenieText>
            </View>
          </View>
        ) : null}

        {state.aiDocuments.map((document, index) => (
          <View
            key={`${document.originalName}-${index}`}
            className="flex-row items-center gap-3 py-3"
          >
            <FileIcon size={20} color={colors.gold} />
            <View className="flex-1">
              <GenieText variant="body-md" numberOfLines={1}>
                {document.originalName}
              </GenieText>
              <GenieText variant="caption" tone="muted">
                {formatFileSize(document.size)}
              </GenieText>
            </View>
          </View>
        ))}
      </Section>

      <Section title="Your lawyer" onEdit={() => onEditStep(3)}>
        <SelectedLawyerCard
          state={state}
          onViewProfile={() => {
            if (state.selectedLawyer) {
              onViewLawyerProfile(
                state.selectedLawyer.userId,
                state.selectedLawyer.fullName,
              );
            }
          }}
        />
      </Section>

      <Pressable
        onPress={() => onAgreedChange(!hasAgreed)}
        accessibilityRole="checkbox"
        accessibilityState={{ checked: hasAgreed }}
        accessibilityLabel="I agree to the Terms & Conditions and the Privacy Policy"
        className="mt-5 flex-row items-start gap-3 rounded-card border border-border bg-surface p-4 active:opacity-80"
      >
        <View
          className={`mt-0.5 h-6 w-6 items-center justify-center rounded-control border-2 ${
            hasAgreed ? 'border-gold bg-gold' : 'border-border'
          }`}
        >
          {hasAgreed ? <CheckIcon size={15} color={colors.background} /> : null}
        </View>

        <View className="flex-1">
          <GenieText variant="body-sm" tone="secondary">
            I agree to the{' '}
            <GenieText
              variant="body-sm"
              tone="gold"
              className="font-semibold underline"
              onPress={onOpenTerms}
            >
              Terms &amp; Conditions
            </GenieText>{' '}
            and the{' '}
            <GenieText
              variant="body-sm"
              tone="gold"
              className="font-semibold underline"
              onPress={onOpenPrivacy}
            >
              Privacy Policy
            </GenieText>
            , and confirm the details above are accurate.
          </GenieText>
        </View>
      </Pressable>

      {submitError ? (
        <GenieNotice tone="error" className="mt-4" message={submitError} />
      ) : null}
    </ScrollView>
  );
};
