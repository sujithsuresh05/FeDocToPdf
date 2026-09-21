# CLAUDE.md — FeDocToPdf (Flutter operator app)

Read this first in a new session. It exists so we do not re-derive context.

## What this project is

The operator-facing half of the Word→PDF splitter: pick a `.docx` + recipient
sheet, split into one PDF per recipient, then send each over WhatsApp.
Backend repo: `sujithsuresh05/BeDocToPdf` (Node/Express).
Branching: feature branches are cut from `Development` and promoted
`Development` → `QA` → `Release` → `main`. See `docs/BRANCHING.md`.

## Stack

- Flutter, Dart SDK `>=3.4.0 <4.0.0`, Material 3
- `http` (API + multipart), `file_picker`, `url_launcher` (wa.me),
  `share_plus` (attach the PDF), `path_provider`, `shared_preferences`
- State: plain `ChangeNotifier` + `AnimatedBuilder`. No state-management
  package — one screen owns one job, and that is all this needs.

## Status: compiled, analyzed and tested

Verified on **Flutter 3.47.4 / Dart 3.13.3** (2026-09-17):

```sh
flutter pub get && flutter analyze && flutter test
# analyze: No issues found!   test: 25/25 pass
```

Still unverified: an actual device build and a run against the backend. That
needs the Android SDK or Xcode, neither of which is in these containers.

### Installing Flutter (it is not preinstalled here)

A fresh container has no `flutter` on PATH. The SDK downloads in about 20
seconds:

```sh
curl -s https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json \
  | grep -o '"archive": *"stable/linux/flutter_linux_[^"]*"' | head -1   # pick the current stable
curl -o /tmp/flutter.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/<archive path>
tar -xJf /tmp/flutter.tar.xz -C /opt
git config --global --add safe.directory /opt/flutter   # else "dubious ownership"
export PATH="/opt/flutter/bin:$PATH"
flutter --disable-analytics
```

### Version constraints are deliberate

`pubspec.yaml` gates on `flutter: '>=3.33.0'` because
`DropdownButtonFormField.initialValue` needs 3.33 and `Color.withValues` needs
3.27. An older SDK now fails resolution loudly instead of failing to compile.

**`pubspec.lock` is committed, and must stay committed.** The repository's
`.gitignore` came from the Flutter SDK repo and ignored `*.lock`, which suits a
package and not an app; there is now a `!pubspec.lock` negation *after* that
rule (gitignore resolves by last match). It matters: the lock pins `share_plus`
**10.1.4**, and share_plus 11 replaces the `Share.shareXFiles` call in
`lib/services/delivery_service.dart`.

Platform folders (`android/`, `ios/`) are committed. **Never run
`flutter create .` here** — it reinstates a counter-app `test/widget_test.dart`
referring to a `MyApp` this project does not have, so `flutter test` stops
compiling, and it rewrites `pubspec.lock` with downgraded transitive packages.

This bit the operator on 2026-09-21, and not by accident: **`README.md` used to
instruct it** ("Platform folders are not committed. On a fresh clone, generate
them once"), which was false, and `flutter run` suggests the same command
whenever it cannot find a device. Both are now corrected, and README has a
Troubleshooting section for the two errors it produces. Recovery is
`rm test/widget_test.dart`.

## Architecture

```
models/      JSON -> typed, every field null-tolerant (fromJson never throws
             on a missing key; the backend adds fields as phases land)
services/    api_client.dart is the only place that knows about HTTP
state/       JobController: owns one job, polls every 2s while it runs,
             tracks per-part busy state so one row's spinner does not block
ui/          home_screen.dart = setup form; job_screen.dart = delivery list
```

## Decisions already made (do not re-litigate without reason)

- **Delivery is two taps and that is not a bug.** A `wa.me` link cannot attach
  a file. *Open chat* pre-fills the message; *Share PDF* pushes the file through
  the share sheet. The app reads `delivery.attachesFileAutomatically` from
  `/api/capabilities` so it can collapse to one tap when Phase 4 lands.
- **The app never claims a message was sent.** It cannot observe WhatsApp, so
  after a share it *asks*. Sent state lives on the server.
- **Marker/key label are suggested, not typed from memory** — `/api/analyse`
  returns candidates and the UI offers them as chips.
- **`matchBy` defaults to `order`.** Serial numbers repeat across wards, so key
  matching is not safe by default; the server degrades it with a warning.
- **Warnings are surfaced prominently.** A run where 176 of 181 notices have no
  recipient must not look like a normal run.

## Backend contract

`GET /api/capabilities` · `POST /api/analyse` · `POST /api/jobs` ·
`GET /api/jobs/:id` · `GET /api/jobs/:id/parts/:index/download` ·
`POST /api/jobs/:id/parts/:index/sent`

Job creation returns `202` and runs in the background — poll until `status` is
`ready` or `failed`. Full reference in the backend's `README.md`.

## Gotcha that wastes an afternoon

`localhost` on a phone means the phone. Set the base URL to the computer's LAN
IP **and** set `PUBLIC_BASE_URL` on the backend to the same, or download links
will point at the device.

## Conventions

- Comments explain *why*, not *what*.
- `fromJson` is defensive: unknown enum values map to `unknown`, missing lists
  become empty. Never let a backend addition crash the app.
- User-facing errors say what to do next, not just what failed.
