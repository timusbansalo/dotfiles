# archdev-dfp dashboard

NVIDIA DFP program-tracking dashboard. Repo `~/src/archdev-programmanager/` (NVIDIA GitLab `gitlab-master.nvidia.com:12051/subansal/archdev-programmanager`), live at **archdev-dfp.nvidia.com**. Stdlib-Python HTTP server + JSON store mirrored to xlsx; single-page inline-JS template; systemd --user service on subansal-prod-vm + nginx; deploys via GitLab CI on `v*` tags. Tracks programs × 39 DFP domains: assignment matrix (owners/PICs), schedule (DFP milestones vs silicon baseline), taxonomy, roadmap.

## Priorities (set 2026-06-10)
- **P0** — every program must appear on BOTH the Assignment Matrix and Schedule pages. Program list comes from Frank's Excel (upstream); missing now: **TCX10** (add manually), **Newport** (Intel naming mismatch). Add a missing-program validator + manual-add fallback.
- **P1** — DFP lifecycle tracking per phase per program (a "DFP stage tracker"). Schedule basis must be **program-specific milestone mapping** (DFP milestone → PFNL/Tapeout reference → offset) with per-program override + signoff/governance — **NOT** pure PON offsets (Vishruth: PON-offset is unreliable; pre-silicon milestones shift).

## Vishruth review (2026-06-10) — outstanding feature asks
- Editing: fix **click→Outlook** (`mailto` person-links fire instead of the edit picker); standardize edit on all non-schema fields.
- **Execution layer** (manager visibility): per program×DFP-milestone — current work items, next 1–2wk plan, dependencies, status; + a `DFP Work Type` field (ASIC / Modeling / Tools / Validation / Dependencies); future effort estimation.
- **Checklist integration**: embed per-domain × DFP-version checklist (Jira→Confluence) into the dashboard; effort-per-item → aggregate per milestone/program.
- Promote the dashboard from viewer → **authoritative source of truth**. Domains stay **schema-locked** (users edit values, not schema).

## Shipped
- **v0.16.0** (2026-06-10) — staffing-gap feature: per-program leadership band (TPM / Bringup Methodology / Prod TPM / Prod Chip Lead), six-state cell vocabulary (Name / Incoming / Open req / Gap / To assign / N/A), per-program staffing rollup, **complete editable grid** (auto-fills every program×domain pair; N/A editable; cell value is the single source of truth with the `Applicable` column kept in sync), append-only `edit_log.jsonl`.
- Deferred foundation: auth/SSO, TLS, SQLite migration, in-app feedback button.

Full detail in the project's per-project auto-memory and the repo's `docs/feedback/2026-06-10-vishruth-review-and-roadmap.md`.
