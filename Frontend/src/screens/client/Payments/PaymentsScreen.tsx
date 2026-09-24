import React, { useMemo, useState } from 'react';
import { FlatList, View } from 'react-native';
import { useQuery } from '@tanstack/react-query';

import {
  GenieButton,
  GenieEmptyState,
  GenieErrorState,
  GenieFilterTabs,
  GenieHeader,
  GenieRefreshControl,
  GenieSkeletonList,
  GenieStatusBadge,
  GenieText,
} from '../../../components';
import { GenieCard } from '../../../components/ui/GenieCard';
import { paymentsApi } from '../../../api/paymentsApi';
import { toAppError } from '../../../utils/errors';
import type { PaymentRecord } from '../../../types/domain';
import type { ClientStackScreenProps } from '../../../types/navigation';

type Tab = 'all' | 'completed' | 'pending' | 'refunded';

const TABS: ReadonlyArray<{ key: Tab; label: string }> = [
  { key: 'all', label: 'All' },
  { key: 'completed', label: 'Completed' },
  { key: 'pending', label: 'Pending' },
  { key: 'refunded', label: 'Refunded' },
];

export const PaymentsScreen: React.FC<ClientStackScreenProps<'Payments'>> = ({ navigation }) => {
  const [tab, setTab] = useState<Tab>('all');

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['payments'],
    queryFn: paymentsApi.list,
  });

  const payments = data ?? [];

  const filtered = useMemo(() => {
    if (tab === 'all') return payments;
    return payments.filter((p) => {
      if (tab === 'refunded') return p.status === 'refunded';
      return p.status === tab;
    });
  }, [payments, tab]);

  const renderItem = ({ item }: { item: PaymentRecord }) => (
    <GenieCard className="mb-3">
      <View className="flex-row items-start justify-between">
        <View className="flex-1">
          <GenieText variant="body" className="font-semibold">
            {item.lawyer?.fullName ?? 'Advocate'}
          </GenieText>
          <GenieText variant="caption" tone="muted">
            {item.purpose === 'subscription' ? 'Subscription' : 'Consultation'}
            {item.appointment ? ' · Appointment' : ''}
            {item.case ? ' · Case' : ''}
          </GenieText>
          <GenieText variant="caption" tone="muted" className="mt-1">
            {new Date(item.createdAt || Date.now()).toLocaleDateString('en-IN', {
              day: 'numeric', month: 'short', year: 'numeric',
            })}
          </GenieText>
        </View>
        <View className="items-end">
          <GenieText variant="body" className="font-semibold" tone={item.status === 'refunded' ? 'error' : 'primary'}>
            ₹{item.amount.toLocaleString('en-IN')}
          </GenieText>
          <View className="mt-1">
            <GenieStatusBadge status={item.status} />
          </View>
        </View>
      </View>
      {item.paymentMethod ? (
        <GenieText variant="caption" tone="muted" className="mt-2">
          {item.paymentMethod}
        </GenieText>
      ) : null}
    </GenieCard>
  );

  if (isLoading) {
    return (
      <View className="flex-1 bg-background">
        <GenieHeader title="Payments" onBack={() => navigation.goBack()} />
        <View className="px-5 pt-2">
          <GenieFilterTabs tabs={TABS} value={tab} onChange={setTab} />
        </View>
        <GenieSkeletonList count={4} />
      </View>
    );
  }

  if (error) {
    return (
      <View className="flex-1 bg-background">
        <GenieHeader title="Payments" onBack={() => navigation.goBack()} />
        <GenieErrorState
          title="Failed to load payments"
          message={toAppError(error).message}
          onRetry={() => refetch()}
        />
      </View>
    );
  }

  return (
    <View className="flex-1 bg-background">
      <GenieHeader title="Payments" onBack={() => navigation.goBack()} />
      <View className="px-5 pt-2">
        <GenieFilterTabs tabs={TABS} value={tab} onChange={setTab} />
      </View>
      <FlatList
        data={filtered}
        keyExtractor={(item) => item._id}
        renderItem={renderItem}
        ListEmptyComponent={
          <GenieEmptyState
            title="No payments yet"
            description="Your payment history will appear here after booking consultations."
          />
        }
        refreshControl={<GenieRefreshControl onRefresh={() => refetch()} />}
        contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 24, flexGrow: filtered.length ? undefined : 1 }}
      />
    </View>
  );
};
