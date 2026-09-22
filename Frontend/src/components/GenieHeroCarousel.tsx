import React, { useEffect, useRef, useState } from 'react';
import {
  Dimensions,
  Image,
  ImageSourcePropType,
  NativeScrollEvent,
  NativeSyntheticEvent,
  Pressable,
  ScrollView,
  View,
} from 'react-native';
import { useScreenFocus } from '../hooks/useScreenFocused';

import banner1 from '../assets/images/banner1.png';
import banner2 from '../assets/images/banner2.png';
import banner3 from '../assets/images/banner3.png';

export interface CarouselSlide {
  id: string;
  source?: any;
  imageUri?: string;
  actionType?: 'advocates' | 'ai' | 'cases' | 'documents';
  title?: string;
}

const resolveSlideSource = (slide: CarouselSlide): ImageSourcePropType | null => {
  if (slide.source) {
    if (typeof slide.source === 'number') {
      return slide.source;
    }
    if (typeof slide.source === 'string') {
      return { uri: slide.source };
    }
    if (
      slide.source &&
      typeof slide.source === 'object' &&
      'default' in slide.source &&
      typeof (slide.source as { default: unknown }).default === 'string'
    ) {
      return { uri: (slide.source as { default: string }).default };
    }
    if (
      slide.source &&
      typeof slide.source === 'object' &&
      'uri' in slide.source
    ) {
      return slide.source as ImageSourcePropType;
    }
  }

  if (slide.imageUri) {
    return { uri: slide.imageUri };
  }

  return null;
};

export const DEFAULT_SLIDES: CarouselSlide[] = [
  {
    id: '1',
    source: banner1,
    imageUri: '/carousel/banner1.png',
    actionType: 'ai',
    title: 'Your Legal Journey',
  },
  {
    id: '2',
    source: banner2,
    imageUri: '/carousel/banner2.png',
    actionType: 'advocates',
    title: 'Real People. Real Lawyers.',
  },
  {
    id: '3',
    source: banner3,
    imageUri: '/carousel/banner3.png',
    actionType: 'ai',
    title: 'Focus on What Matters.',
  },
];

export const GenieHeroCarousel: React.FC<{
  slides?: CarouselSlide[];
  onSlidePress?: (slide: CarouselSlide) => void;
}> = ({ slides = DEFAULT_SLIDES, onSlidePress }) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const { focusedRef } = useScreenFocus();
  const scrollViewRef = useRef<React.ComponentRef<typeof ScrollView>>(null);
  const [containerWidth, setContainerWidth] = useState(
    Dimensions.get('window').width - 32,
  );

  useEffect(() => {
    if (slides.length <= 1) {
      return;
    }

    const timer = setInterval(() => {
      // Home stays mounted as the first tab; don't auto-advance (setState +
      // native scroll) while another screen is showing.
      if (!focusedRef.current) {
        return;
      }
      setActiveIndex(prev => {
        const nextIndex = (prev + 1) % slides.length;
        scrollViewRef.current?.scrollTo({
          x: nextIndex * containerWidth,
          animated: true,
        });
        return nextIndex;
      });
    }, 5000);

    return () => clearInterval(timer);
  }, [slides.length, containerWidth, focusedRef]);

  const handleScroll = (event: NativeSyntheticEvent<NativeScrollEvent>) => {
    const contentOffsetX = event.nativeEvent.contentOffset.x;
    const index = Math.round(contentOffsetX / (containerWidth || 1));
    if (index !== activeIndex && index >= 0 && index < slides.length) {
      setActiveIndex(index);
    }
  };

  return (
    <View
      className="my-3"
      onLayout={e => {
        const w = e.nativeEvent.layout.width;
        if (w > 0) {
          setContainerWidth(w);
        }
      }}
    >
      <ScrollView
        ref={scrollViewRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onScroll={handleScroll}
        scrollEventThrottle={16}
      >
        {slides.map(slide => {
          const imageSrc = resolveSlideSource(slide);

          return (
            <View
              key={slide.id}
              style={{ width: containerWidth }}
              className="px-0.5"
            >
              <Pressable
                onPress={() => onSlidePress?.(slide)}
                accessibilityRole="button"
                accessibilityLabel={slide.title || `Slide ${slide.id}`}
                className="h-[180px] w-full overflow-hidden rounded-[12px] border border-border bg-card active:opacity-90"
              >
                {imageSrc ? (
                  <Image
                    source={imageSrc}
                    className="h-full w-full"
                    resizeMode="cover"
                  />
                ) : null}
              </Pressable>
            </View>
          );
        })}
      </ScrollView>

      <View className="mt-2.5 flex-row items-center justify-center gap-1.5">
        {slides.map((slide, idx) => (
          <View
            key={slide.id}
            className={`h-1.5 rounded-pill ${
              idx === activeIndex ? 'w-6 bg-gold' : 'w-1.5 bg-border'
            }`}
          />
        ))}
      </View>
    </View>
  );
};
