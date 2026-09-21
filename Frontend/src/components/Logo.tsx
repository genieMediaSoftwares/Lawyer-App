import React from 'react';
import { View } from 'react-native';
import Svg, { Circle, Line, Path } from 'react-native-svg';

import { colors } from '../theme';

interface LogoProps {
  size?: number;
  withHalo?: boolean;
}

export const Logo: React.FC<LogoProps> = ({ size = 72, withHalo = false }) => (
  <View
    className="items-center justify-center"
    style={
      withHalo
        ? {
            width: size * 1.6,
            height: size * 1.6,
            borderRadius: size * 0.8,
            backgroundColor: colors.goldMuted,
          }
        : undefined
    }
  >
    <Svg width={size} height={size} viewBox="0 0 120 120">

      <Line
        x1="60"
        y1="58"
        x2="60"
        y2="41"
        stroke={colors.gold}
        strokeWidth="3"
        strokeLinecap="round"
      />

      <Line
        x1="24"
        y1="40"
        x2="96"
        y2="40"
        stroke={colors.gold}
        strokeWidth="3"
        strokeLinecap="round"
      />

      <Circle cx="60" cy="40" r="4" fill={colors.gold} />

      <Line x1="24" y1="40" x2="24" y2="51" stroke={colors.gold} strokeWidth="2" />
      <Line x1="96" y1="40" x2="96" y2="51" stroke={colors.gold} strokeWidth="2" />

      <Path
        d="M13 51 Q24 65 35 51 Z"
        stroke={colors.gold}
        strokeWidth="2.6"
        strokeLinejoin="round"
        fill="none"
      />
      <Path
        d="M85 51 Q96 65 107 51 Z"
        stroke={colors.gold}
        strokeWidth="2.6"
        strokeLinejoin="round"
        fill="none"
      />

      <Circle cx="60" cy="61" r="3.4" fill={colors.gold} />

      <Path
        d="M52 71 L54.5 65 H65.5 L68 71 Z"
        fill={colors.gold}
      />

      <Path
        d="M30 89 C30 76 43 70 60 70 C77 70 90 76 90 89 C90 95 80 99.5 60 99.5 C40 99.5 30 95 30 89 Z"
        fill={colors.gold}
      />

      <Path
        d="M30.5 82 L14 77.5 C12.4 77 11.6 79 13 79.8 L22 84.6 L13.4 87.4 C11.8 87.9 12.3 90.2 14 90 L31 88 Z"
        fill={colors.gold}
      />

      <Path
        d="M88 77.5 C99 75.5 105 88 93.5 94.5"
        stroke={colors.gold}
        strokeWidth="4"
        strokeLinecap="round"
        fill="none"
      />

      <Path
        d="M44 100.5 H76"
        stroke={colors.gold}
        strokeWidth="4"
        strokeLinecap="round"
      />

      <Path
        d="M41 82 C44 77.5 51 75.5 58 75.5"
        stroke={colors.background}
        strokeWidth="2.4"
        strokeLinecap="round"
        opacity={0.35}
        fill="none"
      />
    </Svg>
  </View>
);
