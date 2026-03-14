# CheckID Backlog Grooming & Sprint Design

**Date:** 2026-03-14
**Status:** Draft
**Goal:** Make CheckID consumer-ready — M365-Assess, Stitch-M365, and Darn can reliably depend on CheckID without worrying about breakage.

## Organization

**Cadence:** Milestone-based (no fixed sprints).
**Milestones:** 4 sequential milestones, each delivering tangible consumer value.

## Milestone Overview

| Milestone | Name | Theme | Issues |
|-----------|------|-------|--------|
| M1 | Reliable Build | Consumers can trust `Build-Registry.ps1` output | #3, #4, #5, #8, #9 |
| M2 | Quality & Contracts | Schema won't break under consumers | #6, #7 + new |
| M3 | Rich Data | More value from the registry | #2 + new |
| M4 | Module Packaging | Clean install experience | all new |

---

## M1: Reliable Build

**Goal:** Consumers can trust that `Build-Registry.ps1` produces correct, complete output.

### Issues

| # | GitHub | Title | Type | Work |
|---|--------|-------|------|------|
| 1 | #3 | supersededBy missing | bug | Add `SupersededBy` column to `check-id-mapping.csv`, update `Build-Registry.ps1` to populate it. Preserves the 81 existing mappings. |
| 2 | #4 | MANUAL-CIS naming | bug | Relax tests to allow `MANUAL-CIS-*` as valid prefix for unmigrated checks. Add a separate test counting unmigrated checks so regression is visible without blocking CI. |
| 3 | #5 | Outdated path refs | bug | Update the `.DESCRIPTION` comment block in `Build-Registry.ps1` — line 8 still references `controls/registry.json`. One comment line fix. |
| 4 | #8 | Silent failure | bug | Replace `return` with `throw` in `Export-ComplianceMatrix.ps1` when ImportExcel is missing. Note: `$ErrorActionPreference = 'Stop'` is already set (line 31) but does not prevent the deliberate `return` on line 38. Replace with `throw 'ImportExcel module is required...'`. |
| 5 | #9 | validate.yml | enhancement | Create CI workflow with 4 jobs (lint, validate-data, registry-consistency, test). Registry consistency and Pester start as warnings, flip to required once #3 and #4 land. |

### Exit Criteria

- `Build-Registry.ps1` regenerates all 233 checks including `supersededBy`
- CI pipeline runs green on PRs
- No silent failures in any script

---

## M2: Quality & Contracts

**Goal:** Consumers know the registry schema won't break under them. Data quality is validated automatically.

### Issues

| # | GitHub | Title | Type | Work |
|---|--------|-------|------|------|
| 6 | new | Schema versioning | enhancement | `registry.json` already has a `version` field (currently `"1.0.0"` set by `Build-Registry.ps1` line 202). Rename to `schemaVersion` for clarity — this is the structural contract version, not the data version. Add a separate `dataVersion` field (date-based, e.g. `"2026-03-14"`) that bumps on every data change. Document schema contract: major bump = breaking field changes, minor = new fields, patch = data corrections. |
| 7 | #6 | CSV schema docs | docs | Document required/optional columns for both CSVs. Add column validation to `Build-Registry.ps1` with clear error messages on bad input. |
| 8 | #7 | Expanded Pester tests | enhancement | Add test cases: supersededBy validity, all 10+ frameworks covered, required fields non-empty, no duplicate CheckIds, control_profiles values valid, HIPAA encoding, CSV-to-JSON fidelity. Target: ~20 test cases (up from 9). |
| 9 | new | Data quality tooling | enhancement | Create `Test-RegistryData.ps1` — standalone validation script that checks encoding (HIPAA section symbol U+00A7), duplicate IDs, empty required fields, orphaned supersededBy targets. Runs in CI and locally. |
| 10 | new | HIPAA encoding fix | bug | Fix HIPAA control IDs: the section symbol (U+00A7) is being stored/read as a garbled multi-byte sequence (e.g., `"Â§164.312(a)(1)"` should be `"§164.312(a)(1)"`). Ensure `framework-mappings.csv` is saved as UTF-8-without-BOM and `Build-Registry.ps1` reads CSVs with `-Encoding UTF8`. |

### Exit Criteria

- `registry.json` carries a `schemaVersion`
- Both CSVs have documented and validated schemas
- Pester coverage expands from 9 to ~20 test cases
- Data quality script catches encoding and integrity issues before they ship

---

## M3: Rich Data

**Goal:** Consumers get more value from the registry — human-readable titles, 5 new frameworks, and query tools.

### Issues

| # | GitHub | Title | Type | Work |
|---|--------|-------|------|------|
| 11 | #2 | Framework titles | enhancement | Build a lookup function that resolves control IDs to titles from SecFrame sources at `https://github.com/SelvageLabs/SecFrame`. Update `Build-Registry.ps1` to populate `title` on the 9 frameworks that lack it (CIS M365 v6 already has titles via `CisTitle`). Frameworks needing backfill: NIST 800-53, NIST CSF, ISO 27001, PCI DSS, CMMC, HIPAA, SOC 2, STIG, CISA SCuBA. |
| 12 | new | FedRAMP framework | enhancement | Map existing checks to FedRAMP baselines (Low/Moderate/High). Heavy overlap with NIST 800-53 — mostly a mapping exercise against SecFrame data. |
| 13 | new | GDPR framework | enhancement | Map checks to GDPR articles. Privacy-focused — some checks won't map. New CSV columns + framework definition JSON. |
| 14 | new | Essential Eight framework | enhancement | Map checks to Australian Essential Eight maturity levels. Security-focused — good overlap with existing CIS controls. |
| 15 | new | CIS Controls v8 framework | enhancement | Map checks to generic CIS Controls (not benchmark-specific). Natural fit — current data is CIS benchmark-based. |
| 16 | new | MITRE ATT&CK framework | enhancement | Map checks to ATT&CK techniques/mitigations. Threat-based rather than compliance. May require a separate mapping approach (many-to-many). Should land last in this milestone. |
| 17 | new | Lookup/query scripts | enhancement | Create `Search-Registry.ps1` — query by CheckId, framework, controlId, keyword. Returns formatted results. Serves as both a user tool and foundation for the future module's cmdlets. |

### Sequencing

1. #11 (titles) lands first — establishes the pattern for resolving external reference data
2. Frameworks in order of mapping ease: FedRAMP > CIS Controls v8 > Essential Eight > GDPR > MITRE ATT&CK
3. #17 (lookup scripts) can run in parallel with framework work

### SecFrame References

All framework source data references MUST point to the SecFrame GitHub repository:
`https://github.com/SelvageLabs/SecFrame`

**Never reference local paths** (e.g., `C:\git\SecFrame\...`) in issues, scripts, or documentation. Scripts that need SecFrame data should either:
- Clone/fetch from the GitHub repo at build time, or
- Document the expected local clone location as a configurable parameter defaulting to a sibling directory

### Exit Criteria

- All frameworks (10 existing + 5 new = 15 total) have entries with titles
- `Search-Registry.ps1` works for interactive use
- Schema version bumped (minor version) to reflect new fields/frameworks

---

## M4: Module Packaging

**Goal:** Consumers get a clean `Install-Module CheckID` experience instead of git submodules.

### Issues

| # | GitHub | Title | Type | Work |
|---|--------|-------|------|------|
| 18 | new | Module manifest | enhancement | Create `CheckID.psd1` module manifest — version, description, exported functions, required PowerShell version (7.x). Follows PSGallery publishing requirements. |
| 19 | new | Module root script | enhancement | Create `CheckID.psm1` — loads registry data, exports public functions: `Get-CheckRegistry`, `Get-CheckById`, `Search-Check`, `Test-RegistryData`. Internal helpers stay private. |
| 20 | new | Deprecate submodule pattern | enhancement | Update consumer docs (REFERENCES.md, README.md) with migration guide: submodule to module. Add a deprecation notice to the submodule approach. Consumers continue working during transition. |
| 21 | new | PSGallery publishing | enhancement | Add `Publish-Module` step to CI (manual trigger or tag-based). Add API key management docs. |
| 22 | new | Backwards compatibility | enhancement | During transition period, ensure the repo still works as a submodule (file paths unchanged). Module packaging is additive — doesn't break existing consumers until they're ready to switch. |

### Exit Criteria

- `Install-Module CheckID` works from PSGallery
- Existing submodule consumers verified working against the same commit (M365-Assess, Stitch-M365)
- Migration guide documented
- CI can publish releases
- "Transition period" ends when all three consumers (M365-Assess, Stitch-M365, Darn) have migrated to `Install-Module`

---

## Cross-Cutting: Issue Hygiene

Before creating new issues:

| Action | Detail |
|--------|--------|
| Label all 8 existing issues | Apply `bug`, `enhancement`, or `documentation` labels |
| Create GitHub milestones | `M1: Reliable Build`, `M2: Quality & Contracts`, `M3: Rich Data`, `M4: Module Packaging` |
| Assign milestones to existing issues | Slot into appropriate milestones |
| Fix issue #2 body | Replace local `C:\git\SecFrame\...` paths with `https://github.com/SelvageLabs/SecFrame` references |
| Fix REFERENCES.md | Replace `C:\git\SecFrame` parenthetical with note that the canonical source is `https://github.com/SelvageLabs/SecFrame` and local clone location is user-specific |
| Reconcile framework count | Update README.md and CLAUDE.md to consistently state framework count (currently 10, will become 15 after M3) |
| Create new issues | All items marked "new" in the tables above |

## Cross-Cutting: Definition of Consumer-Ready

A CheckID release is **consumer-ready** when:

1. `Build-Registry.ps1` produces identical output to committed `registry.json` (CI enforced)
2. `registry.json` carries a `schemaVersion` and the schema contract is documented
3. All Pester tests pass (CI required, not warning)
4. No known data integrity bugs (encoding, orphaned references, missing fields)
5. At least one install path works without friction (PSGallery module or documented submodule)

## Total Issue Count

| Category | Existing | New | Total |
|----------|----------|-----|-------|
| M1: Reliable Build | 5 | 0 | 5 |
| M2: Quality & Contracts | 2 | 3 | 5 |
| M3: Rich Data | 1 | 6 | 7 |
| M4: Module Packaging | 0 | 5 | 5 |
| **Total** | **8** | **14** | **22** |
