#!/usr/bin/env python3
"""One-time migration: map existing CheckID checks to SCF controls.

Reads registry.json (v1.1.0), bridges each check's NIST 800-53 control IDs
through the SCF database to find matching SCF controls, ranks candidates by
specificity, and outputs:

  - data/scf-check-mapping.json  (draft check → SCF mapping for Build-Registry)
  - data/scf-migration-review.csv (human review spreadsheet)

Usage:
    python scripts/Build-ScfMigration.py
    python scripts/Build-ScfMigration.py --scf-db C:/git/SecFrame/SCF/scf.db
"""
import argparse
import csv
import io
import json
import re
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path

if sys.stdout.encoding != "utf-8":
    sys.stdout = io.TextIOWrapper(
        sys.stdout.buffer, encoding="utf-8", errors="replace"
    )

SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent

# NIST 800-53 R5 framework_id in the SCF database
NIST_800_53_FW_ID = 45


def normalize_nist_id(control_id: str) -> str:
    """Normalize NIST 800-53 control ID for matching.

    Converts parenthesized enhancement notation AC-6(5) to AC-6.5,
    strips trailing sub-provision letters (AC-6a → AC-6, SI-3a → SI-3),
    and uppercases for consistency with SCF.

    NIST 800-53 uses two distinct notations:
      - Enhancements: AC-6(5) — separate controls, mapped in SCF as AC-6.5
      - Sub-provisions: AC-6a  — paragraphs within a control, not mapped separately in SCF
    """
    cid = control_id.strip().upper()
    # Convert enhancement notation: AC-6(5) → AC-6.5
    cid = re.sub(r"\((\d+)\)", r".\1", cid)
    # Strip trailing sub-provision letters: SI-3A → SI-3, AU-12C → AU-12
    # Only strip if the letter follows a digit (avoids mangling family prefixes)
    cid = re.sub(r"(\d)[A-Z]$", r"\1", cid)
    return cid


def denormalize_nist_id(control_id: str) -> str:
    """Convert SCF-style AC-6.5 back to standard AC-6(5) notation."""
    return re.sub(r"\.(\d+)$", r"(\1)", control_id)


def parse_nist_ids(semicolon_separated: str) -> list[str]:
    """Split semicolon-separated NIST control IDs and normalize each."""
    if not semicolon_separated:
        return []
    return [
        normalize_nist_id(cid)
        for cid in semicolon_separated.split(";")
        if cid.strip()
    ]


def build_nist_to_scf_index(conn: sqlite3.Connection) -> dict[str, list[str]]:
    """Build a reverse index: NIST 800-53 control ID → list of SCF IDs.

    Uses framework_id=45 (NIST 800-53 R5) in the control_mappings table.
    """
    cur = conn.cursor()
    cur.execute(
        "SELECT scf_id, framework_control_id FROM control_mappings WHERE framework_id = ?",
        (NIST_800_53_FW_ID,),
    )
    index: dict[str, list[str]] = defaultdict(list)
    for scf_id, nist_id in cur.fetchall():
        normalized = normalize_nist_id(nist_id)
        index[normalized].append(scf_id)
    return dict(index)


def build_scf_specificity(conn: sqlite3.Connection) -> dict[str, int]:
    """Count total NIST 800-53 mappings per SCF control (for ranking).

    Lower count = more specific control = better primary candidate.
    """
    cur = conn.cursor()
    cur.execute(
        "SELECT scf_id, COUNT(*) FROM control_mappings WHERE framework_id = ? GROUP BY scf_id",
        (NIST_800_53_FW_ID,),
    )
    return dict(cur.fetchall())


def load_scf_control_metadata(
    conn: sqlite3.Connection,
) -> dict[str, dict]:
    """Load SCF control metadata for all controls."""
    cur = conn.cursor()
    cur.execute(
        "SELECT scf_id, scf_domain, control_name, description, control_question, "
        "relative_weighting, csf_function FROM controls"
    )
    controls = {}
    for row in cur.fetchall():
        controls[row[0]] = {
            "scfId": row[0],
            "domain": row[1],
            "controlName": row[2],
            "description": row[3],
            "controlQuestion": row[4],
            "relativeWeighting": row[5],
            "csfFunction": row[6],
        }
    return controls


def find_scf_matches(
    nist_ids: list[str],
    nist_to_scf: dict[str, list[str]],
    scf_specificity: dict[str, int],
) -> tuple[str | None, list[str], list[str], list[str]]:
    """Find SCF controls matching the given NIST 800-53 IDs.

    Returns (primary_scf_id, additional_scf_ids, matched_nist_ids, unmatched_nist_ids).
    Primary is selected as the most specific SCF control (fewest total NIST mappings).
    """
    matched_nist = []
    unmatched_nist = []
    candidate_scf_ids: set[str] = set()

    for nist_id in nist_ids:
        scf_ids = nist_to_scf.get(nist_id, [])
        if scf_ids:
            candidate_scf_ids.update(scf_ids)
            matched_nist.append(nist_id)
        else:
            # Try base control without enhancement (AC-6.5 → AC-6)
            base = re.sub(r"\.\d+$", "", nist_id)
            scf_ids = nist_to_scf.get(base, [])
            if scf_ids:
                candidate_scf_ids.update(scf_ids)
                matched_nist.append(nist_id)
            else:
                unmatched_nist.append(nist_id)

    if not candidate_scf_ids:
        return None, [], matched_nist, unmatched_nist

    # Rank by specificity: fewer NIST mappings = more specific
    ranked = sorted(candidate_scf_ids, key=lambda s: scf_specificity.get(s, 999))
    primary = ranked[0]
    additional = ranked[1:]

    return primary, additional, matched_nist, unmatched_nist


def main():
    parser = argparse.ArgumentParser(description="Map CheckID checks to SCF controls")
    parser.add_argument(
        "--scf-db",
        default="C:/git/SecFrame/SCF/scf.db",
        help="Path to the SCF SQLite database",
    )
    parser.add_argument(
        "--registry",
        default=str(REPO_ROOT / "data" / "registry.json"),
        help="Path to current registry.json",
    )
    parser.add_argument(
        "--output-mapping",
        default=str(REPO_ROOT / "data" / "scf-check-mapping.json"),
        help="Output path for the SCF check mapping JSON",
    )
    parser.add_argument(
        "--output-review",
        default=str(REPO_ROOT / "data" / "scf-migration-review.csv"),
        help="Output path for the human review CSV",
    )
    args = parser.parse_args()

    # Load registry
    print(f"Loading registry from {args.registry}")
    with open(args.registry, "r", encoding="utf-8") as f:
        registry = json.load(f)
    checks = registry["checks"]
    print(f"  Found {len(checks)} checks")

    # Connect to SCF database
    print(f"Connecting to SCF database at {args.scf_db}")
    conn = sqlite3.connect(args.scf_db)

    # Build indexes
    print("Building NIST 800-53 → SCF index...")
    nist_to_scf = build_nist_to_scf_index(conn)
    print(f"  {len(nist_to_scf)} unique NIST control IDs mapped to SCF")

    print("Computing SCF control specificity...")
    scf_specificity = build_scf_specificity(conn)

    print("Loading SCF control metadata...")
    scf_metadata = load_scf_control_metadata(conn)
    print(f"  {len(scf_metadata)} SCF controls loaded")

    # Process each check
    mapping_checks = []
    review_rows = []
    stats = {"matched": 0, "partial": 0, "unmatched": 0}

    for check in checks:
        check_id = check["checkId"]
        name = check["name"]
        category = check["category"]
        collector = check["collector"]
        has_automated = check.get("hasAutomatedCheck", False)
        licensing = check.get("licensing", {}).get("minimum", "E3")
        impact = check.get("impactRating", {})
        impact_severity = impact.get("severity", "")
        impact_rationale = impact.get("rationale", "")

        # Extract NIST 800-53 IDs
        nist_fw = check.get("frameworks", {}).get("nist-800-53", {})
        nist_raw = nist_fw.get("controlId", "")
        nist_ids = parse_nist_ids(nist_raw)

        # Extract CIS M365 data (manual carry-forward)
        cis_fw = check.get("frameworks", {}).get("cis-m365-v6", {})
        cis_control_id = cis_fw.get("controlId", "")
        cis_profiles = cis_fw.get("profiles", [])

        # Extract CISA ScuBA data (manual carry-forward)
        scuba_fw = check.get("frameworks", {}).get("cisa-scuba", {})
        scuba_control_id = scuba_fw.get("controlId", "")

        # Extract STIG data (manual carry-forward)
        stig_fw = check.get("frameworks", {}).get("stig", {})
        stig_control_id = stig_fw.get("controlId", "")

        # Find SCF matches
        primary, additional, matched_nist, unmatched_nist = find_scf_matches(
            nist_ids, nist_to_scf, scf_specificity
        )

        # Determine match quality
        if primary and not unmatched_nist:
            match_quality = "FULL"
            stats["matched"] += 1
        elif primary:
            match_quality = "PARTIAL"
            stats["partial"] += 1
        else:
            match_quality = "NONE"
            stats["unmatched"] += 1

        # Get SCF metadata for primary control
        scf_meta = scf_metadata.get(primary, {}) if primary else {}

        # Build mapping entry
        mapping_entry = {
            "checkId": check_id,
            "name": name,
            "category": category,
            "collector": collector,
            "hasAutomatedCheck": has_automated,
            "licensing": licensing,
            "scfPrimary": primary or "",
            "scfAdditional": additional[:5],  # Cap at 5 additional for sanity
            "impactSeverity": impact_severity,
            "impactRationale": impact_rationale,
        }

        # Add manual carry-forward fields for frameworks not in SCF
        if cis_control_id:
            mapping_entry["cisM365ControlId"] = cis_control_id
            mapping_entry["cisM365Profiles"] = cis_profiles
        if scuba_control_id:
            mapping_entry["cisaScubaControlId"] = scuba_control_id
        if stig_control_id:
            mapping_entry["stigControlId"] = stig_control_id

        mapping_checks.append(mapping_entry)

        # Build review row
        review_rows.append(
            {
                "checkId": check_id,
                "name": name,
                "category": category,
                "collector": collector,
                "nist80053": nist_raw,
                "matchQuality": match_quality,
                "autoScfPrimary": primary or "",
                "autoScfDomain": scf_meta.get("domain", ""),
                "autoScfControlName": (scf_meta.get("controlName", ""))[:120],
                "autoScfWeighting": scf_meta.get("relativeWeighting", ""),
                "autoScfAdditional": ";".join(additional[:5]),
                "unmatchedNist": ";".join(unmatched_nist),
                "manualOverridePrimary": "",
                "manualOverrideAdditional": "",
                "reviewNotes": "",
            }
        )

    # Write scf-check-mapping.json
    mapping_output = {
        "version": "1.0.0",
        "description": "Maps CheckID checks to SCF controls. Source of truth for Build-Registry.ps1.",
        "generatedBy": "Build-ScfMigration.py (one-time migration from registry.json v1.1.0)",
        "scfVersion": "2025.4",
        "checks": mapping_checks,
    }

    print(f"\nWriting {args.output_mapping}")
    with open(args.output_mapping, "w", encoding="utf-8", newline="\n") as f:
        json.dump(mapping_output, f, indent=2, ensure_ascii=False)
        f.write("\n")

    # Write review CSV
    print(f"Writing {args.output_review}")
    fieldnames = [
        "checkId",
        "name",
        "category",
        "collector",
        "nist80053",
        "matchQuality",
        "autoScfPrimary",
        "autoScfDomain",
        "autoScfControlName",
        "autoScfWeighting",
        "autoScfAdditional",
        "unmatchedNist",
        "manualOverridePrimary",
        "manualOverrideAdditional",
        "reviewNotes",
    ]
    with open(args.output_review, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(review_rows)

    # Summary
    print(f"\n{'='*60}")
    print(f"Migration Summary")
    print(f"{'='*60}")
    print(f"Total checks:        {len(checks)}")
    print(f"Full SCF match:      {stats['matched']}")
    print(f"Partial SCF match:   {stats['partial']}")
    print(f"No SCF match:        {stats['unmatched']}")
    print(f"{'='*60}")

    if stats["unmatched"] > 0:
        print("\nChecks with NO SCF match (need manual assignment):")
        for row in review_rows:
            if row["matchQuality"] == "NONE":
                print(f"  {row['checkId']:30s} {row['name'][:60]}")

    if stats["partial"] > 0:
        print(f"\nChecks with PARTIAL match ({stats['partial']} total) — some NIST IDs had no SCF mapping.")
        print("These still got a primary SCF control from the IDs that did match.")

    conn.close()
    print("\nDone. Review the CSV in Excel, then update scf-check-mapping.json.")


if __name__ == "__main__":
    main()
