import React from 'react';
import { ActivityIndicator, Pressable, PressableProps, View } from 'react-native';
import { GenieText } from './GenieText';
import { colors } from '../../theme';

/**
 * Every button in the app.
 *
 * Four variants, and the rule for choosing is about weight rather than colour:
 * one `primary` per screen — the thing the screen is for — `outline` for the
 * alternative to it, `ghost` for actions that should not compete with the
 * content, `danger` for anything that destroys something.
 *
 * Height comes from `h-control`, which inputs also use, so a button stacked
 * under a field lines up with it.
 */

export type GenieButtonVariant = 'primary' | 'outline' | 'ghost' | 'danger';
export type GenieButtonSize = 'sm' | 'md';

const CONTAINER: Record<GenieButtonVariant, string> = {
  primary: 'bg-gold active:bg-gold-pressed',
  outline: 'bg-transparent border border-gold active:bg-gold-muted',
  ghost: 'bg-transparent active:bg-surface-alt',
  danger: 'bg-error active:opacity-80',
};

const LABEL_TONE: Record<GenieButtonVariant, 'on-gold' | 'gold' | 'primary'> = {
  primary: 'on-gold',
  outline: 'gold',
  ghost: 'primary',
  danger: 'primary',
};

const SIZES: Record<GenieButtonSize, string> = {
  // Never below `min-h-touch` — a button smaller than a fingertip is a bug.
  sm: 'min-h-touch px-4',
  md: 'h-control px-5',
};

export interface GenieButtonProps extends Omit<PressableProps, 'children' | 'style'> {
  label: string;
  onPress: () => void;
  variant?: GenieButtonVariant;
  size?: GenieButtonSize;
  loading?: boolean;
  /** Shown in place of `label` while loading, e.g. "Signing in…". */
  loadingLabel?: string;
  disabled?: boolean;
  /** Buttons are full width by default; a row of them sets this false. */
  fullWidth?: boolean;
  icon?: React.ReactNode;
  /** Which side of the label the icon sits on. Left by default. */
  iconPosition?: 'left' | 'right';
  className?: string;
}

export const GenieButton: React.FC<GenieButtonProps> = ({
  label,
  onPress,
  variant = 'primary',
  size = 'md',
  loading = false,
  loadingLabel,
  disabled = false,
  fullWidth = true,
  icon,
  iconPosition = 'left',
  className = '',
  ...rest
}) => {
  const isInactive = disabled || loading;
  const displayLabel = loading ? loadingLabel ?? label : label;

  return (
    <Pressable
      onPress={onPress}
      disabled={isInactive}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: isInactive, busy: loading }}
      className={[
        'flex-row items-center justify-center rounded-control',
        SIZES[size],
        CONTAINER[variant],
        fullWidth ? 'w-full' : 'self-start',
        isInactive ? 'opacity-50' : '',
        className,
      ].join(' ')}
      {...rest}
    >
      {loading ? (
        <ActivityIndicator
          size="small"
          // A spinner takes a colour, not a class — one of the few places the
          // palette is imported rather than named in a className.
          color={variant === 'primary' ? colors.onGold : colors.gold}
        />
      ) : (
        <>
          {icon && iconPosition === 'left' ? (
            <View className="mr-2">{icon}</View>
          ) : null}
          <GenieText variant="button" tone={LABEL_TONE[variant]}>
            {displayLabel}
          </GenieText>
          {icon && iconPosition === 'right' ? (
            <View className="ml-2">{icon}</View>
          ) : null}
        </>
      )}
    </Pressable>
  );
};
