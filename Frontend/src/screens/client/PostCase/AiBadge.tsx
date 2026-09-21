import React from 'react';
import { View } from 'react-native';

import { GenieText } from '../../../components';
import { SparkleIcon } from '../../../components/icons/ClientIcons';
import { colors } from '../../../theme';

/**
 * Marks a value the AI extracted rather than the client typed.
 *
 * It disappears the moment that field is edited, so it always means "this is
 * still the model's wording, check it" — which is the only reading that makes
 * it useful on the review step.
 */
export const AiBadge: React.FC<{ label?: string }> = ({
  label = 'AI extracted',
}) => (
  <View
    className="flex-row items-center gap-1 self-start rounded-pill bg-gold-muted px-2 py-0.5"
    accessibilityLabel={label}
  >
    <SparkleIcon size={11} color={colors.gold} />
    <GenieText variant="caption" tone="gold" className="text-[10px] font-bold">
      {label}
    </GenieText>
  </View>
);

/**
 * Marks a field the server itself flagged as uncertain — low model confidence,
 * or read from a document whose OCR was degraded.
 *
 * Shown alongside the value rather than in place of it: a wrong value the
 * client can see and correct is safer than a blank they never knew about.
 */
export const CheckBadge: React.FC = () => (
  <View
    className="flex-row items-center rounded-pill bg-warning-surface px-2 py-0.5"
    accessibilityLabel="Needs checking"
  >
    <GenieText
      variant="caption"
      tone="warning"
      className="text-[10px] font-bold"
    >
      Check
    </GenieText>
  </View>
);
