import React, { forwardRef } from 'react';
import { Pressable } from 'react-native';
import { GenieInput, GenieInputProps, GenieTextInputRef } from './GenieInput';
import { CloseIcon, SearchIcon } from '../icons/ClientIcons';
import { colors } from '../../theme';

/**
 * A search field: GenieInput with a magnifier, and a clear button once there
 * is something to clear.
 *
 * The clear control replaced a literal ✕ character three screens were drawing
 * as a Text node.
 */

export interface GenieSearchInputProps extends Omit<GenieInputProps, 'leftIcon' | 'rightIcon'> {
  onClear?: () => void;
}

export const GenieSearchInput = forwardRef<GenieTextInputRef, GenieSearchInputProps>(
  ({ onClear, value, ...rest }, ref) => (
    <GenieInput
      ref={ref}
      value={value}
      leftIcon={<SearchIcon size={20} color={colors.textMuted} />}
      rightIcon={
        value && onClear ? (
          <Pressable
            onPress={onClear}
            hitSlop={12}
            accessibilityRole="button"
            accessibilityLabel="Clear search"
            className="p-1"
          >
            <CloseIcon size={18} color={colors.textMuted} />
          </Pressable>
        ) : undefined
      }
      returnKeyType="search"
      autoCapitalize="none"
      autoCorrect={false}
      {...rest}
    />
  ),
);

GenieSearchInput.displayName = 'GenieSearchInput';
