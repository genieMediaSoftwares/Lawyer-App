import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

/**
 * The browser preview target.
 *
 * Runs the same React Native source through `react-native-web`, so the screens
 * in the browser are the screens on the device — not a parallel web app. It
 * exists so the UI can be looked at, and the real backend exercised, without
 * an emulator.
 *
 * The native build is untouched: Metro never reads this file, and the only
 * web-specific source is `src/services/secureStorage.web.ts`.
 */

/** The module `src/config/env.ts` imports. On native it is produced by the
 *  react-native-dotenv Babel plugin, which Vite does not run. */
const ENV_MODULE = '@env';
const RESOLVED_ENV_MODULE = '\0@env';

export default defineConfig(({ mode }) => {
  // Reads the same .env the native build reads — one source of configuration
  // for both targets. The third argument is '' so unprefixed keys are
  // included; Vite would otherwise only expose VITE_*.
  const fileEnv = loadEnv(mode, process.cwd(), '');

  return {
    plugins: [
      // NativeWind on web works the same way it does on native: JSX is
      // compiled through react-native-css-interop's runtime, which reads the
      // `className` off each element and resolves it against the stylesheet
      // PostCSS built from global.css. The alias below is what makes the
      // same package resolve to its web build rather than its .native one.
      react({ jsxImportSource: 'nativewind' }),
      {
        name: 'genie-law-env',
        resolveId(id) {
          return id === ENV_MODULE ? RESOLVED_ENV_MODULE : null;
        },
        load(id) {
          if (id !== RESOLVED_ENV_MODULE) {
            return null;
          }
          return [
            `export const API_BASE_URL = ${JSON.stringify(fileEnv.API_BASE_URL)};`,
            `export const API_TIMEOUT_MS = ${JSON.stringify(fileEnv.API_TIMEOUT_MS)};`,
            `export const SUPPORT_EMAIL = ${JSON.stringify(fileEnv.SUPPORT_EMAIL)};`,
            `export const SUPPORT_PHONE = ${JSON.stringify(fileEnv.SUPPORT_PHONE)};`,
            `export const AI_UPLOAD_MAX_MB = ${JSON.stringify(fileEnv.AI_UPLOAD_MAX_MB)};`,
          ].join('\n');
        },
      },
    ],

    resolve: {
      alias: [
        // Anchored, so only the bare specifier is rewritten. A plain string
        // alias does prefix matching and would turn `react-native-svg` into
        // `react-native-web-svg`, which does not exist.
        { find: /^react-native$/, replacement: 'react-native-web' },

        // react-native-svg reaches for `@react-native/assets-registry`, which
        // React Native 0.87 no longer ships, so nothing in the tree provides
        // it. react-native-web has the same registry with the same
        // `getAssetByID(id)` signature, so this is a real implementation
        // rather than a shim — and it is only reached by SVG <Image href>,
        // which this app does not use. Without the alias the web build fails
        // to resolve the import outright.
        {
          find: /^@react-native\/assets-registry\/registry$/,
          replacement: 'react-native-web/dist/modules/AssetRegistry',
        },
      ],
      // Mirrors Metro's platform resolution: a `.web.ts` beside a `.ts` wins
      // here, which is how the browser gets its own credential store and
      // react-native-svg gets its DOM renderer.
      extensions: [
        '.web.tsx',
        '.web.ts',
        '.web.jsx',
        '.web.js',
        '.tsx',
        '.ts',
        '.jsx',
        '.js',
        '.json',
      ],
    },

    define: {
      // React Native libraries read both of these at module scope.
      global: 'globalThis',
      __DEV__: JSON.stringify(mode !== 'production'),
    },

    // NOTE ON DEV MODE
    //
    // `vite dev` is not used for this target, and the scripts build and serve
    // instead. Vite's dependency optimizer cannot handle react-native-svg
    // either way round:
    //
    //   included  — it walks the package entry into `fabric/*NativeComponent`,
    //               which imports deep paths like
    //               `react-native/Libraries/Utilities/codegenNativeComponent`.
    //               Those are Flow-typed source Rolldown cannot parse, and the
    //               `^react-native$` alias is anchored so it does not catch a
    //               deep path.
    //   excluded  — its generated PEG parsers (`lib/extract/transform.js`) are
    //               CommonJS sitting inside an ESM folder, and without the
    //               optimizer's interop the browser rejects them for having no
    //               named exports.
    //
    // The production build has neither problem: it does not pre-bundle, so the
    // platform extensions below resolve the `.web.js` renderers and the fabric
    // specs are never reached. Builds take well under a second, so
    // `npm run web:watch` alongside `npm run web:preview` gives fast rebuilds
    // without needing the optimizer at all.

    server: {
      port: 5173,
      open: false,
    },
  };
});
