# Genie Law — React Native frontend

The mobile client for Genie Law, talking to the existing Node/Express backend
in `../backend`.

**There is no mock data anywhere in this app.** Every screen shows what the
backend returned, or a loading state, or an empty state, or the real error.
Nothing falls back to fabricated content when a request fails.

---

## Contents

- [Requirements](#requirements)
- [Setup](#setup)
- [Running](#running)
- [Backend API contracts](#backend-api-contracts)
- [Authentication architecture](#authentication-architecture)
- [Browser preview target](#browser-preview-target)
- [What the backend does not have](#what-the-backend-does-not-have)
- [Project layout](#project-layout)
- [Design system](#design-system)

---

## Requirements

| Tool | Version |
| --- | --- |
| Node | ≥ 22.11 |
| JDK | 17 |
| Android SDK | platform 37, build-tools 37.0.0 |
| React Native | 0.87.1 |

---

## Setup

```bash
cd Frontend
npm install
cp .env.example .env      # then set API_BASE_URL
```

`.env` holds configuration only, never secrets: everything in a React Native
bundle can be extracted from the APK. It is gitignored; `.env.example` is the
committed template.

| Variable | Meaning |
| --- | --- |
| `API_BASE_URL` | Backend root **including `/api`**, no trailing slash |
| `API_TIMEOUT_MS` | Per-request timeout, default 20000 |

Pick the address that matches where you are running:

| Target | `API_BASE_URL` |
| --- | --- |
| Deployed backend | `https://lawyerappvizag.duckdns.org/api` |
| Android emulator → local backend | `http://10.0.2.2:5000/api` |
| iOS simulator → local backend | `http://localhost:5000/api` |
| Physical device → local backend | `http://<your-LAN-ip>:5000/api` |

`API_BASE_URL` is read through the `@env` module and inlined at build time, so
**changing `.env` requires a Metro restart with `--reset-cache`.**

### Plain HTTP on Android

A `http://` base URL is blocked by default on Android 9+. For local
development only, add to `android/app/src/main/AndroidManifest.xml` on the
`<application>` element:

```xml
android:usesCleartextTraffic="true"
```

Remove it before shipping. The deployed backend is HTTPS and needs nothing.

---

## Running

```bash
npm start                 # Metro
npm run android           # build + install on a device/emulator
npm run ios               # macOS only

npm run web               # build + serve the browser preview on :5173

npm run typecheck         # both TypeScript programmes (native + web)
npm run lint              # ESLint
```

### Browser preview

`npm run web` runs the **same React Native source** through `react-native-web`
and serves it at <http://127.0.0.1:5173>. It is for looking at the UI and
exercising the real backend without an emulator — not a shipping target. See
[Browser preview target](#browser-preview-target).

For fast iteration, run these in two terminals:

```bash
npm run web:watch         # rebuilds on change (~200ms)
npm run web:preview       # serves dist/ on :5173
```

### Type checking

There are two programmes, on purpose:

| Command | Covers |
| --- | --- |
| `tsc -p tsconfig.json` | The native app. **No DOM lib** |
| `tsc -p tsconfig.web.json` | `web/` and `*.web.ts`. DOM lib on |

The split keeps the React Native base config's guarantee that a screen cannot
reach for `window` or `document` and still type-check, while letting the
browser-only files use them. `npm run typecheck` runs both.

---

## Backend API contracts

Everything below was read from `backend/src/routes/authRoutes.js` and verified
against the running server. **This app never invents an endpoint, a request
field or a response shape.**

### Response envelope

Success — `backend/src/config/ApiResponse.js`:

```json
{ "success": true, "message": "Login successful.", "data": { } }
```

Failure — `backend/src/middleware/errorMiddleware.js`:

```json
{ "success": false, "message": "Invalid email or password.", "code": "INVALID_CREDENTIALS" }
```

Validation failure — `backend/src/middleware/validationMiddleware.js`. Note
this is a **different shape** from every other failure:

```json
{
  "success": false,
  "message": "Validation Failed",
  "errors": [{ "path": "email", "msg": "Valid email is required" }]
}
```

`src/utils/errors.ts` handles all three and is the only place a wire error is
turned into a sentence.

### Endpoints in use

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| `POST` | `/auth/signup` | — | 201. Registers **and** signs in |
| `POST` | `/auth/login` | — | 200 |
| `GET` | `/auth/profile` | Bearer | Returns the raw user document |
| `POST` | `/auth/refresh-token` | — | Refresh token is the credential |
| `POST` | `/auth/logout` | Bearer | Ends this device's session only |
| `POST` | `/auth/logout-all` | Bearer | Ends every session |
| `POST` | `/auth/forgot-password` | — | Emails a 6-digit code |
| `POST` | `/auth/reset-password` | — | `{email, token, newPassword}` |

Other route groups exist on the backend — cases, documents, AI, voice,
appointments, chat, lawyers, payments — and **none of them has an API module in
this app yet**, because this phase covers authentication only. A file is added
under `src/api/` when the screen that uses it is built, never before.

### Signup

`POST /auth/signup` — fields per `backend/src/validations/authValidation.js`:

| Field | Rule |
| --- | --- |
| `fullName` | required, ≥ 3 characters |
| `email` | valid email, normalised server-side |
| `mobile` | `/^[6-9]\d{9}$/` — ten digits, first 6-9 |
| `password` | ≥ 6 characters |
| `role` | optional, `client` or `lawyer` |

`deviceId`, `deviceName` and `platform` are also sent **in the body** — see
[Authentication architecture](#authentication-architecture) and
[The CORS fix](#the-cors-fix).

`confirmPassword` is checked on the client and **not sent**; the backend has no
such field.

Response `201`:

```json
{
  "success": true,
  "message": "User registered successfully.",
  "data": {
    "token": "eyJ...",
    "refreshToken": "0f31887e...",
    "expiresIn": 604800,
    "user": {
      "id": "6aaf...", "fullName": "…", "email": "…",
      "mobile": "…", "role": "client", "profileImage": "", "location": ""
    }
  }
}
```

Failures:

| Status | `code` | Cause |
| --- | --- | --- |
| 400 | — | `errors` array from express-validator |
| 409 | `EMAIL_ALREADY_REGISTERED` | Email taken |
| 409 | `MOBILE_ALREADY_REGISTERED` | Mobile taken |

### Login

`POST /auth/login` — `{email, password}` plus device fields. Response is
identical in shape to signup.

`401 INVALID_CREDENTIALS` covers **both** a wrong password and an unknown
address. The backend does not distinguish them on purpose, so neither does the
app.

### Roles

`client` and `lawyer`, and nothing else. `admin` exists in the User schema but
signup validation rejects it — an administrator is seeded server-side. The
signup form defaults to **Client**. The list lives in `src/constants/roles.ts`
and is tied to the backend's union at compile time.

### The `id` / `_id` inconsistency

`login`, `signup` and `refresh-token` return `publicUser()` — a projection with
`id`. `GET /auth/profile` returns the **raw Mongoose document**, so it has
`_id` plus schema fields (`dob`, `gender`, `languages`, `isVerified`,
`isActive`, timestamps).

This app types them as two separate shapes — `AuthUser` and `ProfileUser` — and
maps `_id → id` in `src/store/authStore.ts`. Treating them as one type is how
an `id` ends up `undefined` at runtime.

---

## Authentication architecture

Implemented exactly as the backend does it. Nothing was redesigned.

### Tokens

| | |
| --- | --- |
| Access token | JWT, field name `token` (**not** `accessToken`) |
| Claims | `id`, `role`, `email`, `sid` |
| Refresh token | 32 random bytes, hex, stored server-side as SHA-256 |
| Lifetime | From `expiresIn` (seconds). The deployed backend sends `604800` |

Both are kept in `react-native-keychain` — the iOS Keychain and the Android
Keystore. Never AsyncStorage, which is plaintext on both platforms.

### Sessions

The `sid` claim names a row in the backend's session collection, checked on
every authenticated request. That is what makes logout real: once the row is
revoked the token still verifies cryptographically but stops being accepted.

`deviceId` is generated once, kept in secure storage, and survives restarts and
sign-outs. Signing in again from the same device **replaces that device's
session** rather than opening a second one, so an app restart never leaves an
orphaned session behind. It is a random label — not a hardware identifier — and
it does not survive an uninstall.

Multiple devices are supported: the backend holds one session row per device
and revoking one never touches another.

### Refresh, and the lock

`src/api/apiClient.ts`:

1. A `401` on any request that is not itself an auth endpoint triggers a
   refresh.
2. **Only the first one does.** `refreshInFlight` is a single-flight promise;
   every other `401` arriving while it is pending awaits the same promise.
3. On success the original request is retried once, with `_genieRetry` set so a
   retry can never itself be retried.
4. On failure — or a second `401` on the same request — the tokens are cleared
   and the store moves to `unauthenticated`, which swaps the navigator to Login.

The lock matters because the backend **rotates the refresh token on every
use**. A second concurrent refresh would spend a token the first had already
replaced: it fails, and since a failed refresh signs the user out, it would
sign out a session that had just been renewed successfully.

The refresh call goes through a second Axios instance with no interceptors, so
its own `401` cannot re-enter the loop.

### A network failure is not a sign-out

`authStore.restore()` clears stored tokens when the backend **says** the
session is invalid. It deliberately does not when the request simply failed to
reach the server — otherwise opening the app without a connection would force
the user to type their password again. The user lands on Login, and the tokens
are still there for the next launch.

### Navigation

Auth and App are two stacks, mounted by authentication state, never pushed onto
one another:

```
RootNavigator
├── status === 'restoring'       → Splash  (outside NavigationContainer)
├── status === 'authenticated'   → AppNavigator   (Home)
└── status === 'unauthenticated' → AuthNavigator  (Login, Signup, ForgotPassword)
```

Because neither stack is ever on the other's back stack, there is no route back
to a screen the user has lost access to, and no `reset()` call to get wrong.
Login ↔ Signup use `replace`, so the two alternatives never accumulate in the
history.

The splash screen runs the **real** session check — it reads stored tokens and
verifies them against `/auth/profile`, renewing through the interceptor if the
access token has expired. It does not route to Login unconditionally.

---

## Browser preview target

`react-native-web` maps React Native primitives onto DOM nodes, so the screens
in the browser are the screens on the device — not a parallel web app. Vite
builds it.

**What is web-specific**, and it is deliberately almost nothing:

| File | Why |
| --- | --- |
| `vite.config.mts` | Aliases `react-native` → `react-native-web`, resolves `.web.*` first, and serves the same `.env` as `@env` |
| `index.html` | Black from first paint; pins the root to 100% on **both** axes |
| `web/main.tsx` | `createRoot` in place of `AppRegistry` |
| `src/services/secureStorage.web.ts` | Browser credential store |

Metro and Vite both prefer a `.web.ts` over a `.ts`, so `secureStorage.web.ts`
is selected automatically on web and `react-native-keychain` — which has no
browser build — never enters the web bundle. Verified: the built bundle
contains zero references to it.

### Security of the web target

`localStorage` is plain text and readable by any script on the origin, so an
XSS bug hands over both tokens. There is no Keychain and no Keystore in a
browser. **The native builds are the product; the browser target is a
development preview and is not a surface to ship to users.** Shipping it would
mean moving the refresh token into an httpOnly cookie, which is a backend
change.

### Why it builds rather than using `vite dev`

Vite's dependency optimizer cannot handle `react-native-svg` either way round:

- **Included** — it walks the package entry into `fabric/*NativeComponent`,
  which imports deep paths like
  `react-native/Libraries/Utilities/codegenNativeComponent`. Those are
  Flow-typed source Rolldown cannot parse, and the `^react-native$` alias is
  anchored so it does not catch a deep path.
- **Excluded** — its generated PEG parsers (`lib/extract/transform.js`) are
  CommonJS inside an ESM folder, and without the optimizer's interop the
  browser rejects them for having no named exports.

The production build has neither problem, because it does not pre-bundle: the
platform extensions resolve the `.web.js` renderers and the fabric specs are
never reached. Builds are ~200ms, so `web:watch` + `web:preview` is quick
enough that losing HMR costs little.

### The CORS fix

The app sent `X-Device-Id`, `X-Device-Name` and `X-Device-Platform` on every
request. Native has no CORS preflight so this was invisible on device, but in a
browser it failed every call:

```
Request header field x-device-id is not allowed by
Access-Control-Allow-Headers in preflight response
```

Those headers were **redundant**. `deviceContext()` in
`backend/src/controllers/auth/authController.js` reads `req.body` first and
only falls back to the headers, it is used by exactly two routes — signup and
login — and `authApi` already sends all three fields in the body of both.
Logout needs none of it: it ends the session named by the token's own `sid`
claim.

So the interceptor no longer sends them. **The backend was not changed.** The
same values still travel, in the body, where the server prefers them anyway.

If a custom header is ever genuinely needed from a browser, it has to be added
to `allowedHeaders` in `backend/src/app.js` — a backend change, and one worth
avoiding while the body already carries the data.

---

## What the backend does not have

Reported rather than invented, faked or stubbed.

### Google sign-in — **missing**

The Login screen shows **Continue with Google**, per the design. There is no
backend route behind it.

- Searched: `backend/src/routes/`, `backend/src/controllers/`. No `/auth/google`,
  no `/auth/google-login`, no id-token exchange, no `google_id` field on the
  User schema.
- The only Google integration that exists is **Calendar sync for lawyers**
  (`/api/lawyers/google-calendar/*`), which is a different feature and requires
  an account that is already signed in.

The button therefore does not sign anyone in and does not pretend to. Pressing
it says the method is unavailable and points at the email/password form.
Nothing mints a token, invents a user, or calls an endpoint that would 404.

**To enable it**, the backend needs a route that accepts a Google id token,
verifies it against Google, finds or creates the user, and returns the same
`{token, refreshToken, expiresIn, user}` payload login does. That is a backend
change and has not been made — see the backend-modification rule.

Once it exists, `src/components/GoogleButton.tsx` gets a real `onPress` and the
`unavailable` state goes away.

### Also absent

| Feature | Status |
| --- | --- |
| Mobile OTP login | No route. Not implemented here |
| Email verification | `isVerified` is admin-set; no user-facing flow |
| Refresh-token revocation list | Rotation only — matches the backend |

### Worth knowing about the deployment

`backend/.env` sets `JWT_EXPIRES_IN=7d` and does **not** set
`JWT_REFRESH_EXPIRES_IN`, so sessions fall back to the access-token lifetime
and both are seven days (`expiresIn: 604800`). The refresh flow is implemented
and verified regardless; it simply fires rarely against this deployment. The
backend's own `.env.example` recommends `15m` / `30d`.

---

## Project layout

```
Frontend/
├── android/                    native Android project
├── ios/                        native iOS project
├── src/
│   ├── api/
│   │   ├── apiClient.ts        Axios + auth interceptor + refresh lock
│   │   ├── authApi.ts          the auth endpoints that exist
│   │   └── tokenStore.ts       in-memory mirror of secure storage
│   ├── components/             CustomTextInput, PasswordInput, PrimaryButton,
│   │                           ScreenContainer, ErrorMessage, Logo, Divider,
│   │                           RolePicker, AuthTabs, GoogleButton, icons/
│   ├── config/env.ts           the only place API_BASE_URL enters the app
│   ├── constants/roles.ts      backend-supported roles
│   ├── navigation/             Root, Auth and App navigators
│   ├── screens/
│   │   ├── auth/               Splash, Login, Signup, ForgotPassword
│   │   └── app/                Home
│   ├── services/
│   │   ├── secureStorage.ts    Keychain / Keystore
│   │   └── device.ts           stable installation id
│   ├── store/authStore.ts      Zustand; the only thing navigation switches on
│   ├── theme/                  colors, spacing, typography
│   ├── types/                  api, auth, navigation, env
│   └── utils/                  errors, validation
├── App.tsx
├── .env.example
└── README.md
```

**Architecture:** screen → store or React Query → `authApi` → `apiClient` →
auth interceptor → backend. No screen knows that tokens exist.

---

## Design system

Black, gold and white. `src/theme/colors.ts` is the closed set — a screen that
needs a new shade takes it from there or does not get one.

| Token | Value | Use |
| --- | --- | --- |
| `background` | `#000000` | Page |
| `surface` | `#111111` | Cards, sheets |
| `inputBackground` | `#0B0B0B` | Input wells |
| `gold` | `#DFA928` | Buttons, accents, the logo |
| `white` | `#FFFFFF` | Primary type |
| `textSecondary` | `#BDBDBD` | Supporting copy |
| `border` | `#2A2A2A` | Hairlines, input outlines |
| `onGold` | `#000000` | Type on gold |

Red (`#E5534B`) is the one hue outside the palette, reserved for errors so a
failure cannot read as decoration.

Controls are 56pt tall with a 14pt radius, spacing is a 4pt scale, and the logo
and icons are inline SVG so they stay sharp at any size and cost no font or
raster assets.

React Native 0.87 draws Android **edge-to-edge**; `StatusBar` no longer accepts
a background colour. The black comes from the Android theme
(`android:windowBackground`) and the root view, and `react-native-safe-area-context`
keeps content clear of the system bars.
