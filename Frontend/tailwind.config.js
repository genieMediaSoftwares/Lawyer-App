const { colors, radius, sizing } = require('./src/theme/tokens.js');

module.exports = {
  content: [
    './App.tsx',
    './src/**/*.{js,jsx,ts,tsx}',
    './web/**/*.{js,jsx,ts,tsx}',
  ],
  presets: [require('nativewind/preset')],

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

      borderColor: {
        DEFAULT: colors.border,
      },

      borderRadius: radius,

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

      height: { control: sizing.control, touch: sizing.touch },
      width: { control: sizing.control, touch: sizing.touch },
      minHeight: { control: sizing.control, touch: sizing.touch },
      minWidth: { touch: sizing.touch },
      spacing: { gutter: sizing.screenGutter },
    },
  },

  plugins: [],
};
