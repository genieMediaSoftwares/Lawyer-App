import { Animated } from 'react-native';
import { cssInterop } from 'react-native-css-interop/dist/runtime/api';

cssInterop(Animated.View, { className: 'style' });
cssInterop(Animated.Text, { className: 'style' });
cssInterop(Animated.ScrollView, { className: 'style' });
