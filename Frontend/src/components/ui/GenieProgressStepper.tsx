import React from 'react';
import { View } from 'react-native';
import { GenieText } from './GenieText';

/**
 * A horizontal progress track: the stages of a case, the steps of a form.
 *
 * Each stage is an equal-width column holding a dot with a connector on either
 * side. Building it that way — rather than as one long line with dots placed
 * over it — is what keeps the dots evenly spaced whatever the labels underneath
 * happen to say.
 *
 * The connectors at the two ends are transparent rather than absent, so every
 * column is the same width and the first and last dots stay aligned with their
 * labels.
 */

export interface GenieProgressStepperProps {
  steps: readonly string[];
  /** Index of the current step. Everything up to and including it reads as done. */
  currentIndex: number;
  className?: string;
}

export const GenieProgressStepper: React.FC<GenieProgressStepperProps> = ({
  steps,
  currentIndex,
  className = '',
}) => (
  <View
    className={`rounded-card border border-border bg-surface p-4 ${className}`}
    accessibilityLabel={`Step ${currentIndex + 1} of ${steps.length}: ${
      steps[currentIndex] ?? ''
    }`}
  >
    <View className="flex-row">
      {steps.map((stage, index) => {
        const done = index <= currentIndex;
        const isFirst = index === 0;
        const isLast = index === steps.length - 1;

        return (
          <View key={stage} className="flex-1 items-center">
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
                className={`h-4 w-4 items-center justify-center rounded-full border-2 ${
                  done ? 'border-gold bg-gold-muted' : 'border-border bg-surface'
                }`}
              >
                {done ? <View className="h-1.5 w-1.5 rounded-full bg-gold" /> : null}
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
              tone={done ? 'gold' : 'muted'}
              className="mt-1.5 text-center text-[10px]"
              numberOfLines={1}
            >
              {stage}
            </GenieText>
          </View>
        );
      })}
    </View>
  </View>
);
