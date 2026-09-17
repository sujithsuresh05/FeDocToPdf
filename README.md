# FeDocToPdf — operator app (Flutter)

Pick a Word document and a recipient sheet, split it into one PDF per
recipient, then work through the list sending each PDF over WhatsApp.

Backend: [BeDocToPdf](https://github.com/sujithsuresh05/BeDocToPdf).

## What the operator does

1. **Point the app at the server.** Enter the API base URL and tap *Test*.
2. **Pick the files** — the `.docx`, and optionally the `.csv`/`.xlsx`
   recipient sheet.
3. **Inspect the document.** The app calls `/api/analyse` and offers the marker
   and key label it found as tappable chips, so nobody has to remember that
   sections start at `Form No.128` and are numbered by `Serial No:`.
4. **Split.** Progress shows `converting` → `splitting` → `ready`.
5. **Deliver.** Each row has *Open chat*, *Share PDF* and a sent checkbox.
   *Next unsent* jumps to where you left off — the point of the app when there
   are 181 notices to get through.

## Why sending is two taps

A WhatsApp `wa.me` link opens the right chat and pre-fills the message, but
**it cannot attach a file** — WhatsApp exposes no URL parameter for an
attachment. So:

- **Open chat** → the conversation with the message ready.
- **Share PDF** → downloads the part and puts it in the OS share sheet, where
  you pick the same chat.

The app reads `delivery.attachesFileAutomatically` from `/api/capabilities`, so
when the backend gains real WhatsApp Cloud API sending (Phase 4 of
`docs/PLAN.md`) this screen can collapse to one tap without a rewrite.

After a share the app cannot know whether you actually pressed send in
WhatsApp, so it asks rather than assuming — the checkbox is yours to tick, and
it is stored on the server so progress survives losing the app.

## Running it

```sh
flutter pub get
flutter run
```

Platform folders are not committed. On a fresh clone, generate them once:

```sh
flutter create . --platforms=android,ios
```

Tests (pure Dart, no device needed):

```sh
flutter test
```

### Pointing the app at the backend

| Running on | Base URL |
|---|---|
| Android emulator | `http://10.0.2.2:4000` (the default) |
| iOS simulator | `http://localhost:4000` |
| A real phone | `http://<your-computer-LAN-IP>:4000` |

Also set `PUBLIC_BASE_URL` on the backend to that same address, or the download
links it returns will point at the phone's own `localhost`.

Android release builds need `INTERNET` permission (debug has it already), and
plain-HTTP access to a LAN address needs a `networkSecurityConfig` or
`usesCleartextTraffic`. Use HTTPS in production.

## Layout

```
lib/
  main.dart app.dart
  config/app_config.dart        defaults, file extensions, mode descriptions
  models/                       job.dart, capabilities.dart -- JSON -> typed
  services/
    api_client.dart             HTTP, multipart upload, part download
    api_exception.dart          server errors vs unreachable server
    delivery_service.dart       wa.me deep link + share sheet
    settings_service.dart       remembers base URL, marker, last job
  state/job_controller.dart     owns one job, polls while it runs
  ui/screens/                   home_screen.dart, job_screen.dart
  ui/widgets/                   part_tile.dart, warning_banner.dart
```

## Design notes

- **Warnings are not decoration.** A count mismatch between document and sheet
  means some notices have no recipient. `WarningBanner` keeps that visible, and
  any part that cannot be sent says why on the row itself.
- **Marking sent is optimistic but honest** — the row ticks over immediately,
  and reverts with a message if the server rejects it.
- **Downloads are cached** by filename and size, so re-sharing a part does not
  re-download it.
- Settings persist, because retyping a LAN address on a phone keyboard every
  launch is how a tool stops getting used.

## Status

Phase 2 of `docs/PLAN.md`. **Written but not yet compiled** — Flutter was not
available in the environment where this was authored. Imports, dependencies and
structure were checked statically; expect to fix small analyzer findings on the
first `flutter pub get && flutter analyze`. See `docs/PROGRESS.md`.

cd FeDocToPdf && flutter pub get && flutter run
cd BeDocToPdf && bash scripts/setup-env.sh
PUBLIC_BASE_URL=http://<your-LAN-IP>:4000 npm start
