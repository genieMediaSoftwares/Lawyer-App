import React from 'react';
import { Pressable, View } from 'react-native';
import { GenieText } from './GenieText';
import { ChevronRightIcon } from '../icons/ClientIcons';
import { colors } from '../../theme';

/**
 * One row in a settings or profile list.
 *
 * Three shapes, all the same height and alignment so a group reads as a single
 * list rather than as stacked one-offs:
 *
 *   - navigates  — `onPress` with a chevron
 *   - shows      — a `value` on the right, no chevron, not tappable
 *   - toggles    — caller passes a Switch as `trailing`
 *
 * `tone="danger"` is for destructive rows. It colours the label and the icon,
 * so Delete Account cannot be mistaken for Change Password at a glance.
 *
 * The profile menu's rows are this component with a `subtitle`, rather than a
 * second near-identical component — they differ by one line of text, and two
 * components that close would drift.
 */

export interface GenieSettingsRowProps {
  label: string;
  /** A second line under the label, as on the profile menu. */
  subtitle?: string;
  /** A gold-tinted circle is drawn around it, as on the profile menu. */
  icon?: React.ReactNode;
  /** Read-only right-hand text, e.g. "English (IN)". */
  value?: string;
  /** A control on the right, e.g. a Switch. Replaces the chevron. */
  trailing?: React.ReactNode;
  onPress?: () => void;
  tone?: 'default' | 'danger' | 'warning';
  disabled?: boolean;
  className?: string;
}

export const GenieSettingsRow: React.FC<GenieSettingsRowProps> = ({
  label,
  subtitle,
  icon,
  value,
  trailing,
  onPress,
  tone = 'default',
  disabled = false,
  className = '',
}) => {
  const labelTone =
    tone === 'danger' ? 'error' : tone === 'warning' ? 'warning' : 'primary';
  const chevronColor =
    tone === 'danger'
      ? colors.error
      : tone === 'warning'
      ? colors.warning
      : colors.textMuted;

  const Container = onPress ? Pressable : View;

  return (
    <Container
      onPress={onPress}
      disabled={disabled}
      accessibilityRole={onPress ? 'button' : undefined}
      accessibilityLabel={
        value ? `${label}, ${value}` : subtitle ? `${label}. ${subtitle}` : label
      }
      accessibilityState={onPress ? { disabled } : undefined}
      className={[
        'min-h-touch flex-row items-center px-4 py-3',
        onPress ? 'active:bg-surface-alt' : '',
        disabled ? 'opacity-50' : '',
        className,
      ].join(' ')}
    >
      {icon ? (
        <View className="mr-3 h-9 w-9 items-center justify-center rounded-full bg-gold-muted">
          {icon}
        </View>
      ) : null}

      <View className="flex-1">
        <GenieText variant="body-lg" tone={labelTone}>
          {label}
        </GenieText>
        {subtitle ? (
          <GenieText variant="caption" tone="muted" className="mt-0.5">
            {subtitle}
          </GenieText>
        ) : null}
      </View>

      {value ? (
        <GenieText variant="body-sm" tone="secondary" className="ml-2">
          {value}
        </GenieText>
      ) : null}

      {trailing ?? (onPress ? <ChevronRightIcon size={18} color={chevronColor} /> : null)}
    </Container>
  );
};

/**
 * The heading above a group of rows, and the card the group sits in.
 *
 * Rows are separated by hairlines drawn between them rather than under each
 * one, so the last row does not end in a dangling line.
 */
export const GenieSettingsGroup: React.FC<{
  title: string;
  children: React.ReactNode;
  className?: string;
}> = ({ title, children, className = '' }) => {
  const rows = React.Children.toArray(children).filter(Boolean);

  return (
    <View className={className}>
      <GenieText
        variant="caption"
        tone="muted"
        className="mb-2 ml-1 font-bold tracking-widest"
      >
        {title}
      </GenieText>
      <View className="overflow-hidden rounded-card border border-border bg-surface">
        {rows.map((row, i) => (
          <View key={i}>
            {i > 0 ? <View className="ml-4 h-px bg-border" /> : null}
            {row}
          </View>
        ))}
      </View>
    </View>
  );
};
