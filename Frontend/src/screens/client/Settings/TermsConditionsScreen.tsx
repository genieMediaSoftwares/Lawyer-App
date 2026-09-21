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

export const TermsConditionsScreen: React.FC<
  ClientStackScreenProps<'TermsConditions'>
> = ({ navigation }) => (
  <GenieScreen
    scrollable
    dismissKeyboardOnTap={false}
    header={
      <GenieHeader title="Terms & Conditions" onBack={() => navigation.goBack()} />
    }
    contentContainerClassName="pb-10"
  >
    <GenieText variant="caption" tone="gold" className="mb-3 font-medium">
      Last updated: September 20, 2026
    </GenieText>

    <Section title="1. Acceptance of Terms">
      <GenieText variant="body-sm" tone="secondary">
        By accessing or using the GenieLaw application, you agree to be bound by
        these Terms &amp; Conditions. If you do not agree, you may not use our
        services.
      </GenieText>
    </Section>

    <Section title="2. Scope of Services">
      <GenieText variant="body-sm" tone="secondary">
        GenieLaw provides a platform connecting clients with independent legal
        practitioners and offers AI-driven document organization tools. GenieLaw
        is not a law firm and does not provide formal legal advice directly.
      </GenieText>
    </Section>

    <Section title="3. Advocate Engagements">
      <GenieText variant="body-sm" tone="secondary">
        Any legal representation or advisory agreement formed through GenieLaw
        is solely between the client and the respective advocate. Advocates
        listed on GenieLaw are independent professionals responsible for their
        own services.
      </GenieText>
    </Section>

    <Section title="4. User Responsibilities">
      <GenieText variant="body-sm" tone="secondary">
        You agree to provide accurate, truthful information when posting cases
        or contacting advocates. Misuse, spam, or fraudulent posting is strictly
        prohibited and subject to immediate account termination.
      </GenieText>
    </Section>

    <Section title="5. Limitation of Liability">
      <GenieText variant="body-sm" tone="secondary">
        GenieLaw shall not be liable for any indirect, incidental, or
        consequential damages arising from advocate consultations or AI
        automated document summaries.
      </GenieText>
    </Section>
  </GenieScreen>
);
