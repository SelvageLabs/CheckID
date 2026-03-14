# CheckID Centralization Design

**Date:** 2026-03-12
**Status:** Approved
**Repository:** github.com/SelvageLabs/CheckID

## Problem

CheckID is a universal identifier system for security checks that maps 151 checks
across 13 compliance frameworks. It currently lives duplicated inside M365-Assess
and Stitch-M365, leading to subtree drift and bugs being fixed in one repo but not
the other (e.g., the `baseCheckId` suffix-stripping fix in Export-ComplianceMatrix).

## Decision

Extract CheckID into its own standalone repository. Consumers reference it via git
submodule at `lib/CheckID/`.

## Scope

CheckID owns the **registry core + compliance matrix export** (7 files + tests + docs).
It does NOT own consumer-specific report generators like `Export-AssessmentReport.ps1`.

### Files Owned by CheckID

| File | Purpose |
|------|---------|
| `data/registry.json` | Master registry (151 checks, 13 frameworks) |
| `data/check-id-mapping.csv` | CheckID to collector/area assignments |
| `data/framework-mappings.csv` | CIS to multi-framework cross-references |
| `scripts/Build-Registry.ps1` | Generates registry.json from CSVs |
| `scripts/Import-ControlRegistry.ps1` | Loads registry into memory (hashtable) |
| `scripts/Show-CheckProgress.ps1` | Real-time progress display |
| `scripts/Export-ComplianceMatrix.ps1` | XLSX multi-framework report |
| `tests/registry-integrity.Tests.ps1` | Pester tests for registry validation |
| `docs/CheckId-Guide.md` | System documentation |

### Canonical Source for Each File

- All scripts and data: **M365-Assess** (has baseCheckId suffix-strip bug fixes and
  Status Legend UX improvement)
- `registry-integrity.Tests.ps1`: **Stitch-M365** (only repo with tests)
- `CheckId-Guide.md`: **M365-Assess** (only repo with docs)

## Repository Structure

```
CheckID/
├── data/
│   ├── registry.json
│   ├── check-id-mapping.csv
│   └── framework-mappings.csv
├── scripts/
│   ├── Build-Registry.ps1
│   ├── Import-ControlRegistry.ps1
│   ├── Show-CheckProgress.ps1
│   └── Export-ComplianceMatrix.ps1
├── tests/
│   └── registry-integrity.Tests.ps1
├── docs/
│   └── CheckId-Guide.md
├── CLAUDE.md
├── REFERENCES.md
├── README.md
└── .gitattributes
```

## Consumer Integration

Each consumer adds CheckID as a git submodule. The mount point varies by repo
structure:

| Consumer | Submodule Path | Reason |
|----------|---------------|--------|
| M365-Assess | `lib/CheckID/` | Top-level project |
| Stitch-M365 | `Engine/lib/CheckID/` | Engine/ is the assessment root |
| Darn | `lib/CheckID/` | Top-level project |

### Submodule Layout in Consumers

```
M365-Assess/                    Stitch-M365/
├── lib/                        ├── Engine/
│   └── CheckID/ ← submodule   │   ├── lib/
├── Common/                     │   │   └── CheckID/ ← submodule
└── ...                         │   ├── Common/
                                │   └── ...
                                └── ...
```

### Consumer Update Workflow

```bash
git submodule update --remote lib/CheckID
git add lib/CheckID
git commit -m "chore: bump CheckID to latest"
```

### Path Changes in Consumers

Old (M365-Assess example):
```powershell
. "$PSScriptRoot/../Common/Import-ControlRegistry.ps1"
```

New:
```powershell
. "$PSScriptRoot/../lib/CheckID/scripts/Import-ControlRegistry.ps1"
```

## Internal Path Updates (Within CheckID)

Five files need path updates when restructuring from the M365-Assess layout.
Note: these scripts use `Join-Path` with computed root variables, not raw
`$PSScriptRoot` strings.

**Build-Registry.ps1** (uses `$repoRoot` = parent of script's directory):
```powershell
# Old (lines 37-41):
$OutputPath = Join-Path $repoRoot 'controls' 'registry.json'
$frameworkCsvPath = Join-Path $repoRoot 'Common' 'framework-mappings.csv'
$checkIdCsvPath   = Join-Path $repoRoot 'controls' 'check-id-mapping.csv'

# New — all three point to data/:
$OutputPath = Join-Path $repoRoot 'data' 'registry.json'
$frameworkCsvPath = Join-Path $repoRoot 'data' 'framework-mappings.csv'
$checkIdCsvPath   = Join-Path $repoRoot 'data' 'check-id-mapping.csv'
```
Also update the `generatedFrom` metadata string to reflect new paths.

**Import-ControlRegistry.ps1** — NO internal changes needed. The function accepts
a `-ControlsPath` parameter; callers pass the path. Callers must change what they
pass (see Consumer Path Updates below).

**Export-ComplianceMatrix.ps1** (uses `$projectRoot` = two levels up from script):
```powershell
# Old (line 55):
$controlsPath = Join-Path -Path $projectRoot -ChildPath 'controls'

# New — point to data/:
$controlsPath = Join-Path -Path $projectRoot -ChildPath 'data'
```
The dot-source of `Import-ControlRegistry.ps1` on line 54 needs no change (same
`scripts/` directory). But the `$controlsPath` child path MUST change or the
registry lookup will silently return empty.

**Show-CheckProgress.ps1** — dot-sources `Import-ControlRegistry.ps1` from same
directory (no change needed). However, the hardcoded `'M365 Security Assessment'`
string in `Write-Progress -Activity` should be parameterized so both M365-Assess
and Stitch can pass their own branding. Add a `$script:ProgressActivityName` variable
(not a parameter, since this file is dot-sourced) defaulting to `'Security Assessment'`.
Consumers set `$script:ProgressActivityName` before calling `Initialize-CheckProgress`.

**registry-integrity.Tests.ps1** (from Stitch — 3 levels deep):
```powershell
# Old (line 3 — Stitch layout: tests/Engine/Controls/):
$registryPath = "$PSScriptRoot/../../../Engine/Controls/registry.json"

# New (CheckID layout: tests/):
$registryPath = "$PSScriptRoot/../data/registry.json"
```

### Consumer Path Updates (in M365-Assess and Stitch-M365)

After deleting local CheckID files, every script that dot-sources or calls CheckID
functions needs updated paths. This includes not just orchestrators and collectors
but also **Export-AssessmentReport.ps1** (consumer-owned), which dot-sources
`Import-ControlRegistry.ps1` and computes `$controlsPath`.

**M365-Assess example — Export-AssessmentReport.ps1:**
```powershell
# Old:
. (Join-Path -Path $PSScriptRoot -ChildPath 'Import-ControlRegistry.ps1')
$controlsPath = Join-Path -Path $projectRoot -ChildPath 'controls'

# New:
. (Join-Path -Path $PSScriptRoot -ChildPath '../lib/CheckID/scripts/Import-ControlRegistry.ps1')
$controlsPath = Join-Path -Path $PSScriptRoot -ChildPath '../lib/CheckID/data'
```

**Stitch-M365 example — Export-AssessmentReport.ps1:**
```powershell
# Old:
. (Join-Path -Path $PSScriptRoot -ChildPath 'Import-ControlRegistry.ps1')
$controlsPath = Join-Path -Path $projectRoot -ChildPath 'controls'

# New (Engine/lib/CheckID/ path):
. (Join-Path -Path $PSScriptRoot -ChildPath '../lib/CheckID/scripts/Import-ControlRegistry.ps1')
$controlsPath = Join-Path -Path $PSScriptRoot -ChildPath '../lib/CheckID/data'
```

## Cross-References

### CheckID → SecFrame (upstream)

SecFrame (`C:\git\SecFrame`) is the authoritative source for framework mapping data.
Documented in `REFERENCES.md` with specific files:
- `CIS/CIS_M365_to_NIST_to_FedRAMP_Crosswalk.csv`
- `SOC/tsc_to_nist_800-53.xlsx`
- `SCF/secure-controls-framework-scf-2025-4.csv`

Workflow: update SecFrame sources → update CheckID CSVs → run Build-Registry.ps1 → commit.

### SecFrame → CheckID (downstream)

SecFrame's CLAUDE.md updated to note CheckID as a downstream consumer of its mapping
data, listing which files feed into CheckID.

### Consumer CLAUDE.md Updates

M365-Assess and Stitch-M365 CLAUDE.md files updated to note:
- CheckID is a git submodule at `lib/CheckID/`
- Do not edit CheckID files in-place — changes go to the CheckID repo

## Rollout Sequence

### Phase 1: Stand Up CheckID Repo

1. Populate `C:\git\CheckID` with new structure
2. Apply internal path updates
3. Run Pester tests to validate registry integrity
4. Write CLAUDE.md, REFERENCES.md, README.md
5. Commit and push
6. Tag initial release (`v1.0.0`) — consumers pin submodule to this tag

### Phase 2: Cut Over Stitch-M365 (Private)

Safe to break — no external users. Validates the integration pattern.

1. Add CheckID as submodule at `Engine/lib/CheckID/`
2. Delete local CheckID files from `Engine/Controls/` and `Engine/Common/`
   (only CheckID-owned files — keep `Export-AssessmentReport.ps1` and other consumer scripts)
3. Update import paths in: orchestrator, collectors, `Export-AssessmentReport.ps1`,
   and any other script that dot-sources `Import-ControlRegistry.ps1` or references
   `controls/registry.json`
4. Test full assessment run
5. Update CLAUDE.md
6. Commit and push (feature branch + PR)

### Phase 3: Cut Over M365-Assess (Public)

Proven pattern from Phase 2 applied to public repo.

1. Add CheckID as submodule at `lib/CheckID/`
2. Delete local CheckID files from `controls/`, `Common/`, `docs/`
   (only CheckID-owned files — keep `Export-AssessmentReport.ps1` and other consumer scripts)
3. Update import paths in: orchestrator, collectors, `Export-AssessmentReport.ps1`,
   and any other script that dot-sources `Import-ControlRegistry.ps1` or references
   `controls/registry.json`
4. Test full assessment run
5. Update CLAUDE.md
6. Commit and push (feature branch + PR)

### Phase 4: Wire Up Darn (When Ready)

1. Add submodule at `lib/CheckID/`
2. Reference `data/registry.json` from .NET code
3. No urgency

### Phase 5: Update SecFrame Cross-References

1. Update SecFrame CLAUDE.md
2. Can run in parallel with any phase

## Key Bug Fix Included

The `baseCheckId` suffix-stripping fix is included in CheckID's copies of
`Export-ComplianceMatrix.ps1`. This fix strips `.N` suffixes from sub-numbered
CheckIDs (e.g., `DEFENDER-ANTIPHISH-001.3` → `DEFENDER-ANTIPHISH-001`) before
registry lookup, ensuring framework columns populate correctly for per-policy rows.

Stitch-M365 gets this fix for free when cutting over to the submodule in Phase 2.

## Risks

- **Phase 2 and 3 are breaking changes** in their respective repos. Each gets its
  own feature branch and PR.
- **Submodule UX friction** — contributors must run `git submodule update --init`
  after cloning. Mitigated by documenting in README and CLAUDE.md.
- **Path update errors** — mitigated by running Pester tests after each phase.
