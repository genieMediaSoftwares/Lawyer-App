/**
 * Genie Law
 *
 * The app's root. Three providers, one navigator, and the wire that lets the
 * network layer tell the auth store when a session has ended for good.
 *
 * @format
 */

import React, { useEffect } from 'react';
import { StatusBar, View } from 'react-native';
import { QueryClientProvider } from '@tanstack/react-query';
import { SafeAreaProvider } from 'react-native-safe-area-context';

// Registers Animated.* with NativeWind. Must run before the first render, or
// every `className` on an Animated component is silently dropped.
import './src/nativewind-interop';

import { queryClient } from './src/api/queryClient';
import { RootNavigator } from './src/navigation/RootNavigator';
import { bindSessionExpiryHandler } from './src/store/authStore';
import { installWebFocusHygiene } from './src/utils/webFocus';

function App(): React.JSX.Element {
  useEffect(() => {
    // Installed before anything can make a request. When a refresh fails for
    // good, the interceptor clears the tokens and fires this, which moves the
    // store to `unauthenticated` and so swaps the navigator to Login.
    const unsubscribe = bindSessionExpiryHandler();
    return unsubscribe;
  }, []);

  useEffect(() => {
    // Releases DOM focus when a control is clicked with a pointer, so that the
    // screen React Navigation then marks `aria-hidden` does not still contain
    // the focused element. A no-op on Android and iOS — see utils/webFocus.
    const uninstall = installWebFocusHygiene();
    return uninstall;
  }, []);

  return (
    <SafeAreaProvider>
      {/* A black root behind the navigator, so nothing white shows through
          during a stack swap or under the status bar. React Native 0.87 draws
          Android edge-to-edge and no longer accepts a status-bar background
          colour, so the bar is transparent over this view by design — the
          black comes from here and from the Android theme, and the safe-area
          insets keep content clear of it. */}
      <View className="flex-1 bg-background">
        <StatusBar barStyle="light-content" />
        <QueryClientProvider client={queryClient}>
          <RootNavigator />
        </QueryClientProvider>
      </View>
    </SafeAreaProvider>
  );
}

export default App;
