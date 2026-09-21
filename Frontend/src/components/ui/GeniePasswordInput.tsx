import React, { forwardRef, useState } from 'react';
import { Pressable } from 'react-native';
import { GenieInput, GenieInputProps, GenieTextInputRef } from './GenieInput';
import { EyeIcon, EyeOffIcon, LockIcon } from '../icons/Icons';
import { colors } from '../../theme';

/**
 * A password field: GenieInput with a lock, and an eye that reveals the text.
 *
 * The reveal control is a real button with a label, because a screen reader
 * user needs to know the field can be shown, and it is the one thing in the
 * row that is tappable.
 */

export type GeniePasswordInputProps = Omit<GenieInputProps, 'secureTextEntry'>;

export const GeniePasswordInput = forwardRef<GenieTextInputRef, GeniePasswordInputProps>(
  ({ leftIcon, ...rest }, ref) => {
    const [secure, setSecure] = useState(true);

    return (
      <GenieInput
        ref={ref}
        leftIcon={leftIcon ?? <LockIcon size={20} color={colors.textMuted} />}
        rightIcon={
          <Pressable
            onPress={() => setSecure(prev => !prev)}
            hitSlop={12}
            accessibilityRole="button"
            accessibilityLabel={secure ? 'Show password' : 'Hide password'}
            className="p-1"
          >
            {secure ? (
              <EyeIcon size={20} color={colors.textMuted} />
            ) : (
              <EyeOffIcon size={20} color={colors.gold} />
            )}
          </Pressable>
        }
        secureTextEntry={secure}
        autoCapitalize="none"
        autoCorrect={false}
        {...rest}
      />
    );
  },
);

GeniePasswordInput.displayName = 'GeniePasswordInput';
