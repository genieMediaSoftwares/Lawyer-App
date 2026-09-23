import React from 'react';
import { SafeAreaView } from 'react-native-safe-area-context';

import { GenieHeader, LegalDocumentView } from '../../../components';
import { useAuthStore } from '../../../store/authStore';
import type { ClientStackScreenProps } from '../../../types/navigation';

// Shows the version the operator currently publishes, not text baked into the
// app, so the wording and its effective date stay under their control.
export const TermsConditionsScreen: React.FC<
  ClientStackScreenProps<'TermsConditions'>
> = ({ navigation }) => {
  const role = useAuthStore(state => state.user?.role);

  return (
    <SafeAreaView edges={['top']} className="flex-1 bg-background">
      <GenieHeader title="Terms & Conditions" onBack={() => navigation.goBack()} />
      <LegalDocumentView
        type={role === 'lawyer' ? 'lawyer_terms' : 'client_terms'}
        emptyDescription="The terms have not been published yet. They will appear here once available."
      />
    </SafeAreaView>
  );
};
