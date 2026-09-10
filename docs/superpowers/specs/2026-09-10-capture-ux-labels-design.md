# Capture UX: labels while shooting, previews, and reuse instead of typing — design

Date: 2026-09-10. Status: approved in conversation. Follows `2026-09-10-in-app-capture-design.md`.

## 1. Feedback this answers

After trying the in-app capture the user reported: the Done button on the capture screen looks
wrong (a stretched primary button beside the shutter); tapping a thumbnail jumps straight to a
delete prompt where a preview was expected; and "Apply to all" in the draft list is not intuitive.
The user asked for a description flow designed from real use rather than a relabel.

## 2. How the photos are actually taken

A skin visit produces two kinds of sets: several angles of one site ("left forearm, eczema, day
0") or one photo each of several sites. Follow-up visits repeat the same site names as the last
visit. Typing on the phone after shooting, card by card with the keyboard bouncing, is the slow
part; many staff skip descriptions entirely because of it. "Apply to all" served only the first
case and required understanding a copy operation.

## 3. Design

### 3.1 Label while you shoot (capture screen)

A label pill sits above the bottom row of the capture screen. Empty it reads "Add a label"; set,
it shows the label with an edit icon. Tapping it opens a bottom sheet with a text field (max 200,
autofocus, hint "e.g. Left forearm"), suggestion chips (see 3.3), "Use label", "Clear label" (only
when a label is set) and Cancel. Every shot taken while a label is set carries that label. Changing
the label mid-session affects later shots only, so a two-site visit is: set "Left forearm", shoot,
set "Right cheek", shoot, Done. Labelled thumbnails show a small accent dot; their semantics label
includes the label text. The session's current label is not persisted across sessions.

### 3.2 Compact Done and full-screen preview (capture screen)

- Bottom row: count chip left, shutter centred, and a compact "Done" pill on the right sized to its
  text (`DsButton.primary(expand: false, height: 40)`), muted while there are no shots, loading
  while Done is handing shots over. The label pill sits above this row, left-aligned.
- Tapping a thumbnail opens a full-screen preview on the same navigator: shell background, a
  `PageView` of the shots (`BoxFit.contain`, swipe between them, starting at the tapped one), a top
  row with close and a mono counter "2 of 3", the shot's label under the counter when present, and
  a bottom "Remove" destructive button (not stretched). Remove asks "Remove this photo?" as today;
  after removal the preview moves to the neighbouring shot, or closes when none remain. The strip
  itself no longer deletes on tap.

### 3.3 Suggestions instead of typing

Whenever a description can be entered a row of tap-to-fill chips shows up to eight suggestions.
The draft card shows them only while its field is blank (spaces included) — it already has a
placeholder and a value to lose; the label sheet shows them whenever there are any, since picking a
*different* suggestion for an existing label is the normal way to relabel. The suggestions come
from `descriptionSuggestionsProvider`, which watches `tomogramHistoryProvider(opid)` and so fetches
the patient's history if the screen has not loaded it yet. The eight are:
1. This patient's previous narrations, from the already-loaded history (`tomogramHistoryProvider`),
   newest first, trimmed, distinct case-insensitively;
2. then the last ten labels used on this device (any patient), most recent first, minus duplicates.
Tapping a chip fills the field (label sheet: fills the text field; card: sets the description).
Recent labels are remembered when a set is uploaded (immediately, or from the offline queue) using
the effective descriptions of that set (3.4), non-empty and distinct. Stored in `SharedPreferences`
under `recent_labels`.

### 3.4 Inherit forward (draft list)

Captured shots arrive in the draft list with their label as the description. A card whose
description is blank inherits the previous card's effective description at upload time; the field
shows this as its placeholder, "Same as previous photo: Left forearm", so it is visible and a single
tap to type over. The first card has no previous, so blank stays blank. The effective descriptions
are what the upload and the offline queue send, and what "recent labels" remembers.

### 3.5 Removed

"Apply to all" (button, dialog, controller method, ARB keys) is removed; 3.1 and 3.4 replace it.

### 3.6 Follow-up (2026-09-10)

Setting the label before shooting works, but it did not read as part of taking photos, and a shot
already taken could not be re-described without retyping the session label. Two changes:

**The pill says what the label is for, and can be dropped in one tap.** Empty it reads "Label next
photos" (`captureLabelNext`) rather than "Add a label" — the old copy left it to be guessed which
photos a label would land on. Set, it reads "Next photos: Left forearm" (`captureNextPhotos`, one
line, ellipsised), and a trailing × appears beside it: `Icons.close`, its own 44 dp target, its own
button semantics, tooltip "Clear label" (`captureLabelClear`, reused from the sheet). The × calls
`setLabel('')` straight away — clearing was three taps through the sheet, and "the next few are of
nothing in particular" is one thought. The text half still opens the sheet. Both halves are inert
while Done is handing the shots over, like everything else on that screen.

**The preview relabels one shot.** The label is a full-width caption row directly under the photo
(`shotPreviewLabelKey`), always present: this shot's description in `type.body`, or "Add a label"
(`captureAddLabel`, kept for exactly this) muted, with a leading `Icons.edit_outlined` when it has
one and `Icons.label_outline` when it does not. The whole row is the button, two lines deep and
ellipsised — as a chip beside the counter it read as metadata about the photo rather than as its
caption, and truncated most real descriptions.

The screen around it is a photo viewer rather than a form. The photo runs edge to edge from the top
of the screen to the bottom bar, `BoxFit.contain` on `ds.shell`, with no margins of its own; the
header (close left, mono counter right) floats over the top of it on a `ds.shell` scrim that fades
to nothing, costing no layout height and — being `IgnorePointer` outside its buttons — no swipe.
Everything else lives in one bottom bar on `ds.shell` under `SafeArea`, at least 56 dp deep: the
caption takes the width, and the only other control is a trash `IconButton` (`Icons.delete_outline`
in `ds.danger`, 48 dp target, tooltip and semantics label `captureRemove`) on the same row, asking
the same "Remove this photo?" as before. The standalone Remove button, the side margins and the dead
band between them are gone. Tapping the caption opens the
same label sheet, prefilled with the shot's own label and offering the same suggestions
(`descriptionSuggestionsProvider(opid)` — so `ShotPreviewScreen` now takes `opid`, passed from
`CaptureScreen`). A result goes to `CaptureController.relabel(path, label)`, which trims and sets
that one shot's label and nothing else: unknown paths are ignored, and `state.label` — what the
*next* shot will be taken under — is left alone, because fixing a photo already on screen says
nothing about the ones to come. The sheet's Clear returns `''` and takes the description off. The
chip and the strip's tag dot both follow, since the screen watches the session.

New ARB keys: `captureLabelNext`, `captureNextPhotos` (String `label`). Tests: `label_pill_test.dart`
(copy, the × vs. the text, both targets, both semantics nodes), the capture screen (× clears in one
tap and the next shot is unlabelled; × inert while finishing), the controller (`relabel` scope,
trimming, unknown path, `state.label` untouched) and the preview (caption copy, the edge-to-edge photo
with its overlay header, the one bottom bar, a swipe that still turns the page through the overlay,
a 120-character description over two lines, the prefilled sheet, relabelling only the shot on
screen, Clear, cancel, and suggestions from a stubbed history).

### 3.7 One viewer, both lists (2026-09-10)

The gallery-style preview is a widget rather than a screen: `PhotoViewer({photos, initialIndex,
onEditCaption, onRemove})` over `ViewerPhoto(path, caption, captionHint)`, in
`presentation/widgets/photo_viewer.dart`, with no Riverpod inside it. It owns nothing but the page it
is on: a caller hands it a list, and a shorter list on the next build is how a removal arrives — the
viewer steps back onto the photo that took the slot, or pops itself when the last one goes. The
layout is §3.6's: edge-to-edge `PageView`, overlay header, one bottom bar of caption plus bin, and
the caption row keeps the button semantics under the key `photoViewerCaptionKey`.

`ShotPreviewScreen` and the new `DraftPreviewScreen({opid, initialIndex})` are the two thin Riverpod
wrappers over it. The draft list needed the same viewer for the same reason the capture screen did: a
card crops its photo to 16:10, which is enough to tell two photos apart and not enough to check one.
Tapping a card's image (`TomogramCard.onTapImage`, with `tomogramCounter` button semantics) pushes
the viewer with the same fade the capture screen uses. Its caption is the draft's own description
when it has one; blank, it shows "Same as previous photo: …" as the `captionHint`, because a blank
description there is an inheritance rather than an absence — the same sentence the card's placeholder
shows, from the same source: `TomogramController.inheritedDescriptionFor(index)`, which the card and
the viewer now share so their promise cannot drift from `resolvedDrafts`. Editing opens the label
sheet prefilled with the draft's own text (not the inherited placeholder: typing over an inheritance
is a decision, not a correction) and writes through `updateDescription`; the sheet's Clear returns
`''` and hands the photo back to inheriting. The bin calls `remove(id)` without asking, which is what
the card's delete has always done.

### 3.8 Zoom, grid, suggestion hygiene (2026-09-10)

**Zoom.** `CameraService` gains `maxZoom` (1 until the camera is ready, so a screen built before
initialisation offers no zoom rather than a range it cannot honour) and `setZoom(level)`;
`PluginCameraService` reads `getMinZoomLevel`/`getMaxZoomLevel` through `_tryOptional` after
`initialize` and clamps into that range, so a camera that will not say keeps 1..1 and every call is a
no-op. `CaptureState.zoom` is the level the preview is at, clamped to `[1, maxZoom]` by
`CaptureController.setZoom` and ignored until the camera is ready. `start()` asks for a non-1 zoom
again — CameraX rebinds the session on open and comes back at 1× — and re-clamps it, because the
camera that came back may not reach as far; `stop()` keeps the value, since the shot being framed is
the same one. Every `setZoom` forwards without comparing against the level already set: a pinch is a
stream of small changes and dropping the ones that round the same would make it stutter.

On the screen, the preview's `GestureDetector` carries `onScaleStart`/`onScaleUpdate` alongside
`onTapUp`; the arena resolves them, so a press that does not move is still a tap-to-focus, and a
one-pointer scale update is ignored (a drag is not a pinch). A mono chip on the shell, centred just
above the bottom panel, reads `captureZoomLevel` ("1.0×") and steps 1× → 2× → 1× on tap for a thumb
that does not want to pinch; it is absent when `maxZoom <= 1`, and inert while Done is handing the
shots over, like everything else on that screen.

**Grid.** `captureGridProvider` is a device preference in `capture_grid` (default off): framing with
thirds is a habit, not a per-session choice. A third header button (`Icons.grid_3x3` /
`Icons.grid_off`, `captureGridOn` / `captureGridOff`) toggles an `IgnorePointer` `CustomPaint` of two
lines each way in `textOnShell` at 35% over the preview area only — never over the bottom panel,
because it is a framing aid for the picture. It draws over whatever box it is given, so the cover
crop needs no arithmetic: the grid is on the screen, which is what the eye lines the subject up
against.

**Suggestion hygiene.** `suggestionMaxLength` (40) is the longest a description may be and still be
offered: narrations run to 200 characters, and a sentence as a chip wraps over two lines and pushes
the row off the screen. `mergeSuggestions` drops anything past it, and `RecentLabelsRepository`
filters on read as well as on write, so a device that stored a sentence before the cap existed stops
offering it with no migration. `RecentLabelsController.forget(label)` removes one case-insensitively
and persists — a wrong guess that keeps coming back is worse than no guess. `SuggestionChips` takes
`removable` (lower-cased) and `onLongPress`, and a long press on one of the device's own labels asks
`suggestionForgetTitle` / `suggestionForgetBody` / `suggestionForget` through the shared
`confirmForgetSuggestion`. The patient's uploaded narrations are not removable: they are what the
server says, and nothing on the device can unsay it. An open label sheet keeps the list it was handed
— the forgotten chip is gone from the next one, which is the sheet the user sees it in.

New ARB keys: `captureZoomLevel` (String `level`), `captureGridOn`, `captureGridOff`,
`suggestionForgetTitle`, `suggestionForgetBody`, `suggestionForget`.

## 4. Architecture

All inside `lib/features/tomogram/`.

- `Shot({required String path, String label = ''})` (data). `CaptureState.shots` becomes
  `List<Shot>`; `CaptureState.label` (current label, `''` when none). `CaptureController.setLabel(String)`;
  `shoot()` attaches `state.label`; `takeAll()` → `Future<List<Shot>>`; `remove(path)` unchanged.
- `RecentLabelsRepository(prefs)` (data): `List<String> read()`, `Future<void> remember(Iterable<String>)`
  (trim, drop empty, case-insensitive dedupe keeping the newest, cap 10). `recentLabelsProvider`
  (`NotifierProvider<RecentLabelsController, List<String>>`, `remember` updates state and prefs).
- `mergeSuggestions(List<String> history, List<String> recent, {int max = 8})` pure;
  `descriptionSuggestionsProvider = Provider.autoDispose.family<List<String>, int>` combining
  `tomogramHistoryProvider(opid).valueOrNull` narrations and `recentLabelsProvider`.
- `CaptureScreen(opid)` (route passes the path parameter) → label pill, `showLabelSheet`, Done pill,
  `ShotStrip(shots, onTap)` with tag dots, `ShotPreviewScreen(initialIndex)` pushed with a fade.
- `SuggestionChips({suggestions, onPick, wrap = false})` widget shared by the label sheet (wrap) and
  the draft card (horizontal row).
- `TomogramController.addDrafts(Iterable<({String path, String description})>)`; `addFiles` stays for
  the gallery path. `List<TomogramDraft> get resolvedDrafts` applies inherit-forward; `upload()` sends
  `resolvedDrafts` and the screen passes `resolvedDrafts` to the queue. On upload success (controller)
  and on enqueue (screen) the effective descriptions go to `recentLabelsProvider.remember`.
- `TomogramCard` gains `inheritedDescription: String?` (placeholder) and `suggestions` + `onSuggestion`.

## 5. Copy (ARB)

| key | text |
| --- | --- |
| `captureAddLabel` | Add a label |
| `captureLabelTitle` | Label these photos |
| `captureLabelHint` | e.g. Left forearm |
| `captureLabelUse` | Use label |
| `captureLabelClear` | Clear label |
| `captureLabelled` | Labelled {label} (semantics, String) |
| `tomogramSameAsPrevious` | Same as previous photo: {text} (String) |
| `tomogramSuggestions` | Suggestions (semantics header for the chips) |

Reused: `captureRemove`, `captureRemoveTitle`, `captureRemoveBody`, `tomogramCounter`, `commonCancel`,
`captureDone`. Removed: `tomogramApplyToAll`, `tomogramApplyAllTitle`, `tomogramApplyAllBody`.

## 6. Testing

- Controller: label attaches to later shots only; `takeAll` returns shots with labels; `setLabel('')` clears.
- Repository/provider: remember dedupes case-insensitively, keeps newest first, caps at 10, persists.
- `mergeSuggestions`: history first, recent appended without duplicates, cap 8, blanks dropped.
- Capture screen: Done pill compact and disabled at zero; label pill text; sheet fills from a chip
  and returns the label; shots taken after setting a label carry it (thumbnail dot); thumbnail tap
  opens the preview at that index; swipe changes the counter; Remove in the preview deletes and
  moves on / closes; no delete dialog from the strip.
- Draft list: captured labels arrive as descriptions; blank second card shows the inherit placeholder
  and uploads with the inherited narration; chips appear only when the field is empty and fill it;
  no "Apply to all" anywhere; recent labels remembered after upload and after queueing.
- Device: label two sites across four shots, preview and remove one, Done, verify placeholders and
  chips, upload, verify narrations on the server (`GET /tomogram?opid=`) and the chips on the next
  visit.

## 7. Risks

- Inheritance is implicit at upload; the visible placeholder is the mitigation. A blank first card
  stays blank, as today.
- Suggestions depend on the history request; when it fails, only recent labels show.
- **Privacy.** Recent labels are device-wide by design: they are body-site text ("Left forearm"),
  reused across patients and across whoever is signed in, and they are not cleared on logout — that
  is what makes them useful on a shared clinic phone. So they must stay body-site text: staff should
  not type patient-identifying text into a label, since the next patient's suggestion row would
  offer it back. Remembering is also best-effort — a device that cannot write its prefs still
  uploads and queues normally.
