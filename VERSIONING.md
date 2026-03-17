# Versioning

CheckID is a shared library consumed by multiple downstream projects. This document defines the versioning contract so consumers can pin safely.

## Version Types

| Version | Location | Format | Bumps when |
|---------|----------|--------|------------|
| **Schema** | `registry.json` `schemaVersion` | semver | Structure of registry.json changes |
| **Module** | `CheckID.psd1` `ModuleVersion` | semver | PowerShell module API changes |
| **Data** | `registry.json` `dataVersion` | YYYY-MM-DD | Every `Build-Registry.ps1` run (informational only) |

### Schema Version (registry.json `schemaVersion`)

Governs the structure of `registry.json`.

| Bump | When |
|------|------|
| **Major** | Removed/renamed fields, changed check object shape, changed framework key names |
| **Minor** | New fields added, new framework mappings, new metadata properties |
| **Patch** | Data corrections (encoding fixes, title updates, profile corrections) |

### Module Version (CheckID.psd1 `ModuleVersion`)

Governs the PowerShell module API.

| Bump | When |
|------|------|
| **Major** | Removed/renamed exported functions, changed parameter signatures, removed parameters |
| **Minor** | New exported functions, new optional parameters on existing functions |
| **Patch** | Bug fixes in existing functions, performance improvements |

### Data Version (registry.json `dataVersion`)

YYYY-MM-DD date that bumps on every `Build-Registry.ps1` run. Purely informational -- never pin to it.

## Breaking Change Examples

| Change | Schema | Module | Breaking? |
|--------|--------|--------|-----------|
| Rename `checkId` to `id` | Major | -- | Yes |
| Add `gdpr` framework to checks | Minor | -- | No |
| Fix HIPAA encoding | Patch | -- | No |
| Add `Get-FrameworkCoverage` | -- | Minor | No |
| Remove `Search-Check` | -- | Major | Yes |
| Add `-Profile` param to `Search-Check` | -- | Minor | No |

## Consumer Guidance

- **Pin to major version**: `RequiredModules = @(@{ModuleName='CheckID'; ModuleVersion='1.0.0'})`
- **Check schema compatibility**: compare `schemaVersion` major digit
- **Data version is informational only** -- never pin to it

## Downstream Consumers

| Consumer | Integration | Depends on |
|----------|-------------|------------|
| M365-Assess | PSGallery module (planned) | registry.json structure, module API |
| M365-Remediate | Submodule (build-time) | registry.json `checkId` field, `frameworks` object |
| Stitch-M365 | Submodule | registry.json structure, module API |
| Darn | Submodule (planned) | registry.json structure (C# deserialization) |
