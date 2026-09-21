/**
 * The Genie Law Tailwind theme.
 *
 * Every value here comes from `src/theme/tokens.js`, which is the one place a
 * colour, radius or control height is defined. This file only decides what the
 * class names for them are.
 *
 * The scale is Tailwind's own — `p-4` is 16, `p-5` is 20, `rounded-xl` is 12 —
 * because a familiar scale is the point of using Tailwind at all. What is
 * added on top is intent: `rounded-card`, `h-control`, `bg-surface`. Those are
 * the handles to pull when the brief is "make all the cards rounder" rather
 * than "make this one card 24pt".
 */

const { colors, radius, sizing } = require('./src/theme/tokens.js');

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './App.tsx',
    './src/**/*.{js,jsx,ts,tsx}',
    './web/**/*.{js,jsx,ts,tsx}',
  ],
  presets: [require('nativewind/preset')],

  // Dark-first, and dark-only for now. The app has no light theme and is not
  // getting one speculatively. What makes a future one cheap is that screens
  // name their colours by role — `bg-surface`, `text-secondary` — so a light
  // theme is a second set of values here, not an edit to every screen.
  darkMode: 'class',

  theme: {
    extend: {
      colors: {
        background: colors.background,
        surface: {
          DEFAULT: colors.surface,
          alt: colors.surfaceAlt,
        },
        card: colors.card,
        input: colors.inputBackground,

        gold: {
          DEFAULT: colors.gold,
          bright: colors.goldBright,
          pressed: colors.goldPressed,
          muted: colors.goldMuted,
          wash: colors.goldWash,
        },
        'on-gold': colors.onGold,

        // Type that is not white. `text-secondary` and `text-muted` are the
        // two steps down from `text-white`, and there is no third.
        secondary: colors.textSecondary,
        muted: colors.textMuted,

        border: colors.border,

        success: {
          DEFAULT: colors.success,
          surface: colors.successSurface,
        },
        warning: {
          DEFAULT: colors.warning,
          surface: colors.warningSurface,
        },
        error: {
          DEFAULT: colors.error,
          surface: colors.errorSurface,
        },
        info: {
          DEFAULT: colors.info,
          surface: colors.infoSurface,
        },

        overlay: colors.overlay,
        disabled: {
          DEFAULT: colors.disabled,
          text: colors.disabledText,
        },
        skeleton: {
          DEFAULT: colors.skeleton,
          highlight: colors.skeletonHighlight,
        },
      },

      // Tailwind v3 leaves a bare `border` at `currentColor`, which on a dark
      // screen paints a white hairline. The app's hairline is the border
      // token, so `border` alone is correct and `border-border` is noise.
      borderColor: {
        DEFAULT: colors.border,
      },

      borderRadius: radius,

      // The type scale, named by role rather than by size. This is the one
      // place a heading or body size is decided: GenieText maps its
      // variants straight onto these, so "make body text bigger" is a
      // change here and nowhere else. Each pair is [size, line-height] —
      // line height travels with the size so vertical rhythm cannot drift.
      fontSize: {
        display: ['36px', '42px'],
        'head-xl': ['30px', '36px'],
        'head-lg': ['24px', '30px'],
        'head-md': ['20px', '26px'],
        'head-sm': ['18px', '24px'],
        'body-lg': ['16px', '24px'],
        'body-md': ['15px', '22px'],
        'body-sm': ['14px', '20px'],
        caption: ['12px', '16px'],
      },

      // `h-control` is the shared input/button height; `min-h-touch` is the
      // floor for anything tappable.
      height: { control: sizing.control, touch: sizing.touch },
      width: { control: sizing.control, touch: sizing.touch },
      minHeight: { control: sizing.control, touch: sizing.touch },
      minWidth: { touch: sizing.touch },
      spacing: { gutter: sizing.screenGutter },
    },
  },

  plugins: [],
};
