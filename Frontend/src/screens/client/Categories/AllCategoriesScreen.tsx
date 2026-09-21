import React, { useMemo, useState } from 'react';
import { FlatList, Pressable, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import {
  GenieEmptyState,
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

      <View className="px-5 pb-2 pt-1">
        <GenieSearchInput
          placeholder="Search categories..."
          value={searchQuery}
          onChangeText={setSearchQuery}
          onClear={() => setSearchQuery('')}
        />
      </View>

      <FlatList
        data={filteredCategories as LegalCategory[]}
        keyExtractor={item => item.id}
        numColumns={2}
        columnWrapperClassName="gap-3"
        contentContainerClassName="gap-3 px-5 pb-6"
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        ListEmptyComponent={
          <GenieEmptyState
            title="No categories found"
            description="Try a different search term."
          />
        }
        renderItem={({ item }) => {
          const IconComponent = getCategoryIcon(item.id);

          return (
            <Pressable
              onPress={() => handleSelectCategory(item)}
              accessibilityRole="button"
              accessibilityLabel={item.title}
              className="min-h-[110px] flex-1 items-center justify-center rounded-card border border-border bg-surface p-3 active:border-gold active:bg-surface-alt"
            >
              <View className="h-11 w-11 items-center justify-center rounded-full bg-gold-muted">
                <IconComponent size={24} color={colors.gold} />
              </View>
              <GenieText
                variant="body-sm"
                className="mt-1 text-center font-medium"
                numberOfLines={2}
              >
                {item.title}
              </GenieText>
            </Pressable>
          );
        }}
      />
    </SafeAreaView>
  );
};
