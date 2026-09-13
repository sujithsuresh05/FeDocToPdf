# Plan — Word→PDF splitter with WhatsApp delivery

One project, two repos:

| Repo | Role | Branch |
|---|---|---|
| `sujithsuresh05/BeDocToPdf` | API: convert, split, pair, link | `claude/wizardly-volta-8c3j0k` |
| `sujithsuresh05/FeDocToPdf` | Flutter operator app | `claude/wizardly-volta-8c3j0k` |

**Live tracker:** [https://claude.ai/code/artifact/d8ef3bf1-4383-40f1-b94a-b105fdbae2c8](https://claude.ai/code/artifact/d8ef3bf1-4383-40f1-b94a-b105fdbae2c8) — the same phases with tickable tasks and a
saved "where we stopped" note. Ticking there is shared with anyone holding the
link; this file stays the version-controlled copy.

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

## Phase 2 — Flutter operator app 🚧 next

- [ ] API client + typed models, base URL configurable in-app
- [ ] Pick `.docx` + sheet; call `/api/analyse`; prefill marker/keyLabel from
      the suggestions instead of making the operator guess
- [ ] Job form: split mode, chunk size, filename pattern, message template
- [ ] Poll job status with clear progress (`converting` → `splitting` → `ready`)
- [ ] Results list: recipient, phone, pages, size, warning badges
- [ ] Per row: **Open WhatsApp** (`wa.me`) + **Share PDF** (share sheet), then
      **Mark sent**; persist sent state to the API
- [ ] "Next unsent" flow so 181 notices can be worked through without hunting
- [ ] Surface `job.warnings` prominently — unmatched parts must not look normal

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
