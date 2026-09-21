module.exports = {
  presets: [
    'module:@react-native/babel-preset',
    // Compiles JSX through react-native-css-interop's runtime, which is what
    // gives every component a working `className`. Must come after the React
    // Native preset, since it overrides that preset's JSX import source.
    'nativewind/babel',
  ],
  plugins: [
    [
      'module:react-native-dotenv',
      {
        moduleName: '@env',
        path: '.env',
        safe: false,
        allowUndefined: true,
      },
    ],
  ],
};
