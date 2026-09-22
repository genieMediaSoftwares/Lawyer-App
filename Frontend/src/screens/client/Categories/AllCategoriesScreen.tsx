import React, { useMemo, useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import {
  GenieEmptyState,
  GenieGrid,
  GenieHeader,
  GenieSearchInput,
  GenieText,
} from '../../../components';
import { getCategoryIcon } from '../../../components/icons/CategoryIcons';
import {
  LEGAL_CATEGORIES,
  type LegalCategory,
} from '../../../constants/categories';
import type { ClientStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

const GRID_COLUMNS = 4;
const GRID_GAP = 12;

export const AllCategoriesScreen: React.FC<
  ClientStackScreenProps<'AllCategories'>
> = ({ navigation }) => {
  const [searchQuery, setSearchQuery] = useState('');

  const filteredCategories = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) {
      return LEGAL_CATEGORIES;
    }
    return LEGAL_CATEGORIES.filter(
      c =>
        c.title.toLowerCase().includes(q) ||
        c.slug.toLowerCase().includes(q) ||
        c.id.toLowerCase().includes(q),
    );
  }, [searchQuery]);

  const handleSelectCategory = (category: LegalCategory) => {
    navigation.navigate('PostCase', {
      start: 'manual',
      categoryId: category.id,
    });
  };

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      <GenieHeader title="All Categories" onBack={() => navigation.goBack()} />

      <View className="px-4 pb-3 pt-1">
        <GenieSearchInput
          placeholder="Search categories..."
          value={searchQuery}
          onChangeText={setSearchQuery}
          onClear={() => setSearchQuery('')}
        />
      </View>

      <ScrollView
        contentContainerClassName="px-4 pb-8"
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <GenieGrid
          testID="all-categories-grid"
          data={filteredCategories as LegalCategory[]}
          keyExtractor={item => item.id}
          numColumns={GRID_COLUMNS}
          gap={GRID_GAP}
          emptyComponent={
            <GenieEmptyState
              title="No categories found"
              description="Try a different search term."
            />
          }
          renderItem={item => {
            const IconComponent = getCategoryIcon(item.id);

            return (
              <Pressable
                onPress={() => handleSelectCategory(item)}
                accessibilityRole="button"
                accessibilityLabel={item.title}
                className="items-center"
              >
                {/* Square icon container — always the same size as every
                    other item in the grid, regardless of row completeness
                    or how long this category's name is. */}
                <View className="aspect-square w-full items-center justify-center rounded-card border border-border bg-surface active:bg-surface-secondary">
                  <IconComponent size={26} color={colors.gold} />
                </View>

                {/* Text area matches the icon card's width; long names wrap
                    instead of resizing the card or truncating. */}
                <GenieText
                  variant="caption"
                  className="mt-2 w-full text-center font-medium"
                >
                  {item.title}
                </GenieText>
              </Pressable>
            );
          }}
        />
      </ScrollView>
    </SafeAreaView>
  );
};
