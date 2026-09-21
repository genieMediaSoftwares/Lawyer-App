import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

const ENV_MODULE = '@env';
const RESOLVED_ENV_MODULE = '\0@env';

export default defineConfig(({ mode }) => {
  const fileEnv = loadEnv(mode, process.cwd(), '');

  return {
    plugins: [
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
        { find: /^react-native$/, replacement: 'react-native-web' },

        {
          find: /^@react-native\/assets-registry\/registry$/,
          replacement: 'react-native-web/dist/modules/AssetRegistry',
        },
      ],
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
      global: 'globalThis',
      __DEV__: JSON.stringify(mode !== 'production'),
    },

    server: {
      port: 5173,
      open: false,
    },
  };
});
