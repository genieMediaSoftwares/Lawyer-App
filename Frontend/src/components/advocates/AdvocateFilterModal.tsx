import React, { useMemo, useState } from 'react';
import { ScrollView, View } from 'react-native';
import { useQuery } from '@tanstack/react-query';
import {
  GenieBottomSheet,
  GenieButton,
  GenieChip,
  GenieText,
} from '../ui';
import { StarIcon } from '../icons/ClientIcons';
import { LEGAL_CATEGORIES } from '../../constants/categories';
import { colors } from '../../theme';
import { advocatesApi } from '../../api/advocatesApi';
import type { AdvocateFilters, ExperienceBucket } from '../../api/advocatesApi';

export interface AdvocateFilterModalProps {
  visible: boolean;
  filters: AdvocateFilters;
  onClose: () => void;
  onApply: (filters: AdvocateFilters) => void;
  onReset: () => void;
}

const ALL_LOCATIONS = 'All Locations';

/**
 * The location chips are the distinct `user.location` values of the advocates
 * the backend actually has, not a fixed list of cities.
 *
 * No endpoint lists locations: the controller just matches `location` as a
 * case-insensitive regex against `User.location`. A hand-written city list
 * therefore offered cities with no advocates (an empty result every time) and
 * hid cities that do have them. Reading the unfiltered list uses the same
 * query key as AdvocatesScreen's first load, so it is normally a cache hit
 * rather than a second request.
 */
const useAdvocateLocations = (enabled: boolean): string[] => {
  const query = useQuery({
    queryKey: ['advocates', {}],
    queryFn: () => advocatesApi.list({}),
    enabled,
  });

  return useMemo(() => {
    const seen = new Map<string, string>();
    for (const advocate of query.data ?? []) {
      const raw = advocate.user?.location?.trim();
      if (raw && !seen.has(raw.toLowerCase())) {
        seen.set(raw.toLowerCase(), raw);
      }
    }
    return [...seen.values()].sort((a, b) => a.localeCompare(b));
  }, [query.data]);
};

const EXPERIENCE_OPTIONS: Array<{ label: string; value?: ExperienceBucket }> = [
  { label: 'All Experience', value: undefined },
  { label: '0-2 Years', value: '0-2' },
  { label: '3-5 Years', value: '3-5' },
  { label: '5-10 Years', value: '5-10' },
  { label: '10+ Years', value: '10+' },
];

/**
 * The rating filter.
 *
 * `value` is what goes to the backend and must stay exactly as it is: the
 * advocates controller strips "★+" from the string and parses the number in
 * front of it, so "4★+" is part of the API contract rather than a label.
 * `label` is what the user reads, and the star beside it is drawn as an icon —
 * which is why the two are separate fields now.
 */
const RATING_OPTIONS: Array<{ label: string; value?: string }> = [
  { label: 'All Ratings', value: undefined },
  { label: '4 & up', value: '4★+' },
  { label: '3 & up', value: '3★+' },
  { label: '2 & up', value: '2★+' },
  { label: '1 & up', value: '1★+' },
];

const FEE_RANGES: Array<{ label: string; min?: number; max?: number }> = [
  // No bounds sent, so every fee matches. It used to read "₹0 - ₹5000", which
  // promised a cap the request never applied.
  { label: 'Any Fee', min: undefined, max: undefined },
  { label: 'Under ₹1000', min: 0, max: 1000 },
  { label: '₹1000 - ₹2500', min: 1000, max: 2500 },
  { label: '₹2500 - ₹5000', min: 2500, max: 5000 },
  { label: '₹5000+', min: 5000, max: undefined },
];

const Group: React.FC<{
  label: string;
  children: React.ReactNode;
  trailing?: React.ReactNode;
}> = ({ label, children, trailing }) => (
  <View className="mb-5">
    <View className="mb-2 flex-row items-center justify-between">
      <GenieText variant="label">{label}</GenieText>
      {trailing}
    </View>
    {children}
  </View>
);

export const AdvocateFilterModal: React.FC<AdvocateFilterModalProps> = ({
  visible,
  filters,
  onClose,
  onApply,
  onReset,
}) => {
  const [specialization, setSpecialization] = useState<string | undefined>(
    filters.specialization,
  );
  const [location, setLocation] = useState<string | undefined>(filters.location);
  const knownLocations = useAdvocateLocations(visible);
  // Keep an already-applied location selectable even if no advocate currently
  // lists it, so reopening the sheet never silently drops the active filter.
  const locations =
    location && !knownLocations.includes(location)
      ? [location, ...knownLocations]
      : knownLocations;
  const [experience, setExperience] = useState<ExperienceBucket | undefined>(
    filters.experience,
  );
  const [rating, setRating] = useState<string | undefined>(filters.rating);
  const [feeIndex, setFeeIndex] = useState(0);

  const handleApply = () => {
    const selectedFee = FEE_RANGES[feeIndex];
    onApply({
      ...filters,
      specialization,
      location,
      experience,
      rating,
      minFee: selectedFee?.min,
      maxFee: selectedFee?.max,
    });
    onClose();
  };

  const handleReset = () => {
    setSpecialization(undefined);
    setLocation(undefined);
    setExperience(undefined);
    setRating(undefined);
    setFeeIndex(0);
    onReset();
    onClose();
  };

  return (
    <GenieBottomSheet
      visible={visible}
      onClose={onClose}
      title="Filter Advocates"
      footer={
        <View className="flex-row gap-3">
          <GenieButton
            label="Reset"
            variant="outline"
            onPress={handleReset}
            className="flex-1"
          />
          <GenieButton
            label="Apply Filters"
            onPress={handleApply}
            className="flex-1"
          />
        </View>
      }
    >
      <ScrollView
        className="max-h-[420px]"
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <Group label="Practice Area">
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerClassName="gap-2 pr-2"
          >
            <GenieChip
              label="All Practice Areas"
              selected={!specialization}
              onPress={() => setSpecialization(undefined)}
            />
            {LEGAL_CATEGORIES.map(cat => (
              <GenieChip
                key={cat.id}
                label={cat.title}
                selected={specialization === cat.title}
                onPress={() =>
                  setSpecialization(
                    specialization === cat.title ? undefined : cat.title,
                  )
                }
              />
            ))}
          </ScrollView>
        </Group>

        <Group label="Location">
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerClassName="gap-2 pr-2"
          >
            {[ALL_LOCATIONS, ...locations].map(loc => {
              const isAll = loc === ALL_LOCATIONS;
              return (
                <GenieChip
                  key={loc}
                  label={loc}
                  selected={isAll ? !location : location === loc}
                  onPress={() => setLocation(isAll ? undefined : loc)}
                />
              );
            })}
          </ScrollView>
        </Group>

        <Group label="Experience">
          <View className="flex-row flex-wrap gap-2">
            {EXPERIENCE_OPTIONS.map(exp => (
              <GenieChip
                key={exp.label}
                label={exp.label}
                selected={experience === exp.value}
                onPress={() => setExperience(exp.value)}
              />
            ))}
          </View>
        </Group>

        <Group label="Rating">
          <View className="flex-row flex-wrap gap-2">
            {RATING_OPTIONS.map(option => {
              const isSelected = option.value
                ? rating === option.value
                : !rating;
              return (
                <GenieChip
                  key={option.label}
                  label={option.label}
                  selected={isSelected}
                  icon={
                    option.value ? (
                      <StarIcon
                        size={13}
                        color={isSelected ? colors.gold : colors.textSecondary}
                      />
                    ) : undefined
                  }
                  onPress={() => setRating(option.value)}
                />
              );
            })}
          </View>
        </Group>

        <Group
          label="Consultation Fee"
          trailing={
            <GenieText variant="body-sm" tone="gold" className="font-semibold">
              {FEE_RANGES[feeIndex]?.label ?? FEE_RANGES[0].label}
            </GenieText>
          }
        >
          <View className="flex-row flex-wrap gap-2">
            {FEE_RANGES.map((fee, idx) => (
              <GenieChip
                key={fee.label}
                label={fee.label}
                selected={feeIndex === idx}
                onPress={() => setFeeIndex(idx)}
              />
            ))}
          </View>
        </Group>
      </ScrollView>
    </GenieBottomSheet>
  );
};
