import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { BottomTabScreenProps } from '@react-navigation/bottom-tabs';
import type { CompositeScreenProps } from '@react-navigation/native';

/**
 * The navigation graph, typed.
 *
 * Auth and App are separate trees, mounted by authentication state rather than
 * pushed onto one another. That is what prevents the loop this kind of app
 * usually grows: with one stack, signing out has to pop screens and signing in
 * has to reset, and any missed case leaves a back button pointing at a screen
 * the user no longer has access to.
 *
 * Inside the app tree, the bottom tabs are nested in a stack. Detail screens —
 * a case, an advocate — are pushed onto the *stack*, not into a tab, so they
 * cover the tab bar and a back gesture returns to the tab that opened them.
 */

export type AuthStackParamList = {
  Login: undefined;
  Signup: undefined;
  /** Pre-filled with the address typed on the Login screen, when there is one. */
  ForgotPassword: { email?: string } | undefined;
};

/** The four bottom tabs. The centre "+" is an action, not a tab. */
export type ClientTabParamList = {
  Home: undefined;
  Cases: undefined;
  Advocates: { initialSearch?: string } | undefined;
  Profile: undefined;
};

/**
 * The client stack.
 *
 * Only screens that exist and are wired to a real endpoint are declared. A
 * route registered here that nothing can navigate to is a route that will rot,
 * so the remaining phases add their own entries when they land.
 */
export type ClientStackParamList = {
  Tabs: undefined;
  CaseDetails: { caseId: string; title?: string };
  AdvocateProfile: { userId: string; name?: string };
  Notifications: undefined;
  Favorites: undefined;
  Messages: undefined;
  Chat: { chatId: string; name?: string; avatar?: string };
  Documents: undefined;
  Settings: undefined;
  MyProfileDetail: undefined;
  PersonalInformation: undefined;
  RecentActivity: undefined;
  ChangePassword: undefined;
  AboutUs: undefined;
  PrivacyPolicy: undefined;
  TermsConditions: undefined;
  AllCategories: undefined;
  /**
   * The five-step Post Your Case flow.
   *
   * `start` decides where it opens. "manual" begins at the category step;
   * "ai" drops straight into the documents step with the assistant, because
   * extraction fills the category and details steps retroactively and making
   * the client complete them first would defeat the point.
   *
   * `sessionId` hands over an analysis the AI Smart Case Assistant has already
   * started. The flow watches that session, folds the result into the form and
   * moves on to lawyer selection by itself — the client does not re-upload and
   * does not re-enter anything the documents already said.
   *
   * `categoryId` opens the category step with that category already chosen and
   * expanded on its sub-types. It is a `LegalCategory.id`, which is what the
   * category tiles on Home and All Categories carry. The sub-type is
   * deliberately **not** preselected: the tile said which area of law, not
   * which kind of matter, and choosing that for the client would file a case
   * under something they never picked.
   */
  PostCase:
    | { start?: 'manual' | 'ai'; sessionId?: string; categoryId?: string }
    | undefined;
  /** The AI assistant's composer: documents, voice note, notes. */
  AiAssistant: undefined;
  /** Watches one analysis, then shows its result. */
  AiSession: { sessionId: string };
  /** Conversational AI Legal Assistant chatbot. */
  AiChat: { initialQuestion?: string } | undefined;
};

/**
 * The lawyer bottom tabs.
 *
 * Six of them, and unlike the client's there is no centre action button — a
 * lawyer's primary job is responding to work that arrives, not creating it.
 */
export type LawyerTabParamList = {
  Workspace: undefined;
  Dashboard: undefined;
  Leads: undefined;
  Clients: undefined;
  Calendar: undefined;
  LawyerProfile: undefined;
};

/**
 * The lawyer stack.
 *
 * As with the client stack, only routes backed by a real endpoint are
 * declared. Research has no backend route of any kind and so has no screen;
 * notes exist only per client, under a client's detail.
 */
export type LawyerStackParamList = {
  Tabs: undefined;
  Hearings: undefined;
  /** The advocate's research workspace: sessions, and a case picker. */
  Research: undefined;
  /**
   * One research session.
   *
   * `sessionId` reopens a saved `AiConversation`; without it the screen starts
   * a new one and learns its id from the first answer. The case fields seed an
   * opening question about one of the advocate's own matters — they are the
   * advocate's own case data, never another lawyer's.
   */
  ResearchSession: {
    sessionId?: string;
    title?: string;
    caseId?: string;
    caseTitle?: string;
    caseCategory?: string;
  } | undefined;
  /** The advocate's private notebook, composed across their clients. */
  Notes: undefined;
  ProfessionalDetails: undefined;
  Subscription: undefined;

  // ── Screens shared with the client tree ─────────────────────────────────
  //
  // These route names deliberately match ClientStackParamList's, with the same
  // params. The screens behind them are the client ones reused verbatim,
  // because the endpoints they call are scoped to the signed-in user and so
  // already serve a lawyer their own data.
  //
  // The names have to match: MessagesScreen calls `navigate('Chat')` and
  // SettingsScreen calls `navigate('AboutUs')` and three siblings. Rename any
  // of these and that navigation throws at runtime, which is exactly what an
  // earlier draft of this stack did.
  Documents: undefined;
  Messages: undefined;
  Chat: { chatId: string; name?: string; avatar?: string };
  Notifications: undefined;
  Settings: undefined;
  ChangePassword: undefined;
  AboutUs: undefined;
  PrivacyPolicy: undefined;
  TermsConditions: undefined;
};

export type AuthScreenProps<T extends keyof AuthStackParamList> =
  NativeStackScreenProps<AuthStackParamList, T>;

export type ClientStackScreenProps<T extends keyof ClientStackParamList> =
  NativeStackScreenProps<ClientStackParamList, T>;

/**
 * A tab screen also needs the parent stack's `navigate`, because every tab
 * pushes detail screens onto it.
 */
export type ClientTabScreenProps<T extends keyof ClientTabParamList> =
  CompositeScreenProps<
    BottomTabScreenProps<ClientTabParamList, T>,
    NativeStackScreenProps<ClientStackParamList>
  >;

export type LawyerStackScreenProps<T extends keyof LawyerStackParamList> =
  NativeStackScreenProps<LawyerStackParamList, T>;

export type LawyerTabScreenProps<T extends keyof LawyerTabParamList> =
  CompositeScreenProps<
    BottomTabScreenProps<LawyerTabParamList, T>,
    NativeStackScreenProps<LawyerStackParamList>
  >;
