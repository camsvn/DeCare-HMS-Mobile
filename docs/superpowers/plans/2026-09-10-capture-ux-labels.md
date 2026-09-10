# Capture UX: labels, previews and suggestions — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Label photos while shooting, preview thumbnails full screen, fill descriptions from suggestions, inherit blank descriptions forward, and remove "Apply to all"; fix the Done pill.

**Architecture:** `Shot(path, label)` replaces the path list in the capture session; a `RecentLabelsRepository` and a pure `mergeSuggestions` feed a `descriptionSuggestionsProvider(opid)`; the capture screen gains a label pill + sheet, a compact Done and a `ShotPreviewScreen`; the draft list gains inherit-forward (`resolvedDrafts`), placeholders and `SuggestionChips`. All inside `lib/features/tomogram/`.

**Tech Stack:** Flutter 3.19 / Dart 3.3, flutter_riverpod 2.6, go_router 14, shared_preferences, mocktail. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-10-capture-ux-labels-design.md`

## Global Constraints

- Flutter 3.19 / Dart 3.3; never `flutter upgrade`; no new dependencies.
- `core` never imports `features`; cross-feature imports via barrels; all UI strings via `context.l10n` (ARB `lib/core/l10n/app_en.arb`, then `flutter gen-l10n`); widgets use design tokens only.
- Suggestions: patient history first (newest first, trimmed, distinct case-insensitively), then recent labels (max 10 stored) without duplicates; at most 8 shown.
- Effective descriptions (inherit forward) are what upload, the offline queue and "recent labels" use; the first card never inherits.
- `flutter analyze` clean and `flutter test` green before every commit; explicit `git add` paths. Branch `flutter-port` in `E:\Projects\personal\deCare\hms\HMSFlutter`.

---

### Task 1: Shots with labels, recent labels, suggestions

**Files:**
- Create: `lib/features/tomogram/data/shot.dart`, `lib/features/tomogram/data/recent_labels_repository.dart`, `lib/features/tomogram/application/recent_labels_controller.dart`, `lib/features/tomogram/application/description_suggestions.dart`
- Modify: `lib/features/tomogram/application/capture_controller.dart`, `lib/features/tomogram/presentation/capture_screen.dart` and `widgets/shot_strip.dart` (minimal type-only changes so the tree compiles: `shots.map((s) => s.path)`; the UX changes come in Task 2), `lib/features/tomogram/presentation/tomogram_screen.dart` (`_capture` maps `Shot.path` into `addFiles` for now), `lib/features/tomogram/tomogram.dart` (exports), `test/helpers/fake_camera_service.dart` if needed
- Test: `test/features/tomogram/capture_controller_test.dart` (extend), `test/features/tomogram/recent_labels_test.dart`, `test/features/tomogram/description_suggestions_test.dart`; adjust existing capture screen/tomogram screen tests for the `Shot` type only.

**Interfaces (produced):**
```dart
class Shot { const Shot({required this.path, this.label = ''}); final String path; final String label; Shot copyWith({String? label}); ==/hashCode on both fields; }

class CaptureState { ..., final List<Shot> shots; final String label; /* '' = none */ }
class CaptureController { void setLabel(String label); /* trimmed; only when status != failed is NOT required — always allowed */
  Future<bool> shoot(); /* appends Shot(path, label: state.label) */
  Future<List<Shot>> takeAll(); Future<void> remove(String path); ... }

class RecentLabelsRepository { RecentLabelsRepository(SharedPreferences prefs); static const key = 'recent_labels'; List<String> read(); Future<void> remember(Iterable<String> labels); }
// remember: trim, drop empty, prepend newest (input order preserved: first element is most recent), dedupe case-insensitively keeping the newest occurrence, cap 10.
class RecentLabelsController extends Notifier<List<String>> { build() => repo.read(); Future<void> remember(Iterable<String>) }
final recentLabelsProvider = NotifierProvider<RecentLabelsController, List<String>>(RecentLabelsController.new);

List<String> mergeSuggestions(List<String> history, List<String> recent, {int max = 8}); // history first (already newest first), then recent not already present (case-insensitive), trimmed, non-empty, cap max
final descriptionSuggestionsProvider = Provider.autoDispose.family<List<String>, int>((ref, opid) {
  final sets = ref.watch(tomogramHistoryProvider(opid)).valueOrNull ?? const [];
  final history = [for (final s in sets) for (final d in s.details) d.narration];
  return mergeSuggestions(history, ref.watch(recentLabelsProvider));
});
```

- [ ] **Step 1: Failing tests**
  - Controller: `setLabel('Left forearm')` then two shots → both `label == 'Left forearm'`; `setLabel('Right cheek')` then one shot → only the third carries it; earlier shots unchanged; `setLabel('  ')` → `label == ''` and later shots unlabelled; `takeAll()` returns `Shot`s with labels in order.
  - Repository: `remember(['Left forearm'])` then `remember(['left FOREARM', 'Back'])` → `read() == ['left FOREARM', 'Back']`? — no: newest first means the second call's items are most recent, in the given order, and the case-insensitive duplicate of the first call is dropped → `['left FOREARM', 'Back']`; blanks dropped; 12 distinct labels → 10 kept, the oldest two gone; persisted (new repository over the same prefs reads the same).
  - `mergeSuggestions`: history `['Left forearm','Left forearm ','BACK']`, recent `['back','Neck']` → `['Left forearm','BACK','Neck']`; cap 8; empty inputs → `[]`.
  - Provider: with a mocked `TomogramHistoryApi` returning two sets (narrations `'a'`, `'b'`) and recent `['c','a']` → `['b','a','c']`? History is newest first as returned by the API (the API already returns newest first; do not re-sort) — assert the order the API returns, then `c`.
- [ ] **Step 2: Implement**; keep the capture screen/strip compiling with path mapping only.
- [ ] **Step 3: Verify and commit** — `flutter analyze && flutter test`; `feat(tomogram): labelled shots, recent labels and description suggestions`.

---

### Task 2: Capture screen UX — label pill and sheet, compact Done, thumbnail preview

**Files:**
- Create: `lib/features/tomogram/presentation/widgets/label_pill.dart`, `lib/features/tomogram/presentation/widgets/label_sheet.dart` (`showLabelSheet`), `lib/features/tomogram/presentation/widgets/suggestion_chips.dart`, `lib/features/tomogram/presentation/shot_preview_screen.dart`
- Modify: `lib/features/tomogram/presentation/capture_screen.dart` (`CaptureScreen({required int opid})`, layout), `lib/features/tomogram/presentation/widgets/shot_strip.dart` (`List<Shot>`, tag dot, tap → preview), `lib/features/tomogram/tomogram.dart` (route passes `opid`; exports), `lib/core/l10n/app_en.arb`
- Test: `test/features/tomogram/capture_screen_test.dart` (extend/adjust), `test/features/tomogram/shot_preview_screen_test.dart`, `test/features/tomogram/label_sheet_test.dart`, `test/core/design/...` none; `test/app/app_gate_test.dart` route test adjusts to `CaptureScreen(opid: 581)`.

**Interfaces:**
- `LabelPill({required String label, required VoidCallback onTap})`: pill on `ds.shellRaised`, radius `DsRadius.full`, icon `Icons.label_outline` when empty / `Icons.edit_outlined` when set, text `label.isEmpty ? l10n.captureAddLabel : label` (ellipsis, max 1 line), `Semantics(button: true, label: label.isEmpty ? captureAddLabel : captureLabelled(label))`.
- `Future<String?> showLabelSheet(BuildContext context, {required String initial, required List<String> suggestions})`: `showDsSheet` with heading `captureLabelTitle`, `DsTextField(autofocus: true, maxLength: 200, hint: captureLabelHint, textInputAction: done, onSubmitted → use)`, `SuggestionChips(wrap: true, onPick: fills the field)` when `suggestions.isNotEmpty`, footer: `DsButton.ghost(commonCancel)`, `DsButton.ghost(captureLabelClear)` only when `initial.isNotEmpty` (returns `''`), `DsButton.primary(captureLabelUse, expand: false)` returns the trimmed text. Returns `null` on cancel/dismiss.
- `SuggestionChips({required List<String> suggestions, required ValueChanged<String> onPick, bool wrap = false, bool onShell = false})`: `Semantics(header: true, label: tomogramSuggestions)` container; each chip `DsChip` inside an `InkWell` (radius full); `wrap` → `Wrap(spacing: DsSpace.x2, runSpacing: DsSpace.x2)`, else horizontal `ListView`/`SingleChildScrollView` row; `SizedBox.shrink()` when empty.
- `ShotStrip({required List<Shot> shots, required ValueChanged<int> onTap})`: 56 dp thumbnails as today; a labelled shot shows an 8 dp `ds.accentSolid` dot with a 1 dp `ds.shell` border at bottom-right; semantics `'${tomogramCounter(i+1, n)}${label.isEmpty ? '' : ', ${captureLabelled(label)}'}'`, button.
- `ShotPreviewScreen({required int initialIndex})`: reads `captureControllerProvider`; `PageView.builder` over `shots` (`Image.file(File(path), fit: BoxFit.contain)`), `PageController(initialPage)`; top row on shell: close (`closeButtonTooltip`) and `DsChip(tomogramCounter(page+1, n), mono, onShell)`; label text (`type.label`, `textOnShellMuted`) under it when non-empty; bottom `DsButton.destructive(label: captureRemove, expand: false, onPressed: _remove)` → `showDsDialog(captureRemoveTitle/Body, confirmLabel: captureRemove, destructive: true)` → `controller.remove(path)`; if `shots` becomes empty → pop; else clamp the page index. Pushed from `CaptureScreen` via `Navigator.of(context).push(PageRouteBuilder(opaque: true, transitionDuration: DsMotion.of(ctx, DsMotion.base), pageBuilder: ..., transitionsBuilder: fade))`.
- `CaptureScreen` layout changes: bottom panel = `Column[ ShotStrip, LabelPill (left-aligned, above the row), Row[ Expanded(Align(left, count chip)), ShutterButton, Expanded(Align(right, DsButton.primary(captureDone, expand: false, height: 40, loading: _finishing, onPressed: shots.isEmpty || _finishing ? null : _done))) ] ]`; label pill `onTap` → `showLabelSheet(initial: state.label, suggestions: ref.read(descriptionSuggestionsProvider(opid)))` → on non-null result `controller.setLabel(result)`; disabled while `_finishing`. Thumbnail tap → push preview (guarded by `_finishing`).
- Route: `captureRoute` pageBuilder reads `int.tryParse(state.pathParameters['opid'] ?? '') ?? 0` → `CaptureScreen(opid: opid)`.
- ARB: `captureAddLabel`, `captureLabelTitle`, `captureLabelHint`, `captureLabelUse`, `captureLabelClear`, `captureLabelled` (String `label`), `tomogramSuggestions`.

- [ ] **Step 1: Failing tests**
  - Capture screen: Done pill is not expanded (its width < half the surface) and disabled at zero; label pill shows "Add a label"; tapping it opens the sheet; typing "Left forearm" + "Use label" → pill shows "Left forearm"; shots taken afterwards carry the label (strip shows a dot; `takeAll` via Done pops shots with `label == 'Left forearm'`); a suggestion chip in the sheet fills the field; "Clear label" appears only when set and clears; tapping a thumbnail pushes `ShotPreviewScreen` at that index (counter "2 of 3") and shows NO remove dialog directly.
  - Preview: swipe changes the counter; Remove → dialog → confirm → file deleted, counter "1 of 2"; removing the last shot pops the preview; label shown under the counter when set.
  - Route test updated for `opid`.
- [ ] **Step 2: Implement**; `flutter gen-l10n`.
- [ ] **Step 3: Verify and commit** — `flutter analyze && flutter test`; `feat(tomogram): label while shooting, compact Done, full-screen shot preview`.

---

### Task 3: Draft list — labels as descriptions, inherit forward, suggestions, remove "Apply to all"

**Files:**
- Modify: `lib/features/tomogram/application/tomogram_controller.dart` (`addDrafts`, `resolvedDrafts`, remove `applyDescriptionToAll`, remember labels on upload success), `lib/features/tomogram/presentation/tomogram_screen.dart` (`_capture` → `addDrafts`, enqueue `resolvedDrafts` and remember labels, remove `_applyToAll`), `lib/features/tomogram/presentation/widgets/tomogram_card.dart` (`inheritedDescription`, `suggestions`/`onSuggestion`, remove `onApplyToAll`), `lib/core/l10n/app_en.arb` (add `tomogramSameAsPrevious`; remove the three apply-all keys), `README.md`
- Test: `test/features/tomogram/tomogram_controller_test.dart`, `tomogram_screen_test.dart` (replace apply-all tests), `tomogram_card_test.dart` if present

**Interfaces:**
- `TomogramController.addDrafts(Iterable<({String path, String description})> items)`; `addFiles(paths)` delegates with `''`.
- `List<TomogramDraft> get resolvedDrafts`: walk `state.drafts`; `effective = d.description.trim().isEmpty ? previousEffective : d.description`; first card's previous is `''`. Returned drafts carry the effective description; ids/paths unchanged.
- `upload()` posts `resolvedDrafts`; on success `ref.read(recentLabelsProvider.notifier).remember(resolvedDrafts.map((d) => d.description))` before invalidating history.
- Screen: `_upload` passes `notifier.resolvedDrafts` to `queue.enqueue(...)` and calls `remember` with their descriptions after a successful enqueue.
- `TomogramCard({..., String? inheritedDescription, List<String> suggestions = const [], ValueChanged<String>? onSuggestion})`: `DsTextField(hint: inheritedDescription == null ? null : l10n.tomogramSameAsPrevious(inheritedDescription))`; under the field, when `draft.description.isEmpty && suggestions.isNotEmpty`, `SuggestionChips(suggestions, onPick: onSuggestion)` with `DsSpace.x2` above.
- Screen builds `inheritedDescription` for card `i` as the effective description of card `i-1` when card `i` is blank and that effective text is non-empty; `suggestions = ref.watch(descriptionSuggestionsProvider(_opid))`.

- [ ] **Step 1: Failing tests**
  - Controller: `addDrafts` keeps order and descriptions; `resolvedDrafts` — `['a','','','b','']` → `['a','a','a','b','b']`; `['', 'x']` → `['', 'x']`; upload posts resolved descriptions (mock `TomogramApi.upload` captures drafts) and `recentLabelsProvider` afterwards equals `['b','a']`-style newest-first distinct (define: remember is called with descriptions in draft order → repository treats the first as most recent, so expect `['a','b']` for drafts a,a,a,b,b — assert exactly what the repository contract yields).
  - Screen: `onCapture` returning `[Shot(path1, 'Left forearm'), Shot(path2, '')]` → first card field text "Left forearm", second card hint "Same as previous photo: Left forearm"; typing in the second clears the hint; Upload sends `['Left forearm','Left forearm']`; with a history mock returning narration "Back" and recent `['Neck']`, an empty card shows chips "Back","Neck" and tapping "Back" fills it; a filled card shows no chips; `find.text('Apply to all')` finds nothing; offline path (`CannotConnectFailure`) enqueues resolved descriptions and remembers labels.
- [ ] **Step 2: Implement**; `flutter gen-l10n`; README tomogram paragraph: labels while shooting, suggestions, inherit forward.
- [ ] **Step 3: Verify and commit** — `flutter analyze && flutter test`; `feat(tomogram): descriptions from labels, suggestions and inherit-forward; drop apply-to-all`.

---

### Task 4: Device verification (controller-run)

Debug build on the emulator, signed in, server up: open SAJU (581) → Take Photo → set label "Left forearm" (pick a suggestion if history offers one) → two shots → set label "Right cheek" → two shots → tap a thumbnail → preview, swipe, Remove one → Done → four/three cards: labels present, blank placeholders correct → Upload → `GET /api/tomogram?opid=581` shows the narrations in order → reopen the patient → chips show "Left forearm", "Right cheek". Record in the ledger.
