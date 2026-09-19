# Plan — Word→PDF splitter with WhatsApp delivery

One project, two repos:

| Repo | Role | Branch |
|---|---|---|
| `sujithsuresh05/BeDocToPdf` | API: convert, split, pair, link | `claude/wizardly-volta-8c3j0k` |
| `sujithsuresh05/FeDocToPdf` | Flutter operator app | `claude/wizardly-volta-8c3j0k` |

**Live tracker:** [https://claude.ai/code/artifact/d8ef3bf1-4383-40f1-b94a-b105fdbae2c8](https://claude.ai/code/artifact/d8ef3bf1-4383-40f1-b94a-b105fdbae2c8) — the same phases with tickable tasks and a
saved "where we stopped" note. Ticking there is shared with anyone holding the
link; this file stays the version-controlled copy.

---

## ▶ Resume here — last worked 2026-09-19 (end of day)

**Everything is merged into `Development` in both repos, both green, nothing
in flight.** No open pull requests.

| | |
|---|---|
| `BeDocToPdf` `Development` | 85 tests, 0 skipped, `npm audit` clean |
| `FeDocToPdf` `Development` | `flutter analyze` clean, 25 tests |
| CI | live in both repos, on every PR into `Development` / `QA` / `Release` / `main` |
| API docs | Swagger UI at `/docs`, OpenAPI 3.1 at `/openapi.json` |

**Two things are outstanding, and both need something the containers cannot
provide.**

**1. The server needs the `ML-TTRevathi` font file — this blocks a correct run
on the real document.** The notices are legacy 8-bit Malayalam: the `.docx`
stores Latin characters that only become Malayalam inside a specific font. When
that font is absent LibreOffice substitutes it *silently* — exit 0, no warning —
and every Malayalam page converts to gibberish while the job reports success.
The job now refuses instead (`missing_fonts`, 0 parts). Checked against the real
362-page run, the document applies **Times New Roman, Tahoma and ML-TTRevathi**;
the first two substitute safely and **ML-TTRevathi is the only blocker**.
`ML-TTKarthika`, the file already in `fonts/`, is not used by this document at
all. Drop `ML-TTRevathi` (ISFOC filename probably `MLRV0NTT.TTF` — inferred,
not verified) into `fonts/` and run `bash scripts/install-fonts.sh`.

**2. The Flutter app has never been *run*.** A device build needs the Android
SDK or Xcode, neither of which exists in these containers. Everything up to and
including compilation and layout is verified — what cannot be verified here is
how WhatsApp's share sheet behaves, and that is the core interaction.

**Next, in order:**

1. **Drop the font in and confirm.** From `BeDocToPdf`:
   ```sh
   bash scripts/install-fonts.sh
   node scripts/check-fonts.mjs <the real notice>.docx    # exits 1 while a font is missing
   ```
2. **Run the app.** On a machine with the Android SDK or Xcode:
   ```sh
   cd FeDocToPdf && flutter pub get && flutter run
   ```
3. **Start the backend so the phone can reach it.**
   ```sh
   cd BeDocToPdf && bash scripts/setup-env.sh
   PUBLIC_BASE_URL=http://<your-LAN-IP>:4000 npm start
   ```
   Put that same address in the app's Backend field. `localhost` on a phone
   means the phone. Browse `http://<LAN-IP>:4000/docs` to poke the API directly.
4. **Walk one notice end to end** with the real document. The app inspects it
   and offers `Form No.128` / `Serial No:` itself, so confirm the sentence, then
   on the focused card: *Open WhatsApp chat* → *Attach the PDF* → *Mark sent*.
   Open the produced PDF and **look at page 2** — that is the only way to know
   the Malayalam rendered rather than substituted.
5. **Come back with what broke or annoyed you.** Phase 3 is all UX and is
   better shaped by one real run than by guessing — the rejected dark-theme
   round demonstrated the cost of guessing.

**Worth deciding separately:** converting the notices to Unicode Malayalam
upstream in Word removes the font dependency permanently instead of working
around it. Unicode Malayalam and Devanagari (Noto) are already installed by
`scripts/setup-env.sh` and verified; they do not help the legacy files, because
a legacy font's code points mean something else entirely.

**Environment, before anything:** neither Flutter nor (in some containers)
LibreOffice Writer is preinstalled. Each repo's `CLAUDE.md` has the exact
install steps; in `BeDocToPdf`, `scripts/setup-env.sh` handles it.

**Fonts are committed on purpose.** `BeDocToPdf` is a **private** repository, so
a licensed font in `fonts/` is internal use rather than redistribution, and
committing it makes a deployment reproducible. Nothing under `fonts/` is ignored.
If the repository is ever made public, strip the proprietary ML-TT fonts from
`fonts/` **and from history** first — a git history is published in full.

**Branching:** feature branches are cut from `Development` and promoted
`Development` → `QA` → `Release` → `main`; `hotfix/*` is the only branch cut
from `main`. See `docs/BRANCHING.md`. **Never base a PR on another feature
branch** — a stacked PR merged into its own base instead of `Development` and
the work had to be re-landed.

**Housekeeping that needs doing by hand** (the git proxy refuses ref deletion
from the agent session): every `feature/*` branch in both repos is merged and
safe to delete, along with `claude/wizardly-volta-8c3j0k`, and in `BeDocToPdf`
the five branches created in error on 13 September — `development` (a lower-case
duplicate of `Development`), `qa`, `release`,
`feature/backend-splitter-pipeline` and `feature/project-context-docs`.

## The problem, in the user's own data

A ward Profession Tax run is a single **362-page `.docx`** containing **181
two-page demand notices** (page 1 the English Form No.128, page 2 the Malayalam
reverse). The recipient list is a spreadsheet whose header sits on **row 4**
under three merged title banners, and whose contact column
(`E-mail & phone Number`) mixes labels, several phone numbers and e-mail
addresses in one cell.

Manually splitting that and sending 181 WhatsApp messages is the job we are
removing.

## Scope decisions (settled with the user)

- **All four split modes** ship, not just the one we need today: `section`
  (default), `page`, `chunk`, `whole`. The requirement is still being refined.
- **Delivery is click-to-chat for now.** `wa.me` opens the right chat with the
  message pre-filled; the operator attaches the PDF via the share sheet. A deep
  link **cannot** attach a file — automatic attachment is Phase 4.
- **Recipients come from a separate CSV/Excel upload.**
- **Conversion is LibreOffice headless** — highest fidelity, self-hosted, free.

---

## Phase 1 — Backend core ✅ done

- [x] Express API, ESM, config via `.env`
- [x] LibreOffice conversion, per-job profile dir (concurrency-safe), timeout,
      magic-byte validation
- [x] Four split modes, pure and unit-tested
- [x] Marker-based sectioning, matched **literally**; separate `keyLabel`
- [x] Recipient parsing: header-row detection, column aliases, phone extraction
      from free text, E.164 normalisation
- [x] Pairing parts↔rows by order or key, with safe degradation
- [x] `wa.me` link + message templating per part
- [x] `POST /api/analyse` — suggests marker and key label from the document
- [x] Background jobs + polling, retention purge, restart recovery
- [x] OpenAPI 3.1 generated from `config.js`, served as Swagger UI at `/docs`;
      tests fail on a route missing from the spec *and* on a spec route that
      does not exist
- [x] Missing-font guard: a document applying a font the server lacks is
      refused up front (`missing_fonts`, 0 parts) rather than converted with a
      silent substitution; `POST /api/analyse` and `scripts/check-fonts.mjs`
      report it without committing to a job
- [x] 85 tests; `npm audit` clean
- [x] Verified end-to-end on the real 362-page document

## Phase 2 — Flutter operator app ✅ built, tested and rendered

- [x] API client + typed models, base URL configurable in-app
- [x] Inspect the document and prefill the marker/key label from what the
      server detected, stated as a sentence to confirm
- [x] Job form, with split mode / matching / filenames behind Advanced
- [x] Poll job status with clear progress
- [x] Delivery worklist: one notice in focus, the rest a compact index
- [x] The hand-off drawn as three ordered steps, since a wa.me link cannot
      carry an attachment
- [x] Counts double as the filter (To send / Sent / Blocked); tap a row to
      focus it
- [x] Warnings stated at full size, not hidden behind a disclosure triangle
- [x] Light and dark themes, following the phone, with a persisted toggle
- [x] Compiles clean: `flutter analyze` — no issues; 24/24 tests pass (3.47.4)
- [x] Models tested against **real captured backend responses** — no drift
- [x] Platform wiring for a real device: INTERNET permission, cleartext to a
      LAN backend in debug only, the `<queries>` entry `canLaunchUrl` needs on
      Android 11+, and iOS ATS local networking
- [x] `android/` and `ios/` committed; `pubspec.lock` committed and pinned
- [ ] **Run on a device or emulator against the backend** (needs Android SDK /
      Xcode — not available in the container this was built in)

## Phase 3 — Operator hardening

- [ ] Resume a job after app restart (job id list, deep link back into a job)
- [ ] Bulk export: ZIP of all parts, CSV of the delivery manifest
- [ ] Edit a recipient's number in-app when the sheet is wrong, and re-link
- [ ] Retry a single failed part without re-running the whole job
- [ ] Dry-run preview: first page thumbnail per part before committing

## Phase 4 — Real WhatsApp sending

- [ ] Provider interface behind the current link builder
- [ ] Meta WhatsApp Cloud API adapter: media upload → template message with the
      PDF attached
- [ ] Template approval workflow + per-recipient send status/receipts
- [ ] Rate limiting, retry with backoff, delivery-failure reporting
- [ ] Keep click-to-chat as the fallback when no template is approved

## Phase 5 — Production readiness

- [ ] Authentication and per-user job isolation (**the API is currently open**)
- [ ] Shared job store (Postgres/Redis) so it can run more than one instance
- [ ] Object storage for parts instead of local disk; signed download URLs
- [ ] Structured audit log: who sent what to which number, when
- [ ] Container image with LibreOffice baked in; CI running `npm test`
- [ ] Data retention policy — these are citizens' tax notices

## Known risks

| Risk | Mitigation |
|---|---|
| A `wa.me` link cannot attach the PDF | Share-sheet pairing now; Cloud API in Phase 4 |
| Serial numbers repeat across wards | Pair by order; `key` mode degrades with a warning |
| Sheet row count ≠ notice count (5 vs 181 in the sample) | Always reported as a warning; extra parts get no link |
| Unofficial WhatsApp automation would risk a ban | Rejected; official API only |
| Real data contains personal phone numbers | Never committed; synthetic fixtures only |
| The notices use a legacy 8-bit Malayalam font, and LibreOffice substitutes a missing font silently | The job is refused before conversion; the font is installed from `fonts/` |

---

## Session log

Only the first session is written out here. Every session since is in
`docs/PROGRESS.md`, newest first — that is the log to read, and the one to
append to at the end of a working session.

### 2026-09-13 — Phase 1 built and verified; Phase 2 written

**Shipped**

- Complete Node/Express backend: LibreOffice conversion, four split modes,
  marker sectioning, recipient parsing, part↔row pairing, `wa.me` links,
  background jobs with polling, document analysis endpoint. 55 tests.
- Complete Flutter operator app: API client, setup form with marker
  suggestions, job polling, delivery list with *Open chat* / *Share PDF* /
  *Mark sent*, *Next unsent* jump, warning surfacing. 16 model tests (unrun).

**Verified on the real uploaded sample**

| | |
|---|---|
| Source | one 362-page `.docx` |
| Output | **181 PDFs, exactly 2 pages each** |
| Filenames | `ProfTax_Traders_Notice-1..181.pdf` |
| Sheet header | auto-found on **row 4** |
| Keys | from `Sl No.`, values 1–181 |
| Phones | pulled out of the combined `E-mail & phone Number` column |
| Mismatch | 5 sheet rows vs 181 parts — reported as a warning, extra parts get no link |

**What the real data changed in the design**

- **The spreadsheet header is not row 1.** Three merged title banners
  (`CORPORATION OF THIRUVANANTHAPURAM`, the assessment-list title,
  `NEDUMCAUD WARD(54)`) sit above it, so the parser scores candidate rows and
  finds the header instead of assuming its position.
- **One column holds phone *and* e-mail, often several numbers.**
  `Mob: 8086006942, 8086006941, email: oprh694@axisbank.com` →
  `+918086006942`, with `+918086006941` kept as an alternative. Digits inside
  e-mail local parts (`oprh694@…`) are ignored.
- **The marker and the key are different text.** A notice begins with
  `Form No.128` but identifies itself further down with `Serial No: 12`, so
  marker and key label are separate fields rather than one pattern.
- **Serial numbers are not unique.** The sample runs 1–177 and then restarts
  1–4, so pairing defaults to document order and `matchBy=key` degrades to
  order with a warning rather than mis-delivering a notice.

**About the three sample PDFs that were provided**

`ProfTax_Traders_Notice-1..3.pdf` are **format references, not expected bytes.**
They came from a different run: they read `2025-2026 IInd Half` while the
provided `.docx` is `2026-27 Ist Half`, they omit the phone line, and they carry
overlapping duplicated text layers. Our parts are structurally correct (right
notice, right serial, right name, two pages) and far smaller — 70 KB vs 637 KB,
because only the resources each page actually needs are copied.

**Environment fixes that cost time — already codified**

- The container shipped `libreoffice-core` **without Writer**, so every
  conversion failed with `Error: source file could not be loaded`. Installing
  `libreoffice-writer` fixed it; `scripts/setup-env.sh` now does this and
  verifies. Run it once per fresh container.
- Replaced `xlsx`/SheetJS — abandoned on npm at a high-severity advisory with
  no fix — with `exceljs`. Upgraded `multer` 1.x→2.x. Pinned `qs` and `uuid`
  via `overrides`. `npm audit` must stay at 0.

**Reproducing the backend verification**

```sh
bash scripts/setup-env.sh
PORT=4010 STORAGE_DIR=/tmp/e2e-storage npm start &

# suggests the marker and key label from the document itself
curl -s -X POST localhost:4010/api/analyse -F "document=@ProfTax.docx"

curl -s -X POST localhost:4010/api/jobs \
  -F "document=@ProfTax.docx" -F "recipients=@prof_tax_test.xlsx" \
  -F "splitMode=section" -F "marker=Form No.128" -F "keyLabel=Serial No:" \
  -F "filenamePattern=ProfTax_Traders_Notice-{{index}}"
# then poll GET /api/jobs/<id> until status=ready
```

**Open decisions**

1. **Backend language — decided for now: stay on Node.** An earlier planning
   chat recommended Python. Phase 1 is built and verified in Node; the call was
   to keep Node and revisit once the end-to-end POC is clickable. The Flutter
   app talks HTTP and is unaffected. If revived, the mapping is close:
   `pdf-lib`→`pypdf`/PyMuPDF, `pdfjs-dist`→PyMuPDF text extraction,
   `exceljs`→`openpyxl`, `libphonenumber-js`→`phonenumbers`, Express→FastAPI,
   LibreOffice unchanged. Cost is ~1,400 lines plus 55 tests rewritten for no
   new capability. **Do not start a rewrite without an explicit decision.**
2. `DEFAULT_COUNTRY` on the backend is `IN`. Confirm if other regions are needed.
3. Should the operator be able to correct a wrong phone number in-app (Phase 3),
   or fix the sheet and re-run?

**Housekeeping**

- Real uploaded sample data is **deliberately not committed** to either repo —
  it contains actual traders' names and phone numbers. Test fixtures are
  synthetic (`tests/fixtures/payslips.docx`, regenerable via
  `scripts/make-fixture.mjs`).
- The earlier planning chat was **not readable** from the session that built
  this: the container starts from a fresh clone with no prior transcript. That
  is why this file, `CLAUDE.md` and `docs/PROGRESS.md` exist — so context is
  carried in the repo rather than in a conversation.
