# CheckID Centralization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract CheckID into a standalone shared repository, populate it with canonical files from M365-Assess and Stitch-M365, apply path updates, and prepare for consumer integration.

**Architecture:** Domain-organized repo (`data/`, `scripts/`, `tests/`, `docs/`) with internal path updates so scripts resolve data from the new layout. Consumers will add this repo as a git submodule.

**Tech Stack:** PowerShell 7.x, Pester 5.x, Git

**Spec:** `docs/superpowers/specs/2026-03-12-checkid-centralization-design.md`

---

## File Map

### Files to Create (new in CheckID)
| File | Source | Responsibility |
|------|--------|---------------|
| `data/registry.json` | Copy from `C:\git\M365-Assess\controls\registry.json` | Master registry |
| `data/check-id-mapping.csv` | Copy from `C:\git\M365-Assess\controls\check-id-mapping.csv` | CheckID assignments |
| `data/framework-mappings.csv` | Copy from `C:\git\M365-Assess\Common\framework-mappings.csv` | Framework cross-refs |
| `scripts/Build-Registry.ps1` | Copy from `C:\git\M365-Assess\controls\Build-Registry.ps1` | Registry generator |
| `scripts/Import-ControlRegistry.ps1` | Copy from `C:\git\M365-Assess\Common\Import-ControlRegistry.ps1` | Registry loader |
| `scripts/Show-CheckProgress.ps1` | Copy from `C:\git\M365-Assess\Common\Show-CheckProgress.ps1` | Progress display |
| `scripts/Export-ComplianceMatrix.ps1` | Copy from `C:\git\M365-Assess\Common\Export-ComplianceMatrix.ps1` | XLSX compliance export |
| `tests/registry-integrity.Tests.ps1` | Copy from `C:\git\Stitch-M365\tests\Engine\Controls\registry-integrity.Tests.ps1` | Pester validation |
| `docs/CheckId-Guide.md` | Copy from `C:\git\M365-Assess\docs\CheckId-Guide.md` | Documentation |
| `CLAUDE.md` | New | Project conventions |
| `REFERENCES.md` | New | Upstream/downstream refs |
| `README.md` | New | Public-facing overview |

### Files to Modify (path updates within CheckID after copy)
| File | What Changes |
|------|-------------|
| `scripts/Build-Registry.ps1:37,40,41,203` | `Join-Path` child paths: `controls`→`data`, `Common`→`data`; `generatedFrom` metadata |
| `scripts/Export-ComplianceMatrix.ps1:55` | `$controlsPath` child path: `controls`→`data` |
| `scripts/Show-CheckProgress.ps1:128,207,222,236` | Parameterize hardcoded `'M365 Security Assessment'` activity name |
| `tests/registry-integrity.Tests.ps1:3` | Registry path: `$PSScriptRoot/../../../Engine/Controls/registry.json`→`$PSScriptRoot/../data/registry.json` |

### Files NOT modified (no changes needed)
| File | Why |
|------|-----|
| `scripts/Import-ControlRegistry.ps1` | Fully parameterized via `-ControlsPath`; callers pass path |
| `data/registry.json` | Generated artifact, will be regenerated after path updates |
| `data/*.csv` | Raw data, no paths inside |

---

## Chunk 1: Copy Files and Create Structure

### Task 1: Create directory structure and copy data files

**Files:**
- Create: `C:\git\CheckID\data\` directory
- Create: `C:\git\CheckID\data\registry.json` (copy)
- Create: `C:\git\CheckID\data\check-id-mapping.csv` (copy)
- Create: `C:\git\CheckID\data\framework-mappings.csv` (copy)

- [ ] **Step 1: Create data directory**

```bash
mkdir -p /c/git/CheckID/data
```

- [ ] **Step 2: Copy data files from M365-Assess**

```bash
cp /c/git/M365-Assess/controls/registry.json /c/git/CheckID/data/
cp /c/git/M365-Assess/controls/check-id-mapping.csv /c/git/CheckID/data/
cp /c/git/M365-Assess/Common/framework-mappings.csv /c/git/CheckID/data/
```

- [ ] **Step 3: Verify files copied correctly**

```bash
wc -l /c/git/CheckID/data/*
```
Expected: `registry.json` ~6312 lines, `check-id-mapping.csv` 141 lines, `framework-mappings.csv` 141 lines.

- [ ] **Step 4: Commit data files**

```bash
cd /c/git/CheckID
git add data/
git commit -m "feat: add CheckID data files from M365-Assess

Copy registry.json, check-id-mapping.csv, and framework-mappings.csv
as canonical data sources for the CheckID shared library."
```

---

### Task 2: Copy script files

**Files:**
- Create: `C:\git\CheckID\scripts\` directory
- Create: `C:\git\CheckID\scripts\Build-Registry.ps1` (copy)
- Create: `C:\git\CheckID\scripts\Import-ControlRegistry.ps1` (copy)
- Create: `C:\git\CheckID\scripts\Show-CheckProgress.ps1` (copy)
- Create: `C:\git\CheckID\scripts\Export-ComplianceMatrix.ps1` (copy)

- [ ] **Step 1: Create scripts directory**

```bash
mkdir -p /c/git/CheckID/scripts
```

- [ ] **Step 2: Copy script files from M365-Assess**

```bash
cp /c/git/M365-Assess/controls/Build-Registry.ps1 /c/git/CheckID/scripts/
cp /c/git/M365-Assess/Common/Import-ControlRegistry.ps1 /c/git/CheckID/scripts/
cp /c/git/M365-Assess/Common/Show-CheckProgress.ps1 /c/git/CheckID/scripts/
cp /c/git/M365-Assess/Common/Export-ComplianceMatrix.ps1 /c/git/CheckID/scripts/
```

- [ ] **Step 3: Verify files copied**

```bash
ls -la /c/git/CheckID/scripts/
```
Expected: 4 `.ps1` files.

- [ ] **Step 4: Commit script files**

```bash
cd /c/git/CheckID
git add scripts/
git commit -m "feat: add CheckID scripts from M365-Assess

Copy Build-Registry, Import-ControlRegistry, Show-CheckProgress,
and Export-ComplianceMatrix as shared PowerShell scripts."
```

---

### Task 3: Copy test and doc files

**Files:**
- Create: `C:\git\CheckID\tests\registry-integrity.Tests.ps1` (copy from Stitch)
- Create: `C:\git\CheckID\docs\CheckId-Guide.md` (copy from M365-Assess)

- [ ] **Step 1: Create directories**

```bash
mkdir -p /c/git/CheckID/tests
```
Note: `docs/` already exists (has `superpowers/specs/`).

- [ ] **Step 2: Copy test from Stitch-M365**

```bash
cp "/c/git/Stitch-M365/tests/Engine/Controls/registry-integrity.Tests.ps1" /c/git/CheckID/tests/
```

- [ ] **Step 3: Copy docs from M365-Assess**

```bash
cp /c/git/M365-Assess/docs/CheckId-Guide.md /c/git/CheckID/docs/
```

- [ ] **Step 4: Verify**

```bash
ls /c/git/CheckID/tests/ /c/git/CheckID/docs/CheckId-Guide.md
```
Expected: `registry-integrity.Tests.ps1` and `CheckId-Guide.md` both present.

- [ ] **Step 5: Commit**

```bash
cd /c/git/CheckID
git add tests/ docs/CheckId-Guide.md
git commit -m "feat: add Pester tests and CheckId guide

Tests from Stitch-M365, documentation from M365-Assess."
```

---

## Chunk 2: Apply Path Updates

### Task 4: Update Build-Registry.ps1 paths

**Files:**
- Modify: `C:\git\CheckID\scripts\Build-Registry.ps1:37,40,41,203`

The script computes `$repoRoot` as the parent of its own directory. When it lives at
`scripts/Build-Registry.ps1`, `$repoRoot` resolves to the CheckID repo root. The three
`Join-Path` calls and the `generatedFrom` metadata need updating.

- [ ] **Step 1: Update OutputPath default (line 37)**

Change `Join-Path $repoRoot 'controls' 'registry.json'` to `Join-Path $repoRoot 'data' 'registry.json'`.

- [ ] **Step 2: Update frameworkCsvPath (line 40)**

Change `Join-Path $repoRoot 'Common' 'framework-mappings.csv'` to `Join-Path $repoRoot 'data' 'framework-mappings.csv'`.

- [ ] **Step 3: Update checkIdCsvPath (line 41)**

Change `Join-Path $repoRoot 'controls' 'check-id-mapping.csv'` to `Join-Path $repoRoot 'data' 'check-id-mapping.csv'`.

- [ ] **Step 4: Update generatedFrom metadata (line 203)**

Change `'Common/framework-mappings.csv + controls/check-id-mapping.csv'` to `'data/framework-mappings.csv + data/check-id-mapping.csv'`.

- [ ] **Step 5: Update .DESCRIPTION comment block (lines 9-10)**

Change references from `Common/framework-mappings.csv` and `controls/check-id-mapping.csv`
to `data/framework-mappings.csv` and `data/check-id-mapping.csv`.

- [ ] **Step 6: Update .EXAMPLE comment (line 24)**

Change `.\controls\Build-Registry.ps1` to `.\scripts\Build-Registry.ps1`.

- [ ] **Step 7: Verify script parses cleanly**

```bash
pwsh -NoProfile -Command "Get-Command /c/git/CheckID/scripts/Build-Registry.ps1 | Select-Object Name, CommandType"
```
Expected: Returns `Build-Registry.ps1` as `ExternalScript` with no parse errors.

- [ ] **Step 8: Commit**

```bash
cd /c/git/CheckID
git add scripts/Build-Registry.ps1
git commit -m "fix: update Build-Registry.ps1 paths for data/ layout

Change Join-Path child paths from controls/ and Common/ to data/.
Update generatedFrom metadata and comment block references."
```

---

### Task 5: Update Export-ComplianceMatrix.ps1 controlsPath

**Files:**
- Modify: `C:\git\CheckID\scripts\Export-ComplianceMatrix.ps1:55`

The script computes `$projectRoot` (two levels up from `$PSCommandPath`) and then does
`Join-Path -Path $projectRoot -ChildPath 'controls'`. Since data now lives in `data/`,
this must change. If this is missed, the registry lookup silently returns empty.

- [ ] **Step 1: Update controlsPath (line 55)**

Change `Join-Path -Path $projectRoot -ChildPath 'controls'` to `Join-Path -Path $projectRoot -ChildPath 'data'`.

- [ ] **Step 2: Verify dot-source path on line 54 still resolves**

Line 54 is `. (Join-Path -Path $PSScriptRoot -ChildPath 'Import-ControlRegistry.ps1')`.
Since both scripts live in `scripts/`, this needs no change. Confirm:
```bash
pwsh -NoProfile -Command "Select-String -Path /c/git/CheckID/scripts/Export-ComplianceMatrix.ps1 -Pattern 'Import-ControlRegistry'"
```
Expected: Shows the `Join-Path` with `$PSScriptRoot` and `Import-ControlRegistry.ps1` (same directory).

- [ ] **Step 3: Verify script parses cleanly**

```bash
pwsh -NoProfile -Command "Get-Command /c/git/CheckID/scripts/Export-ComplianceMatrix.ps1 | Select-Object Name, CommandType"
```
Expected: `ExternalScript`, no parse errors.

- [ ] **Step 4: Commit**

```bash
cd /c/git/CheckID
git add scripts/Export-ComplianceMatrix.ps1
git commit -m "fix: update Export-ComplianceMatrix.ps1 controlsPath to data/

Change Join-Path child from 'controls' to 'data' so the registry
lookup finds registry.json in the new layout."
```

---

### Task 6: Parameterize Show-CheckProgress.ps1 activity name

**Files:**
- Modify: `C:\git\CheckID\scripts\Show-CheckProgress.ps1:128,207,222,236`

The hardcoded `'M365 Security Assessment'` string appears in 4 `Write-Progress -Activity`
calls. Since this is now a shared library, parameterize it so consumers can pass their own
branding. Add a `$script:ProgressActivityName` variable defaulting to `'Security Assessment'`
and replace all 4 occurrences.

- [ ] **Step 1: Add `$script:ProgressActivityName` variable near top of file (after line 18)**

The script is designed to be dot-sourced (not called with parameters), so a `$script:`
variable is the correct approach. Add after the comment-based help block:
```powershell
# Configurable activity name for Write-Progress — consumers set $script:ProgressActivityName
# before calling Initialize-CheckProgress. Defaults to 'Security Assessment'.
if (-not $script:ProgressActivityName) {
    $script:ProgressActivityName = 'Security Assessment'
}
```

- [ ] **Step 2: Replace all 4 hardcoded strings**

Replace `'M365 Security Assessment'` with `$script:ProgressActivityName` on lines 128, 207, 222, and 236.

- [ ] **Step 3: Verify script parses cleanly**

```bash
pwsh -NoProfile -Command "Get-Command /c/git/CheckID/scripts/Show-CheckProgress.ps1 | Select-Object Name, CommandType"
```

- [ ] **Step 4: Verify no remaining hardcoded strings**

```bash
pwsh -NoProfile -Command "Select-String -Path /c/git/CheckID/scripts/Show-CheckProgress.ps1 -Pattern 'M365 Security Assessment'"
```
Expected: No output (all occurrences replaced).

- [ ] **Step 5: Commit**

```bash
cd /c/git/CheckID
git add scripts/Show-CheckProgress.ps1
git commit -m "refactor: parameterize Write-Progress activity name

Replace hardcoded 'M365 Security Assessment' with configurable
\$script:ProgressActivityName (defaults to 'Security Assessment')
so consumers can set their own branding."
```

---

### Task 7: Update registry-integrity.Tests.ps1 path

**Files:**
- Modify: `C:\git\CheckID\tests\registry-integrity.Tests.ps1:3`

The test was written for Stitch's layout (`tests/Engine/Controls/` — 3 levels deep).
In CheckID it lives at `tests/` — 1 level deep.

- [ ] **Step 1: Update registry path (line 3)**

Change `"$PSScriptRoot/../../../Engine/Controls/registry.json"` to `"$PSScriptRoot/../data/registry.json"`.

- [ ] **Step 2: Verify test file parses**

```bash
pwsh -NoProfile -Command "Get-Content /c/git/CheckID/tests/registry-integrity.Tests.ps1 | Select-Object -First 5"
```
Expected: Line 3 shows `$registryPath = "$PSScriptRoot/../data/registry.json"`.

- [ ] **Step 3: Commit**

```bash
cd /c/git/CheckID
git add tests/registry-integrity.Tests.ps1
git commit -m "fix: update test registry path for CheckID layout

Change from Stitch's 3-level-deep path to CheckID's tests/ directory."
```

---

### Task 8: Run Pester tests to validate everything works

**Files:**
- Test: `C:\git\CheckID\tests\registry-integrity.Tests.ps1`

- [ ] **Step 1: Run Pester tests**

```bash
pwsh -NoProfile -Command "Invoke-Pester /c/git/CheckID/tests/registry-integrity.Tests.ps1 -Output Detailed"
```
Expected: All 7 tests pass:
- Has at least 139 entries
- No duplicate CheckIds
- Every entry has required fields
- CIS-mapped entries have valid CIS framework data
- All automated checks have a collector field
- CheckId format matches convention
- SOC 2 mappings exist for NIST AC/AU/IA/SC/SI families

- [ ] **Step 2: If any test fails, investigate and fix before proceeding**

Common failure: path still pointing to old location. Verify `$registryPath` resolves correctly.

---

## Chunk 3: Documentation

### Note on .gitattributes

The repo already has a `.gitattributes` (from the initial GitHub commit) with `* text=auto`.
No changes needed — it handles line ending normalization for all file types.

---

### Task 9: Write CLAUDE.md

**Files:**
- Create: `C:\git\CheckID\CLAUDE.md`

- [ ] **Step 1: Write CLAUDE.md**

Contents should include:
- Project purpose (shared CheckID registry library)
- Testing policy (Pester 5.x, on demand)
- Structure overview (data/, scripts/, tests/, docs/)
- Key rule: this is a shared library — changes here affect M365-Assess, Stitch-M365, and Darn
- After modifying data CSVs, run `scripts/Build-Registry.ps1` to regenerate `data/registry.json`
- After any changes, consumers must bump their submodule pointer
- SecFrame is the upstream reference source (see REFERENCES.md)
- Coding standards inherited from `~/.claude/CLAUDE.md`

- [ ] **Step 2: Commit**

```bash
cd /c/git/CheckID
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md project conventions"
```

---

### Task 10: Write REFERENCES.md

**Files:**
- Create: `C:\git\CheckID\REFERENCES.md`

- [ ] **Step 1: Write REFERENCES.md**

Contents should include:

**Upstream — SecFrame** (`C:\git\SecFrame`, github.com/SelvageLabs/SecFrame):
- `CIS/CIS_M365_to_NIST_to_FedRAMP_Crosswalk.csv` — CIS M365 → NIST → FedRAMP
- `SOC/tsc_to_nist_800-53.xlsx` — SOC 2 TSC → NIST 800-53
- `SCF/secure-controls-framework-scf-2025-4.csv` — Master cross-framework mapping (80+ frameworks)
- Workflow: update SecFrame sources → update CheckID CSVs → run Build-Registry.ps1

**Downstream Consumers** (via git submodule):
- M365-Assess (`C:\git\M365-Assess`) — submodule at `lib/CheckID/`
- Stitch-M365 (`C:\git\Stitch-M365`) — submodule at `Engine/lib/CheckID/`
- Darn (`C:\git\Darn`) — submodule at `lib/CheckID/` (future)

- [ ] **Step 2: Commit**

```bash
cd /c/git/CheckID
git add REFERENCES.md
git commit -m "docs: add REFERENCES.md with upstream/downstream links"
```

---

### Task 11: Write README.md

**Files:**
- Create: `C:\git\CheckID\README.md`

- [ ] **Step 1: Write README.md**

Public-facing overview covering:
- What CheckID is (universal identifier system, 151 checks, 13 frameworks)
- CheckID format: `{COLLECTOR}-{AREA}-{NNN}` (e.g., `ENTRA-ADMIN-001`)
- Repository structure (data/, scripts/, tests/, docs/)
- Quick start: how to use as a git submodule
  ```bash
  git submodule add https://github.com/SelvageLabs/CheckID.git lib/CheckID
  ```
- How to load the registry in PowerShell:
  ```powershell
  . ./lib/CheckID/scripts/Import-ControlRegistry.ps1
  $registry = Import-ControlRegistry -ControlsPath ./lib/CheckID/data
  ```
- How to rebuild the registry after CSV changes
- Supported frameworks list (all 13)
- License note

- [ ] **Step 2: Commit**

```bash
cd /c/git/CheckID
git add README.md
git commit -m "docs: add README.md with usage guide and quick start"
```

---

### Task 12: Regenerate registry.json to verify Build-Registry.ps1 works

**Files:**
- Validate: `C:\git\CheckID\scripts\Build-Registry.ps1`
- Validate: `C:\git\CheckID\data\registry.json`

- [ ] **Step 1: Regenerate registry.json**

```bash
pwsh -NoProfile -Command "& /c/git/CheckID/scripts/Build-Registry.ps1 -Verbose"
```
Expected: Writes to `data/registry.json` with verbose output showing check count.

- [ ] **Step 2: Verify output matches original**

```bash
pwsh -NoProfile -Command "(Get-Content /c/git/CheckID/data/registry.json | ConvertFrom-Json).checks.Count"
```
Expected: `151`

- [ ] **Step 3: Run Pester tests again to confirm regenerated registry passes**

```bash
pwsh -NoProfile -Command "Invoke-Pester /c/git/CheckID/tests/registry-integrity.Tests.ps1 -Output Detailed"
```
Expected: All 7 tests pass.

- [ ] **Step 4: Commit regenerated registry (if changed)**

```bash
cd /c/git/CheckID
git diff --stat data/registry.json
```
If changes exist (metadata update), commit:
```bash
git add data/registry.json
git commit -m "chore: regenerate registry.json with updated metadata paths"
```

---

### Task 13: Tag initial release and push

- [ ] **Step 1: Push all commits to origin**

```bash
cd /c/git/CheckID && git push origin main
```

- [ ] **Step 2: Tag v1.0.0**

```bash
cd /c/git/CheckID && git tag -a v1.0.0 -m "CheckID v1.0.0 — initial shared library release

Extracted from M365-Assess with bug fixes (baseCheckId suffix stripping)
and UX improvements (Status Legend). Includes Pester tests from Stitch-M365."
```

- [ ] **Step 3: Push tag**

```bash
cd /c/git/CheckID && git push origin v1.0.0
```

---

## Chunk 4: SecFrame Cross-References

### Task 14: Update SecFrame CLAUDE.md

**Files:**
- Modify: `C:\git\SecFrame\CLAUDE.md`

- [ ] **Step 1: Read current SecFrame CLAUDE.md**

Read the file to find the right insertion point.

- [ ] **Step 2: Add downstream consumer section**

Add a section noting that CheckID (`C:\git\CheckID`) consumes SecFrame mapping data.
List which SecFrame files feed into CheckID:
- `CIS/CIS_M365_to_NIST_to_FedRAMP_Crosswalk.csv`
- `SOC/tsc_to_nist_800-53.xlsx`
- `SCF/secure-controls-framework-scf-2025-4.csv`

Note: changes to these files should trigger a CheckID update.

- [ ] **Step 3: Commit**

```bash
cd /c/git/SecFrame
git add CLAUDE.md
git commit -m "docs: add CheckID downstream consumer reference

CheckID repo consumes SecFrame mapping data for its registry.
List specific source files and update workflow."
```

---

## Summary

| Chunk | Tasks | Purpose |
|-------|-------|---------|
| 1 | Tasks 1-3 | Copy files into CheckID structure |
| 2 | Tasks 4-8 | Apply path updates + validate with tests |
| 3 | Tasks 9-13 | Documentation, regenerate registry, tag + push |
| 4 | Task 14 | SecFrame cross-reference |

**Total:** 14 tasks, ~50 steps

**Not in this plan** (separate sessions):
- Phase 2: Stitch-M365 cutover (private repo, separate session)
- Phase 3: M365-Assess cutover (public repo, separate session)
- Phase 4: Darn integration (future)
