import React from 'react';
import {
  Keyboard,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  ScrollViewProps,
  TouchableWithoutFeedback,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

/**
 * The frame every screen sits in.
 *
 * It owns the four things a screen should never decide for itself: the page
 * background, the safe-area insets, the horizontal gutter, and what happens to
 * the keyboard. A screen that renders its own `flex-1 bg-background px-5` is a
 * screen that will drift from the others.
 *
 * `edges` is worth reading before changing. A screen under the tab bar passes
 * `['top']`, because the tab bar already sits in the bottom inset and taking
 * it twice leaves a gap above the navigation. A screen pushed on top of the
 * tabs takes both.
 */

export interface GenieScreenProps {
  children: React.ReactNode;
  /**
   * Rendered above the content and outside the scroll area, so it stays put
   * while the content moves. Almost always a GenieHeader. It sits inside the
   * safe area but outside the gutter, because a header manages its own
   * horizontal padding to keep its icons flush with the screen edge.
   */
  header?: React.ReactNode;
  /** Wraps the content in a ScrollView. Use a FlatList directly for long lists. */
  scrollable?: boolean;
  /** Which insets to consume. Defaults to the top only — see above. */
  edges?: ReadonlyArray<'top' | 'bottom' | 'left' | 'right'>;
  /** Turn off to run content to the screen edge, e.g. a full-bleed list. */
  padded?: boolean;
  /** Tapping outside an input dismisses the keyboard. Native only; the web has no keyboard to dismiss. */
  dismissKeyboardOnTap?: boolean;
  /** Extra classes for the content container. */
  className?: string;
  /** Extra classes for the outermost safe-area view. */
  containerClassName?: string;
  contentContainerClassName?: string;
  scrollViewProps?: Omit<ScrollViewProps, 'children'>;
}

export const GenieScreen: React.FC<GenieScreenProps> = ({
  children,
  scrollable = false,
  edges = ['top'],
  padded = true,
  dismissKeyboardOnTap = true,
  header,
  className = '',
  containerClassName = '',
  contentContainerClassName = '',
  scrollViewProps,
}) => {
  const gutter = padded ? 'px-5' : '';

  const content = scrollable ? (
    <ScrollView
      className="flex-1"
      contentContainerClassName={`${gutter} py-3 ${contentContainerClassName}`}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
      {...scrollViewProps}
    >
      {children}
    </ScrollView>
  ) : (
    <View className={`flex-1 ${gutter} py-3 ${className}`}>{children}</View>
  );

  // `TouchableWithoutFeedback` swallows the first tap on web, which is what
  // made inputs need a second click. There is no software keyboard in a
  // browser to dismiss, so the wrapper simply is not used there.
  const body =
    dismissKeyboardOnTap && Platform.OS !== 'web' ? (
      <TouchableWithoutFeedback onPress={Keyboard.dismiss} accessible={false}>
        <View className="flex-1">{content}</View>
      </TouchableWithoutFeedback>
    ) : (
      content
    );

  return (
    <SafeAreaView
      edges={edges}
      className={`flex-1 bg-background ${containerClassName}`}
    >
      {header}
      <KeyboardAvoidingView
        className="flex-1"
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        {body}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};
