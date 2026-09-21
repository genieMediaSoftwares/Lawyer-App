import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import type { Theme } from '@react-navigation/native';

import { AuthNavigator } from './AuthNavigator';
import { ClientNavigator } from './ClientNavigator';
import { LawyerNavigator } from './LawyerNavigator';
import { SplashScreen } from '../screens/auth/SplashScreen';
import { useAuthStore } from '../store/authStore';
import { blurActiveElement } from '../utils/webFocus';
import { colors } from '../theme';

/**
 * Chooses the tree from authentication state — the whole of the app's routing
 * policy.
 *
 * Nothing navigates between the two. Signing in flips `status` and the Auth
 * tree unmounts; signing out flips it back and the client tree unmounts.
 * Because neither is ever on the other's back stack, there is no route to pop
 * back to a screen the user has lost access to, and no reset call to get
 * wrong. A failed token refresh takes the same path: the interceptor clears
 * the tokens, the store moves to `unauthenticated`, and Login appears.
 *
 * `restoring` renders the splash rather than an empty view, so the session
 * check happens behind the brand — and a returning user never sees Login flash
 * before the dashboard.
 *
 * ── On roles ──────────────────────────────────────────────────────────────
 *
 * A `lawyer` account gets the lawyer tree, everyone else the client tree. The
 * two are siblings, mounted by role and never pushed onto one another, so the
 * same guarantee as above holds across roles: there is no route from one into
 * the other, and nothing to pop back to after a sign-out.
 *
 * The role comes from the session the backend issued, not from anything the
 * app decides. It is a routing convenience only — every lawyer endpoint
 * re-checks the role server-side, so a client who somehow reached this tree
 * would be refused by the API rather than shown another user's work.
 *
 * `admin` has its own backend route group and no app; an admin account lands
 * on the client tree, which shows its own empty states because `GET /cases`
 * scopes to `client: req.user._id`.
 */

const navigationTheme: Theme = {
  dark: true,
  colors: {
    primary: colors.gold,
    background: colors.background,
    card: colors.surface,
    text: colors.white,
    border: colors.border,
    notification: colors.gold,
  },
  fonts: {
    regular: { fontFamily: 'System', fontWeight: '400' },
    medium: { fontFamily: 'System', fontWeight: '500' },
    bold: { fontFamily: 'System', fontWeight: '700' },
    heavy: { fontFamily: 'System', fontWeight: '800' },
  },
};

export const RootNavigator: React.FC = () => {
  const status = useAuthStore(state => state.status);
  const role = useAuthStore(state => state.user?.role);

  // Outside NavigationContainer on purpose: while the session is being
  // restored there is no graph to be in, and mounting one would make the
  // splash a route the user could navigate back to.
  if (status === 'restoring') {
    return <SplashScreen />;
  }

  return (
    /**
     * `onStateChange` drops DOM focus on every navigation, web only.
     *
     * `@react-navigation/elements` marks the screen you leave `aria-hidden`,
     * and the control you tapped to leave it still holds focus — which Chrome
     * refuses to hide, warning that focus must not be hidden from assistive
     * technology. Releasing focus as the route changes is the fix, and is
     * correct behaviour regardless: keyboard and screen-reader users resume
     * from the new screen rather than from a button that is no longer visible.
     *
     * See `utils/webFocus.ts`. It is a no-op on Android and iOS.
     */
    <NavigationContainer theme={navigationTheme} onStateChange={blurActiveElement}>
      {status !== 'authenticated' ? (
        <AuthNavigator />
      ) : role === 'lawyer' ? (
        <LawyerNavigator />
      ) : (
        <ClientNavigator />
      )}
    </NavigationContainer>
  );
};
