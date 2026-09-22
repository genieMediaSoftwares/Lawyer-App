import React, { useState } from 'react';
import { Pressable, RefreshControl, ScrollView, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';

import {
  GenieErrorState,
  GenieHeader,
  GenieScreen,
  GenieSkeleton,
  GenieText,
} from '../../../components';
import { lawyerApi } from '../../../api/lawyerApi';
import type { LawyerStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';
import { PlanCard } from './PlanCard';
import type { PlanItem } from './types';

export type { PlanItem };

const CATALOG_PLANS: PlanItem[] = [
  {
    id: 'Starter',
    name: 'Starter',
    price: '₹999 / month',
    amount: 999,
    features: ['Chat Support', 'Basic Profile Listing'],
  },
  {
    id: 'Professional',
    name: 'Professional',
    price: '₹2,999 / month',
    amount: 2999,
    features: ['Priority Support', 'Featured in Search'],
  },
  {
    id: 'Premium',
    name: 'Premium',
    price: '₹5,999 / month',
    amount: 5999,
    popular: true,
    features: ['Verified Badge', 'Priority Support', 'Featured Listing', 'Profile Highlight'],
  },
  {
    id: 'Elite',
    name: 'Elite',
    price: '₹12,999 / month',
    amount: 12999,
    features: ['Verified Badge', 'Top Ranking', 'Featured Profile', 'Dedicated Manager'],
  },
];

export const SubscriptionScreen: React.FC<
  LawyerStackScreenProps<'Subscription'>
> = ({ navigation }) => {
  const insets = useSafeAreaInsets();

  const subscriptionQuery = useQuery({
    queryKey: ['subscription'],
    queryFn: lawyerApi.getSubscription,
  });

  const [selectedPlanId, setSelectedPlanId] = useState<string>('Premium');

  const header = (
    <GenieHeader title="Subscription Plans" onBack={() => navigation.goBack()} />
  );

  if (subscriptionQuery.isLoading) {
    return (
      <GenieScreen header={header} dismissKeyboardOnTap={false}>
        <View className="px-5 py-3">
          <GenieSkeleton className="h-6 w-3/4 mb-4" />
          <GenieSkeleton className="h-36 w-full rounded-card mb-4" />
          <GenieSkeleton className="h-36 w-full rounded-card mb-4" />
          <GenieSkeleton className="h-44 w-full rounded-card" />
        </View>
      </GenieScreen>
    );
  }

  if (subscriptionQuery.isError) {
    return (
      <GenieScreen header={header} dismissKeyboardOnTap={false}>
        <View className="px-5 py-3">
          <GenieErrorState
            title="Subscription Error"
            message={(subscriptionQuery.error as Error).message}
            onRetry={() => subscriptionQuery.refetch()}
          />
        </View>
      </GenieScreen>
    );
  }

  const activePlanName = subscriptionQuery.data?.plan;

  return (
    <View className="flex-1 bg-background">
      <GenieScreen header={header} dismissKeyboardOnTap={false} padded={false}>
        <View className="flex-1">
          <ScrollView
            className="flex-1 px-5"
            contentContainerClassName="pt-2 pb-32"
            showsVerticalScrollIndicator={false}
            refreshControl={
              <RefreshControl
                refreshing={subscriptionQuery.isRefetching}
                onRefresh={() => {
                  void subscriptionQuery.refetch();
                }}
                tintColor={colors.gold}
                colors={[colors.gold]}
              />
            }
          >
            <GenieText variant="body-md" tone="secondary" className="mb-5 leading-5 font-normal">
              Choose the plan that's right for your practice
            </GenieText>

            {CATALOG_PLANS.map(plan => (
              <PlanCard
                key={plan.id}
                plan={plan}
                isSelected={selectedPlanId === plan.id}
                isActivePlan={activePlanName === plan.id}
                onPress={() => setSelectedPlanId(plan.id)}
              />
            ))}
          </ScrollView>

          <View
            className="absolute bottom-0 left-0 right-0 border-t border-border bg-background px-5 pt-3"
            style={{ paddingBottom: Math.max(insets.bottom, 16) }}
          >
            <Pressable
              onPress={() => {
                navigation.goBack();
              }}
              accessibilityRole="button"
              accessibilityLabel="Continue"
              className="h-14 w-full items-center justify-center rounded-control bg-gold active:bg-gold-pressed"
            >
              <GenieText variant="body-lg" tone="on-gold" className="font-bold">
                Continue
              </GenieText>
            </Pressable>
          </View>
        </View>
      </GenieScreen>
    </View>
  );
};
