import React, { useEffect } from 'react';
import { StatusBar, View } from 'react-native';
import { QueryClientProvider } from '@tanstack/react-query';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import './src/nativewind-interop';

import { queryClient } from './src/api/queryClient';
import { RootNavigator } from './src/navigation/RootNavigator';
import { bindSessionExpiryHandler } from './src/store/authStore';
import { installWebFocusHygiene } from './src/utils/webFocus';

function App(): React.JSX.Element {
  useEffect(() => {
    const unsubscribe = bindSessionExpiryHandler();
    return unsubscribe;
  }, []);

  useEffect(() => {
    const uninstall = installWebFocusHygiene();
    return uninstall;
  }, []);

  return (
    <SafeAreaProvider>
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
