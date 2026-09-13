# Progress log

Newest first. Update this at the end of a working session so the next one can
resume without re-reading the code.

---

## 2026-09-13 — Phase 2 written (frontend), needs a compile pass

**State:** the full operator flow is implemented. Backend Phase 1 is done and
verified. Nothing has been compiled — Flutter was not installed in the
authoring environment.

### Done

- Models (`job.dart`, `capabilities.dart`) with null-tolerant `fromJson`
- `ApiClient` — capabilities, analyse, create job, poll, download part,
  mark sent; distinguishes a server error from an unreachable server
- `JobController` — polls every 2s while a job runs, per-part busy state,
  optimistic sent toggle that reverts if the server rejects it
- `HomeScreen` — base URL + test, file pickers, **inspect document** that
  pre-fills marker/key label from `/api/analyse` suggestions as tappable chips,
  split options, filename pattern, message template
- `JobScreen` — progress, warning banner, delivery list, *Next unsent*,
  pending-only filter, resume last job
- `DeliveryService` — `wa.me` deep link + share sheet, with the two-tap
  limitation documented where it is implemented
- `test/models_test.dart` — 16 model tests (unrun)
- Static checks passed: balanced delimiters in all 14 Dart files, every
  relative import resolves, every imported package declared in `pubspec.yaml`

### Next session starts here

1. **`flutter pub get && flutter analyze && flutter test`** and fix findings.
   Most likely: the `share_plus` major version (see `CLAUDE.md`) and
   `withOpacity` deprecation on a newer SDK.
2. `flutter create . --platforms=android,ios` to generate platform folders.
3. Run against the backend end to end with the real 362-page document; set
   `PUBLIC_BASE_URL` on the backend to the host's LAN IP first.
4. Then Phase 3 in `docs/PLAN.md` (bulk ZIP export, in-app phone correction).

### Open decisions

1. **Backend language.** An earlier chat recommended Python; Phase 1 is built
   and verified in Node. Decision: **stay on Node for now, revisit after the
   end-to-end POC is clickable.** Nothing in this app depends on the choice —
   it talks HTTP.
2. Whether the operator should be able to fix a wrong phone number in-app
   (Phase 3) or correct the sheet and re-run.
3. `DEFAULT_COUNTRY` on the backend is `IN`; confirm if other regions are used.

### Notes

- The sample `ProfTax_Traders_Notice-1..3.pdf` files are format references, not
  expected bytes: they read `2025-2026 IInd Half` while the provided `.docx` is
  `2026-27 Ist Half`. Details in the backend's `docs/PROGRESS.md`.
- Real uploaded data (traders' names and phone numbers) is deliberately **not**
  committed to either repo. Test fixtures are synthetic.
