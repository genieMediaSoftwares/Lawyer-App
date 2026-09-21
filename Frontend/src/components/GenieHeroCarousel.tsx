import React, { useEffect, useRef, useState } from 'react';
import {
  Dimensions,
  Image,
  NativeScrollEvent,
  NativeSyntheticEvent,
  Pressable,
  ScrollView,
  View,
} from 'react-native';

export interface CarouselSlide {
  id: string;
  imageUri?: string;
  actionType?: 'advocates' | 'ai' | 'cases' | 'documents';
  title?: string;
}

export const DEFAULT_SLIDES: CarouselSlide[] = [
  {
    id: '1',
    imageUri: '/carousel/hero_slide_1.jpg',
    actionType: 'ai',
    title: 'Your Legal Journey',
  },
  {
    id: '2',
    imageUri: '/carousel/hero_slide_2.jpg',
    actionType: 'advocates',
    title: 'Real People. Real Lawyers.',
  },
  {
    id: '3',
    imageUri: '/carousel/hero_slide_3.jpg',
    actionType: 'ai',
    title: 'Focus on What Matters.',
  },
];

export const GenieHeroCarousel: React.FC<{
  slides?: CarouselSlide[];
  onSlidePress?: (slide: CarouselSlide) => void;
}> = ({ slides = DEFAULT_SLIDES, onSlidePress }) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const scrollViewRef = useRef<React.ComponentRef<typeof ScrollView>>(null);
  const [containerWidth, setContainerWidth] = useState(
    Dimensions.get('window').width - 32,
  );

  useEffect(() => {
    if (slides.length <= 1) {
      return;
    }

    const timer = setInterval(() => {
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
  }, [slides.length, containerWidth]);

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
        {slides.map(slide => (
          <View
            key={slide.id}
            style={{ width: containerWidth }}
            className="px-0.5"
          >
            <Pressable
              onPress={() => onSlidePress?.(slide)}
              accessibilityRole="button"
              accessibilityLabel={slide.title || `Slide ${slide.id}`}
              className="h-[180px] w-full overflow-hidden rounded-[16px] bg-[#121212] active:opacity-90"
            >
              {slide.imageUri ? (
                <Image
                  source={{ uri: slide.imageUri }}
                  className="h-full w-full"
                  resizeMode="cover"
                />
              ) : null}
            </Pressable>
          </View>
        ))}
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
