/**
 * Teaches NativeWind about the components it does not know by default.
 *
 * react-native-css-interop auto-registers the core React Native components —
 * View, Text, Pressable, ScrollView, TextInput and friends — and nothing else.
 * Anything outside that list takes `className` without complaint and then
 * silently drops it: no error, no warning, just an unstyled element.
 *
 * `Animated.View` is outside that list, which is what made the drawer render
 * with no background at all. `bg-surface` never reached it, so the panel was
 * fully transparent and the Home screen showed straight through it — which in
 * turn looked like the menu labels were overlapping other text.
 *
 * The same bug was quietly affecting the skeleton loaders, the splash screen
 * text and the AI progress bar. Registering the component once here fixes all
 * of them, rather than working around it at each call site.
 *
 * Imported for its side effect by App.tsx, so it runs before anything renders.
 */
import { Animated } from 'react-native';
// Deep-imported on purpose. Both `nativewind` and the root of
// `react-native-css-interop` pull in the latter's `doctor` module, which ships
// raw JSX inside a plain .js file — Rolldown will not parse it, and the Vite
// web build dies with a PARSE_ERROR. The rest of the app never hits this
// because it reaches the library through its jsx-runtime, which bypasses the
// root entry.
//
// `runtime/api` is that same entry minus the doctor, and it resolves per
// platform on its own: Metro takes `api.native.js` (native/api), Vite takes
// `api.js` (web/api). Both export `cssInterop`.
import { cssInterop } from 'react-native-css-interop/dist/runtime/api';

// `className` is merged into the existing `style` prop rather than replacing
// it, so a component can carry classes for its static styling and an Animated
// value for the part that actually moves.
cssInterop(Animated.View, { className: 'style' });
cssInterop(Animated.Text, { className: 'style' });
cssInterop(Animated.ScrollView, { className: 'style' });
