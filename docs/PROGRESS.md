# Progress log

Newest first. Update this at the end of a working session so the next one can
resume without re-reading the code.

---

## 2026-09-21 — First real device build; two things in the way, both now fixed

The operator got as far as `flutter run` on a Mac. Two failures, neither caused
by app code, and the first one was a documentation bug of mine.

### The README told them to run the one forbidden command

`README.md` said "Platform folders are not committed. On a fresh clone, generate
them once: `flutter create . --platforms=android,ios`". Both folders *are*
committed, and that command writes a counter-app `test/widget_test.dart`
referring to a `MyApp` this project does not have, so `flutter test` stops
compiling, and rewrites `pubspec.lock` with downgraded transitive packages.
`CLAUDE.md` warned against it on one page while README instructed it on another.

`flutter run` suggests the same command whenever it cannot find a device, so the
warning now lives where someone reading about running the app will see it, with
a Troubleshooting section for both errors it produces. Recovery is
`rm test/widget_test.dart` — the file is untracked and has never been in the
repo.

### The Android build failed on compileSdk, and the app's setting was irrelevant

```
Dependency ':flutter_plugin_android_lifecycle' requires ... version 36 or later
:file_picker is currently compiled against android-34
```

The obvious reading — raise `compileSdk` in `android/app/build.gradle.kts` — is
wrong. The app already uses `compileSdk = flutter.compileSdkVersion`. Read from
the pub cache instead of guessing:

| package | declares |
|---|---|
| `file_picker 8.3.7` | `compileSdk 34`, **hardcoded** |
| `flutter_plugin_android_lifecycle 2.0.35` | `flutter.compileSdkVersion` → 36 |

Both are built from source in the app's own Gradle build, so the mismatch was
inside file_picker itself. **`file_picker 11.0.3` follows
`flutter.compileSdkVersion`**, so both modules track the same level. Toolchain
was never the problem: AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0 already support 36.

One source change came with it: `FilePicker` is now an `abstract final class`
with static methods, so `FilePicker.platform.pickFiles(...)` became
`FilePicker.pickFiles(...)`. I had predicted the API was unchanged; `flutter
analyze` proved otherwise, which is why it was run rather than assumed.

### file_picker is now capped at 11 by the share_plus pin

Trying 13 first made the coupling visible: `file_picker 13` → `windows_file_picker`
→ `share_plus ^13`, which version-solving rejects against the deliberate
`share_plus ^10.1.0` pin. 12.x also restructures into federated plugins and
needs Flutter ≥ 3.38.

So moving file_picker past 11 means taking share_plus 13 and migrating
`Share.shareXFiles` to `SharePlus.instance.share(ShareParams(...))`. Worth doing
eventually — not while the share sheet, the one interaction never exercised on a
device, is still unverified. Recorded in `CLAUDE.md`.

### Verified, and not

Installed Flutter 3.47.5 in the container to resolve this for real rather than
by inspection:

- `flutter analyze` — no issues.
- `flutter test` — 25 pass.
- `pubspec.lock` diff is file_picker 8.3.7 → 11.0.3 plus three transitive
  desktop packages (`dbus`, `petitparser`, `xml`). **`share_plus` untouched at
  10.1.4.**

**The Android build itself is still unverified here** — no Android SDK in the
container, so `assembleDebug` could not be run. The operator's next
`flutter run` is the verification.

---

## 2026-09-19 — Nothing changed in the app; the blocker is a font on the server

**State:** `flutter analyze` clean, 25 tests, all merged into `Development`,
nothing in flight. No app code was touched today.

The day went entirely into a backend problem that is worth knowing about here,
because it decides what the operator sees.

The notices are **legacy 8-bit Malayalam**: the `.docx` stores plain Latin
characters with an `ML-TT` font applied, and they only become Malayalam inside
that font's glyph table. Two things follow for this app:

1. **Do not expect Malayalam out of any text the backend reports.** Markers,
   key labels and detected text come back as Latin gibberish
   (`Xncph´]pcw \Kck`) for the Malayalam page. That is the encoding, not a bug,
   and it is why detection targets `Form No.128` on the English page.
2. **A new failure mode reaches the UI.** When the server lacks a font the
   document applies, the job fails with code `missing_fonts` and produces
   **zero** parts, on purpose — LibreOffice would otherwise substitute the font
   silently and every Malayalam page would convert to nonsense while the job
   reported success. The message is written for the operator and says which
   font to install, so the existing failure banner shows it as-is; nothing in
   the app needed changing. `POST /api/analyse` now also returns a `fonts`
   block, which `fromJson` tolerates because it ignores unknown keys.

**Still the only unverified thing:** an actual device run. The backend
additionally needs the `ML-TTRevathi` font file before a real run will produce
readable Malayalam — see `docs/PLAN.md`, which is kept identical in both repos.

---

## 2026-09-17 (afternoon) — contract tests, device wiring, UI rebuilt

**State:** green. `flutter analyze` clean, 24 tests pass. The app has still
never been run on a device.

### The models are now tested against real backend responses

Model tests used hand-written JSON, which proves the parsing logic but not that
it matches the API — a renamed server field would have surfaced at the
operator's first tap. `test/fixtures/api/` holds responses captured from a
running backend, parsed through the real model classes. **Result: no drift.**

### Four things that would have broken the first device run

Each would have failed at runtime, not at build:

- `INTERNET` was missing from the **main** manifest (only debug/profile had
  it), so a release build could make no network call at all;
- Android 9+ blocks plaintext HTTP, so `http://<LAN-IP>:4000` failed before any
  request left the device — cleartext is now allowed in the **debug manifest
  only**;
- no `<queries>` entry for `https`, which per url_launcher's own README makes
  `canLaunchUrl` return false on Android 11+ — "Open chat" would have reported
  WhatsApp as missing on every modern phone. `openChat` also no longer treats
  that check as a veto;
- iOS ATS blocks the same thing; `NSAllowsLocalNetworking` relaxes it for local
  addresses only.

### The UI was rebuilt

Stock Material 3 with 181 identical cards gave no answer to "where was I", and
showed the same two buttons on notices that could not be sent. It is now a
worklist: one notice in focus, the rest a compact index, the hand-off drawn as
three ordered steps, counts doubling as the filter, warnings stated rather than
hidden. Setup leads with the common path and states what the server detected as
a sentence to confirm.

Light and dark both ship, following the phone with a persisted toggle. The dark
palette was designed fresh after the first one was rejected: the ground is
lifted off near-black so surfaces and rules stay legible against each other,
and the app bar is a surface rather than a full bar of accent. Widgets read
colour from the `ColorScheme`, so nothing knows which theme is active.

### How it was verified without a device

Built for web and drove the real widget tree in a headless browser at 390x844
under both `prefers-color-scheme` settings. This is worth repeating: it caught
a bug the analyzer cannot see — the trailing "↗" is absent from the bundled
font and rendered as a missing-glyph box. The web platform files and the
preview harness are not committed.

### Process note

PR #6 was based on another feature branch rather than `Development`, and when
its base merged first, #6 merged into that base instead of `Development`. The
work had to be cherry-picked onto a fresh branch off `Development` and
re-opened. **Base feature branches on `Development`.**

### Next session starts here

Nothing in this repo can progress without a device. See `docs/PLAN.md` →
"Resume here".

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
