# M1: Reliable Build — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consumers can trust that `Build-Registry.ps1` produces correct, complete output including all 233 checks with `supersededBy` metadata.

**Architecture:** Add a `SupersededBy` column to `check-id-mapping.csv`, update `Build-Registry.ps1` to populate it during registry generation, fix two failing Pester tests by allowing MANUAL-CIS as a valid prefix, fix a silent failure in `Export-ComplianceMatrix.ps1`, fix stale comments, and harden the CI pipeline to enforce these checks.

**Tech Stack:** PowerShell 7.x, Pester 5.x, GitHub Actions, PSScriptAnalyzer

**Spec:** `docs/superpowers/specs/2026-03-14-backlog-grooming-design.md` — M1 section

---

## Chunk 1: Issue Hygiene (Labels, Milestones, Issue Fixes)

Before any code changes, set up the GitHub project structure.

### Task 1: Create GitHub milestones

**Files:** None (GitHub API only)

- [ ] **Step 1: Create all 4 milestones**

```bash
gh milestone create "M1: Reliable Build" --description "Consumers can trust Build-Registry.ps1 output. Issues: #3, #4, #5, #8, #9"
gh milestone create "M2: Quality & Contracts" --description "Schema versioning, CSV validation, expanded tests, data quality tooling"
gh milestone create "M3: Rich Data" --description "Framework titles, 5 new frameworks, lookup/query scripts"
gh milestone create "M4: Module Packaging" --description "PSGallery module, stable API, deprecate submodule approach"
```

- [ ] **Step 2: Verify milestones exist**

```bash
gh milestone list
```

Expected: 4 milestones listed.

### Task 2: Label and assign existing issues to milestones

**Files:** None (GitHub API only)

- [ ] **Step 1: Label existing issues**

```bash
# M1 issues
gh issue edit 3 --add-label "bug" --milestone "M1: Reliable Build"
gh issue edit 4 --add-label "bug" --milestone "M1: Reliable Build"
gh issue edit 5 --add-label "bug" --milestone "M1: Reliable Build"
gh issue edit 8 --add-label "bug" --milestone "M1: Reliable Build"
gh issue edit 9 --add-label "enhancement" --milestone "M1: Reliable Build"

# M2 issues
gh issue edit 6 --add-label "documentation" --milestone "M2: Quality & Contracts"
gh issue edit 7 --add-label "enhancement" --milestone "M2: Quality & Contracts"

# M3 issues
gh issue edit 2 --add-label "enhancement" --milestone "M3: Rich Data"
```

- [ ] **Step 2: Verify labels and milestones**

```bash
gh issue list --state open --json number,title,labels,milestone
```

Expected: All 8 issues have labels and milestones.

### Task 3: Fix issue #2 body — remove local paths

**Files:** None (GitHub API only)

- [ ] **Step 1: Update issue #2 body**

Replace all `C:\git\SecFrame\...` local paths in issue #2's body with references to `https://github.com/SelvageLabs/SecFrame`. Specifically:

| Old | New |
|-----|-----|
| `C:\git\SecFrame\NIST\NIST_SP-800-53_rev5_catalog.json` | `https://github.com/SelvageLabs/SecFrame` — `NIST/NIST_SP-800-53_rev5_catalog.json` |
| `C:\git\SecFrame\NIST\NIST_CSF_v2.0_catalog.json` | `https://github.com/SelvageLabs/SecFrame` — `NIST/NIST_CSF_v2.0_catalog.json` |
| `C:\git\SecFrame\SCF\scf.db` | `https://github.com/SelvageLabs/SecFrame` — `SCF/scf.db` |
| `C:\git\SecFrame\CMMC/` | `https://github.com/SelvageLabs/SecFrame` — `CMMC/` |
| `C:\git\SecFrame\SOC/` | `https://github.com/SelvageLabs/SecFrame` — `SOC/` |

Use `gh issue edit 2 --body-file` with the corrected body.

- [ ] **Step 2: Fix REFERENCES.md local path**

**File:** Modify: `REFERENCES.md`

Replace the `C:\git\SecFrame` parenthetical with a note that the canonical source is `https://github.com/SelvageLabs/SecFrame` and local clone location is user-specific.

- [ ] **Step 3: Commit**

```bash
git add REFERENCES.md
git commit -m "docs: replace local SecFrame paths with GitHub repo URLs"
```

### Task 4: Create new issues for M2, M3, M4

**Files:** None (GitHub API only)

- [ ] **Step 1: Create M2 new issues**

```bash
# Schema versioning
gh issue create --title "Add schemaVersion and dataVersion fields to registry.json" \
  --label "enhancement" --milestone "M2: Quality & Contracts" \
  --body "## Summary
Rename existing \`version\` field to \`schemaVersion\` for clarity (structural contract version). Add \`dataVersion\` field (date-based, e.g. \`2026-03-14\`) that bumps on every data change. Document schema contract: major = breaking field changes, minor = new fields, patch = data corrections.

## Files
- Modify: \`scripts/Build-Registry.ps1\` (lines 201-203)
- Modify: \`data/registry.json\` (generated)
- Create: \`docs/schema-contract.md\`"

# Data quality tooling
gh issue create --title "Create Test-RegistryData.ps1 validation script" \
  --label "enhancement" --milestone "M2: Quality & Contracts" \
  --body "## Summary
Standalone validation script for CI and local use. Checks: HIPAA section symbol encoding (U+00A7), duplicate CheckIds, empty required fields, orphaned supersededBy targets.

## Files
- Create: \`scripts/Test-RegistryData.ps1\`
- Modify: \`.github/workflows/validate.yml\` (add validation step)"

# HIPAA encoding fix
gh issue create --title "Fix HIPAA section symbol encoding in framework-mappings.csv" \
  --label "bug" --milestone "M2: Quality & Contracts" \
  --body "## Problem
HIPAA control IDs use the section symbol (U+00A7) but it is stored as a garbled multi-byte sequence. E.g. \`Â§164.312(a)(1)\` should be \`§164.312(a)(1)\`.

## Fix
- Ensure \`framework-mappings.csv\` is saved as UTF-8-without-BOM
- Ensure \`Build-Registry.ps1\` reads CSVs with explicit UTF-8 encoding
- Regenerate \`registry.json\` and verify HIPAA entries"
```

- [ ] **Step 2: Create M3 new issues**

```bash
# FedRAMP
gh issue create --title "Add FedRAMP framework mappings" \
  --label "enhancement" --milestone "M3: Rich Data" \
  --body "Map existing checks to FedRAMP baselines (Low/Moderate/High). Heavy overlap with NIST 800-53. Source: https://github.com/SelvageLabs/SecFrame"

# GDPR
gh issue create --title "Add GDPR framework mappings" \
  --label "enhancement" --milestone "M3: Rich Data" \
  --body "Map checks to GDPR articles. Privacy-focused — some checks won't map. New CSV columns + framework definition JSON. Source: https://github.com/SelvageLabs/SecFrame"

# Essential Eight
gh issue create --title "Add Essential Eight framework mappings" \
  --label "enhancement" --milestone "M3: Rich Data" \
  --body "Map checks to Australian Essential Eight maturity levels. Security-focused — good overlap with existing CIS controls. Source: https://github.com/SelvageLabs/SecFrame"

# CIS Controls v8
gh issue create --title "Add CIS Controls v8 framework mappings" \
  --label "enhancement" --milestone "M3: Rich Data" \
  --body "Map checks to generic CIS Controls v8 (not benchmark-specific). Natural fit — current data is CIS benchmark-based. Source: https://github.com/SelvageLabs/SecFrame"

# MITRE ATT&CK
gh issue create --title "Add MITRE ATT&CK framework mappings" \
  --label "enhancement" --milestone "M3: Rich Data" \
  --body "Map checks to ATT&CK techniques/mitigations. Threat-based rather than compliance. May require many-to-many mapping approach. Should land last in M3. Source: https://github.com/SelvageLabs/SecFrame"

# Lookup scripts
gh issue create --title "Create Search-Registry.ps1 lookup/query script" \
  --label "enhancement" --milestone "M3: Rich Data" \
  --body "## Summary
Create \`Search-Registry.ps1\` — query registry by CheckId, framework, controlId, keyword. Returns formatted results. Foundation for future module cmdlets.

## Files
- Create: \`scripts/Search-Registry.ps1\`
- Create: \`tests/search-registry.Tests.ps1\`"
```

- [ ] **Step 3: Create M4 new issues**

```bash
# Module manifest
gh issue create --title "Create CheckID.psd1 module manifest" \
  --label "enhancement" --milestone "M4: Module Packaging" \
  --body "Create PowerShell module manifest. Version, description, exported functions, RequiredVersion 7.x. Follows PSGallery publishing requirements."

# Module root script
gh issue create --title "Create CheckID.psm1 module root script" \
  --label "enhancement" --milestone "M4: Module Packaging" \
  --body "Module root script. Exports: Get-CheckRegistry, Get-CheckById, Search-Check, Test-RegistryData. Internal helpers stay private."

# Deprecate submodule
gh issue create --title "Document migration guide: submodule to PSGallery module" \
  --label "enhancement" --milestone "M4: Module Packaging" \
  --body "Update REFERENCES.md and README.md with migration guide. Add deprecation notice to submodule approach. Consumers continue working during transition (until all three have migrated)."

# PSGallery publishing
gh issue create --title "Add PSGallery publishing to CI pipeline" \
  --label "enhancement" --milestone "M4: Module Packaging" \
  --body "Add Publish-Module step to CI (manual trigger or tag-based). Document API key management."

# Backwards compatibility
gh issue create --title "Ensure backwards compatibility during module transition" \
  --label "enhancement" --milestone "M4: Module Packaging" \
  --body "During transition period, repo must still work as a git submodule (file paths unchanged). Module packaging is additive. Transition period ends when M365-Assess, Stitch-M365, and Darn have all migrated to Install-Module."
```

- [ ] **Step 4: Verify all issues created**

```bash
gh issue list --state open --json number,title,milestone
```

Expected: 22 open issues across 4 milestones.

### Task 4b: Reconcile framework count in README.md and CLAUDE.md

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

The spec's cross-cutting hygiene table requires reconciling the framework count. Currently README.md and CLAUDE.md reference "13 compliance frameworks" but the supported frameworks table lists 10. Correct both to state "10 compliance frameworks" (will become 15 after M3).

- [ ] **Step 1: Update README.md and CLAUDE.md**

Find and update any references to "13 compliance frameworks" or similar to "10 compliance frameworks" in both files.

- [ ] **Step 2: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: reconcile framework count to 10 in README and CLAUDE.md"
```

---

## Chunk 2: Fix supersededBy in Build-Registry.ps1 (Issue #3)

The core data integrity fix. Currently `Build-Registry.ps1` produces 139 checks without `supersededBy`. The committed `registry.json` has 233 checks with 81 `supersededBy` entries. This task adds a `SupersededBy` column to the CSV and teaches the build script to populate it.

### Task 5: Add SupersededBy column to check-id-mapping.csv

**Files:**
- Modify: `data/check-id-mapping.csv`

- [ ] **Step 1: Extract existing supersededBy mappings from committed registry.json**

Write a temporary script that reads the committed `registry.json` and outputs the CisControl → supersededBy mappings as CSV-ready data:

```powershell
# _tmp_extract.ps1
$reg = Get-Content ./data/registry.json -Raw | ConvertFrom-Json
foreach ($check in $reg.checks) {
    if ($check.supersededBy) {
        $cisId = $check.frameworks.'cis-m365-v6'.controlId
        Write-Output "$cisId,$($check.supersededBy)"
    }
}
```

Run: `pwsh -NoProfile -File _tmp_extract.ps1`

This gives you the 81 CisControl → SupersededBy pairs to add to the CSV.

- [ ] **Step 2: Add SupersededBy column to check-id-mapping.csv**

The current CSV header is: `CisControl,CheckId,Collector,Area,Name`

Change to: `CisControl,CheckId,Collector,Area,Name,SupersededBy`

For each of the 81 MANUAL-CIS entries that have a supersededBy mapping, populate the `SupersededBy` column with the target CheckId. Leave it empty for all other rows.

Example rows after change:
```
CisControl,CheckId,Collector,Area,Name,SupersededBy
1.1.1,MANUAL-CIS-1-1-1,,,"Ensure Administrative accounts are cloud-only",ENTRA-CLOUDADMIN-001
1.1.3,ENTRA-ADMIN-001,Entra,ADMIN,"Ensure that between two and four global admins are designated",
```

- [ ] **Step 3: Verify CSV structure**

```bash
pwsh -NoProfile -Command "Import-Csv ./data/check-id-mapping.csv | Select-Object -First 3 | Format-Table"
```

Expected: 6 columns including `SupersededBy`. First MANUAL-CIS entry shows its supersedure target.

- [ ] **Step 4: Commit CSV change**

```bash
git add data/check-id-mapping.csv
git commit -m "feat: add SupersededBy column to check-id-mapping.csv (#3)"
```

### Task 6: Update Build-Registry.ps1 to populate supersededBy

**Files:**
- Modify: `scripts/Build-Registry.ps1:143-190` (check object construction)

- [ ] **Step 1: Write the failing test**

Add a test to `tests/registry-integrity.Tests.ps1` inside the `Describe` block, after the last `It` block (after line 77):

```powershell
    It 'supersededBy references valid CheckIds when present' {
        $superseded = $checks | Where-Object { $_.supersededBy }
        $allIds = $checks | ForEach-Object { $_.checkId }
        foreach ($check in $superseded) {
            $check.supersededBy | Should -BeIn $allIds `
                -Because "$($check.checkId) supersededBy '$($check.supersededBy)' must reference an existing CheckId"
        }
    }
```

- [ ] **Step 2: Run test to establish baseline against committed registry**

```bash
pwsh -NoProfile -Command "Install-Module Pester -RequiredVersion 5.7.1 -Force -Scope CurrentUser; Invoke-Pester ./tests/registry-integrity.Tests.ps1 -Output Detailed"
```

Expected: The new test should PASS against the committed `registry.json` (which already has `supersededBy`). This establishes the contract — after we regenerate the registry from CSVs, this test ensures `supersededBy` targets are still valid.

- [ ] **Step 3: Update Build-Registry.ps1 to read SupersededBy from CSV**

In `scripts/Build-Registry.ps1`, after line 148 (`$collector = ...`), add:

```powershell
    # SupersededBy
    $supersededBy = if ([string]::IsNullOrWhiteSpace($cidRow.SupersededBy)) { $null } else { $cidRow.SupersededBy.Trim() }
```

Then in the `$checkObj` ordered hashtable (lines 180-188), add the `supersededBy` field after `frameworks`:

```powershell
    $checkObj = [ordered]@{
        checkId           = $checkId
        name              = $fwRow.CisTitle
        category          = $category
        collector         = $collector
        hasAutomatedCheck = $hasAutomated
        licensing         = [ordered]@{ minimum = $minimumLicense }
        frameworks        = $frameworks
    }

    if ($supersededBy) {
        $checkObj['supersededBy'] = $supersededBy
    }
```

- [ ] **Step 4: Regenerate registry.json**

```bash
pwsh -NoProfile -File scripts/Build-Registry.ps1
```

Expected output: `Total checks: 139` (still only CSV rows — the 94 superseded-only entries that exist in the committed registry but not in the CSV are a separate concern tracked by the check count gap).

- [ ] **Step 5: Run tests to verify supersededBy populates correctly**

```bash
pwsh -NoProfile -Command "Invoke-Pester ./tests/registry-integrity.Tests.ps1 -Output Detailed"
```

Expected: The new `supersededBy` test passes. Other tests may still fail (MANUAL-CIS naming — addressed in Task 7).

- [ ] **Step 6: Commit**

```bash
git add scripts/Build-Registry.ps1 tests/registry-integrity.Tests.ps1 data/registry.json
git commit -m "feat: populate supersededBy field from CSV in Build-Registry.ps1 (#3)"
```

### Task 7: Reconcile check count (233 committed vs 139 rebuilt)

The committed `registry.json` has 233 checks but `Build-Registry.ps1` only produces 139 from CSVs. The gap is 94 checks that exist in the committed JSON but have no CSV row. These are MANUAL-CIS entries that were manually added to the JSON previously.

**Files:**
- Modify: `data/check-id-mapping.csv`
- Modify: `data/framework-mappings.csv`

**Important — CisControl key collisions:** `Build-Registry.ps1` indexes `check-id-mapping.csv` by `CisControl` using `$checkIdMap[$row.CisControl] = $row` (line 50), which silently overwrites duplicates. Before appending rows, verify that no missing check has a `CisControl` value that already exists in the CSV. If collisions are found, investigate whether the committed `registry.json` has duplicate CIS control mappings and resolve them before proceeding.

- [ ] **Step 1: Extract the 94 missing checks and verify no key collisions**

Write a temporary script to identify checks in the committed `registry.json` that are NOT in `check-id-mapping.csv`, and check for key collisions:

```powershell
# _tmp_find_missing.ps1
$reg = Get-Content ./data/registry.json -Raw | ConvertFrom-Json
$csv = Import-Csv ./data/check-id-mapping.csv
$csvControls = $csv | ForEach-Object { $_.CisControl }

$missing = $reg.checks | Where-Object {
    $_.frameworks.'cis-m365-v6'.controlId -notin $csvControls
}

# Check for duplicate CisControl values among the missing checks themselves.
# If two missing checks share the same CisControl, appending both to the CSV
# would cause Build-Registry.ps1's $checkIdMap to silently overwrite one.
$dupes = $missing | Group-Object { $_.frameworks.'cis-m365-v6'.controlId } |
    Where-Object { $_.Count -gt 1 }
if ($dupes) {
    Write-Host "WARNING: $($dupes.Count) duplicate CisControl value(s) among missing checks:"
    $dupes | ForEach-Object {
        Write-Host "  $($_.Name) -> $($_.Count) entries: $(($_.Group | ForEach-Object { $_.checkId }) -join ', ')"
    }
    Write-Host "Resolve duplicates before appending to CSV."
}

Write-Host "Missing from CSV: $($missing.Count) checks"
$missing | ForEach-Object {
    $cis = $_.frameworks.'cis-m365-v6'.controlId
    $ss = if ($_.supersededBy) { $_.supersededBy } else { '' }
    Write-Output "$cis,$($_.checkId),$($_.collector),$($_.category),$($_.name),$ss"
}
```

Run: `pwsh -NoProfile -File _tmp_find_missing.ps1 > _tmp_missing_rows.csv`

If collisions are detected, investigate and resolve before proceeding to Step 2. If no collisions, continue.

- [ ] **Step 2: Add missing rows to both CSVs**

Append the 94 missing rows to `data/check-id-mapping.csv` with appropriate columns.

For `data/framework-mappings.csv`, extract the framework columns for each missing check from the committed `registry.json` and append corresponding rows.

- [ ] **Step 3: Regenerate and verify count**

```bash
pwsh -NoProfile -File scripts/Build-Registry.ps1
```

Expected: `Total checks: 233`

- [ ] **Step 4: Diff the regenerated registry against committed**

```bash
pwsh -NoProfile -Command "(Get-Content ./data/registry.json -Raw | ConvertFrom-Json).checks.Count"
```

Expected: 233

- [ ] **Step 5: Run all tests**

```bash
pwsh -NoProfile -Command "Invoke-Pester ./tests/ -Output Detailed"
```

- [ ] **Step 6: Clean up temp scripts and commit**

```bash
pwsh -NoProfile -Command "Remove-Item _tmp_*.ps1, _tmp_*.csv -ErrorAction SilentlyContinue"
git add data/check-id-mapping.csv data/framework-mappings.csv data/registry.json
git commit -m "feat: add 94 missing checks to CSVs, registry now builds all 233 (#3)"
```

---

## Chunk 3: Fix Tests and Scripts (Issues #4, #5, #8)

### Task 8: Fix MANUAL-CIS naming convention tests (Issue #4)

**Files:**
- Modify: `tests/registry-integrity.Tests.ps1:26-36`

- [ ] **Step 1: Update the two failing tests**

Replace lines 26-36 in `tests/registry-integrity.Tests.ps1`:

**Old (lines 26-29):**
```powershell
    It 'No MANUAL-CIS-* CheckIds remain (all use {SERVICE}-{AREA}-{NNN} convention)' {
        $manualIds = $checks | Where-Object { $_.checkId -like 'MANUAL-*' }
        $manualIds | Should -BeNullOrEmpty -Because "All CheckIds should use the {SERVICE}-{AREA}-{NNN} naming convention"
    }
```

**New:**
```powershell
    It 'Tracks MANUAL-CIS migration progress' {
        $manualIds = $checks | Where-Object { $_.checkId -like 'MANUAL-*' }
        # Track count for regression visibility — do not fail
        Write-Host "  MANUAL-CIS entries remaining: $($manualIds.Count) of $($checks.Count) total"
        # Fail only if count increases (regression)
        $manualIds.Count | Should -BeLessOrEqual 94 `
            -Because "MANUAL-CIS count should decrease over time, not increase (was 94 at baseline)"
    }
```

**Old (lines 31-36):**
```powershell
    It 'All CheckIds follow the {SERVICE}-{AREA}-{NNN} naming convention' {
        foreach ($check in $checks) {
            $check.checkId | Should -Match '^[A-Z]+-[A-Z0-9]+-\d{3}$' `
                -Because "$($check.checkId) must follow {SERVICE}-{AREA}-{NNN} naming convention"
        }
    }
```

**New:**
```powershell
    It 'All automated CheckIds follow the {SERVICE}-{AREA}-{NNN} naming convention' {
        $automated = $checks | Where-Object { $_.checkId -notlike 'MANUAL-*' }
        foreach ($check in $automated) {
            $check.checkId | Should -Match '^[A-Z]+-[A-Z0-9]+-\d{3}$' `
                -Because "$($check.checkId) must follow {SERVICE}-{AREA}-{NNN} naming convention"
        }
    }
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
pwsh -NoProfile -Command "Invoke-Pester ./tests/registry-integrity.Tests.ps1 -Output Detailed"
```

Expected: Both modified tests PASS. MANUAL-CIS entries are tracked but don't block CI.

- [ ] **Step 3: Commit**

```bash
git add tests/registry-integrity.Tests.ps1
git commit -m "fix: relax naming tests to allow MANUAL-CIS prefix, track migration count (#4)"
```

### Task 9: Fix outdated path reference in Build-Registry.ps1 (Issue #5)

**Files:**
- Modify: `scripts/Build-Registry.ps1:6`

- [ ] **Step 1: Fix the comment**

Change line 6 from:
```
    Reads two CSV sources and produces controls/registry.json — the canonical registry
```
To:
```
    Reads two CSV sources and produces data/registry.json — the canonical registry
```

Also fix line 16 from:
```
    Path to write the JSON registry. Defaults to controls/registry.json relative to
```
To:
```
    Path to write the JSON registry. Defaults to data/registry.json relative to
```

Also fix line 25 from:
```
    Generates controls/registry.json from the default CSV sources.
```
To:
```
    Generates data/registry.json from the default CSV sources.
```

- [ ] **Step 2: Verify parse**

```bash
pwsh -NoProfile -Command "Get-Command ./scripts/Build-Registry.ps1"
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/Build-Registry.ps1
git commit -m "fix: update comment-based help to reference data/registry.json (#5)"
```

### Task 10: Fix silent failure in Export-ComplianceMatrix.ps1 (Issue #8)

**Files:**
- Modify: `scripts/Export-ComplianceMatrix.ps1:36-38`

- [ ] **Step 1: Replace return with throw**

Change lines 36-38 from:
```powershell
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Warning "ImportExcel module not available — skipping XLSX compliance matrix export. Install with: Install-Module ImportExcel -Scope CurrentUser"
    return
}
```
To:
```powershell
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    throw "ImportExcel module is required for XLSX export. Install with: Install-Module ImportExcel -Scope CurrentUser"
}
```

- [ ] **Step 2: Update comment-based help to reflect new behavior**

In `scripts/Export-ComplianceMatrix.ps1`, update line 9 from:
```
    Requires the ImportExcel module. If not available, logs a warning and returns.
```
To:
```
    Requires the ImportExcel module. Throws a terminating error if not installed.
```

- [ ] **Step 3: Verify parse**

```bash
pwsh -NoProfile -Command "Get-Command ./scripts/Export-ComplianceMatrix.ps1"
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/Export-ComplianceMatrix.ps1
git commit -m "fix: throw instead of silent return when ImportExcel missing (#8)"
```

---

## Chunk 4: Harden CI Pipeline (Issue #9)

### Task 11: Update validate.yml to enforce checks

**Files:**
- Modify: `.github/workflows/validate.yml`

Now that #3 and #4 are fixed, the CI pipeline can flip from warning to enforcing.

- [ ] **Step 1: Update registry-consistency job to fail on mismatch**

In `.github/workflows/validate.yml`, replace the registry-consistency `run` block (lines 136-156). Change the warning-only behavior to fail:

```yaml
      - name: Rebuild and compare
        shell: pwsh
        run: |
          $tempOut = Join-Path $env:RUNNER_TEMP 'registry-rebuilt.json'
          & scripts/Build-Registry.ps1 -OutputPath $tempOut

          $committed = Get-Content data/registry.json -Raw | ConvertFrom-Json
          $rebuilt = Get-Content $tempOut -Raw | ConvertFrom-Json

          $committedCount = $committed.checks.Count
          $rebuiltCount = $rebuilt.checks.Count

          Write-Host "Committed registry: $committedCount checks"
          Write-Host "Rebuilt registry:   $rebuiltCount checks"

          if ($committedCount -ne $rebuiltCount) {
            $delta = $committedCount - $rebuiltCount
            Write-Host "::error::Registry mismatch: $committedCount committed vs $rebuiltCount rebuilt ($delta checks differ)"
            exit 1
          }
          Write-Host "Registry is consistent with CSVs"
```

- [ ] **Step 2: Update Pester job to fail on test failures**

Replace the test job's `run` block (lines 166-183):

```yaml
      - name: Run Pester
        shell: pwsh
        run: |
          Install-Module Pester -RequiredVersion 5.7.1 -Force -Scope CurrentUser
          $config = New-PesterConfiguration
          $config.Run.Path = './tests/'
          $config.Output.Verbosity = 'Detailed'
          $config.Run.Exit = $true
          $config.Run.Throw = $true
          Invoke-Pester -Configuration $config
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/validate.yml
git commit -m "ci: enforce registry consistency and Pester tests in CI (#9)"
```

### Task 12: Verify full CI pipeline locally

- [ ] **Step 1: Run Build-Registry.ps1 and verify count**

```bash
pwsh -NoProfile -File scripts/Build-Registry.ps1
```

Expected: `Total checks: 233`

- [ ] **Step 2: Run full Pester suite**

```bash
pwsh -NoProfile -Command "Invoke-Pester ./tests/ -Output Detailed"
```

Expected: All tests pass.

- [ ] **Step 3: Verify registry consistency**

Write a temp script per project convention (avoid inline `$` in bash):

```powershell
# _tmp_verify_consistency.ps1
$tempOut = Join-Path $env:TEMP 'registry-rebuilt.json'
& ./scripts/Build-Registry.ps1 -OutputPath $tempOut
$committed = (Get-Content ./data/registry.json -Raw | ConvertFrom-Json).checks.Count
$rebuilt = (Get-Content $tempOut -Raw | ConvertFrom-Json).checks.Count
Write-Host "Committed: $committed, Rebuilt: $rebuilt"
if ($committed -ne $rebuilt) { Write-Host 'MISMATCH'; exit 1 } else { Write-Host 'CONSISTENT' }
```

```bash
pwsh -NoProfile -File _tmp_verify_consistency.ps1
```

Expected: `Committed: 233, Rebuilt: 233` then `CONSISTENT`

- [ ] **Step 4: Final commit — update registry.json generatedFrom**

The committed `registry.json` line 3 still says `"generatedFrom": "Common/framework-mappings.csv + controls/check-id-mapping.csv"` — this is stale. Regenerate the registry to fix it:

```bash
pwsh -NoProfile -File scripts/Build-Registry.ps1
git add data/registry.json
git commit -m "chore: regenerate registry.json with corrected generatedFrom path"
```
