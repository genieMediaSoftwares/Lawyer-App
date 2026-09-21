import React from 'react';
import { Pressable, View } from 'react-native';
import { GenieAvatar, GenieCard, GenieText } from './ui';
import { getCategoryIcon } from './icons/CategoryIcons';
import {
  CalendarIcon,
  ChatIcon,
  ChevronRightIcon,
  ClockIcon,
  LocationIcon,
  StarIcon,
} from './icons/ClientIcons';
import { AlertIcon, CheckIcon } from './icons/Icons';
import {
  PROGRESS_STEPS,
  getAssignedLawyerData,
  getCaseProgressStep,
  getStatusBadgeTheme,
} from '../utils/caseUtils';
import { formatDate } from '../utils/format';
import { getUploadUrl } from '../utils/urls';
import type { LegalCase } from '../types/domain';
import { colors } from '../theme';

export interface GenieCaseCardProps {
  item: LegalCase;
  onPress: (id: string) => void;
  onMessageLawyer?: (lawyerId: string, lawyerName: string) => void;
}

export const GenieCaseCard: React.FC<GenieCaseCardProps> = ({
  item,
  onPress,
  onMessageLawyer,
}) => {
  const { currentStep, isRejected, activeLabel } = getCaseProgressStep(
    item.status,
    item,
  );
  const badgeTheme = getStatusBadgeTheme(item.status);
  const lawyer = getAssignedLawyerData(item);
  const CategoryIcon = getCategoryIcon(item.category);
  const shortId = `#${item._id.slice(-6).toUpperCase()}`;
  const displayLocation =
    item.locationCity ||
    item.locationDistrict ||
    item.location ||
    'Location not specified';

  return (
    <GenieCard
      tone="surface"
      onPress={() => onPress(item._id)}
      accessibilityLabel={`Case ${item.title}`}
      className="mb-4 overflow-hidden rounded-card border border-border bg-[#151515] p-4 shadow-lg"
    >
      <View className="flex-row items-center justify-between pb-2.5">
        <View className="flex-row items-center gap-1.5 rounded-pill border border-gold/30 bg-gold/10 px-2.5 py-1">
          <CategoryIcon size={14} color={colors.gold} />
          <GenieText variant="caption" tone="gold" className="font-semibold text-[11px]">
            {item.category || 'Legal Case'}
          </GenieText>
        </View>

        <View
          className={`flex-row items-center gap-1.5 rounded-pill border px-2.5 py-1 ${badgeTheme.bg} ${badgeTheme.border}`}
        >
          <View className={`h-1.5 w-1.5 rounded-full ${isRejected ? 'bg-red-400' : 'bg-gold'}`} />
          <GenieText variant="caption" className={`font-bold text-[11px] ${badgeTheme.text}`}>
            {item.status}
          </GenieText>
        </View>
      </View>

      <View className="mt-1">
        <GenieText variant="caption" tone="muted" className="font-mono text-[10px] tracking-wider">
          {shortId}
        </GenieText>
        <GenieText variant="heading-sm" className="mt-0.5 font-bold text-white" numberOfLines={2}>
          {item.title}
        </GenieText>
      </View>

      <View className="mt-2 flex-row flex-wrap items-center gap-3">
        <View className="flex-row items-center gap-1">
          <LocationIcon size={13} color={colors.textMuted} />
          <GenieText variant="caption" tone="secondary" className="text-[12px]">
            {displayLocation}
          </GenieText>
        </View>

        <View className="flex-row items-center gap-1">
          <ClockIcon size={13} color={colors.textMuted} />
          <GenieText variant="caption" tone="secondary" className="text-[12px]">
            Created {formatDate(item.createdAt)}
          </GenieText>
        </View>
      </View>

      <View className="my-4 rounded-lg border border-border/60 bg-[#1a1a1a] p-3">
        <View className="mb-2 flex-row items-center justify-between">
          <GenieText variant="caption" tone="muted" className="text-[10px] font-bold uppercase tracking-wider">
            Case Progress Tracker
          </GenieText>
          <GenieText variant="caption" tone={isRejected ? 'error' : 'gold'} className="text-[11px] font-semibold">
            {activeLabel}
          </GenieText>
        </View>

        <View className="flex-row items-center justify-between px-1 pt-1">
          {PROGRESS_STEPS.map((step, idx) => {
            const isCompleted = step.index < currentStep && !isRejected;
            const isCurrent = step.index === currentStep && !isRejected;
            const isStepRejected = isRejected && step.index === 2;

            return (
              <React.Fragment key={step.index}>
                {idx > 0 ? (
                  <View
                    className={`h-0.5 flex-1 ${
                      step.index <= currentStep && !isRejected ? 'bg-gold' : 'bg-border'
                    }`}
                  />
                ) : null}

                <View className="items-center">
                  <View
                    className={`h-6 w-6 items-center justify-center rounded-full border ${
                      isCompleted
                        ? 'border-gold bg-gold'
                        : isCurrent
                        ? 'border-gold bg-gold-muted'
                        : isStepRejected
                        ? 'border-red-500 bg-red-500/20'
                        : 'border-border bg-surface'
                    }`}
                  >
                    {isCompleted ? (
                      <CheckIcon size={12} color={colors.onGold} />
                    ) : isStepRejected ? (
                      <AlertIcon size={12} color={colors.error} />
                    ) : (
                      <GenieText
                        variant="caption"
                        tone={isCurrent ? 'gold' : 'muted'}
                        className="text-[10px] font-bold"
                      >
                        {String(step.index)}
                      </GenieText>
                    )}
                  </View>
                  <GenieText
                    variant="caption"
                    tone={isCurrent ? 'gold' : isCompleted ? 'primary' : 'muted'}
                    className={`mt-1 text-[9px] ${
                      isCurrent || isCompleted ? 'font-bold' : 'font-normal'
                    }`}
                  >
                    {step.title}
                  </GenieText>
                </View>
              </React.Fragment>
            );
          })}
        </View>
      </View>

      {lawyer ? (
        <View className="mb-3.5 flex-row items-center justify-between rounded-control border border-border bg-[#1a1a1a] p-3">
          <View className="flex-row items-center gap-2.5">
            <GenieAvatar
              uri={getUploadUrl(lawyer.profileImage)}
              name={lawyer.fullName}
              size="sm"
              ring
            />
            <View>
              <GenieText variant="body-sm" className="font-bold text-white">
                Adv. {lawyer.fullName}
              </GenieText>
              <GenieText variant="caption" tone="secondary" className="text-[11px]">
                {lawyer.specialization}
              </GenieText>
            </View>
          </View>

          <View className="flex-row items-center gap-1 rounded-pill border border-gold/30 bg-gold/10 px-2 py-0.5">
            <StarIcon size={12} color={colors.gold} />
            <GenieText variant="caption" tone="gold" className="font-bold text-[11px]">
              {lawyer.rating.toFixed(1)}
            </GenieText>
          </View>
        </View>
      ) : null}

      {item.nextHearing ? (
        <View className="mb-3.5 flex-row items-center gap-2 rounded-control border border-gold/30 bg-gold/10 px-3 py-2">
          <CalendarIcon size={14} color={colors.gold} />
          <GenieText variant="caption" tone="gold" className="font-medium text-[12px]">
            Next Hearing: {formatDate(item.nextHearing)}
          </GenieText>
        </View>
      ) : null}

      <View className="flex-row items-center gap-2 border-t border-border pt-3">
        <Pressable
          onPress={() => onPress(item._id)}
          accessibilityRole="button"
          accessibilityLabel="View case details"
          className="h-10 flex-1 flex-row items-center justify-center gap-1.5 rounded-control border border-border bg-surface-alt active:bg-surface-highlight"
        >
          <GenieText variant="button" className="text-[13px] text-white">
            View Case Details
          </GenieText>
          <ChevronRightIcon size={14} color={colors.white} />
        </Pressable>

        {lawyer && onMessageLawyer ? (
          <Pressable
            onPress={() => onMessageLawyer(lawyer.id, lawyer.fullName)}
            accessibilityRole="button"
            accessibilityLabel="Message advocate"
            className="h-10 flex-row items-center justify-center gap-1.5 rounded-control bg-gold px-3.5 active:bg-gold-bright"
          >
            <ChatIcon size={16} color={colors.onGold} />
            <GenieText variant="button" tone="on-gold" className="text-[13px]">
              Message
            </GenieText>
          </Pressable>
        ) : null}
      </View>
    </GenieCard>
  );
};
