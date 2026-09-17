# Progress log

Newest first. Update this at the end of a working session so the next one can
resume without re-reading the code.

---

## 2026-09-17 — Flutter app compiled, analyzed and tested for the first time

**State:** green. `flutter analyze` reports no issues and all 14 model tests
pass on **Flutter 3.47.4 / Dart 3.13.3**. `android/` and `ios/` are committed.
The app has still never been *run* — that needs an Android SDK or Xcode.

### Flutter is not preinstalled in these containers

`flutter` was absent again on a fresh container. Installing the stable tarball
takes about 20 seconds (1.5 GB); exact steps are in `CLAUDE.md`. The one
non-obvious part: `git config --global --add safe.directory /opt/flutter`, or
every `flutter` command dies with "detected dubious ownership".

### What the analyzer found (3 issues, all deprecations, no errors)

The code type-checked on the first run. Fixes applied:

- `DropdownButtonFormField.value` → `initialValue` (2 call sites in
  `home_screen.dart`). **This is a rename, not a behaviour change** — worth
  recording because it looks like one. The constructor already forwarded
  `value` to `FormField.initialValue`, and while the base `FormFieldState`
  ignores `initialValue` changes, `_DropdownButtonFormFieldState` overrides
  `didUpdateWidget` to call `setValue(widget.initialValue)`. So the split-mode
  dropdown still tracks a programmatic change, which it must: choosing a marker
  suggestion sets the mode to `section`.
- `Color.withOpacity` → `withValues(alpha:)` in `part_tile.dart`.

Both APIs postdate the old `>=3.4.0` floor, so `pubspec.yaml` now gates on
`flutter: '>=3.33.0'` — an older SDK fails resolution instead of failing to
compile.

### The share_plus risk did not materialise, and is now pinned

`share_plus` resolved to **10.1.4**, where `Share.shareXFiles` still exists, so
`delivery_service.dart` needed no change. Version 11 *would* break it.

That made a real problem visible: `.gitignore` was the **Flutter SDK
repository's**, which ignores `*.lock` — sensible for a package, wrong for an
app — so `pubspec.lock` was never committed and a later resolve could have
picked share_plus 11 silently. The lockfile is committed now, behind a
`!pubspec.lock` negation placed **after** the `*.lock` rule; putting it before
had no effect, since gitignore resolves by last match.

### `flutter create .` needs watching

Generating the platform folders had two side effects, both reverted:

- it added a `test/widget_test.dart` driving the counter sample app and
  referencing a `MyApp` that does not exist here — it would fail analyze and
  test, so it was deleted;
- it rewrote `pubspec.lock`, downgrading six transitive packages away from the
  verified resolution.

Its `.idea/` and `*.iml` output is now ignored.

### Next session starts here

The app compiles; the remaining step is to *run* it. See `docs/PLAN.md`
→ "Resume here" for the ordered steps. Nothing is outstanding in this repo
that can be done without a device.

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
- `test/models_test.dart` — 14 model tests (unrun at the time)
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
