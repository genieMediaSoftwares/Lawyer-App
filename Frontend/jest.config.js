module.exports = {
  preset: '@react-native/jest-preset',
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native[^/]*|@react-native(-community)?|@react-native-documents|@react-navigation|nativewind)/)',
  ],
  setupFiles: [
    '<rootDir>/node_modules/@react-native-documents/picker/jest/build/jest/setup.js',
    '<rootDir>/jest.setup.js',
  ],
};
