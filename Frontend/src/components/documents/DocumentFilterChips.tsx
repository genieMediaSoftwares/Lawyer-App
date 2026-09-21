import React from 'react';
import { Pressable, ScrollView, View } from 'react-native';
import { GenieText } from '../ui';

export type DocumentFilterType = 'All' | 'PDF' | 'DOCX' | 'Images' | 'TXT';

const FILTER_TYPES: DocumentFilterType[] = ['All', 'PDF', 'DOCX', 'Images', 'TXT'];

export interface DocumentFilterChipsProps {
  selectedFilter: DocumentFilterType;
  onSelectFilter: (filter: DocumentFilterType) => void;
}

export const DocumentFilterChips: React.FC<DocumentFilterChipsProps> = ({
  selectedFilter,
  onSelectFilter,
}) => {
  return (
    <View className="py-2.5">
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerClassName="px-5 gap-2 flex-row items-center"
      >
        {FILTER_TYPES.map(filter => {
          const isSelected = selectedFilter === filter;
          return (
            <Pressable
              key={filter}
              onPress={() => onSelectFilter(filter)}
              accessibilityRole="button"
              accessibilityState={{ selected: isSelected }}
              className={`h-9 items-center justify-center rounded-pill border px-4 active:opacity-80 ${
                isSelected
                  ? 'border-gold bg-gold-muted/40'
                  : 'border-border bg-[#151515]'
              }`}
            >
              <GenieText
                variant="body-sm"
                tone={isSelected ? 'gold' : 'secondary'}
                className={isSelected ? 'font-bold' : 'font-medium'}
              >
                {filter}
              </GenieText>
            </Pressable>
          );
        })}
      </ScrollView>
    </View>
  );
};
