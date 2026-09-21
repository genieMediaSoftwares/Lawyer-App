import React, { useCallback, useRef, useState } from 'react';
import { Pressable, View } from 'react-native';

import {
  AuthTabs,
  GenieButton,
  GenieDivider,
  GenieInput,
  GenieNotice,
  GeniePasswordInput,
  GenieScreen,
  GenieText,
  GenieTextInputRef,
  GoogleButton,
  Logo,
} from '../../components';
import { MailIcon } from '../../components/icons/Icons';
import { useAuthStore } from '../../store/authStore';
import { toAppError } from '../../utils/errors';
import {
  collectErrors,
  validateEmail,
  validateLoginPassword,
} from '../../utils/validation';
import type { AuthScreenProps } from '../../types/navigation';
import { colors } from '../../theme';

type FormField = 'email' | 'password';

export const LoginScreen: React.FC<AuthScreenProps<'Login'>> = ({
  navigation,
}) => {
  const login = useAuthStore(state => state.login);

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fieldErrors, setFieldErrors] = useState<
    Partial<Record<FormField, string>>
  >({});
  const [formError, setFormError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const passwordRef = useRef<GenieTextInputRef>(null);

  const clearMessages = useCallback(() => {
    setFormError(null);
    setNotice(null);
  }, []);

  const handleSubmit = useCallback(async () => {
    if (isSubmitting) {
      return;
    }

    clearMessages();

    const errors = collectErrors<FormField>({
      email: validateEmail(email),
      password: validateLoginPassword(password),
    });

    setFieldErrors(errors);

    if (Object.keys(errors).length > 0) {
      return;
    }

    setIsSubmitting(true);

    try {
      await login(email.trim(), password);
    } catch (error) {
      const info = toAppError(error);
      if (info.fieldErrors) {
        setFieldErrors(current => ({ ...current, ...info.fieldErrors }));
      }
      setFormError(info.message);
    } finally {
      setIsSubmitting(false);
    }
  }, [clearMessages, email, isSubmitting, login, password]);

  return (
    <GenieScreen scrollable>
      <AuthTabs
        active="login"
        onSelectLogin={() => {}}
        onSelectSignup={() => navigation.replace('Signup')}
      />

      <View className="my-6 items-center">
        <Logo size={76} />
        <GenieText variant="heading-lg" className="mt-3">
          Welcome Back
        </GenieText>
        <GenieText variant="body-lg" tone="secondary" className="mt-1">
          Login to continue
        </GenieText>
      </View>

      <GenieNotice message={formError} className="mb-3" />
      <GenieNotice message={notice} tone="gold" className="mb-3" />

      <GenieInput
        label="Email"
        placeholder="you@example.com"
        value={email}
        onChangeText={value => {
          setEmail(value);
          setFieldErrors(current => ({ ...current, email: undefined }));
          clearMessages();
        }}
        error={fieldErrors.email}
        leftIcon={<MailIcon size={20} color={colors.textMuted} />}
        keyboardType="email-address"
        autoCapitalize="none"
        autoCorrect={false}
        autoComplete="email"
        returnKeyType="next"
        onSubmitEditing={() => passwordRef.current?.focus()}
        editable={!isSubmitting}
        containerClassName="mb-3"
      />

      <GeniePasswordInput
        ref={passwordRef}
        label="Password"
        placeholder="Enter your password"
        value={password}
        onChangeText={value => {
          setPassword(value);
          setFieldErrors(current => ({ ...current, password: undefined }));
          clearMessages();
        }}
        error={fieldErrors.password}
        returnKeyType="go"
        onSubmitEditing={handleSubmit}
        editable={!isSubmitting}
        containerClassName="mb-3"
      />

      <Pressable
        onPress={() =>
          navigation.navigate('ForgotPassword', {
            email: email.trim() || undefined,
          })
        }
        hitSlop={8}
        disabled={isSubmitting}
        accessibilityRole="button"
        accessibilityLabel="Forgot password"
        className="mb-4 min-h-touch justify-center self-end px-1 active:opacity-70"
      >
        <GenieText variant="label" tone="gold">
          Forgot Password?
        </GenieText>
      </Pressable>

      <GenieButton
        label="Login"
        loadingLabel="Logging in..."
        loading={isSubmitting}
        onPress={handleSubmit}
      />

      <GenieDivider className="my-4" />

      <GoogleButton onUnavailable={setNotice} disabled={isSubmitting} />

      <View className="my-6 flex-row items-center justify-center">
        <GenieText variant="body-sm" tone="secondary">
          {'Don’t have an account? '}
        </GenieText>
        <Pressable
          onPress={() => navigation.replace('Signup')}
          hitSlop={8}
          disabled={isSubmitting}
          accessibilityRole="button"
          accessibilityLabel="Sign up"
          className="active:opacity-70"
        >
          <GenieText variant="label" tone="gold">
            Sign Up
          </GenieText>
        </Pressable>
      </View>
    </GenieScreen>
  );
};
