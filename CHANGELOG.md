# Changelog

All notable changes to the CheckID module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.2.0] - 2026-03-17

### Added

- Framework definition JSONs for all 14 frameworks with unified schema
  - 4 existing definitions updated with `registryKey`, `csvColumn`, `displayOrder`, and `colors` fields
  - 7 new coverage-scored frameworks: NIST CSF 2.0, ISO 27001:2022, DISA STIG, PCI DSS v4.0.1, CMMC 2.0, HIPAA, CISA SCuBA
  - 3 derived frameworks: CIS Controls v8.1, FedRAMP Rev 5, MITRE ATT&CK v10
- `tests/framework-definitions.Tests.ps1` with comprehensive schema validation (158 new tests)
- `totalControls` field to SOC 2 (11) and Essential Eight (24) definitions
- Profile-level `colors` for CIS L2 and NIST 800-53 High/Privacy profiles
- Light and dark theme color support for all framework tags

### Changed

- Updated `CheckID.psd1` FileList to include all 14 framework definition files

## [1.1.0] - 2026-03-14

### Added

- `Get-FrameworkCoverage` cmdlet for framework-level coverage reporting
- Hash-indexed `Get-CheckById` for O(1) lookups
- Essential Eight (ASD) framework definition

### Fixed

- HIPAA encoding corruption in registry data
- Missing framework files in module FileList

## [1.0.0] - 2026-03-09

### Added

- Initial release with 233 security configuration checks
- 14 compliance framework mappings (CIS, NIST 800-53, NIST CSF, ISO 27001, DISA STIG, PCI DSS, CMMC, HIPAA, CISA SCuBA, SOC 2, Essential Eight, CIS Controls v8, FedRAMP, MITRE ATT&CK)
- `Get-CheckRegistry`, `Get-CheckById`, `Search-Check`, `Test-CheckRegistryData` cmdlets
- JSON Schema validation for registry.json
- CI pipeline with Python build script validation
