/**
 * The browser half of NativeWind.
 *
 * On native, Metro compiles `global.css` with Tailwind itself (see
 * `metro.config.js`). Vite has no such integration, so PostCSS does the same
 * job here and Vite injects the result as a real stylesheet — which is what
 * react-native-css-interop reads on web.
 */
module.exports = {
  plugins: {
    tailwindcss: {},
  },
};
