import React from 'react';
import { ScrollView, View } from 'react-native';

import { GenieText } from './ui';
import { ChevronRightIcon, CloudUploadIcon, EditIcon, ScalesIcon } from './icons/ClientIcons';
import { CheckCircleIcon, UsersIcon } from './icons/LawyerIcons';
import type { IconProps } from './icons/Icons';
import { colors } from '../theme';

export interface HowItWorksStep {
  id: string;
  title: string;
  description: string;
  Icon: React.FC<IconProps>;
}

// Static instructions for posting a case; not backend data.
export const HOW_IT_WORKS_STEPS: readonly HowItWorksStep[] = [
  {
    id: 'select-issue',
    title: 'Select Issue',
    description: 'Choose your legal issue category.',
    Icon: ScalesIcon,
  },
  {
    id: 'case-details',
    title: 'Case Details',
    description:
      'Add your issue description, location, court preference and urgency.',
    Icon: EditIcon,
  },
  {
    id: 'upload-document',
    title: 'Upload Document',
    description: 'Upload your acknowledgement or supporting document.',
    Icon: CloudUploadIcon,
  },
  {
    id: 'recommended-lawyer',
    title: 'Recommended Lawyer',
    description: 'AI recommends lawyers based on your issue type and location.',
    Icon: UsersIcon,
  },
  {
    id: 'review',
    title: 'Review',
    description: 'Verify all details and submit your case.',
    Icon: CheckCircleIcon,
  },
];

export const HowItWorksCarousel: React.FC<{
  steps?: readonly HowItWorksStep[];
  bleed?: number;
}> = ({ steps = HOW_IT_WORKS_STEPS, bleed = 16 }) => {
  return (
    <View testID="how-it-works" style={{ marginHorizontal: -bleed }}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={{
          paddingHorizontal: bleed,
          paddingVertical: 12,
          flexDirection: 'row',
          alignItems: 'flex-start',
        }}
      >
        {steps.map((step, index) => {
          const { Icon } = step;
          const isLast = index === steps.length - 1;

          return (
            <React.Fragment key={step.id}>
              {/* Step Item */}
              <View
                testID={`how-it-works-slide-${index}`}
                accessible
                accessibilityLabel={`Step ${index + 1} of ${steps.length}: ${step.title}. ${step.description}`}
                style={{ width: 104 }}
                className="items-center"
              >
                {/* Step Circle & Badge */}
                <View className="relative items-center justify-center">
                  <View
                    testID={`how-it-works-circle-${index}`}
                    className="h-12 w-12 items-center justify-center rounded-full bg-surface-secondary"
                  >
                    <Icon size={22} color={colors.gold} />
                  </View>
                  <View
                    testID={`how-it-works-badge-${index}`}
                    className="absolute -right-1 -top-1 h-5 w-5 items-center justify-center rounded-full border-2 border-background bg-gold"
                  >
                    <GenieText
                      variant="caption"
                      tone="on-gold"
                      className="text-small-label font-bold"
                    >
                      {String(index + 1)}
                    </GenieText>
                  </View>
                </View>

                {/* Step Title */}
                <GenieText
                  variant="caption"
                  className="mt-2.5 text-center font-semibold"
                  numberOfLines={2}
                >
                  {step.title}
                </GenieText>

                {/* Step Description */}
                <GenieText
                  variant="caption"
                  tone="muted"
                  className="mt-1 text-center text-small-label leading-tight"
                  numberOfLines={3}
                >
                  {step.description}
                </GenieText>
              </View>

              {/* Small light arrow connecting adjacent steps */}
              {!isLast && (
                <View
                  pointerEvents="none"
                  importantForAccessibility="no-hide-descendants"
                  className="items-center justify-center px-1"
                  style={{ marginTop: 21 }}
                >
                  <ChevronRightIcon size={14} color={colors.textMuted} />
                </View>
              )}
            </React.Fragment>
          );
        })}
      </ScrollView>
    </View>
  );
};
