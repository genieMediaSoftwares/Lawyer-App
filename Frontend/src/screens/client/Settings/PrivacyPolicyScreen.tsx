import React from 'react';

import {
  GenieCard,
  GenieHeader,
  GenieScreen,
  GenieText,
} from '../../../components';
import type { ClientStackScreenProps } from '../../../types/navigation';

const Section: React.FC<{ title: string; children: React.ReactNode }> = ({
  title,
  children,
}) => (
  <GenieCard tone="surface" className="mb-3 p-5">
    <GenieText variant="caption" tone="gold" className="mb-2 font-bold tracking-widest">
      {title}
    </GenieText>
    {children}
  </GenieCard>
);

export const PrivacyPolicyScreen: React.FC<
  ClientStackScreenProps<'PrivacyPolicy'>
> = ({ navigation }) => (
  <GenieScreen
    scrollable
    dismissKeyboardOnTap={false}
    header={<GenieHeader title="Privacy Policy" onBack={() => navigation.goBack()} />}
    contentContainerClassName="pb-10"
  >
    <GenieText variant="caption" tone="gold" className="mb-3 font-medium">
      Last updated: September 20, 2026
    </GenieText>

    <Section title="1. Information We Collect">
      <GenieText variant="body-sm" tone="secondary">
        We collect information you provide directly, including your name, email
        address, mobile number, uploaded documents, case descriptions, and
        messaging history with advocates.
      </GenieText>
    </Section>

    <Section title="2. How We Use Your Data">
      <GenieText variant="body-sm" tone="secondary">
        Your data is used strictly to provide legal matching services, power our
        AI Smart Case Assistant, enable secure communication with verified
        advocates, and manage your account.
      </GenieText>
    </Section>

    <Section title="3. Data Encryption &amp; Confidentiality">
      <GenieText variant="body-sm" tone="secondary">
        All sensitive legal files and messages are encrypted in transit and at
        rest using bank-grade AES-256 encryption. Attorney-client privilege
        standards are respected across all communications.
      </GenieText>
    </Section>

    <Section title="4. Third-Party Sharing">
      <GenieText variant="body-sm" tone="secondary">
        GenieLaw does not sell, rent, or trade your personal or case information
        to third-party advertisers. Information is shared only with advocates
        you explicitly contact or retain.
      </GenieText>
    </Section>

    <Section title="5. Your Rights &amp; Account Deletion">
      <GenieText variant="body-sm" tone="secondary">
        You retain full ownership of your data. You may request export or
        complete permanent deletion of your account and documents at any time
        from your Account Settings.
      </GenieText>
    </Section>
  </GenieScreen>
);
