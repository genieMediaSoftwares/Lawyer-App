import React, { useCallback, useMemo, useState } from 'react';
import { View } from 'react-native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { useQuery } from '@tanstack/react-query';

import { GenieBottomNavigation, GenieDrawer } from '../components/navigation';
import { CreateCaseSheet } from '../components/CreateCaseSheet';
import { ProfileImageModal } from '../components/ui/ProfileImageModal';
import {
  BellIcon,
  BriefcaseIcon,
  ChatIcon,
  FileIcon,
  HeartIcon,
  HomeIcon,
  ScalesIcon,
  SettingsIcon,
} from '../components/icons/ClientIcons';
import { UserIcon } from '../components/icons/Icons';
import { notificationsApi } from '../api/clientApi';
import { chatApi } from '../api/chatApi';
import { HomeScreen } from '../screens/client/Home/HomeScreen';
import { MyCasesScreen } from '../screens/client/Cases/MyCasesScreen';
import { CaseDetailsScreen } from '../screens/client/Cases/CaseDetailsScreen';
import { AdvocatesScreen } from '../screens/client/Advocates/AdvocatesScreen';
import { AdvocateProfileScreen } from '../screens/client/Advocates/AdvocateProfileScreen';
import { ProfileScreen } from '../screens/client/Profile/ProfileScreen';
import { NotificationsScreen } from '../screens/client/Notifications/NotificationsScreen';
import { FavoritesScreen } from '../screens/client/Favorites/FavoritesScreen';
import { MessagesScreen } from '../screens/client/Messages/MessagesScreen';
import { ChatScreen } from '../screens/client/Messages/ChatScreen';
import { DocumentsScreen } from '../screens/client/Documents/DocumentsScreen';
import { SettingsScreen } from '../screens/client/Settings/SettingsScreen';
import { MyProfileDetailScreen } from '../screens/client/Profile/MyProfileDetailScreen';
import { PersonalInformationScreen } from '../screens/client/Profile/PersonalInformationScreen';
import { RecentActivityScreen } from '../screens/client/Profile/RecentActivityScreen';
import { ChangePasswordScreen } from '../screens/client/Settings/ChangePasswordScreen';
import { AboutUsScreen } from '../screens/client/Settings/AboutUsScreen';
import { PrivacyPolicyScreen } from '../screens/client/Settings/PrivacyPolicyScreen';
import { TermsConditionsScreen } from '../screens/client/Settings/TermsConditionsScreen';
import { AllCategoriesScreen } from '../screens/client/Categories/AllCategoriesScreen';
import { PostCaseScreen } from '../screens/client/PostCase/PostCaseScreen';
import { AiAssistantScreen } from '../screens/client/AI/AiAssistantScreen';
import { AiSessionScreen } from '../screens/client/AI/AiSessionScreen';
import { AiChatScreen } from '../screens/client/AI/AiChatScreen';
import { useAuthStore } from '../store/authStore';
import { useUiStore } from '../store/uiStore';
import { colors } from '../theme';
import type { GenieDrawerItem } from '../components/navigation';
import type {
  ClientStackParamList,
  ClientTabParamList,
} from '../types/navigation';

const Tab = createBottomTabNavigator<ClientTabParamList>();
const Stack = createNativeStackNavigator<ClientStackParamList>();

const renderTabBar = (props: BottomTabBarProps) => (
  <GenieBottomNavigation {...props} />
);

const ClientTabs: React.FC = () => {
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        sceneStyle: { backgroundColor: colors.background },
      }}
      tabBar={renderTabBar}
    >
      <Tab.Screen name="Home" component={HomeScreen} />
      <Tab.Screen name="Cases" component={MyCasesScreen} />
      <Tab.Screen name="Advocates" component={AdvocatesScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
    </Tab.Navigator>
  );
};

const ClientOverlays: React.FC = () => {
  const navigation =
    useNavigation<NativeStackNavigationProp<ClientStackParamList>>();

  const user = useAuthStore(state => state.user);
  const logout = useAuthStore(state => state.logout);

  const isDrawerOpen = useUiStore(state => state.isDrawerOpen);
  const closeDrawer = useUiStore(state => state.closeDrawer);
  const isCreateSheetOpen = useUiStore(state => state.isCreateSheetOpen);
  const closeCreateSheet = useUiStore(state => state.closeCreateSheet);

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

  const unreadChatsCount = (chatsQuery.data || []).reduce(
    (acc, c) => acc + (c.unreadCount || 0),
    0,
  );

  const go = useCallback(
    <T extends keyof ClientStackParamList>(
      screen: T,
      params?: ClientStackParamList[T],
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
    (screen: keyof ClientTabParamList) => {
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
    if (isSigningOut) return;
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
        key: 'dashboard',
        label: 'Dashboard',
        Icon: HomeIcon,
        onPress: () => go('Tabs'),
      },
      {
        key: 'cases',
        label: 'My Cases',
        Icon: BriefcaseIcon,
        onPress: () => goToTab('Cases'),
      },
      {
        key: 'advocates',
        label: 'Advocates',
        Icon: ScalesIcon,
        onPress: () => goToTab('Advocates'),
      },
      {
        key: 'messages',
        label: 'Messages',
        Icon: ChatIcon,
        badge: unreadChatsCount > 0 ? unreadChatsCount : undefined,
        onPress: () => go('Messages'),
      },
      {
        key: 'documents',
        label: 'My Documents',
        Icon: FileIcon,
        onPress: () => go('Documents'),
      },
      {
        key: 'favorites',
        label: 'Favorite Lawyers',
        Icon: HeartIcon,
        onPress: () => go('Favorites'),
      },
      {
        key: 'profile',
        label: 'My Profile',
        Icon: UserIcon,
        onPress: () => goToTab('Profile'),
      },
      {
        key: 'notifications',
        label: 'Notifications',
        Icon: BellIcon,
        badge: notificationsQuery.data?.unreadCount ?? 0,
        onPress: () => go('Notifications'),
      },
      {
        key: 'settings',
        label: 'Settings',
        Icon: SettingsIcon,
        onPress: () => go('Settings'),
      },
    ],
    [go, goToTab, notificationsQuery.data?.unreadCount, unreadChatsCount],
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
      />

      <ProfileImageModal
        visible={isProfileModalOpen}
        onClose={() => setIsProfileModalOpen(false)}
        imageUri={user?.profileImage}
        name={user?.fullName}
      />

      <CreateCaseSheet
        visible={isCreateSheetOpen}
        onClose={closeCreateSheet}
        onStartManual={() => {
          closeCreateSheet();
          navigation.navigate('PostCase', { start: 'manual' });
        }}
        onStartAi={() => {
          closeCreateSheet();
          navigation.navigate('AiAssistant');
        }}
      />
    </>
  );
};

export const ClientNavigator: React.FC = () => (
  <View className="flex-1 bg-background">
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: colors.background },
        animation: 'slide_from_right',
        gestureEnabled: true,
      }}
    >
      <Stack.Screen name="Tabs" component={ClientTabs} />
      <Stack.Screen name="CaseDetails" component={CaseDetailsScreen} />
      <Stack.Screen name="AdvocateProfile" component={AdvocateProfileScreen} />
      <Stack.Screen name="Notifications" component={NotificationsScreen} />
      <Stack.Screen name="Favorites" component={FavoritesScreen} />
      <Stack.Screen name="Messages" component={MessagesScreen} />
      <Stack.Screen name="Chat" component={ChatScreen} />
      <Stack.Screen name="Documents" component={DocumentsScreen} />
      <Stack.Screen name="Settings" component={SettingsScreen} />
      <Stack.Screen name="MyProfileDetail" component={MyProfileDetailScreen} />
      <Stack.Screen name="PersonalInformation" component={PersonalInformationScreen} />
      <Stack.Screen name="RecentActivity" component={RecentActivityScreen} />
      <Stack.Screen name="ChangePassword" component={ChangePasswordScreen} />
      <Stack.Screen name="AboutUs" component={AboutUsScreen} />
      <Stack.Screen name="PrivacyPolicy" component={PrivacyPolicyScreen} />
      <Stack.Screen name="TermsConditions" component={TermsConditionsScreen} />
      <Stack.Screen name="AllCategories" component={AllCategoriesScreen} />
      <Stack.Screen name="PostCase" component={PostCaseScreen} />
      <Stack.Screen name="AiAssistant" component={AiAssistantScreen} />
      <Stack.Screen name="AiSession" component={AiSessionScreen} />
      <Stack.Screen name="AiChat" component={AiChatScreen} />
    </Stack.Navigator>

    <ClientOverlays />
  </View>
);
