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
import { CheckCircleIcon } from '../../../components/icons/LawyerIcons';
import { lawyerApi } from '../../../api/lawyerApi';
import type { LawyerStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';

export interface PlanItem {
  id: string;
  name: string;
  price: string;
  amount: number;
  popular?: boolean;
  features: string[];
}

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
    features: ['Priority Support', 'Featured Listing', 'Profile Highlight'],
  },
  {
    id: 'Elite',
    name: 'Elite',
    price: '₹12,999 / month',
    amount: 12999,
    features: ['Top Ranking', 'Featured Profile', 'Dedicated Manager'],
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

            {CATALOG_PLANS.map(plan => {
              const isSelected = selectedPlanId === plan.id;
              const isActivePlan = activePlanName === plan.id;

              return (
                <Pressable
                  key={plan.id}
                  onPress={() => setSelectedPlanId(plan.id)}
                  accessibilityRole="radio"
                  accessibilityState={{ selected: isSelected }}
                  className={`relative mb-4 rounded-card bg-card p-5 ${
                    isSelected
                      ? 'border-2 border-gold shadow-md'
                      : 'border border-border active:border-border/80'
                  }`}
                >
                  {/* MOST POPULAR BADGE */}
                  {plan.popular ? (
                    <View className="absolute right-0 top-0 bg-gold px-3 py-1 rounded-tr-[18px] rounded-bl-xl shadow-sm">
                      <GenieText variant="caption" tone="on-gold" className="font-bold">
                        Most Popular
                      </GenieText>
                    </View>
                  ) : isActivePlan ? (
                    <View className="absolute right-0 top-0 bg-gold-muted px-3 py-1 rounded-tr-[18px] rounded-bl-xl border-l border-b border-gold/30">
                      <GenieText variant="caption" tone="gold" className="font-bold">
                        Active Plan
                      </GenieText>
                    </View>
                  ) : null}

                  {/* TITLE & PRICE */}
                  <View className="flex-row items-center justify-between pr-20">
                    <GenieText variant="heading-md" className="font-bold text-white">
                      {plan.name}
                    </GenieText>

                    <GenieText variant="heading-md" className="font-bold text-white">
                      {plan.price}
                    </GenieText>
                  </View>

                  {/* FEATURES LIST */}
                  <View className="mt-4 gap-2.5">
                    {plan.features.map((feature, idx) => (
                      <View key={idx} className="flex-row items-center">
                        <CheckCircleIcon size={18} color={colors.success} />
                        <GenieText
                          variant="body-sm"
                          tone="secondary"
                          className="ml-2.5 font-medium"
                        >
                          {feature}
                        </GenieText>
                      </View>
                    ))}
                  </View>
                </Pressable>
              );
            })}
          </ScrollView>

          {/* FIXED BOTTOM CONTINUE BUTTON */}
          <View
            className="absolute bottom-0 left-0 right-0 border-t border-border/40 bg-background px-5 pt-3"
            style={{ paddingBottom: Math.max(insets.bottom, 16) }}
          >
            <Pressable
              onPress={() => {
                // Return to previous screen or show selection confirmation
                navigation.goBack();
              }}
              accessibilityRole="button"
              accessibilityLabel="Continue"
              className="h-14 w-full items-center justify-center rounded-control bg-gold active:bg-gold-pressed shadow-md"
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
