import React, { forwardRef, useImperativeHandle, useRef, useState } from 'react';
import {
  Platform,
  Pressable,
  StyleSheet,
  TextInput,
  TextInputProps,
  View,
} from 'react-native';
import { GenieText } from './GenieText';
import { colors } from '../../theme';

/**
 * Every text field in the app.
 *
 * ON THE FIRST CLICK
 *
 * The field used to need two clicks in the browser before it would take text.
 * The cause was the container: it was a `Pressable` whose `onPress` focused
 * the input, and on web that wrapper answers the click itself — the first one
 * lands on the wrapper, and only the second reaches the input.
 *
 * On a phone that wrapper is worth having, because the padding around the text
 * should be tappable. In a browser it is not, because a real <input> already
 * takes focus from a click anywhere inside it. So the wrapper is native-only,
 * and the web gets a plain View that clicks fall straight through.
 */

/**
 * What a ref to one of these fields points at.
 *
 * Derived from the component rather than named directly: React Native renamed
 * this instance type in 0.87, and `ComponentRef` follows whatever the
 * installed version calls it.
 */
export type GenieTextInputRef = React.ComponentRef<typeof TextInput>;

export interface GenieInputProps extends TextInputProps {
  label?: string;
  /** Sets the error style and is shown beneath the field. */
  error?: string;
  /** Shown beneath the field when there is no error. */
  helperText?: string;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  containerClassName?: string;
  className?: string;
}

export const GenieInput = forwardRef<GenieTextInputRef, GenieInputProps>(
  (
    {
      label,
      error,
      helperText,
      leftIcon,
      rightIcon,
      containerClassName = '',
      className = '',
      onFocus,
      onBlur,
      editable = true,
      ...rest
    },
    ref,
  ) => {
    const [isFocused, setIsFocused] = useState(false);
    const innerRef = useRef<GenieTextInputRef>(null);

    useImperativeHandle(ref, () => innerRef.current as GenieTextInputRef);

    const hasError = Boolean(error);
    const helper = error ?? helperText;

    const focusInput = () => {
      if (editable) {
        innerRef.current?.focus();
      }
    };

    // Error outranks focus: a field that is both wrong and focused should read
    // as wrong.
    const borderClass = hasError
      ? 'border-error'
      : isFocused
      ? 'border-gold'
      : 'border-border';

    const fieldClasses = [
      'h-control flex-row items-center rounded-control border bg-surface px-3',
      borderClass,
      editable ? '' : 'opacity-50',
    ].join(' ');

    const field = (
      <>
        {leftIcon ? (
          <View className="mr-2" pointerEvents="none">
            {leftIcon}
          </View>
        ) : null}
        <TextInput
          ref={innerRef}
          editable={editable}
          placeholderTextColor={colors.textMuted}
          className={`h-full flex-1 text-body-lg text-white ${className}`}
          style={webInputReset}
          accessibilityLabel={label}
          onFocus={e => {
            setIsFocused(true);
            onFocus?.(e);
          }}
          onBlur={e => {
            setIsFocused(false);
            onBlur?.(e);
          }}
          {...rest}
        />
        {rightIcon ? <View className="ml-2">{rightIcon}</View> : null}
      </>
    );

    return (
      <View className={`w-full ${containerClassName}`}>
        {label ? (
          <GenieText variant="label" className="mb-1.5">
            {label}
          </GenieText>
        ) : null}

        {Platform.OS === 'web' ? (
          <View className={fieldClasses}>{field}</View>
        ) : (
          <Pressable className={fieldClasses} onPress={focusInput}>
            {field}
          </Pressable>
        )}

        {helper ? (
          <GenieText
            variant="caption"
            tone={hasError ? 'error' : 'muted'}
            className="mt-1"
          >
            {helper}
          </GenieText>
        ) : null}
      </View>
    );
  },
);

GenieInput.displayName = 'GenieInput';

/**
 * A genuine StyleSheet exception. `outlineStyle` is a web-only property with
 * no Tailwind equivalent that react-native-web understands, and without it the
 * browser paints its own focus ring on top of the gold border.
 */
const webInputReset = StyleSheet.create({
  reset: Platform.OS === 'web' ? ({ outlineStyle: 'none' } as object) : {},
}).reset;
