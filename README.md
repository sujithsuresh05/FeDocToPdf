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

**`android/` and `ios/` are committed, so there is nothing to generate.**

> ### ⚠️ Never run `flutter create .` in this repo
>
> An earlier version of this file told you to, and it was wrong. That command
> does two damaging things to an existing project:
>
> 1. It writes a counter-app `test/widget_test.dart` referring to a `MyApp`
>    this project does not have, so `flutter test` then fails to compile.
> 2. It rewrites `pubspec.lock`, downgrading transitive packages. The lock pins
>    `share_plus` **10.1.4** on purpose — version 11 removes the
>    `Share.shareXFiles` call in `lib/services/delivery_service.dart`.
>
> `flutter run` itself suggests this command when it cannot find a device. It is
> suggesting the wrong fix; see *Troubleshooting* below.

Tests (pure Dart, no device or emulator needed):

```sh
flutter test        # 25 tests
flutter analyze     # no issues
```

### Pointing the app at the backend

| Running on | Base URL |
|---|---|
| Android emulator | `http://10.0.2.2:4000` (the default) |
| iOS simulator | `http://localhost:4000` |
| A real phone | `http://<your-computer-LAN-IP>:4000` |

Also set `PUBLIC_BASE_URL` on the backend to that same address, or the download
links it returns will point at the phone's own `localhost`.

`INTERNET` is declared in the **main** manifest, so release builds have it too,
and the `<queries>` entry `canLaunchUrl` needs on Android 11+ is there.
`usesCleartextTraffic` is set in the **debug** manifest only, so a debug build
can reach a plain-HTTP LAN backend while release builds are not opened up. Use
HTTPS in production.

## Troubleshooting

### `Error: Couldn't find constructor 'MyApp'` in `test/widget_test.dart`

That file is not part of this project and never has been — `flutter create .`
wrote it. Delete it:

```sh
rm test/widget_test.dart
flutter test
```

### `No supported devices connected` — macOS and Chrome listed as unsupported

Expected. Only `android/` and `ios/` are committed, so a desktop or web target
is not configured. **Do not take `flutter run`'s advice to run
`flutter create .`** — see the warning above. Get a supported device instead:

```sh
# iOS simulator (needs Xcode)
open -a Simulator
flutter run

# Android emulator
flutter emulators                      # list
flutter emulators --launch <id>
flutter run

# A real phone: enable USB debugging (Android) or trust the Mac (iOS), plug in
flutter devices
```

**A real phone is what actually matters here.** The core interaction is
WhatsApp's share sheet, and WhatsApp is not installed on a simulator or
emulator — so a simulator verifies the form, the polling and the delivery list,
but not the hand-off itself.

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

Phase 2 of `docs/PLAN.md`. **Compiles, analyzes clean and passes its tests** —
verified on Flutter 3.47.4 / Dart 3.13.3: `flutter analyze` reports no issues
and `flutter test` passes 25.

**Still unverified: a run on a real device.** That needs the Android SDK or
Xcode, and it is the one thing that matters most, because the core interaction
is WhatsApp's share sheet and WhatsApp exists on neither a simulator nor an
emulator. See `docs/PROGRESS.md`.

The backend it talks to is verified end to end: a 362-page ward document yields
181 correctly-rendered Malayalam notices.
