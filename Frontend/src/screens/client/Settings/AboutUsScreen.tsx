import React from 'react';
import { View } from 'react-native';

import {
  ContactSupportRows,
  GenieCard,
  GenieHeader,
  GenieScreen,
  GenieSettingsGroup,
  GenieText,
  Logo,
} from '../../../components';
import { env } from '../../../config/env';
import type { ClientStackScreenProps } from '../../../types/navigation';

const Bullet: React.FC<{ children: string }> = ({ children }) => (
  <View className="mb-2 flex-row items-start">
    <View className="mr-2 mt-2 h-1.5 w-1.5 rounded-full bg-gold" />
    <GenieText variant="body-sm" tone="secondary" className="flex-1">
      {children}
    </GenieText>
  </View>
);

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

export const AboutUsScreen: React.FC<ClientStackScreenProps<'AboutUs'>> = ({
  navigation,
}) => (
  <GenieScreen
    scrollable
    dismissKeyboardOnTap={false}
    header={<GenieHeader title="About GenieLaw" onBack={() => navigation.goBack()} />}
    contentContainerClassName="pb-10"
  >
      <View className="my-3 items-center">
        <Logo size={64} />
        <GenieText variant="heading-md" className="mt-2 tracking-[2px]">
          GENIE LAW
        </GenieText>
        <GenieText variant="caption" tone="gold" className="mt-1">
          AI-Powered Legal Marketplace &amp; Case Assistant
        </GenieText>
        <GenieText variant="caption" tone="muted" className="mt-1 text-[10px]">
          Version {env.appVersion}
        </GenieText>
      </View>

      <Section title="OUR MISSION">
        <GenieText variant="body-sm" tone="secondary">
          GenieLaw is dedicated to democratizing legal assistance by connecting
          clients directly with top verified advocates and empowering both
          parties with cutting-edge AI legal analysis tools.
        </GenieText>
      </Section>

      <Section title="KEY FEATURES">
        <Bullet>
          AI Smart Case Assistant for document summary and legal drafting
        </Bullet>
        <Bullet>
          Direct advocate search, rating reviews, and consultation booking
        </Bullet>
        <Bullet>
          Secure encrypted document repository and message encryption
        </Bullet>
        <Bullet>
          Real-time notifications for hearing dates and case updates
        </Bullet>
      </Section>

      <GenieSettingsGroup title="CONTACT SUPPORT">
        <ContactSupportRows />
      </GenieSettingsGroup>
  </GenieScreen>
);
