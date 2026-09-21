import React, { useRef, useState } from 'react';
import { LayoutAnimation, Platform, Pressable, ScrollView, UIManager, View } from 'react-native';

import { GenieText } from '../../../../components';
import { getCategoryIcon } from '../../../../components/icons/CategoryIcons';
import { ChevronRightIcon } from '../../../../components/icons/ClientIcons';
import { ChevronDownIcon } from '../../../../components/icons/Icons';
import { orderedCategories, type LegalCategory } from '../../../../constants/categories';
import type { PostCaseState } from '../types';
import { colors } from '../../../../theme';

if (
  Platform.OS === 'android' &&
  UIManager.setLayoutAnimationEnabledExperimental
) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

interface CategoryStepProps {
  state: PostCaseState;
  onChange: (patch: Partial<PostCaseState>) => void;
}

const CategoryRow: React.FC<{
  category: LegalCategory;
  isSelected: boolean;
  isExpanded: boolean;
  selectedSubType: string;
  onToggle: () => void;
  onPickSubType: (subType: string) => void;
  onLayoutY: (y: number) => void;
}> = ({
  category,
  isSelected,
  isExpanded,
  selectedSubType,
  onToggle,
  onPickSubType,
  onLayoutY,
}) => {
  const Icon = getCategoryIcon(category.id);
  const highlighted = isSelected || isExpanded;

  return (
    <View
      onLayout={event => onLayoutY(event.nativeEvent.layout.y)}
      className={`mb-3 overflow-hidden rounded-card border ${
        highlighted ? 'border-gold bg-card' : 'border-border bg-card'
      }`}
    >
      <Pressable
        onPress={onToggle}
        accessibilityRole="button"
        accessibilityState={{ selected: isSelected, expanded: isExpanded }}
        accessibilityLabel={category.title}
        className="min-h-touch flex-row items-center gap-3 px-4 py-4 active:opacity-80"
      >
        <Icon size={24} color={highlighted ? colors.gold : colors.textSecondary} />

        <GenieText
          variant="heading-sm"
          tone={highlighted ? 'gold' : 'primary'}
          className="flex-1"
          numberOfLines={1}
        >
          {category.title}
        </GenieText>

        {isExpanded ? (
          <ChevronDownIcon size={18} color={colors.textSecondary} />
        ) : (
          <ChevronRightIcon size={18} color={colors.textSecondary} />
        )}
      </Pressable>

      {isExpanded ? (
        <View className="px-4 pb-4">
          <View className="mb-3 h-px bg-border" />

          {category.subTypes.map(subType => {
            const active = selectedSubType === subType;
            return (
              <Pressable
                key={subType}
                onPress={() => onPickSubType(subType)}
                accessibilityRole="button"
                accessibilityState={{ selected: active }}
                className={`mb-2 min-h-touch justify-center rounded-control border px-4 py-3 active:opacity-80 ${
                  active
                    ? 'border-gold bg-gold-muted'
                    : 'border-border bg-surface'
                }`}
              >
                <GenieText
                  variant="body-md"
                  tone={active ? 'gold' : 'secondary'}
                  className={active ? 'font-semibold' : ''}
                >
                  {subType}
                </GenieText>
              </Pressable>
            );
          })}
        </View>
      ) : null}
    </View>
  );
};

export const CategoryStep: React.FC<CategoryStepProps> = ({
  state,
  onChange,
}) => {
  const [expandedId, setExpandedId] = useState<string>(
    state.categoryId && !state.subcategory ? state.categoryId : '',
  );

  const scrollRef = useRef<React.ComponentRef<typeof ScrollView>>(null);
  const hasScrolledRef = useRef(false);
  const presetId = useRef(
    state.categoryId && !state.subcategory ? state.categoryId : '',
  ).current;

  const handleRowLayout = (categoryId: string, y: number) => {
    if (!presetId || hasScrolledRef.current || categoryId !== presetId) {
      return;
    }
    hasScrolledRef.current = true;
    scrollRef.current?.scrollTo({ y: Math.max(0, y - 12), animated: false });
  };

  const categories = orderedCategories();

  const toggle = (category: LegalCategory) => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setExpandedId(current => (current === category.id ? '' : category.id));
  };

  const pickSubType = (category: LegalCategory, subType: string) => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setExpandedId('');
    onChange({
      categoryId: category.id,
      category: category.title,
      subcategory: subType,
      ...(category.id !== state.categoryId
        ? { selectedLawyer: null }
        : {}),
    });
  };

  return (
    <ScrollView
      ref={scrollRef}
      className="flex-1"
      contentContainerClassName="px-5 pb-6 pt-5"
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      <GenieText variant="heading-lg" className="mb-4">
        Select Category
      </GenieText>

      {categories.map(category => (
        <CategoryRow
          key={category.id}
          category={category}
          onLayoutY={y => handleRowLayout(category.id, y)}
          isSelected={state.categoryId === category.id && Boolean(state.subcategory)}
          isExpanded={expandedId === category.id}
          selectedSubType={
            state.categoryId === category.id ? state.subcategory : ''
          }
          onToggle={() => toggle(category)}
          onPickSubType={subType => pickSubType(category, subType)}
        />
      ))}
    </ScrollView>
  );
};
