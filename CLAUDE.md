# CLAUDE.md — FeDocToPdf (Flutter operator app)

Read this first in a new session. It exists so we do not re-derive context.

## What this project is

The operator-facing half of the Word→PDF splitter: pick a `.docx` + recipient
sheet, split into one PDF per recipient, then send each over WhatsApp.
Backend repo: `sujithsuresh05/BeDocToPdf` (Node/Express).
Working branch in both repos: `claude/wizardly-volta-8c3j0k`.

## Stack

- Flutter, Dart SDK `>=3.4.0 <4.0.0`, Material 3
- `http` (API + multipart), `file_picker`, `url_launcher` (wa.me),
  `share_plus` (attach the PDF), `path_provider`, `shared_preferences`
- State: plain `ChangeNotifier` + `AnimatedBuilder`. No state-management
  package — one screen owns one job, and that is all this needs.

## Status: written, not compiled

Flutter was **not installed** in the authoring environment, so this code has
never been through `flutter analyze` or `flutter test`. Structure, imports and
declared dependencies were verified statically. **First job in a new session:**

```sh
flutter pub get && flutter analyze && flutter test
```

Fix whatever that reports before adding features. Two things to watch:

- `share_plus` ^10 uses `Share.shareXFiles(...)`. Version 11 moved to
  `SharePlus.instance.share(ShareParams(...))` — if pub resolves 11+, update
  `lib/services/delivery_service.dart`.
- `part_tile.dart` uses `Color.withOpacity`, correct for the Flutter 3.22
  floor. On a modern SDK the analyzer will suggest `withValues(alpha:)`.

Platform folders are not committed: `flutter create . --platforms=android,ios`.

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
