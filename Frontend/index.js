/**
 * @format
 */

// Must be imported before anything renders: this is the compiled Tailwind
// output, and NativeWind's runtime needs it registered before the first
// component with a `className` mounts.
import './global.css';

import { AppRegistry } from 'react-native';
import App from './App';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);
