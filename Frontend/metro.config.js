const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const { withNativeWind } = require('nativewind/metro');

const config = mergeConfig(getDefaultConfig(__dirname), {});

// Runs Tailwind over `global.css` and feeds the compiled output to the css
// interop runtime, so `className` resolves on device.
//
// `inlineRem` matters more than it looks. NativeWind defaults to 14px per rem
// on native, to match React Native's default font size, while a browser is
// 16px. Left alone, `rounded-xl` is 10.5 on a phone and 12 in the browser and
// `text-base` is 14 against 16 — the same class, two designs. Pinning it to 16
// makes one class mean one thing everywhere.
module.exports = withNativeWind(config, {
  input: './global.css',
  inlineRem: 16,
});
