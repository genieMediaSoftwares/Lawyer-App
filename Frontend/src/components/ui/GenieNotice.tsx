import React from 'react';
import { View } from 'react-native';
import { GenieText } from './GenieText';
import type { GenieTextTone } from './GenieText';
import { AlertIcon, CheckIcon } from '../icons/Icons';
import { InfoCircleIcon } from '../icons/ClientIcons';
import { colors } from '../../theme';

/**
 * A form-level banner: what the request said, as opposed to what one field
 * said.
 *
 * It replaces both the old ErrorMessage component and the hand-rolled success
 * banners that several screens carried — those drew a literal "✓" as text and
 * hard-coded #22C55E, so the same idea looked slightly different on every
 * screen and the tick's weight followed the system font.
 *
 * Renders nothing when there is no message, so a screen can mount it
 * unconditionally without reserving space.
 */

export type GenieNoticeTone = 'error' | 'success' | 'warning' | 'info' | 'gold';

const TONES: Record<
  GenieNoticeTone,
  { surface: string; border: string; text: GenieTextTone; color: string }
> = {
  error: {
    surface: 'bg-error-surface',
    border: 'border-error',
    text: 'error',
    color: colors.error,
  },
  success: {
    surface: 'bg-success-surface',
    border: 'border-success',
    text: 'success',
    color: colors.success,
  },
  warning: {
    surface: 'bg-warning-surface',
    border: 'border-warning',
    text: 'warning',
    color: colors.warning,
  },
  info: {
    surface: 'bg-info-surface',
    border: 'border-info',
    text: 'info',
    color: colors.info,
  },
  // For notices that are neither good nor bad, just worth reading — such as a
  // sign-in method that is not available yet.
  gold: {
    surface: 'bg-gold-muted',
    border: 'border-gold-wash',
    text: 'gold',
    color: colors.gold,
  },
};

export interface GenieNoticeProps {
  message?: string | null;
  tone?: GenieNoticeTone;
  className?: string;
}

export const GenieNotice: React.FC<GenieNoticeProps> = ({
  message,
  tone = 'error',
  className = '',
}) => {
  if (!message) {
    return null;
  }

  const { surface, border, text, color } = TONES[tone];

  return (
    <View
      className={`flex-row items-start rounded-control border px-4 py-3 ${surface} ${border} ${className}`}
      accessibilityRole="alert"
      accessibilityLiveRegion="polite"
    >
      {tone === 'success' ? (
        <CheckIcon size={18} color={color} />
      ) : tone === 'info' || tone === 'gold' ? (
        <InfoCircleIcon size={18} color={color} />
      ) : (
        <AlertIcon size={18} color={color} />
      )}
      <GenieText variant="body-sm" tone={text} className="ml-2 flex-1">
        {message}
      </GenieText>
    </View>
  );
};
