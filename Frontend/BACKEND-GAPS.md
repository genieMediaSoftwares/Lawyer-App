# Missing or problematic backend support

Written for: the Genie Law backend maintainer.

Findings from wiring the React Native client section to the live backend. Per
the no-modification rule, **nothing here has been changed** — this is a report,
with the minimal fix proposed for each item.

Each entry gives: what the client needs, what exists today, what is missing.

---

## 1. Gemini 3.6 Flash was requested — it does not work

**Status:** do not change. The backend already tested this and rejected it.

`backend/src/services/ai/geminiClient.js` documents a probe against this
project's own API key on **2026-09-15**:

```
gemini-2.5-flash       404 "no longer available to new users"
gemini-3.6-flash       404 "no longer available"
gemini-flash-latest    503, plain and structured alike
```

and states explicitly:

> Deliberately excluded: `gemini-3.6-flash` and `gemini-3.7-flash`, both 503
> on probing, and preview ids, which are withdrawn without notice.

The current list, ordered by measured latency on a ~10KB legal-extraction
payload, is:

| Model | Latency | Result |
| --- | --- | --- |
| `gemini-3.5-flash-lite` | 2.3–2.6s | correct |
| `gemini-flash-lite-latest` | 2.1–2.5s | correct |
| `gemini-3.1-flash-lite` | 2.3–2.8s | correct |
| `gemini-3.5-flash` | 10–14s | correct, timed out at 60s once |
| `gemini-flash-latest` | 503 | — |

**Switching to `gemini-3.6-flash` would break OCR, transcription and extraction
simultaneously**, which is the exact failure the file was written to prevent:
the comment describes an earlier incident where a dead model produced "an
intake pipeline that produced confident output from documents it had never
read."

**Recommendation:** leave it. If Google re-enables the model, add it to
`DEFAULT_MODELS` *above* the lite entries only after a real `generateContent`
probe with the extractor's own prompt and `responseSchema` — the file notes
ListModels is not a reliable guide.

Two stale references remain and are worth tidying:
`aiController.js:522` and `:636` still name `gemini-3.6-flash` in fallback
lists that bypass `geminiClient.generate()`.

---

## 2. `GET /lawyers` fabricates advocate profiles

**Severity: high.** This one writes invented data into the production database.

`lawyerController.getAllLawyers` creates a Lawyer document for any user with
`role: "lawyer"` that lacks one, filled with hardcoded values:

```js
specialization: "General Practice",
experience: 2,
education: "LLB",
consultationFee: 1500,
bio: "Professional advocate specializing in litigation and advisory.",
barCouncilNumber: "12345/2026",
```

Every advocate returned by the live backend today shows
**"General Practice"** for this reason — visible in the client's Advocates
list. `barCouncilNumber: "12345/2026"` is a fake bar registration number
attached to real advocates.

The repo already ships `scripts/clearFabricatedLawyerStats.js`, so this is a
known class of problem.

**The client does not display these as facts:** a zero rating renders "No
ratings yet" and a zero fee is omitted. But `specialization`, `bio` and
`barCouncilNumber` are non-empty strings and cannot be distinguished from real
data by the client.

**Proposed minimal change:** create the profile with empty/zero fields
(`specialization: ""`, `bio: ""`, `barCouncilNumber: ""`, `experience: 0`,
`consultationFee: 0`) so "not filled in" is representable, and let the client
show its existing empty states. A one-off migration would clear the placeholder
values already written.

---

## 3. No categories endpoint

**Needed for:** Home → Popular Categories, Post Case → Category.

`backend/src/config/legalCategories.json` holds the authoritative 15-category
taxonomy, but nothing under `backend/src/routes/` serves it. Its only consumer
is `services/ai/aiSmartIntakeService.js`, server-side.

The client therefore **mirrors the file** in
`src/constants/categories.ts` — permitted by the brief when no endpoint
exists, but it is now a third copy (Dart list → JSON → TypeScript), and only
the first two are kept in step by a test.

**Proposed minimal change:** `GET /api/categories` returning
`legalCategories.json` verbatim. Three lines in a new route file; no schema or
contract changes.

---

## 4. `GET /cases` has no pagination or filtering

**Needed for:** My Cases at scale.

The controller returns every case belonging to the client in one array, sorted
by `createdAt`, with four `populate` calls plus an N+1 `Lawyer.findOne` per
case inside a `for` loop.

The client filters the three tabs in memory, which is correct given there is no
server-side alternative — but a client with hundreds of cases transfers all of
them on every load, and the N+1 makes that quadratic on the server.

**Proposed minimal change:** accept `?page=&limit=&status=` and return the same
`{items, pagination}` envelope `GET /notifications` already uses, so the shape
is consistent with an existing endpoint. Replacing the per-case `Lawyer.findOne`
with one `$in` query would help regardless of pagination.

---

## 5. Case documents cannot be opened by the client

**Needed for:** Case Details → Documents, My Documents.

`Case.documents[]` carries `{name, url, size}`. The `url` points under
`/uploads`, which `fileAuthMiddleware` protects — and only the `profiles`
folder is public:

```js
const PUBLIC_FOLDERS = new Set(["profiles"]);
```

React Native's `<Image>` and a browser `<a href>` cannot attach a Bearer token,
so **a case attachment cannot be fetched from its stored URL**. The proper
route, `GET /documents/:id/view`, needs a Document `_id` — which the Case
payload does not include, because `Case.documents[]` is an embedded
subdocument, not a reference to the Document collection.

The client currently **lists documents without making them openable**, rather
than rendering a link that would 401.

**Proposed minimal change:** either add the Document `_id` to the embedded
entries, or add a short-lived signed-URL endpoint
(`GET /cases/:id/documents/:index/url`) that returns a token-bearing link.

---

## 6. `Case.documents[].size` is a String of inconsistent format

Sometimes a byte count, sometimes an already-formatted label. The client's
`formatFileSize` formats numeric strings and passes anything else through
untouched, so nothing breaks — but a `Number` field would remove the ambiguity.

---

## 7. Notification `referenceId` has no type

`Notification` carries `referenceId` but nothing saying what kind of entity it
names. The client therefore **marks a notification read but does not navigate
from it**, because routing would mean guessing whether the id is a case, a
chat or an appointment.

**Proposed minimal change:** add `referenceType` (`"case" | "chat" |
"appointment" | …`) alongside it. The existing `type` enum may already imply it
— if so, documenting the mapping is enough.

---

## 8. No role-based routing target for lawyers

`authMiddleware` and the User schema support `client`, `lawyer` and `admin`,
and `/lawyers/*` has a full set of lawyer-side endpoints. The React Native app
currently has a **client section only**, so an account with `role: "lawyer"`
signs in and lands on the client tree, where `GET /cases` scopes to
`client: req.user._id` and returns nothing.

Not a backend gap — noted so it is not mistaken for one. The lawyer app is
separate work.

---

## Endpoints used by the client section today

All verified against the live backend.

| Endpoint | Used by |
| --- | --- |
| `POST /auth/signup`, `/auth/login`, `/auth/logout`, `/auth/refresh-token` | Auth |
| `GET /auth/profile` | Session restore |
| `GET /client/profile` | Profile |
| `GET /client/stats` | Home, Profile |
| `GET /cases` | Home, My Cases |
| `GET /cases/:id` | Case Details |
| `GET /lawyers` | Advocates (server-side search, filter, sort) |
| `GET /lawyers/:id` | Advocate Profile |
| `GET /favorites`, `POST /favorites` | Favourites, heart toggle |
| `GET /notifications`, `PUT /notifications/:id/read`, `PUT /notifications/read-all` | Notifications |

Endpoints deliberately **not** called yet, because the screens that would use
them belong to later phases: `/ai/*`, `/chats/*`, `/documents/*`,
`/appointments/*`, `/reviews/*`, `/payments/*`, `/courts`, `/places/*`.
