# Capture UX: labels, previews and suggestions — execution log

Ledger of the subagent-driven execution (pre-flight scan, rulings, review outcomes, device checks, parked findings). Copied from the SDD workspace on completion.

# SDD ledger — plan: docs/superpowers/plans/2026-09-10-capture-ux-labels.md
Spec: docs/superpowers/specs/2026-09-10-capture-ux-labels-design.md. Branch flutter-port.

Pre-flight scan (2026-09-10):
| T1 -> T2 | Shot, CaptureState.label, setLabel, takeAll -> List<Shot>, descriptionSuggestionsProvider, recentLabelsProvider | consumed by the screen/sheet | consistent |
| T1 -> T3 | Shot from takeAll -> addDrafts records; recentLabelsProvider.remember | T3 owns addDrafts/resolvedDrafts | consistent |
| T1 | keeps capture screen/strip/tomogram screen compiling with path mapping only | T2/T3 replace those spots | acceptable transitional step |
| T2 <-> T3 | SuggestionChips created in T2, reused by T3 card | T2 must export it from the barrel | ruling: T2 exports |
| T3 | removes apply-all keys/tests; T2 must not reference them | T2 brief does not | consistent |
| T1 test text | repository newest-first semantics spelled out with a self-correction in the brief | implementer follows the final stated expectation (second call items first, dup dropped) | ruling recorded |

Task 1: dispatched (BASE a78d517).
Task 1: DONE (eb5f293, 365 tests). Ruling: shot_strip left as List<String> for now (T2 retypes). Review dispatched.
Task 1: complete (a78d517..eb5f293, review Approved, no findings).
Task 2: dispatched (BASE eb5f293).
Task 2: DONE_WITH_CONCERNS (27ffbc6, 388 tests). Rulings: (1) showDsSheet must respect the keyboard (isScrollControlled + viewInsets padding, keep the 9/16 cap) — core change, goes into the Task 2 fix round; (2) label sheet shows suggestions whenever present (accepted; draft cards keep empty-only per T3 brief); (3) pill guards _finishing internally (accepted). Review dispatched.
Task 3: dispatched (BASE 27ffbc6) in parallel with the Task 2 review (read-only); any Task 2 fix round is held until Task 3 reports to avoid concurrent commits.
Task 2: review Needs fixes — Important: (1) LabelPill excludeSemantics strips the tap action (screen reader cannot open the sheet); (2) suggestion chips/pill tap targets ~25-33dp, need 44dp min. Fix round 1/5 to include the ds_sheet keyboard ruling (isScrollControlled + viewInsets padding + scrollable body, 9/16 cap kept) and minors 4 (preview cacheWidth), 5 (watch suggestions in build). HELD until Task 3 reports (no concurrent implementers).
Task 3: DONE (02c054f, 395 tests). Review dispatched. Task 2 fix round 1 dispatched now (FIX_BASE 27ffbc6, on top of 02c054f).
Task 3: review Approved (minors: ref.read after awaits in _upload offline path -> hoist notifier read; whitespace-only blank test mismatch (isEmpty vs trim); untrimmed descriptions posted). Ruling: send minors 1-3 to the Task 3 implementer as a small round after the Task 2 fix round lands (serial commits).
Task 2: fix round 1 done (db6bb4b, 401 tests). Scoped re-review dispatched. Task 3 minors round dispatched (FIX_BASE db6bb4b).
Task 2: complete (eb5f293..27ffbc6 + db6bb4b, re-review clean). Parked: pending_uploads_sheet hardcodes 9/16 instead of dsSheetMaxHeightFactor (comment stale).
Task 3: fix round 1 done (b679599, 404 tests). Scoped re-review dispatched. Task 4: building debug at b679599 for device checks.
Task 3: complete (27ffbc6..02c054f + b679599, re-review clean). Task 4 (device, debug b679599) started.
Task 4: controller found DsButton(expand:false) filled bounded parents (Container alignment) -> fixed in core with tests (406 tests); commit above. Device walk continues.
Task 4 (device, debug c66cf97): compact Done pill OK after DsButton fix; label pill -> sheet with patient-history chips (8) above the keyboard (keyboard-safe sheet verified); typed label attached to 2 shots, chip label to the 3rd, tag dots shown; preview 1 of 3 with label, swipe -> 2 of 3, Remove -> 2 of 2 showing next shot; Done -> 2 drafts with labels as descriptions; clearing the 2nd shows "Same as previous photo: Right cheek." and suggestion chips; Upload -> server DB connection timed out (server process cannot reach SQL Server after the low-memory event; sqlcmd works) -> app queued it ("1 pending"). Server-side narration check blocked until the server is restarted by the user; DB shows latest master 19 from earlier. Final whole-branch review dispatched (a78d517..c66cf97).
Final review (a78d517..c66cf97): With fixes. Important: remember() on the critical path of upload/enqueue success (prefs failure -> leaked files / duplicate upload). ONE fix dispatch (FIX_BASE c66cf97) incl. minors 4 (pending sheet constant/comment), 5 (capture Scaffold resizeToAvoidBottomInset false), 6 (hint lines), 7 (spec drift), 2 (privacy note in README/spec; ruling: do NOT clear recent labels on logout, consistent with recent patients). Parked: duplicated trim/dedupe loop; Shot.copyWith unused; capture-failure retry shape not device-walked.
Final fix round done (837fd4c, ecd07af; 410 tests). Scoped re-review dispatched; controller verification on ecd07af running.
Final re-review clean. Controller verification on ecd07af: analyze clean, 410 tests; debug build installed on emulator. LABELS PLAN COMPLETE: a78d517..ecd07af. Parked: bare catch around remember hides regressions silently; duplicated trim/dedupe loop; capture-failure retry shape not device-walked; server-side narration check pending server restart (queued set "1 pending" will drain and can be verified via GET /tomogram?opid=581).
