import React from 'react';
import { SafeAreaView } from 'react-native-safe-area-context';

import { GenieHeader, LegalDocumentView } from '../../../components';
import type { ClientStackScreenProps } from '../../../types/navigation';

// Shows the published privacy policy from the backend rather than text baked
// into the app.
export const PrivacyPolicyScreen: React.FC<
  ClientStackScreenProps<'PrivacyPolicy'>
> = ({ navigation }) => (
  <SafeAreaView edges={['top']} className="flex-1 bg-background">
    <GenieHeader title="Privacy Policy" onBack={() => navigation.goBack()} />
    <LegalDocumentView
      type="privacy_policy"
      emptyDescription="The privacy policy has not been published yet. It will appear here once available."
    />
  </SafeAreaView>
);
