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

## ▶ Resume here — last worked 2026-09-17

**Where things stand:** both repos are green. The backend is finished for
Phase 1 and verified against the real 362-page notice run (55 tests, `npm
audit` clean). The Flutter app is now **compiled, analyzed and tested** for the
first time — Flutter 3.47.4 / Dart 3.13.3, `flutter analyze` reports no issues
and all 14 model tests pass — and `android/` and `ios/` are committed so it can
be built from a clean clone.

**What is still unverified:** the app has never been *run*. A device or
emulator build needs the Android SDK or Xcode, and neither is present in these
containers. Everything up to and including compilation is confirmed.

**Next, in order:**

1. **Run it, on a machine with the Android SDK or Xcode.**
   ```sh
   cd FeDocToPdf && flutter run
   ```
2. **Start the backend and make it reachable from the device.**
   ```sh
   cd BeDocToPdf && bash scripts/setup-env.sh
   PUBLIC_BASE_URL=http://<your-LAN-IP>:4000 npm start
   ```
   Put that same address in the app's API base URL field. `localhost` on a
   phone means the phone.
3. **Feed it the real document** and walk the delivery list end to end: marker
   `Form No.128`, key label `Serial No:`, filename pattern
   `ProfTax_Traders_Notice-{{index}}`. Confirm *Open chat* and *Share PDF*
   behave on a real WhatsApp install — that two-tap hand-off is the one part no
   test covers.
4. Then Phase 3 below.

**Environment, before anything:** neither Flutter nor (in some containers)
LibreOffice Writer is preinstalled. Each repo's `CLAUDE.md` has the exact
install steps; in `BeDocToPdf`, `scripts/setup-env.sh` handles it.

**Branching:** feature branches are cut from `Development` and promoted
`Development` → `QA` → `Release` → `main`; `hotfix/*` is the only branch cut
from `main`. See `docs/BRANCHING.md`.

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
- [x] 55 tests; `npm audit` clean
- [x] Verified end-to-end on the real 362-page document

## Phase 2 — Flutter operator app ✅ built and verified

- [x] API client + typed models, base URL configurable in-app
- [x] Pick `.docx` + sheet; call `/api/analyse`; prefill marker/keyLabel from
      the suggestions instead of making the operator guess
- [x] Job form: split mode, chunk size, filename pattern, message template
- [x] Poll job status with clear progress (`converting` → `splitting` → `ready`)
- [x] Results list: recipient, phone, pages, size, warning badges
- [x] Per row: **Open WhatsApp** (`wa.me`) + **Share PDF** (share sheet), then
      **Mark sent**; persist sent state to the API
- [x] "Next unsent" flow so 181 notices can be worked through without hunting
- [x] Surface `job.warnings` prominently — unmatched parts must not look normal
- [x] Compiles clean: `flutter analyze` — no issues; 14/14 tests pass (3.47.4)
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

---

## Session log

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
