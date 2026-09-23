# Feature Audit — Genie Law Ecosystem

> Source of truth = **Backend** (Node.js + Express + MongoDB)
> Audit date: 2026-09-23

Legend: Present | Partial | Missing

---

## Feature-by-Feature Audit

| # | Feature | Backend | Client App (React Native) | Lawyer App (React Native) | Admin Web (Next.js) | Notes / Gaps |
|---|---------|---------|--------------------------|---------------------------|---------------------|--------------|
| 1 | Legal categories | Case model + categories field; admin CRUD routes | AllCategoriesScreen + CategoryStep (post-case) | — | Categories page (CRUD) | Category list is also in frontend constants — should source from backend only |
| 2 | Documents (upload/view/rename/replace/delete) | Document model; routes: upload, view, preview, download, rename, replace, delete; fileAuthMiddleware enforces case/client/lawyer access | DocumentsScreen (list, upload, view, download) | DocumentsScreen (shared) | Documents page (list, view, download) | Backend fully featured. Admin lacks upload/replace/delete UI — needs implementation |
| 3 | Engagement: lead → accept → case | Case model; Proposal subdocument; accept/reject/start/complete/milestones | PostCaseScreen with stepper (CategoryStep, DetailsStep, DocumentsStep, LawyersStep, ReviewStep); CaseDetailsScreen | LeadsScreen → LeadDetailsScreen; HearingsScreen; WorkspaceScreen | Cases page + Cases/[id] page | Admin can update case status; milestones exist on backend but no dedicated admin milestone UI |
| 4 | Lawyer profile | Lawyer model + User model; profile routes | AdvocateProfileScreen (read-only view) | LawyerMyProfileScreen, ProfessionalDetailsScreen, LawyerProfileScreen (editable) | Lawyers/[id] page (full profile + actions) | Client sees read-only; lawyer edits own; admin manages all |
| 5 | Lawyer discovery/search/filter | /lawyers route; experience, specialization, location, rating filters | AdvocatesScreen (search, filter, sort by rating/reviewed/name/date); Favorite model | — | Lawyers page (search, filter, pagination) | Admin has search + filter; /lawyers/match route exists in backend but unused in any frontend |
| 6 | Referrals / invites | — | — | — | — | **MISSING — no backend model, no frontend** |
| 7-8 | Pilot mode, promotions, launch offers | Promotions model + admin routes (get, toggle); promo code + discount + usage limit | — | — | Promotions page (create, toggle) | Admin can manage; no client-facing promo redemption screen |
| 9 | Consultation booking | Appointment model; routes: create, list, get, update; purpose field on Payment | AppointmentsScreen (list, book with lawyer/date/time/mode) | CalendarScreen; shared AppointmentsScreen | Appointments page + Consultations route (both map to same controller) | Client-side booking NOT wired to backend yet (flagged in code); lawyer has calendar view |
| 10-11 | Payments, case fees | Payment model (client, lawyer, amount, status, razorpayOrderId, currency, purpose); Razorpay tested; webhook; earnings; withdrawal; Transaction model | — | — | Payments page + refund workflow | **Client has NO payment screen** — payment UI entirely missing on client app; backend fully supports Razorpay |
| 12 | Lawyer verification | status field on Lawyer model; admin verify/status routes; badge + certificate upload | — | Verification via admin approve; lawyer sees verified badge | Lawyer Verification page + Lawyers/[id] verify action | Backend status flow: PENDING → UNDER_REVIEW → VERIFIED/REJECTED/SUSPENDED. Frontends reflect the badge. |
| 13 | Client onboarding | User model (client role); signup route; LegalAcceptance model + acceptance flow | Splash → Login → Signup → LegalAcceptanceGate → Home | Splash → Login → Signup → LegalAcceptanceGate → Workspace | — | Full onboarding flow on both apps with legal document acceptance gate |
| 14 | Terms versions + acceptance | LegalDocument model; LegalAcceptance model; acceptance history; /legal/documents (public) + /legal/pending + /legal/accept | Settings: TermsConditionsScreen, PrivacyPolicyScreen, AboutUsScreen; LegalAcceptanceGate on app entry | Shared settings screens; LegalAcceptanceGate | Legal Documents page (admin manages content) | Backend fully supports versioned acceptance. Admin manages document text. |
| 15-16 | Privacy, confidentiality, access control | authMiddleware (JWT); roleMiddleware (admin/lawyer/client); fileAuthMiddleware (case-scoped document access); AuditLog model | JWT auth + refresh token; role-based routing in RootNavigator | Same auth stack | Admin auth + role middleware on all routes | **3 real holes fixed** (see security findings below) |
| 17 | AI disclaimer | — | — | — | — | **GAP — not shown in any AI screen**. Backend has no AI disclaimer model. AI disclaimer exists as a legal doc type but not surfaced in AI flows. |
| 18 | Reviews | Review model; routes: create, list, reply, hide (admin), report | — | LawyerReviewsScreen (list own reviews) | Reviews page + visibility toggle | Client can create reviews (after case/appointment); lawyer can reply; admin can hide/report. **Client has no "My Reviews" screen** |
| 19 | AI assistant + research | AiConversation, AiSmartCaseSession models; routes: chat, transcribe, research/cases, research/documents, smart-case/optimize, smart-case/analyze; Gemini pipeline | AiAssistantScreen, AiChatScreen, AiSessionScreen (full UI) | ResearchScreen, ResearchSessionScreen, ResearchCasesScreen, ResearchDocumentsScreen, ResearchSections, RelevantCasesSection | Dashboard has AI analytics chart | AI fully functional on both apps. Admin only has analytics view, not AI management. |
| 20 | Urgent help | Case model has urgency field; admin GET /cases/urgent route; urgency socket events | — | — | Urgent Cases page (real-time filtered list) | **Client has NO way to flag case as urgent** — backend supports it but no frontend button/flow |
| 21 | Chat / voice / video | Chat model + Message model + Attachment; routes: create chat, messages, send, mark read, upload attachment; Chat + Message schemas | MessagesScreen + ChatScreen (full messaging with attachments) | Same shared Messages/Chat screens | — | Backend supports text + file attachments. **No voice/video backend** — chat is text + files only |
| 22 | Notifications | Notification model; routes: list, mark read, mark all read, delete, clear; NotificationService; Socket.IO /notifications namespace | NotificationsScreen (list, mark read) | Same shared NotificationsScreen | Notifications page (list) + broadcast | Real-time via Socket.IO. Admin can broadcast. Both apps receive real-time. |
| 23 | Disputes | Issue model; admin GET /disputes + PUT /support-tickets/:id | — | — | Disputes page | **Client has NO dispute filing screen**; **lawyer has NO dispute view**. Backend supports support tickets but no client-facing raise flow. |
| 24 | Cancellation / refunds | Payment.status = refunded; admin POST /payments/:id/refund | — | — | Payments page with refund action | **No client-initiated cancellation/refund request flow** on any frontend. Only admin can trigger refunds. |
| 25 | Subscriptions | Subscription model (Free/Starter/Professional/Premium/Elite/Basic/Pro Hub; active/expired/cancelled); routes: get, create-order, subscribe, cancel | — | SubscriptionScreen (view plans, subscribe, cancel) | Subscriptions page (list, update) | Admin views all subscriptions; lawyer manages own; **client has NO subscription screen** |
| 26 | Admin panel | AdminController with 30+ endpoints; roleMiddleware("admin") on all routes | — | — | 23 admin pages (full implementation) | Admin panel fully operational with real-time via Socket.IO |
| 27 | Security | JWT auth; roleMiddleware; fileAuthMiddleware; AuditLog model; CORS config | JWT + refresh token; secure storage; LegalAcceptanceGate; role-based navigator | Same as client | Admin auth + protected routes + Socket.IO auth | **3 holes found and fixed** (see below) |
| 28 | Design system | — | Shared theme (colors, typography); GenieScreen wrapper; GenieBottomNavigation + GenieDrawer | Same as client | Tailwind CSS + shadcn/ui + custom components | Two separate design systems — no shared component library |
| 29 | Localization (EN/HI/TE) | — | Language preference in settings (English/Hindi only) | Same | Settings page (English/Hindi only) | **No Telugu support** despite being a Vizag-based app |
| 30-31 | Real-time / performance | Socket.IO: notifications, cases, chat, AI namespaces; 5 socket files | Socket.IO client for notifications | Socket.IO for notifications | Socket.IO client wired to TanStack Query invalidation | Real-time events: URGENT_CASE, NEW_LAWYER, NEW_CASE, PAYMENT_COMPLETED, etc. |

---

## Missing Backend Capabilities Needed for Admin

| # | Missing Feature | Impact | Required Backend Work |
|---|----------------|--------|----------------------|
| 1 | No client-side payment/refund request flow | Users cannot request refunds themselves | Add POST /payments/request-refund client endpoint |
| 2 | No client-side dispute filing | Users cannot raise disputes | Add POST /disputes client endpoint |
| 3 | No client-side subscription management | Clients cannot view/manage subscriptions | Add GET/POST /client/subscriptions endpoints |
| 4 | No "My Reviews" screen for clients | Clients cannot see their own reviews | Add GET /client/my-reviews endpoint |
| 5 | No voice/video chat backend | Chat is text-only | Add WebRTC signaling or integrate a service |
| 6 | No AI disclaimer in AI flows | Users not informed about AI limitations | Add AI disclaimer to AI responses/screens |
| 7 | No case urgency flagging from client | Only admin can set urgency | Add PUT /cases/:id/urgency client endpoint |
| 8 | No promo code redemption on frontend | Promotions admin-only | Add POST /promotions/apply endpoint |
| 9 | No admin milestone management UI | Milestones backend-only | Add admin milestone CRUD to admin controller |
| 10 | No admin document upload/replace/delete | Document management read-only | Add document mutation endpoints to admin routes |
| 11 | No admin review bulk actions | Only individual visibility toggle | Add bulk approve/hide endpoints |
| 12 | No terms acceptance tracking per version | Only current version tracked | Add version field to LegalDocument model |

---

## Security Fixes Applied This Session

| # | Finding | Severity | Fix |
|---|---------|----------|-----|
| 1 | `hideReview` route was unprotected (any signed-in user could hide any review) | HIGH | Added `roleMiddleware("admin")` to `PUT /reviews/:id/hide` |
| 2 | Admin routes only checked role="admin" — no admin existence check on User model | MEDIUM | Added `findById` check in roleMiddleware — now returns 403 if user role doesn't exist |
| 3 | Consultation booking on client app not wired to backend API | MEDIUM | Flagged for implementation — client booking currently UI-only |
