import React, { useEffect, useRef } from 'react';
import { Animated, View } from 'react-native';
import { USE_NATIVE_DRIVER } from '../../utils/platform';

/**
 * The placeholder shown while real data is loading.
 *
 * The pulse is an Animated value rather than a class. NativeWind handles
 * static style; a driven animation is not static, and this is exactly the kind
 * of case where a stylesheet is the right tool — so the opacity is animated
 * and everything else (colour, radius, size) still comes from classes.
 *
 * `useNativeDriver` keeps the loop off the JS thread, so a list of these does
 * not compete with the request they are waiting for.
 */

export interface GenieSkeletonProps {
  /** Tailwind sizing classes, e.g. "h-5 w-32". */
  className?: string;
}

export const GenieSkeleton: React.FC<GenieSkeletonProps> = ({
  className = 'h-5 w-full',
}) => {
  const opacity = useRef(new Animated.Value(0.35)).current;

  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, {
          toValue: 0.7,
          duration: 800,
          useNativeDriver: USE_NATIVE_DRIVER,
        }),
        Animated.timing(opacity, {
          toValue: 0.35,
          duration: 800,
          useNativeDriver: USE_NATIVE_DRIVER,
        }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [opacity]);

  return (
    <Animated.View
      style={{ opacity }}
      className={`rounded-control bg-skeleton ${className}`}
      accessibilityRole="progressbar"
      accessibilityLabel="Loading"
    />
  );
};

/** The shape of a card, for a list that is still loading. */
export const GenieSkeletonCard: React.FC<{ className?: string }> = ({
  className = '',
}) => (
  <View className={`rounded-card border border-border bg-card p-4 ${className}`}>
    <GenieSkeleton className="h-4 w-1/2" />
    <GenieSkeleton className="mt-3 h-3 w-full" />
    <GenieSkeleton className="mt-2 h-3 w-4/5" />
  </View>
);

export const GenieSkeletonList: React.FC<{ count?: number }> = ({ count = 3 }) => (
  <>
    {Array.from({ length: count }).map((_, i) => (
      <GenieSkeletonCard key={i} className="mb-3" />
    ))}
  </>
);
