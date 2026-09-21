import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

import { ForgotPasswordScreen } from '../screens/auth/ForgotPasswordScreen';
import { LoginScreen } from '../screens/auth/LoginScreen';
import { SignupScreen } from '../screens/auth/SignupScreen';
import { colors } from '../theme';
import type { AuthStackParamList } from '../types/navigation';

const Stack = createNativeStackNavigator<AuthStackParamList>();

/**
 * The screens available to someone who is not signed in.
 *
 * Headers are off: Login and Signup carry their own tab control, and Forgot
 * Password draws its own back button, so a native bar would be a second,
 * lighter-coloured one on top.
 */
export const AuthNavigator: React.FC = () => (
  <Stack.Navigator
    initialRouteName="Login"
    screenOptions={{
      headerShown: false,
      // Without this the native stack flashes its own white background during
      // the push animation, on an otherwise entirely black app.
      contentStyle: { backgroundColor: colors.background },
      animation: 'slide_from_right',
    }}
  >
    <Stack.Screen name="Login" component={LoginScreen} />
    <Stack.Screen name="Signup" component={SignupScreen} />
    <Stack.Screen name="ForgotPassword" component={ForgotPasswordScreen} />
  </Stack.Navigator>
);
