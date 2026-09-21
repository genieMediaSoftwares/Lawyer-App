module.exports = {
  preset: '@react-native/jest-preset',
  // The preset only transforms `react-native/` itself. Several dependencies here
  // (react-native-css-interop via nativewind, safe-area-context, screens,
  // reanimated, worklets, @react-navigation) publish untranspiled TS/JSX, so
  // without this the suite dies on "SyntaxError: Unexpected token '<'" before a
  // single test runs.
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native[^/]*|@react-native(-community)?|@react-native-documents|@react-navigation|nativewind)/)',
  ],
  setupFiles: [
    // The picker's own mock, shipped for exactly this purpose.
    '<rootDir>/node_modules/@react-native-documents/picker/jest/build/jest/setup.js',
    '<rootDir>/jest.setup.js',
  ],
};
