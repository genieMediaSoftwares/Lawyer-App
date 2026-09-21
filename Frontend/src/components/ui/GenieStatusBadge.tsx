import React from 'react';
import { View } from 'react-native';
import { GenieText } from './GenieText';
import type { GenieTextTone } from './GenieText';

type Kind = 'live' | 'done' | 'pending' | 'failed' | 'neutral';

const KINDS: Record<Kind, { surface: string; tone: GenieTextTone }> = {
  live: { surface: 'bg-gold-muted', tone: 'gold' },
  done: { surface: 'bg-success-surface', tone: 'success' },
  pending: { surface: 'bg-warning-surface', tone: 'warning' },
  failed: { surface: 'bg-error-surface', tone: 'error' },
  neutral: { surface: 'bg-surface-alt', tone: 'secondary' },
};

const BY_STATUS: Record<string, Kind> = {
  active: 'live',
  open: 'live',
  verified: 'live',
  ongoing: 'live',
  closed: 'done',
  completed: 'done',
  resolved: 'done',
  approved: 'done',
  pending: 'pending',
  in_progress: 'pending',
  'in review': 'pending',
  review: 'pending',
  rejected: 'failed',
  cancelled: 'failed',
  failed: 'failed',
};

export interface GenieStatusBadgeProps {
  status: string;
  className?: string;
}

export const GenieStatusBadge: React.FC<GenieStatusBadgeProps> = ({
  status,
  className = '',
}) => {
  const kind = BY_STATUS[status.toLowerCase().trim()] ?? 'neutral';
  const { surface, tone } = KINDS[kind];

  return (
    <View className={`self-start rounded-lg px-2 py-0.5 ${surface} ${className}`}>
      <GenieText variant="caption" tone={tone} className="font-bold capitalize">
        {status.replace(/_/g, ' ')}
      </GenieText>
    </View>
  );
};
