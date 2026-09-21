import React from 'react';
import { View } from 'react-native';

/** A hairline. Its colour is the border token, like every other edge. */
export const GenieDivider: React.FC<{ className?: string }> = ({
  className = '',
}) => <View className={`h-px w-full bg-border ${className}`} />;
