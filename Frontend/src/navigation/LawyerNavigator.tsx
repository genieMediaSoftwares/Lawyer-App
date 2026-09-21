import React, { useCallback, useMemo, useState } from 'react';
import { View } from 'react-native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { useQuery } from '@tanstack/react-query';

import { GenieDrawer, LawyerBottomNavigation } from '../components/navigation';
import { ProfileImageModal } from '../components/ui/ProfileImageModal';
import {
  BellIcon,
  ChatIcon,
  FileIcon,
  ScalesIcon,
  SettingsIcon,
  StarIcon,
} from '../components/icons/ClientIcons';
import { UserIcon } from '../components/icons/Icons';
import {
  CalendarIcon,
  ChartIcon,
  GridIcon,
  UserPlusIcon,
  UsersIcon,
} from '../components/icons/LawyerIcons';

import { WorkspaceScreen } from '../screens/lawyer/Workspace/WorkspaceScreen';
import { LawyerDashboardScreen } from '../screens/lawyer/Dashboard/LawyerDashboardScreen';
import { LeadsScreen } from '../screens/lawyer/Leads/LeadsScreen';
import { LawyerClientsScreen } from '../screens/lawyer/Clients/LawyerClientsScreen';
import { CalendarScreen } from '../screens/lawyer/Calendar/CalendarScreen';
import { LawyerProfileScreen } from '../screens/lawyer/Profile/LawyerProfileScreen';
import { HearingsScreen } from '../screens/lawyer/Hearings/HearingsScreen';
import { ResearchScreen } from '../screens/lawyer/Research/ResearchScreen';
import { ResearchSessionScreen } from '../screens/lawyer/Research/ResearchSessionScreen';
import { NotesScreen } from '../screens/lawyer/Notes/NotesScreen';
import { ProfessionalDetailsScreen } from '../screens/lawyer/Profile/ProfessionalDetailsScreen';
import { SubscriptionScreen } from '../screens/lawyer/Subscription/SubscriptionScreen';

// Reused from the client section rather than rebuilt: these screens are
// already scoped to the signed-in user by the backend, so a lawyer sees their
// own documents, conversations and notifications through the same endpoints.
import { DocumentsScreen } from '../screens/client/Documents/DocumentsScreen';
import { MessagesScreen } from '../screens/client/Messages/MessagesScreen';
import { ChatScreen } from '../screens/client/Messages/ChatScreen';
import { NotificationsScreen } from '../screens/client/Notifications/NotificationsScreen';
import { SettingsScreen } from '../screens/client/Settings/SettingsScreen';
import { ChangePasswordScreen } from '../screens/client/Settings/ChangePasswordScreen';
import { AboutUsScreen } from '../screens/client/Settings/AboutUsScreen';
import { PrivacyPolicyScreen } from '../screens/client/Settings/PrivacyPolicyScreen';
import { TermsConditionsScreen } from '../screens/client/Settings/TermsConditionsScreen';

import { notificationsApi } from '../api/clientApi';
import { chatApi } from '../api/chatApi';
import { lawyerApi } from '../api/lawyerApi';
import { useAuthStore } from '../store/authStore';
import { useUiStore } from '../store/uiStore';
import { colors } from '../theme';
import type { GenieDrawerItem } from '../components/navigation';
import type {
  LawyerStackParamList,
  LawyerTabParamList,
} from '../types/navigation';

/**
 * The lawyer application.
 *
 * Structured exactly like ClientNavigator — tabs nested in a stack, with the
 * drawer and its overlays mounted as siblings of the stack so they float above
 * every screen. Reusing that shape means the drawer, header and tab bar behave
 * identically in both halves of the app.
 *
 * Research runs on `POST /ai/chat` with `mode: "research"`, which the backend
 * routes to its own advocate-facing system instruction, and Notes on the
 * per-client `/clients/:id/notes` CRUD.
 *
 * An earlier draft of this comment said neither had a backend route of any
 * kind. That was wrong on both counts — the routes were there and unused, and
 * the claim kept two working features hidden behind dimmed cards.
 */

/**
 * Registers a screen written against the client stack on the lawyer stack.
 *
 * The five reused screens are typed `ClientStackScreenProps<...>`, and the two
 * param lists are different types even where the route they use is identical.
 * The cast is safe because of what surrounds it, not in spite of it: every
 * route these screens navigate to — Chat, AboutUs, PrivacyPolicy,
 * TermsConditions, ChangePassword — is declared on LawyerStackParamList under
 * the same name with the same params, and registered below. Widening the
 * screens' own prop types instead would mean editing five client files to
 * serve the lawyer tree, which is the worse trade.
 */
const shared = <P,>(screen: React.ComponentType<P>) =>
  screen as unknown as React.ComponentType<Record<string, never>>;

const Tab = createBottomTabNavigator<LawyerTabParamList>();
const Stack = createNativeStackNavigator<LawyerStackParamList>();

const renderTabBar = (props: BottomTabBarProps) => (
  <LawyerBottomNavigation {...props} />
);

const LawyerTabs: React.FC = () => (
  <Tab.Navigator
    screenOptions={{
      headerShown: false,
      sceneStyle: { backgroundColor: colors.background },
    }}
    tabBar={renderTabBar}
  >
    <Tab.Screen name="Workspace" component={WorkspaceScreen} />
    <Tab.Screen name="Dashboard" component={LawyerDashboardScreen} />
    <Tab.Screen name="Leads" component={LeadsScreen} />
    <Tab.Screen name="Clients" component={LawyerClientsScreen} />
    <Tab.Screen name="Calendar" component={CalendarScreen} />
    <Tab.Screen name="LawyerProfile" component={LawyerProfileScreen} />
  </Tab.Navigator>
);

const LawyerOverlays: React.FC = () => {
  const navigation =
    useNavigation<NativeStackNavigationProp<LawyerStackParamList>>();

  const user = useAuthStore(state => state.user);
  const logout = useAuthStore(state => state.logout);

  const isDrawerOpen = useUiStore(state => state.isDrawerOpen);
  const closeDrawer = useUiStore(state => state.closeDrawer);

  const [isSigningOut, setIsSigningOut] = useState(false);
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);

  const notificationsQuery = useQuery({
    queryKey: ['notifications', 1],
    queryFn: () => notificationsApi.list(1, 15),
  });

  const chatsQuery = useQuery({
    queryKey: ['chats'],
    queryFn: chatApi.getChats,
  });

  const leadsQuery = useQuery({
    queryKey: ['lawyer', 'leads'],
    queryFn: lawyerApi.getLeads,
  });

  const unreadChatsCount = (chatsQuery.data ?? []).reduce(
    (acc, c) => acc + (c.unreadCount || 0),
    0,
  );

  const go = useCallback(
    <T extends keyof LawyerStackParamList>(
      screen: T,
      params?: LawyerStackParamList[T],
    ) => {
      closeDrawer();
      navigation.navigate(
        ...([screen, params] as unknown as Parameters<
          typeof navigation.navigate
        >),
      );
    },
    [closeDrawer, navigation],
  );

  const goToTab = useCallback(
    (screen: keyof LawyerTabParamList) => {
      closeDrawer();
      navigation.navigate(
        ...(['Tabs', { screen }] as unknown as Parameters<
          typeof navigation.navigate
        >),
      );
    },
    [closeDrawer, navigation],
  );

  const handleSignOut = useCallback(async () => {
    if (isSigningOut) {
      return;
    }
    setIsSigningOut(true);
    try {
      await logout();
      closeDrawer();
    } finally {
      setIsSigningOut(false);
    }
  }, [closeDrawer, isSigningOut, logout]);

  const items = useMemo<GenieDrawerItem[]>(
    () => [
      {
        key: 'workspace',
        label: 'Workspace',
        Icon: GridIcon,
        onPress: () => goToTab('Workspace'),
      },
      {
        key: 'dashboard',
        label: 'Dashboard',
        Icon: ChartIcon,
        onPress: () => goToTab('Dashboard'),
      },
      {
        key: 'leads',
        label: 'Leads',
        Icon: UserPlusIcon,
        badge: leadsQuery.data?.length || undefined,
        onPress: () => goToTab('Leads'),
      },
      {
        key: 'clients',
        label: 'Clients',
        Icon: UsersIcon,
        onPress: () => goToTab('Clients'),
      },
      {
        key: 'calendar',
        label: 'Calendar',
        Icon: CalendarIcon,
        onPress: () => goToTab('Calendar'),
      },
      {
        key: 'documents',
        label: 'Documents',
        Icon: FileIcon,
        onPress: () => go('Documents'),
      },
      {
        key: 'hearings',
        label: 'Hearings',
        Icon: ScalesIcon,
        onPress: () => go('Hearings'),
      },
      {
        key: 'messages',
        label: 'Messages',
        Icon: ChatIcon,
        badge: unreadChatsCount > 0 ? unreadChatsCount : undefined,
        onPress: () => go('Messages'),
      },
      {
        key: 'notifications',
        label: 'Notifications',
        Icon: BellIcon,
        badge: notificationsQuery.data?.unreadCount || undefined,
        onPress: () => go('Notifications'),
      },
      {
        key: 'subscription',
        label: 'Subscription Plans',
        Icon: StarIcon,
        onPress: () => go('Subscription'),
      },
      {
        key: 'profile',
        label: 'My Profile',
        Icon: UserIcon,
        onPress: () => goToTab('LawyerProfile'),
      },
      {
        key: 'settings',
        label: 'Settings',
        Icon: SettingsIcon,
        onPress: () => go('Settings'),
      },
    ],
    [
      go,
      goToTab,
      leadsQuery.data?.length,
      notificationsQuery.data?.unreadCount,
      unreadChatsCount,
    ],
  );

  return (
    <>
      <GenieDrawer
        isOpen={isDrawerOpen}
        onClose={closeDrawer}
        user={user}
        items={items}
        onSignOut={handleSignOut}
        isSigningOut={isSigningOut}
        onAvatarPress={() => setIsProfileModalOpen(true)}
        onSubscriptionPress={() => go('Subscription')}
      />

      <ProfileImageModal
        visible={isProfileModalOpen}
        onClose={() => setIsProfileModalOpen(false)}
        imageUri={user?.profileImage}
        name={user?.fullName}
      />
    </>
  );
};

export const LawyerNavigator: React.FC = () => (
  <View className="flex-1 bg-background">
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: colors.background },
        animation: 'slide_from_right',
        gestureEnabled: true,
      }}
    >
      <Stack.Screen name="Tabs" component={LawyerTabs} />
      <Stack.Screen name="Hearings" component={HearingsScreen} />
      <Stack.Screen name="Research" component={ResearchScreen} />
      <Stack.Screen name="ResearchSession" component={ResearchSessionScreen} />
      <Stack.Screen name="Notes" component={NotesScreen} />
      <Stack.Screen
        name="ProfessionalDetails"
        component={ProfessionalDetailsScreen}
      />
      <Stack.Screen name="Subscription" component={SubscriptionScreen} />

      {/* Shared with the client tree, under the same route names. */}
      <Stack.Screen name="Documents" component={shared(DocumentsScreen)} />
      <Stack.Screen name="Messages" component={shared(MessagesScreen)} />
      <Stack.Screen name="Chat" component={shared(ChatScreen)} />
      <Stack.Screen name="Notifications" component={shared(NotificationsScreen)} />
      <Stack.Screen name="Settings" component={shared(SettingsScreen)} />
      <Stack.Screen name="ChangePassword" component={shared(ChangePasswordScreen)} />
      <Stack.Screen name="AboutUs" component={shared(AboutUsScreen)} />
      <Stack.Screen name="PrivacyPolicy" component={shared(PrivacyPolicyScreen)} />
      <Stack.Screen name="TermsConditions" component={shared(TermsConditionsScreen)} />
    </Stack.Navigator>

    <LawyerOverlays />
  </View>
);
