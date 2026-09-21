/**
 * Browser entry point.
 *
 * The native entry is `index.js`, which hands App to React Native's
 * AppRegistry. This does the DOM equivalent and nothing else — the App
 * component, the navigators and every screen are shared verbatim.
 */

// The compiled Tailwind stylesheet. Native gets this through Metro from
// index.js; in the browser Vite and PostCSS build it and inject it here. It
// must load before the first component with a `className` renders.
import '../global.css';

import React from 'react';
import { createRoot } from 'react-dom/client';
import { enableScreens } from 'react-native-screens';

enableScreens(false);

import App from '../App';

const container = document.getElementById('root');

if (!container) {
  throw new Error('index.html is missing its #root element.');
}

createRoot(container).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
