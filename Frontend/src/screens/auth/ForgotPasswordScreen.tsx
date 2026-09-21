import React, { useCallback, useRef, useState } from 'react';
import { Pressable, View } from 'react-native';

import {
  GenieNotice,
  GenieButton,
  GenieInput,
  GeniePasswordInput,
  GenieScreen,
  GenieText,
  GenieTextInputRef,
  Logo,
} from '../../components';
import { BackIcon, MailIcon } from '../../components/icons/Icons';
import { authApi } from '../../api/authApi';
import { toAppError } from '../../utils/errors';
import {
  collectErrors,
  validateConfirmPassword,
  validateEmail,
  validatePassword,
  validateResetCode,
} from '../../utils/validation';
import type { AuthScreenProps } from '../../types/navigation';
import { colors } from '../../theme';

type Step = 'request' | 'reset';
type FormField = 'email' | 'code' | 'password' | 'confirmPassword';

export const ForgotPasswordScreen: React.FC<
  AuthScreenProps<'ForgotPassword'>
> = ({ navigation, route }) => {
  const [step, setStep] = useState<Step>('request');
  const [email, setEmail] = useState(route.params?.email ?? '');
  const [code, setCode] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const [fieldErrors, setFieldErrors] = useState<
    Partial<Record<FormField, string>>
  >({});
  const [formError, setFormError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const passwordRef = useRef<GenieTextInputRef>(null);
  const confirmRef = useRef<GenieTextInputRef>(null);

  const clearFieldError = useCallback((field: FormField) => {
    setFieldErrors(current => ({ ...current, [field]: undefined }));
    setFormError(null);
  }, []);

  const requestCode = useCallback(async () => {
    if (isSubmitting) return;

    setFormError(null);
    setNotice(null);

    const errors = collectErrors<FormField>({ email: validateEmail(email) });
    setFieldErrors(errors);

    if (Object.keys(errors).length > 0) return;

    setIsSubmitting(true);

    try {
      await authApi.forgotPassword(email.trim());
      setStep('reset');
      setNotice(
        'If that email is registered, a 6-digit reset code is on its way. It expires in 15 minutes.',
      );
    } catch (error) {
      setFormError(toAppError(error).message);
    } finally {
      setIsSubmitting(false);
    }
  }, [email, isSubmitting]);

  const submitReset = useCallback(async () => {
    if (isSubmitting) return;

    setFormError(null);

    const errors = collectErrors<FormField>({
      email: validateEmail(email),
      code: validateResetCode(code),
      password: validatePassword(password),
      confirmPassword: validateConfirmPassword(password, confirmPassword),
    });

    setFieldErrors(errors);

    if (Object.keys(errors).length > 0) return;

    setIsSubmitting(true);

    try {
      await authApi.resetPassword({
        email: email.trim(),
        token: code.trim(),
        newPassword: password,
      });

      navigation.replace('Login');
    } catch (error) {
      const info = toAppError(error);
      if (info.fieldErrors) {
        setFieldErrors(current => ({ ...current, ...info.fieldErrors }));
      }
      setFormError(info.message);
    } finally {
      setIsSubmitting(false);
    }
  }, [code, confirmPassword, email, isSubmitting, navigation, password]);

  return (
    <GenieScreen scrollable>
      <View className="py-1">
        <Pressable
          onPress={() => navigation.goBack()}
          disabled={isSubmitting}
          hitSlop={8}
          accessibilityRole="button"
          accessibilityLabel="Go back"
          className="min-h-touch min-w-touch items-center justify-center self-start rounded-full active:bg-surface-alt"
        >
          <BackIcon size={20} color={colors.white} />
        </Pressable>
      </View>

      <View className="my-4 items-center">
        <Logo size={64} />
        <GenieText variant="heading-md" className="mt-2">
          {step === 'request' ? 'Forgot Password' : 'Reset Password'}
        </GenieText>
        <GenieText
          variant="body-sm"
          tone="secondary"
          className="mt-1 max-w-[280px] text-center"
        >
          {step === 'request'
            ? 'Enter your email and we will send a reset code'
            : 'Enter the code from your email and choose a new password'}
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
          clearFieldError('email');
        }}
        error={fieldErrors.email}
        leftIcon={<MailIcon size={20} color={colors.textMuted} />}
        keyboardType="email-address"
        autoCapitalize="none"
        autoCorrect={false}
        autoComplete="email"
        returnKeyType={step === 'request' ? 'go' : 'next'}
        onSubmitEditing={step === 'request' ? requestCode : undefined}
        editable={!isSubmitting && step === 'request'}
        containerClassName="mb-3"
      />

      {step === 'reset' && (
        <>
          <GenieInput
            label="Reset Code"
            placeholder="6-digit code"
            value={code}
            onChangeText={value => {
              setCode(value.replace(/\D/g, '').slice(0, 6));
              clearFieldError('code');
            }}
            error={fieldErrors.code}
            keyboardType="number-pad"
            maxLength={6}
            returnKeyType="next"
            onSubmitEditing={() => passwordRef.current?.focus()}
            editable={!isSubmitting}
            containerClassName="mb-3"
          />
          <GeniePasswordInput
            ref={passwordRef}
            label="New Password"
            placeholder="At least 6 characters"
            value={password}
            onChangeText={value => {
              setPassword(value);
              clearFieldError('password');
              if (confirmPassword) clearFieldError('confirmPassword');
            }}
            error={fieldErrors.password}
            returnKeyType="next"
            onSubmitEditing={() => confirmRef.current?.focus()}
            editable={!isSubmitting}
            containerClassName="mb-3"
          />
          <GeniePasswordInput
            ref={confirmRef}
            label="Confirm New Password"
            placeholder="Re-enter your new password"
            value={confirmPassword}
            onChangeText={value => {
              setConfirmPassword(value);
              clearFieldError('confirmPassword');
            }}
            error={fieldErrors.confirmPassword}
            returnKeyType="go"
            onSubmitEditing={submitReset}
            editable={!isSubmitting}
            containerClassName="mb-4"
          />
        </>
      )}

      <GenieButton
        label={step === 'request' ? 'Send Reset Code' : 'Reset Password'}
        loadingLabel={step === 'request' ? 'Sending...' : 'Resetting...'}
        loading={isSubmitting}
        onPress={step === 'request' ? requestCode : submitReset}
      />

      {step === 'reset' && (
        <Pressable
          onPress={() => {
            setStep('request');
            setCode('');
            setPassword('');
            setConfirmPassword('');
            setFieldErrors({});
            setFormError(null);
            setNotice(null);
          }}
          disabled={isSubmitting}
          accessibilityRole="button"
          accessibilityLabel="Use a different email, or request a new code"
          className="mt-3 min-h-touch justify-center self-center px-2 active:opacity-70"
        >
          <GenieText variant="caption" tone="secondary" className="text-center">
            Use a different email, or request a new code
          </GenieText>
        </Pressable>
      )}

      <View className="my-6 flex-row items-center justify-center">
        <GenieText variant="body-sm" tone="secondary">
          Remembered your password?{' '}
        </GenieText>
        <Pressable
          onPress={() => navigation.replace('Login')}
          hitSlop={8}
          disabled={isSubmitting}
          accessibilityRole="button"
          accessibilityLabel="Login"
          className="active:opacity-70"
        >
          <GenieText variant="label" tone="gold">
            Login
          </GenieText>
        </Pressable>
      </View>
    </GenieScreen>
  );
};
