import React from 'react';
import { View } from 'react-native';

import { GenieText } from '../../../components';
import { CheckIcon } from '../../../components/icons/Icons';
import { POST_CASE_STEPS } from './types';
import { colors } from '../../../theme';

/**
 * The five-step header.
 *
 * Distinct from `GenieProgressStepper`, which draws small dots for a case's
 * lifecycle. This one numbers its steps and puts the connectors between the
 * circles rather than through them, because the step number is the thing the
 * client is asked to keep track of.
 *
 * Each column is `flex-1` so the circles stay evenly spaced whatever the
 * labels say, and the connectors are drawn as siblings inside the column
 * rather than as one line behind everything — the same reason the dot stepper
 * is built that way.
 */

interface PostCaseStepperProps {
  currentIndex: number;
  /** The highest step reached, so completed circles read as done. */
  furthestIndex: number;
}

export const PostCaseStepper: React.FC<PostCaseStepperProps> = ({
  currentIndex,
  furthestIndex,
}) => (
  <View
    className="border-b border-border bg-surface px-3 pb-3 pt-4"
    accessibilityLabel={`Step ${currentIndex + 1} of ${
      POST_CASE_STEPS.length
    }: ${POST_CASE_STEPS[currentIndex] ?? ''}`}
  >
    <View className="flex-row">
      {POST_CASE_STEPS.map((label, index) => {
        const isCurrent = index === currentIndex;
        const isDone = index < currentIndex || index <= furthestIndex;
        const isFilled = isCurrent || index < currentIndex;
        const isFirst = index === 0;
        const isLast = index === POST_CASE_STEPS.length - 1;

        return (
          <View key={label} className="flex-1 items-center">
            <View className="w-full flex-row items-center">
              <View
                className={`h-0.5 flex-1 ${
                  isFirst
                    ? 'bg-transparent'
                    : index <= currentIndex
                    ? 'bg-gold'
                    : 'bg-border'
                }`}
              />

              <View
                className={`h-9 w-9 items-center justify-center rounded-full ${
                  isFilled ? 'bg-gold' : 'bg-surface-alt'
                }`}
              >
                {isDone && !isCurrent && index < currentIndex ? (
                  <CheckIcon size={16} color={colors.background} />
                ) : (
                  <GenieText
                    variant="body-md"
                    className={`font-bold ${
                      isFilled ? 'text-background' : 'text-muted'
                    }`}
                  >
                    {String(index + 1)}
                  </GenieText>
                )}
              </View>

              <View
                className={`h-0.5 flex-1 ${
                  isLast
                    ? 'bg-transparent'
                    : index < currentIndex
                    ? 'bg-gold'
                    : 'bg-border'
                }`}
              />
            </View>

            <GenieText
              variant="caption"
              tone={isCurrent ? 'primary' : 'muted'}
              className={`mt-1.5 text-center ${isCurrent ? 'font-bold' : ''}`}
              numberOfLines={1}
            >
              {label}
            </GenieText>
          </View>
        );
      })}
    </View>
  </View>
);
