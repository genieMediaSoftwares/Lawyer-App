export const SIGNUP_ROLES = ['client', 'lawyer'] as const;
export type SignupRole = (typeof SIGNUP_ROLES)[number];

export type UserRole = SignupRole | 'admin';

export interface AuthUser {
  id: string;
  fullName: string;
  email: string;
  mobile: string;
  role: UserRole;
  profileImage: string;
  location: string;
}

export interface ProfileUser {
  _id: string;
  fullName: string;
  email: string;
  mobile: string;
  role: UserRole;
  profileImage: string;
  location: string;
  dob: string;
  gender: string;
  languages: string[];
  isVerified: boolean;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AuthSession {
  token: string;
  refreshToken: string;
  expiresIn: number;
  user: AuthUser;
}

export interface DeviceContext {
  deviceId: string;
  deviceName: string;
  platform: string;
}

export interface LoginRequest extends DeviceContext {
  email: string;
  password: string;
}

export interface SignupRequest extends DeviceContext {
  fullName: string;
  email: string;
  mobile: string;
  password: string;
  role: SignupRole;
}

export interface RefreshRequest {
  refreshToken: string;
}

export interface ForgotPasswordRequest {
  email: string;
}

export interface ResetPasswordRequest {
  email: string;
  token: string;
  newPassword: string;
}

export interface LogoutAllResult {
  sessionsRevoked: number;
}
