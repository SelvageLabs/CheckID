<#
.SYNOPSIS
    Reads NIST 800-53 Rev 5 OSCAL baseline profiles and builds a profile lookup hashtable.

.DESCRIPTION
    Parses the 4 OSCAL baseline profile JSONs (Low, Moderate, High, Privacy) from the
    SecFrame repository and produces a hashtable mapping each control ID to its profile
    memberships. Control IDs are normalised from OSCAL format (lowercase, dot-delimited
    enhancements) to CheckID format (uppercase, parenthesised enhancements).

    Can optionally write the lookup to a JSON file for caching / inspection.

.PARAMETER SecFramePath
    Root path of the SecFrame repository. Defaults to a sibling directory of the
    CheckID repo root: ../../SecFrame relative to this script.

.PARAMETER ExportPath
    Optional. If provided, writes the lookup hashtable to this JSON path.

.OUTPUTS
    [hashtable] keyed by normalised control ID (e.g. AC-2, AC-6(5)),
    values are string arrays of profile names (e.g. @('Low','Moderate','High')).

.EXAMPLE
    $lookup = & ./scripts/Import-NistBaselines.ps1
    $lookup['AC-2']   # -> @('Low','Moderate','High')

.EXAMPLE
    & ./scripts/Import-NistBaselines.ps1 -ExportPath data/nist-800-53-baselines.json
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$SecFramePath,

    [Parameter()]
    [string]$ExportPath
)

# Resolve repo root (parent of this script's directory)
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not $SecFramePath) {
    # Resolve main repo root via git (works in both normal repos and worktrees)
    $gitCommonDir = git -C $repoRoot rev-parse --git-common-dir 2>$null
    if ($gitCommonDir) {
        $mainRepoRoot = Split-Path -Parent (Resolve-Path $gitCommonDir).Path
        $SecFramePath = Join-Path (Split-Path -Parent $mainRepoRoot) 'SecFrame'
    } else {
        $SecFramePath = Join-Path (Split-Path -Parent $repoRoot) 'SecFrame'
    }
    if (-not (Test-Path $SecFramePath)) {
        Write-Error "SecFrame repository not found at '$SecFramePath'. Provide -SecFramePath parameter."
        return
    }
}

$nistDir = Join-Path $SecFramePath 'NIST'

# Baseline profile files in order
$baselineFiles = [ordered]@{
    'Low'     = 'NIST_SP-800-53_rev5_LOW-baseline_profile.json'
    'Moderate'= 'NIST_SP-800-53_rev5_MODERATE-baseline_profile.json'
    'High'    = 'NIST_SP-800-53_rev5_HIGH-baseline_profile.json'
    'Privacy' = 'NIST_SP-800-53_rev5_PRIVACY-baseline_profile.json'
}

function ConvertTo-CheckIdFormat {
    <#
    .SYNOPSIS
        Converts an OSCAL control ID to CheckID format.
    .DESCRIPTION
        OSCAL: lowercase, dot-delimited enhancements (ac-2.1)
        CheckID: uppercase, parenthesised enhancements (AC-2(1))
    #>
    [CmdletBinding()]
    param([string]$OscalId)

    # Split on first dot to separate base from enhancement number
    if ($OscalId -match '^([a-z]{2}-\d+)\.(\d+)$') {
        $base = $Matches[1].ToUpper()
        $enhancement = $Matches[2]
        return "$base($enhancement)"
    }
    # No enhancement — just uppercase
    return $OscalId.ToUpper()
}

# Build the lookup hashtable
$lookup = @{}

foreach ($profileName in $baselineFiles.Keys) {
    $filePath = Join-Path $nistDir $baselineFiles[$profileName]

    if (-not (Test-Path $filePath)) {
        Write-Error "Baseline profile not found: $filePath"
        return
    }

    $json = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    $controlIds = $json.profile.imports[0].'include-controls'[0].'with-ids'

    Write-Verbose "$profileName baseline: $($controlIds.Count) controls"

    foreach ($oscalId in $controlIds) {
        $normalised = ConvertTo-CheckIdFormat -OscalId $oscalId

        if (-not $lookup.ContainsKey($normalised)) {
            $lookup[$normalised] = [System.Collections.Generic.List[string]]::new()
        }
        $lookup[$normalised].Add($profileName)
    }
}

# Summary
$counts = [ordered]@{}
foreach ($profileName in $baselineFiles.Keys) {
    $count = ($lookup.Values | Where-Object { $_ -contains $profileName }).Count
    $counts[$profileName] = $count
}
Write-Verbose "Profile membership counts: $(($counts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')"

# Optional export
if ($ExportPath) {
    $exportObj = [ordered]@{}
    foreach ($key in ($lookup.Keys | Sort-Object)) {
        $exportObj[$key] = @($lookup[$key])
    }
    $jsonText = $exportObj | ConvertTo-Json -Depth 5
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ExportPath, $jsonText, $utf8NoBom)
    Write-Verbose "Exported baseline lookup to: $ExportPath"
}

# Return the lookup
return $lookup
