# Plan A: Server hardening and app workflow completion

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce JWT auth on the HMS server with a refresh endpoint and settings-driven identifiers, add a tomogram history endpoint, and make the Flutter app refresh tokens, show already-uploaded tomograms, queue uploads offline, and resize photos at capture.

**Architecture:** Server tasks edit `E:\Projects\personal\deCare\hms\HMSServer` (branch `hardening`; Express + Sequelize 5 + TypeScript 4.3; `npm run dev` recompiles and restarts automatically, so edits are live on `http://localhost:4041`). App tasks edit `E:\Projects\personal\deCare\hms\HMSFlutter` (branch `flutter-port`; Flutter 3.19, Riverpod 2.6, Dio 5.11). The app keeps its layering: `core/network` gets a refresh hook via a provider overridden in `main.dart`; `features/tomogram` gains history and queue data/application/presentation; `features/dashboard` shows the pending chip.

**Tech Stack:** jsonwebtoken 8, sequelize 5 (mssql/tedious), Dio `QueuedInterceptor`, `connectivity_plus ^7.3.1`, `path_provider`, `intl` (already present).

**Spec:** `E:\Projects\personal\deCare\hms\HMSFlutter\docs\superpowers\specs\2026-09-09-hardening-and-polish-design.md` (sections 2 to 5)

## Global Constraints

- Server: TypeScript must compile (`npm run build` → `tsc` clean). No new npm dependencies. Do not touch `.env`. Passwords stay plain text (shared ERP table). The dev server on port 4041 is the user's; never kill it; it reloads on compile.
- Server API contract after this plan: `POST /api/auth/login` (open), `POST /api/auth/refresh` (open), `GET /api/auth/healthcheck` (open), `GET /api/opregister?opid=` (Bearer), `POST /api/tomogram` (Bearer), `GET /api/tomogram?opid=` (Bearer). JSend envelopes unchanged. Auth failures are 401 with `failResponse(message)`.
- App: Flutter 3.19 / Dart 3.3, no `flutter upgrade`; new dependencies only `connectivity_plus ^7.3.1` and `path_provider`; `core` never imports `features`; cross-feature imports via barrels; all UI strings via `context.l10n`; screens use only design tokens; `flutter analyze` clean and `flutter test` green before every commit.
- Run server commands from `E:\Projects\personal\deCare\hms\HMSServer`, app commands from `E:\Projects\personal\deCare\hms\HMSFlutter` (Git Bash paths with forward slashes).
- Verification against the live local server uses `curl` to `http://localhost:4041`. Local credentials for manual checks: username `System`, password `lagoon` (local dev DB only; never write them into source or tests).

---

## File map

| Path | Responsibility |
|---|---|
| server `src/middlewares/auth.ts` | Bearer verification, 401 responses |
| server `src/controllers/auth/login.ts` | login (fixed attributes), refresh |
| server `src/controllers/auth/index.ts` | mounts `/login`, `/refresh`, `/healthcheck` |
| server `src/controllers/opRegister/index.ts`, `src/controllers/tomogram/index.ts` | apply `authentication` |
| server `src/helpers/settings.ts` | `getSetting`, `getSettingInt` |
| server `src/models/main/settings.model.ts` | attribute `key` for column `Key` |
| server `src/controllers/tomogram/tomogram.ts` | settings-driven IDs; `listTomogramsController` |
| server `sql/seed-local-tomogram.sql`, `README-api.md` | local seed and curl walkthrough |
| app `lib/core/network/auth_interceptor.dart`, `dio_client.dart` | refresh-on-401, `refreshAccessTokenProvider`, `authFailureProvider` |
| app `lib/features/auth/data/auth_api.dart`, `application/session_controller.dart` | `refresh`, `refreshAccessToken` |
| app `lib/app/session_expiry_listener.dart` | logout + banner on terminal 401 |
| app `lib/features/tomogram/data/tomogram_history_api.dart`, `application/tomogram_history_controller.dart`, `presentation/widgets/tomogram_history_card.dart` | history |
| app `lib/features/tomogram/data/pending_upload.dart`, `pending_uploads_repository.dart`, `application/upload_queue_controller.dart`, `application/connectivity_provider.dart`, `presentation/widgets/pending_uploads_sheet.dart` | offline queue |
| app `lib/features/dashboard/presentation/widgets/context_strip.dart` | pending chip |

---

### Task 1: Server auth: middleware, refresh endpoint, login fix, protected routes

**Files:**
- Modify: `src/middlewares/auth.ts`, `src/controllers/auth/login.ts`, `src/controllers/auth/index.ts`, `src/controllers/opRegister/index.ts`, `src/controllers/tomogram/index.ts`, `src/interfaces/vendors/IRequest.ts`
- Create: `README-api.md`

**Interfaces:**
- Produces: `POST /api/auth/refresh` `{refreshToken}` → `{status:'success', data:{accessToken}}`; 401 JSend `fail` on missing/invalid tokens; `req.user`, `req.user_id` set by the middleware.

- [ ] **Step 1: Replace `src/middlewares/auth.ts`**

```ts
import { Request, Response, NextFunction } from "express";
import jwt from 'jsonwebtoken';
import Locals from '../providers/Locals';
import { failResponse } from '../helpers/JSend';
import { IUserJWT } from '../interfaces/vendors/IRequest';

/**
 * Bearer-token guard. Reads `Authorization: Bearer <accessToken>` (also
 * `req.body.token` / `req.query.token` for backwards compatibility) and
 * puts `user` / `user_id` on the request. Always 401 on failure.
 */
export default function authentication(req: Request, res: Response, next: NextFunction) {
    const authHeader = (req.headers['authorization'] as string | undefined) || req.body?.token || req.query?.token;
    const token = typeof authHeader === 'string' && authHeader.startsWith('Bearer ')
        ? authHeader.slice('Bearer '.length).trim()
        : (typeof authHeader === 'string' ? authHeader : undefined);

    if (!token) {
        return res.status(401).json(failResponse("Authentication required"));
    }

    try {
        const decoded = jwt.verify(token, Locals.config().appSecret) as IUserJWT;
        if (decoded.token_type && decoded.token_type !== 'access') {
            return res.status(401).json(failResponse("Invalid or expired token"));
        }
        req.user = decoded.username;
        req.user_id = decoded.user_id;
        return next();
    } catch (e) {
        return res.status(401).json(failResponse("Invalid or expired token"));
    }
}
```

`src/interfaces/vendors/IRequest.ts`: add `token_type?: 'access' | 'refresh';` to `IUserJWT`. Check how `req.user`/`req.user_id` are typed today (`grep -rn "user_id" src/`); if an Express `Request` augmentation exists keep it, otherwise add `src/types/express.d.ts`:

```ts
declare namespace Express {
    interface Request {
        user?: string;
        user_id?: number;
    }
}
```

and make sure `tsconfig.json` `include` covers `src/**/*`.

- [ ] **Step 2: Login fix and refresh controller in `src/controllers/auth/login.ts`**

Replace the query and comparison:

```ts
        const user = await userDB.UserModel?.findOne({
            attributes: ['ID', 'Username', 'Password'],
            where: { Username: username }
        });

        if (user && user.get('Password') === password) {
            const userId = user.get('ID') as number;
            const accessToken = signAccessToken(userId, username);
            const refreshToken = jwt.sign(
                { user_id: userId, username, token_type: "refresh" },
                Locals.config().appSecret + '_refresh',
                { expiresIn: '5 days' }
            );
            return res.status(200).json(successResponse({ id: userId, username, accessToken, refreshToken }));
        }
        res.status(404).json(failResponse("Invalid Credentials"));
```

Add above the controllers:

```ts
const signAccessToken = (userId: number, username: string) =>
    jwt.sign({ user_id: userId, username, token_type: "access" }, Locals.config().appSecret, { expiresIn: '2h' });

export const refreshController = async (req: Request, res: Response) => {
    const { refreshToken } = req.body ?? {};
    if (!refreshToken || typeof refreshToken !== 'string') {
        return res.status(400).json(failResponse("refreshToken is required"));
    }
    try {
        const decoded = jwt.verify(refreshToken, Locals.config().appSecret + '_refresh') as IUserJWT;
        if (decoded.token_type !== 'refresh') throw new Error('wrong token type');
        return res.status(200).json(successResponse({ accessToken: signAccessToken(decoded.user_id, decoded.username) }));
    } catch (e) {
        return res.status(401).json(failResponse("Invalid or expired refresh token"));
    }
};
```

(import `IUserJWT` from `../../interfaces/vendors/IRequest`).

- [ ] **Step 3: Routes**

`src/controllers/auth/index.ts`: add `router.post('/refresh', refreshController);`.
`src/controllers/opRegister/index.ts`: `router.get('/', authentication, getOPRegisterController);` (remove the commented line).
`src/controllers/tomogram/index.ts`: `import authentication from '../../middlewares/auth';` and `router.post('/', authentication, uploadFile, uploadTomogramController);` (auth before multer so unauthenticated uploads are rejected before any file is written).

- [ ] **Step 4: Build and verify against the live server**

```bash
cd "E:/Projects/personal/deCare/hms/HMSServer" && npm run build
```
Expected: no TypeScript errors. The dev server picks up `dist` automatically; wait 5 s, then:

```bash
curl -s -w '\nHTTP %{http_code}\n' "http://localhost:4041/api/opregister?opid=580"
# expect HTTP 401 {"status":"fail","data":"Authentication required"}
TOKENS=$(curl -s -H 'Content-Type: application/json' -d '{"username":"System","password":"lagoon"}' http://localhost:4041/api/auth/login)
ACCESS=$(echo "$TOKENS" | sed -E 's/.*"accessToken":"([^"]+)".*/\1/'); REFRESH=$(echo "$TOKENS" | sed -E 's/.*"refreshToken":"([^"]+)".*/\1/')
curl -s -w '\nHTTP %{http_code}\n' -H "Authorization: Bearer $ACCESS" "http://localhost:4041/api/opregister?opid=580"
# expect HTTP 200 with the patient
curl -s -w '\nHTTP %{http_code}\n' -H 'Content-Type: application/json' -d "{\"refreshToken\":\"$REFRESH\"}" http://localhost:4041/api/auth/refresh
# expect HTTP 200 {"status":"success","data":{"accessToken":"..."}}
curl -s -w '\nHTTP %{http_code}\n' -H 'Content-Type: application/json' -d '{"refreshToken":"bad"}' http://localhost:4041/api/auth/refresh
# expect HTTP 401
curl -s -w '\nHTTP %{http_code}\n' -H "Authorization: Bearer $ACCESS" -F opid=580 http://localhost:4041/api/tomogram
# expect 400 "Expecting narrations as an Array!" (auth passed, no files) — proves auth runs before multer
curl -s -w '\nHTTP %{http_code}\n' -F opid=580 http://localhost:4041/api/tomogram
# expect HTTP 401
```

- [ ] **Step 5: `README-api.md`** with the endpoint table from Global Constraints and the curl sequence above (credentials replaced by placeholders).

- [ ] **Step 6: Commit**

```bash
git add -A src README-api.md && git commit -m "feat(auth): enforce Bearer auth on opregister and tomogram, add refresh endpoint, fix login attributes"
```

---

### Task 2: Server settings-driven identifiers and local seed

**Files:**
- Create: `src/helpers/settings.ts`, `sql/seed-local-tomogram.sql`
- Modify: `src/models/main/settings.model.ts`, `src/middlewares/multer.ts`, `src/controllers/tomogram/tomogram.ts`

- [ ] **Step 1: Model attribute rename**

In `settings.model.ts` rename the attribute `opid` → `key` (keep `field: 'Key'`), and the interface `readonly key: string;`. In `multer.ts` the lookup becomes `mainDB.Settings.findOne({ where: { key: "TomogramPath" } })` and reads `uploadPath.get('value')`.

- [ ] **Step 2: `src/helpers/settings.ts`**

```ts
import { mainDB } from "../providers/Database";

export async function getSetting(key: string, fallback: string): Promise<string> {
    const row = await mainDB.Settings?.findOne({ where: { key } });
    const value = row?.get('value');
    return typeof value === 'string' && value.length > 0 ? value : fallback;
}

export async function getSettingInt(key: string, fallback: number): Promise<number> {
    const raw = await getSetting(key, String(fallback));
    const n = parseInt(raw, 10);
    return Number.isFinite(n) ? n : fallback;
}
```

- [ ] **Step 3: Use them in `uploadTomogramController`**

Before the transaction:

```ts
  const [doctorId, tomogramTypeId, tomogramPartId] = await Promise.all([
    getSettingInt('PrimaryDoctorID', 1),
    getSettingInt('TomogramTypeID', 6),
    getSettingInt('TomogramPartID', 2),
  ]);
```

and replace the literals: `{ opid: op?.id, doctorId, tomogramTypeId, narration: "" }` and `{ masterid: result.id, tomogrampartid: tomogramPartId, narration }`.

- [ ] **Step 4: `sql/seed-local-tomogram.sql`**

```sql
USE HospitalMain;
IF NOT EXISTS (SELECT 1 FROM dbo.TomogramType WHERE ID = 6)
BEGIN
  SET IDENTITY_INSERT dbo.TomogramType ON;
  INSERT INTO dbo.TomogramType (ID, Name) VALUES (6, 'Dermatology');
  SET IDENTITY_INSERT dbo.TomogramType OFF;
END
IF NOT EXISTS (SELECT 1 FROM dbo.TomogramPart WHERE ID = 2)
BEGIN
  SET IDENTITY_INSERT dbo.TomogramPart ON;
  INSERT INTO dbo.TomogramPart (ID, Name) VALUES (2, 'Skin');
  SET IDENTITY_INSERT dbo.TomogramPart OFF;
END
IF NOT EXISTS (SELECT 1 FROM dbo.Settings WHERE [Key] = 'TomogramTypeID')
  INSERT INTO dbo.Settings ([Key], [Value]) VALUES ('TomogramTypeID', '6');
IF NOT EXISTS (SELECT 1 FROM dbo.Settings WHERE [Key] = 'TomogramPartID')
  INSERT INTO dbo.Settings ([Key], [Value]) VALUES ('TomogramPartID', '2');
```

Do not run it against the database in this task; the user's DB already has the lookup rows. Mention it in `README-api.md`.

- [ ] **Step 5: Build, verify an upload still works end to end**

`npm run build` clean. Then with a token from Task 1 and any JPEG on disk (e.g. `E:/Projects/personal/deCare/hms/Tomogram/*.jpg` or create one with `curl -s -o /tmp/t.jpg https://...` is NOT allowed — use an existing local JPEG; if none exists, skip the upload curl and say so):

```bash
curl -s -w '\nHTTP %{http_code}\n' -H "Authorization: Bearer $ACCESS" -F opid=580 -F "images=@/e/Projects/personal/deCare/hms/Tomogram/<some>.jpg;type=image/jpeg" -F "narrations[0]=curl test" http://localhost:4041/api/tomogram
```
Expected HTTP 200 with the detail rows; a `<masterid>_<id>.JPEG` appears in `E:\Projects\personal\deCare\hms\Tomogram`.

- [ ] **Step 6: Commit** — `git add -A src sql README-api.md && git commit -m "feat(tomogram): settings-driven doctor/type/part ids; local seed script"`

---

### Task 3: Server tomogram history endpoint

**Files:**
- Modify: `src/controllers/tomogram/tomogram.ts`, `src/controllers/tomogram/index.ts`, `README-api.md`

- [ ] **Step 1: Controller**

```ts
export const listTomogramsController = async (req: Request, res: Response) => {
  const opid = Number(req.query.opid);
  if (!opid) return res.status(400).json(failResponse("Invalid opid"));
  try {
    const op = await mainDB.OpRegisters.findOne({ where: { opid } });
    if (!op) return res.status(404).json(failResponse("Invalid OP Number"));

    const masters = await mainDB.TomogramMasters.findAll({
      where: { opid: op.get('id') },
      order: [['date', 'DESC'], ['id', 'DESC']],
    });
    const masterIds = masters.map((m) => m.get('id') as number);
    const details = masterIds.length === 0 ? [] : await mainDB.TomogramDetails.findAll({
      where: { masterid: masterIds },
      order: [['id', 'ASC']],
    });
    const byMaster = new Map<number, any[]>();
    for (const d of details) {
      const list = byMaster.get(d.get('masterid') as number) ?? [];
      list.push({ id: d.get('id'), tomogramPartId: d.get('tomogrampartid'), narration: d.get('narration') ?? '' });
      byMaster.set(d.get('masterid') as number, list);
    }
    const data = masters.map((m) => ({
      id: m.get('id'),
      dateTime: m.get('date'),
      doctorId: m.get('doctorId'),
      tomogramTypeId: m.get('tomogramTypeId'),
      details: byMaster.get(m.get('id') as number) ?? [],
    }));
    return res.status(200).json(successResponse(data));
  } catch (e: any) {
    Log.error(e.message);
    return res.status(500).json(errorResponse("Internal Server Error", e.message));
  }
};
```

Check `tomogramDetail.model.ts` attribute names (`masterid`, `tomogrampartid`, `narration`) and adjust the `get()` keys to match exactly.

- [ ] **Step 2: Route** — `router.get('/', authentication, listTomogramsController);` in `src/controllers/tomogram/index.ts`.

- [ ] **Step 3: Build and verify**

```bash
npm run build && sleep 5
curl -s -w '\nHTTP %{http_code}\n' -H "Authorization: Bearer $ACCESS" "http://localhost:4041/api/tomogram?opid=580"
# expect 200 and a JSON array (possibly empty) of {id,dateTime,doctorId,tomogramTypeId,details:[...]}
curl -s -w '\nHTTP %{http_code}\n' -H "Authorization: Bearer $ACCESS" "http://localhost:4041/api/tomogram?opid=999999"
# expect 404 Invalid OP Number
```

- [ ] **Step 4: README-api.md** documents the response shape. **Commit**: `git add -A && git commit -m "feat(tomogram): list uploaded tomogram sets by OP number"`.

---

### Task 4: App: token refresh on 401 and session-expiry handling

**Files:**
- Modify: `lib/core/network/dio_client.dart`, `lib/core/network/auth_interceptor.dart`, `lib/features/auth/data/auth_api.dart`, `lib/features/auth/application/session_controller.dart`, `lib/features/auth/auth.dart`, `lib/main.dart`, `lib/app/app.dart`, `lib/core/l10n/app_en.arb`
- Create: `lib/app/session_expiry_listener.dart`
- Test: `test/core/network/dio_client_test.dart` (extend), `test/features/auth/session_controller_test.dart` (extend), `test/app/session_expiry_test.dart`

**Interfaces:**
- Produces in `core/network/dio_client.dart`:
  - `typedef TokenRefresher = Future<String?> Function();`
  - `final refreshAccessTokenProvider = Provider<TokenRefresher>((ref) => throw UnimplementedError(...))` (overridden in `main.dart`).
  - `final authFailureProvider = StateProvider<int>((ref) => 0)`: incremented when a protected request ends in 401 after the refresh attempt.
  - `Dio buildDio({required String baseUrl, required String? Function() tokenReader, TokenRefresher? refresher, VoidCallback? onAuthFailure})`.
- `AuthInterceptor extends QueuedInterceptorsWrapper`-style class (`QueuedInterceptor`) with constructor `AuthInterceptor({required Dio dio, required String? Function() tokenReader, TokenRefresher? refresher, VoidCallback? onAuthFailure})`.
- `AuthApi.refresh(String refreshToken) → Future<String>` (new access token; throws `ApiFailure`).
- `SessionController.refreshAccessToken() → Future<String?>`: null when no session or refresh fails (failure also clears nothing; logout is decided by the listener).
- `SessionExpiryListener({required Widget child})` in `lib/app/`: `ref.listen(authFailureProvider, ...)` → `logout()` and `showDsBanner(rootNavigatorKey.currentContext!, l10n.errorSessionExpired, kind: danger)` when a context is available.
- ARB: `errorSessionExpired` "Session expired, please sign in again".

- [ ] **Step 1: Failing tests**

Extend `test/core/network/dio_client_test.dart` with a scripted adapter (responses queued per call) and three tests:
1. `401 then refresh then retry succeeds`: adapter returns 401 for the first `/a`, 200 for the second; `refresher` returns `'new'`; assert the second request carried `Bearer new`, the final response is 200, `onAuthFailure` not called, refresher called once.
2. `refresh failure surfaces 401 and signals auth failure`: refresher returns null; expect `DioException` with 401, `onAuthFailure` called once, adapter saw one request.
3. `auth routes are not retried`: 401 on `/auth/login`; refresher never called; error propagates.

Extend `test/features/auth/session_controller_test.dart`: `refreshAccessToken stores the new token` (mock `api.refresh('r')` → `'A2'`; expect state and secure store `access_token == 'A2'`, refresh token unchanged) and `refreshAccessToken returns null on failure without clearing the session`.

`test/app/session_expiry_test.dart`: pump `HmsApp` via the `containerWith(url, session: true)` helper pattern from `app_gate_test.dart`, expect dashboard, then `c.read(authFailureProvider.notifier).state++`, `pumpAndSettle`, expect `find.text('Sign In')` and secure store cleared; pump 4 s for the banner.

- [ ] **Step 2: Implement `auth_interceptor.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

typedef TokenRefresher = Future<String?> Function();

/// Adds the Bearer header and, on a 401 from a protected route, refreshes the
/// access token once and retries. Auth routes are never retried.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.dio, required this.tokenReader, this.refresher, this.onAuthFailure});

  final Dio dio;
  final String? Function() tokenReader;
  final TokenRefresher? refresher;
  final VoidCallback? onAuthFailure;

  static const _retried = 'auth_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenReader();
    if (token != null && token.isNotEmpty) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final isAuthRoute = path.startsWith('/auth/');
    final alreadyRetried = err.requestOptions.extra[_retried] == true;
    if (status != 401 || isAuthRoute || alreadyRetried || refresher == null) {
      if (status == 401 && !isAuthRoute) onAuthFailure?.call();
      return handler.next(err);
    }
    String? newToken;
    try {
      newToken = await refresher!();
    } catch (_) {
      newToken = null;
    }
    if (newToken == null || newToken.isEmpty) {
      onAuthFailure?.call();
      return handler.next(err);
    }
    final opts = err.requestOptions;
    opts.headers['Authorization'] = 'Bearer $newToken';
    opts.extra[_retried] = true;
    try {
      final response = await dio.fetch<dynamic>(opts);
      return handler.resolve(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) onAuthFailure?.call();
      return handler.next(e);
    }
  }
}
```

Note: retrying a multipart upload requires a fresh `FormData`; Dio's `RequestOptions.data` for `FormData` cannot be re-sent after being read. Handle it: if `opts.data is FormData` and the form has already been finalized (`(opts.data as FormData).isFinalized`), do not retry; call `onAuthFailure` only if the refresh itself failed, otherwise `handler.next(err)` so the caller sees the 401 and the app's upload path treats it as `UnauthorizedFailure` (the queue will retry with the fresh token later). Document this in a comment.

- [ ] **Step 3: `dio_client.dart`** adds `refreshAccessTokenProvider`, `authFailureProvider`, and wires `buildDio` to construct `AuthInterceptor(dio: dio, ...)` after creating `dio`. `dioProvider` passes `refresher: () => ref.read(refreshAccessTokenProvider)()` and `onAuthFailure: () => ref.read(authFailureProvider.notifier).state++`.

- [ ] **Step 4: Auth feature**

`AuthApi.refresh` (Dio POST `/auth/refresh` `{refreshToken}` → `unwrapEnvelope(...)['accessToken']`, `BadDataFailure` if missing, all wrapped by `ApiFailure.from`). `SessionController.refreshAccessToken()`:

```dart
  Future<String?> refreshAccessToken() async {
    final current = state.valueOrNull;
    if (current == null) return null;
    try {
      final token = await ref.read(authApiProvider).refresh(current.refreshToken);
      final next = Session(accessToken: token, refreshToken: current.refreshToken);
      await ref.read(sessionRepositoryProvider).save(next);
      state = AsyncData(next);
      return token;
    } catch (_) {
      return null;
    }
  }
```

Important: `authApiProvider` depends on `dioProvider`, which depends on `accessTokenProvider`, which watches the session state. Refreshing changes the session, which rebuilds `dioProvider`. That is acceptable (the interceptor instance that is mid-retry keeps its own `dio` reference). Do not `ref.watch` the session inside `refreshAccessToken`.

- [ ] **Step 5: `main.dart` override and listener**

`refreshAccessTokenProvider.overrideWith((ref) => () => ref.read(sessionControllerProvider.notifier).refreshAccessToken())`.

`lib/app/session_expiry_listener.dart`:

```dart
class SessionExpiryListener extends ConsumerWidget {
  const SessionExpiryListener({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(authFailureProvider, (prev, next) {
      if (prev == next) return;
      final session = ref.read(sessionControllerProvider).valueOrNull;
      if (session == null) return;
      ref.read(sessionControllerProvider.notifier).logout();
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        showDsBanner(ctx, AppLocalizations.of(ctx).errorSessionExpired, kind: DsBannerKind.danger);
      }
    });
    return child;
  }
}
```

Wrap it around the `AnnotatedRegion` child in `HmsApp`'s `builder`.

- [ ] **Step 6: Verify and commit**

`flutter gen-l10n && flutter analyze && flutter test`; commit `feat(auth): refresh access token on 401 and sign out on session expiry`.

---

### Task 5: App: tomogram history section

**Files:**
- Create: `lib/features/tomogram/data/tomogram_set.dart`, `lib/features/tomogram/data/tomogram_history_api.dart`, `lib/features/tomogram/application/tomogram_history_controller.dart`, `lib/features/tomogram/presentation/widgets/tomogram_history_card.dart`
- Modify: `lib/features/tomogram/presentation/tomogram_screen.dart`, `lib/features/tomogram/tomogram.dart`, `lib/core/l10n/app_en.arb`
- Test: `test/features/tomogram/tomogram_history_test.dart` (API parsing + controller), `test/features/tomogram/tomogram_history_card_test.dart`, extend `tomogram_screen_test.dart`

**Interfaces:**
- `TomogramSetDetail(id, tomogramPartId, narration)`, `TomogramSet(id, dateTime: DateTime, doctorId, tomogramTypeId, details)` with `fromJson` tolerant of ISO strings and numeric strings; `TomogramSet.narrationsSummary` joins non-empty narrations with " · ", falling back to `null`.
- `abstract class TomogramHistoryApi { Future<List<TomogramSet>> list(int opid); }`, `DioTomogramHistoryApi(dio)` calling `GET /tomogram` with `queryParameters: {'opid': opid}`; `tomogramHistoryApiProvider`.
- `tomogramHistoryProvider = AsyncNotifierProvider.autoDispose.family<TomogramHistoryController, List<TomogramSet>, int>`; `build(opid)` fetches; `TomogramController.upload()` success calls `ref.invalidate(tomogramHistoryProvider(arg))`.
- `TomogramHistoryCard({required int opid})`: `DsCard`, header row = `DsIconTile(Icons.history, size: 32)`, title `l10n.tomogramHistoryTitle`, `DsChip(l10n.tomogramHistoryCount(count), mono)`, chevron toggling expansion (`AnimatedSize` over `DsMotion.base`); subtitle `l10n.tomogramHistoryLast(formatted)` where formatted = `DateFormat('d MMM HH:mm').format(set.dateTime.toLocal())`; expanded = rows per set (mono date, narrations summary or `tomogramHistoryNoNarration`). Loading: one `DsSkeleton.row()` inside the card; error: `Text(l10n.tomogramHistoryError, secondary)`; empty list: the widget returns `SizedBox.shrink()`.
- ARB: `tomogramHistoryTitle` "Already uploaded"; `tomogramHistoryCount` `"{count, plural, =1{1 set} other{{count} sets}}"` with `count` int placeholder; `tomogramHistoryLast` "Last {date}"; `tomogramHistoryError` "Could not load history"; `tomogramHistoryNoNarration` "No description".

- [ ] **Step 1: Failing tests** — API parses the documented JSON (two sets, details grouped, order preserved); controller exposes data and error; card renders collapsed count/last date, expands on tap to show narrations, hides when empty, shows error text on failure; tomogram screen test: with a mocked `TomogramHistoryApi` returning one set, the card appears above the empty state, and after a successful upload the history API is called a second time (`verify(() => api.list(42)).called(2)`).
- [ ] **Step 2: Implement** per the interfaces; `flutter gen-l10n`.
- [ ] **Step 3: Verify and commit** — `flutter analyze && flutter test`; `feat(tomogram): show already-uploaded tomogram sets per patient`.

---

### Task 6: App: offline upload queue and photo resizing

**Files:**
- Create: `lib/features/tomogram/data/pending_upload.dart`, `lib/features/tomogram/data/pending_uploads_repository.dart`, `lib/features/tomogram/application/connectivity_provider.dart`, `lib/features/tomogram/application/upload_queue_controller.dart`, `lib/features/tomogram/presentation/widgets/pending_uploads_sheet.dart`, `lib/features/tomogram/presentation/widgets/pending_line.dart`
- Modify: `pubspec.yaml` (add `connectivity_plus ^7.3.1`, `path_provider`), `lib/features/tomogram/application/media_picker_service.dart`, `lib/features/tomogram/application/tomogram_controller.dart`, `lib/features/tomogram/presentation/tomogram_screen.dart`, `lib/features/tomogram/tomogram.dart`, `lib/features/dashboard/presentation/widgets/context_strip.dart`, `lib/main.dart` (start the queue), `lib/core/l10n/app_en.arb`
- Test: `test/features/tomogram/pending_uploads_repository_test.dart`, `test/features/tomogram/upload_queue_controller_test.dart`, extend `tomogram_screen_test.dart`, `media_picker_service_test.dart`, `test/features/dashboard/dashboard_screen_test.dart`

**Interfaces:**
- `PendingFile(path, description)`; `PendingUpload(id, opid, patientName, files, createdAt, attempts = 0, lastError)` with `toJson`/`fromJson`, `copyWith`, `isFailed => attempts >= maxAttempts` where `const int maxUploadAttempts = 5`.
- `PendingUploadsRepository(prefs, Directory root)`: `List<PendingUpload> read()`, `Future<void> write(List<PendingUpload>)`, `Future<PendingUpload> stage(PendingUpload draft)` copies each file into `<root>/pending/<id>/<n>.jpg` and returns the entry with the new paths, `Future<void> purge(PendingUpload)` deletes the folder. `pendingUploadsRepositoryProvider` reads `sharedPreferencesProvider` and a new `appDocumentsDirProvider = Provider<Directory>` overridden in `main.dart` with `getApplicationDocumentsDirectory()` (awaited before `runApp`) and with a temp dir in tests.
- `abstract class ConnectivityService { Stream<bool> get onlineChanges; Future<bool> isOnline(); }`, `ConnectivityPlusService` maps `List<ConnectivityResult>` to `!contains(ConnectivityResult.none)`; `connectivityServiceProvider`; `FakeConnectivityService` in tests.
- `UploadQueueController extends AsyncNotifier<List<PendingUpload>>` with `enqueue(int opid, String patientName, List<TomogramDraft> drafts)`, `processQueue()`, `retryAll()` (resets `attempts` to 0 then processes), `discard(String id)`, `start()` (subscribe to connectivity; called once from `main.dart` after container creation via `container.read(uploadQueueProvider.notifier).start()`), `bool get isProcessing`. Processing rules per spec §5.2; uses `tomogramApiProvider.upload(opid, drafts-from-pending)` and on success `ref.invalidate(tomogramHistoryProvider(opid))`. Network failures = `CannotConnectFailure | TimeoutFailure`.
- `uploadQueueProvider = AsyncNotifierProvider<UploadQueueController, List<PendingUpload>>`; `pendingCountProvider = Provider<int>`; `pendingForOpidProvider = Provider.family<PendingUpload?, int>`.
- `TomogramScreen._upload`: on `CannotConnectFailure`/`TimeoutFailure` → `await queue.enqueue(...)`, `await controller.clearAll()` (the staged copies are separate files, so clearing the drafts deletes only the picker originals), banner `l10n.tomogramQueued` warning, `_pop()`.
- `PendingLine(opid)` widget: `DsCard` compact line `l10n.tomogramPendingLine(n)` "{n} photos waiting to upload" with a cloud-upload icon; shown above the history card when `pendingForOpidProvider(opid)` is non-null.
- Dashboard `ContextStrip`: when `pendingCountProvider > 0`, a `DsChip(text: l10n.dashboardPending(count), onShell: true)` inside an `InkWell` opening `showPendingUploadsSheet(context)`.
- `showPendingUploadsSheet(context)`: `showDsSheet` with a heading row (`l10n.queueTitle` "Pending uploads"), one `DsListRow` per entry (title patient name, `trailingValue` `'${files.length}'`, `trailingIcon: Icons.delete_outline` → `showDsDialog` then `discard`), rows for failed entries get a `label` secondary line with `lastError`; footer `DsButton.primary(l10n.queueRetry "Retry now", loading: isProcessing)` calling `retryAll()`.
- `MediaPickerService`: `pickImage(source: camera, maxWidth: 2000, maxHeight: 2000, imageQuality: 85)` and `pickMultiImage(maxWidth: 2000, maxHeight: 2000, imageQuality: 85)`; constants `const double pickerMaxDimension = 2000; const int pickerQuality = 85;`.
- ARB: `tomogramQueued` "Saved offline. It will upload when the server is reachable.", `tomogramPendingLine` `"{count, plural, =1{1 photo waiting to upload} other{{count} photos waiting to upload}}"`, `dashboardPending` `"{count, plural, =1{1 pending} other{{count} pending}}"`, `queueTitle` "Pending uploads", `queueRetry` "Retry now", `queueDiscard` "Discard", `queueDiscardTitle` "Discard pending upload?", `queueDiscardBody` "The photos will be deleted from this device.", `queueFailedLine` "Failed {attempts} times: {error}".

- [ ] **Step 1: Failing tests**
- Repository: round trip through prefs; `stage` copies files into the documents dir and the returned paths exist; `purge` deletes them.
- Controller (fake connectivity, mock `TomogramApi`, temp dir): enqueue stages files and persists; `processQueue` uploads oldest first and removes on success (files deleted, history invalidated: assert via a listener on `tomogramHistoryProvider` or by checking the mock upload order); `CannotConnectFailure` stops processing and leaves attempts unchanged; `RejectedFailure` increments attempts and continues to the next entry; entries with 5 attempts are skipped until `retryAll`; connectivity going offline→online triggers `processQueue` (emit on the fake stream, `await Future<void>.delayed(Duration.zero)`); concurrent `processQueue` calls do not double-upload.
- Screen: with `api.upload` throwing `CannotConnectFailure`, tapping Upload shows the queued banner, the draft list empties, and `uploadQueueProvider` has one entry; with `TimeoutFailure` the same; with `RejectedFailure` drafts stay (existing test).
- Media picker: `verify(() => picker.pickImage(source: ImageSource.camera, maxWidth: 2000, maxHeight: 2000, imageQuality: 85))` and the multi variant.
- Dashboard: with one pending entry the chip "1 pending" shows; tapping opens the sheet with the patient name; "Retry now" calls `processQueue` (mock api succeeds → entry removed → chip gone).

- [ ] **Step 2: Implement** per the interfaces. Key controller sketch:

```dart
class UploadQueueController extends AsyncNotifier<List<PendingUpload>> {
  bool _running = false;
  StreamSubscription<bool>? _sub;
  bool _lastOnline = true;

  @override
  Future<List<PendingUpload>> build() async => ref.watch(pendingUploadsRepositoryProvider).read();

  Future<void> start() async {
    _sub?.cancel();
    _sub = ref.read(connectivityServiceProvider).onlineChanges.listen((online) {
      final cameBack = online && !_lastOnline;
      _lastOnline = online;
      if (cameBack) processQueue();
    });
    ref.onDispose(() => _sub?.cancel());
    await processQueue();
  }

  Future<void> enqueue(int opid, String patientName, List<TomogramDraft> drafts) async {
    final repo = ref.read(pendingUploadsRepositoryProvider);
    final staged = await repo.stage(PendingUpload(
      id: ref.read(uuidProvider)(), opid: opid, patientName: patientName,
      files: [for (final d in drafts) PendingFile(path: d.filePath, description: d.description)],
      createdAt: DateTime.now(),
    ));
    final next = [...(state.valueOrNull ?? const []), staged];
    await repo.write(next);
    state = AsyncData(next);
    if (await ref.read(connectivityServiceProvider).isOnline()) processQueue();
  }

  Future<void> processQueue() async {
    if (_running) return;
    _running = true;
    try {
      var list = [...(state.valueOrNull ?? const <PendingUpload>[])];
      for (final entry in List<PendingUpload>.of(list)) {
        if (entry.isFailed) continue;
        try {
          await ref.read(tomogramApiProvider).upload(entry.opid, [
            for (final f in entry.files) TomogramDraft(id: '', filePath: f.path, description: f.description),
          ]);
          await ref.read(pendingUploadsRepositoryProvider).purge(entry);
          list.removeWhere((e) => e.id == entry.id);
          ref.invalidate(tomogramHistoryProvider(entry.opid));
        } on ApiFailure catch (e) {
          if (e is CannotConnectFailure || e is TimeoutFailure) break;
          final i = list.indexWhere((x) => x.id == entry.id);
          list[i] = entry.copyWith(attempts: entry.attempts + 1, lastError: e.detail ?? e.runtimeType.toString());
        }
        await ref.read(pendingUploadsRepositoryProvider).write(list);
        state = AsyncData(list);
      }
      await ref.read(pendingUploadsRepositoryProvider).write(list);
      state = AsyncData(list);
    } finally {
      _running = false;
    }
  }
  ...
}
```

`TomogramDraft.id` is only used for the multipart filename (`image<id>.jpg`); for queued files use the pending file index as the id (`'q$i'`) so filenames stay unique.

- [ ] **Step 3: `main.dart`**: `final docs = await getApplicationDocumentsDirectory();` override `appDocumentsDirProvider`; after the container is built and sessions loaded: `unawaited(container.read(uploadQueueProvider.notifier).start());`.
- [ ] **Step 4: Verify and commit** — `flutter gen-l10n && flutter analyze && flutter test`; `feat(tomogram): offline upload queue with automatic retry; resize photos at capture`.

---

### Task 7: End-to-end verification against the live server (controller-run)

Not delegated. With the server on 4041 and the emulator:
1. Auth: `curl` confirms `GET /api/opregister` without a token is 401 while the app still looks patients up (token attached). The refresh path cannot be exercised on device without waiting two hours, so the interceptor and controller tests are the evidence for it.
2. History: open a patient that has uploads; the "Already uploaded" card shows the count and expands to the narrations.
3. Offline: disable emulator networking (`adb shell svc wifi disable && adb shell svc data disable`), add a photo, tap Upload → queued banner and pop; the dashboard shows "1 pending"; re-enable (`adb shell svc wifi enable && adb shell svc data enable`); the queue uploads within seconds, the chip disappears, and a renamed `<masterid>_<id>.JPEG` lands in `E:\Projects\personal\deCare\hms\Tomogram`.
4. Photo size: the uploaded file is at most 2000 px on its long edge (check with `magick identify` if available, otherwise confirm the file is well under 1 MB).
Record results in the ledger; anything failing goes to a fix round.
