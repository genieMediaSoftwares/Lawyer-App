import React from 'react';
import { ActivityIndicator, Pressable, PressableProps, View } from 'react-native';
import { GenieText } from './GenieText';
import { colors } from '../../theme';

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
  sm: 'min-h-touch px-4',
  md: 'h-control px-5',
};

export interface GenieButtonProps extends Omit<PressableProps, 'children' | 'style'> {
  label: string;
  onPress: () => void;
  variant?: GenieButtonVariant;
  size?: GenieButtonSize;
  loading?: boolean;
  loadingLabel?: string;
  disabled?: boolean;
  fullWidth?: boolean;
  icon?: React.ReactNode;
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
