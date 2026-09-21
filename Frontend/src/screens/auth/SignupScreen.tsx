import React, { useCallback, useRef, useState } from 'react';
import { Pressable, View } from 'react-native';

import {
  AuthTabs,
  GenieNotice,
  GenieButton,
  GenieInput,
  GeniePasswordInput,
  GenieScreen,
  GenieText,
  GenieTextInputRef,
  Logo,
  RolePicker,
} from '../../components';
import { MailIcon, PhoneIcon, UserIcon } from '../../components/icons/Icons';
import { DEFAULT_ROLE } from '../../constants/roles';
import { useAuthStore } from '../../store/authStore';
import { toAppError } from '../../utils/errors';
import {
  collectErrors,
  validateConfirmPassword,
  validateEmail,
  validateFullName,
  validateMobile,
  validatePassword,
} from '../../utils/validation';
import type { SignupRole } from '../../types/auth';
import type { AuthScreenProps } from '../../types/navigation';
import { colors } from '../../theme';

type FormField =
  | 'fullName'
  | 'email'
  | 'mobile'
  | 'password'
  | 'confirmPassword';

export const SignupScreen: React.FC<AuthScreenProps<'Signup'>> = ({
  navigation,
}) => {
  const signup = useAuthStore(state => state.signup);

  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [mobile, setMobile] = useState('');
  const [role, setRole] = useState<SignupRole>(DEFAULT_ROLE);
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const [fieldErrors, setFieldErrors] = useState<
    Partial<Record<FormField, string>>
  >({});
  const [formError, setFormError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const emailRef = useRef<GenieTextInputRef>(null);
  const mobileRef = useRef<GenieTextInputRef>(null);
  const passwordRef = useRef<GenieTextInputRef>(null);
  const confirmRef = useRef<GenieTextInputRef>(null);

  const clearFieldError = useCallback((field: FormField) => {
    setFieldErrors(current => ({ ...current, [field]: undefined }));
    setFormError(null);
  }, []);

  const handleSubmit = useCallback(async () => {
    if (isSubmitting) return;

    setFormError(null);

    const errors = collectErrors<FormField>({
      fullName: validateFullName(fullName),
      email: validateEmail(email),
      mobile: validateMobile(mobile),
      password: validatePassword(password),
      confirmPassword: validateConfirmPassword(password, confirmPassword),
    });

    setFieldErrors(errors);

    if (Object.keys(errors).length > 0) return;

    setIsSubmitting(true);

    try {
      await signup({
        fullName: fullName.trim(),
        email: email.trim(),
        mobile: mobile.trim(),
        password,
        role,
      });
    } catch (error) {
      const info = toAppError(error);
      if (info.fieldErrors) {
        setFieldErrors(current => ({ ...current, ...info.fieldErrors }));
      }
      setFormError(info.message);
    } finally {
      setIsSubmitting(false);
    }
  }, [
    confirmPassword,
    email,
    fullName,
    isSubmitting,
    mobile,
    password,
    role,
    signup,
  ]);

  return (
    <GenieScreen scrollable>
      <AuthTabs
        active="signup"
        onSelectLogin={() => navigation.replace('Login')}
        onSelectSignup={() => {}}
      />

      <View className="my-4 items-center">
        <Logo size={64} />
        <GenieText variant="heading-md" className="mt-2">
          Create Account
        </GenieText>
        <GenieText variant="body-lg" tone="secondary" className="mt-1">
          Join Genie Law to get started
        </GenieText>
      </View>

      <GenieNotice message={formError} className="mb-3" />

      <GenieInput
        label="Full Name"
        placeholder="Your full name"
        value={fullName}
        onChangeText={value => {
          setFullName(value);
          clearFieldError('fullName');
        }}
        error={fieldErrors.fullName}
        leftIcon={<UserIcon size={20} color={colors.textMuted} />}
        autoCapitalize="words"
        autoComplete="name"
        returnKeyType="next"
        onSubmitEditing={() => emailRef.current?.focus()}
        editable={!isSubmitting}
        containerClassName="mb-3"
      />

      <GenieInput
        ref={emailRef}
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
        returnKeyType="next"
        onSubmitEditing={() => mobileRef.current?.focus()}
        editable={!isSubmitting}
        containerClassName="mb-3"
      />

      <GenieInput
        ref={mobileRef}
        label="Mobile Number"
        placeholder="10-digit mobile number"
        value={mobile}
        onChangeText={value => {
          setMobile(value.replace(/\D/g, '').slice(0, 10));
          clearFieldError('mobile');
        }}
        error={fieldErrors.mobile}
        helperText="Indian mobile number, starting 6-9"
        leftIcon={<PhoneIcon size={20} color={colors.textMuted} />}
        keyboardType="number-pad"
        maxLength={10}
        returnKeyType="next"
        onSubmitEditing={() => passwordRef.current?.focus()}
        editable={!isSubmitting}
        containerClassName="mb-3"
      />

      <RolePicker label="Select Role" value={role} onChange={setRole} />

      <GeniePasswordInput
        ref={passwordRef}
        label="Password"
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
        label="Confirm Password"
        placeholder="Re-enter your password"
        value={confirmPassword}
        onChangeText={value => {
          setConfirmPassword(value);
          clearFieldError('confirmPassword');
        }}
        error={fieldErrors.confirmPassword}
        returnKeyType="go"
        onSubmitEditing={handleSubmit}
        editable={!isSubmitting}
        containerClassName="mb-4"
      />

      <GenieButton
        label="Create Account"
        loadingLabel="Creating account..."
        loading={isSubmitting}
        onPress={handleSubmit}
      />

      <View className="my-6 flex-row items-center justify-center">
        <GenieText variant="body-sm" tone="secondary">
          Already have an account?{' '}
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
