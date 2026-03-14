#!/usr/bin/env python3
"""Derive new framework mappings from the SCF database.

Uses CheckID's existing NIST 800-53 control IDs as a bridge through the
SCF database to produce transitive mappings for additional frameworks.

Pipeline: CheckID check → NIST 800-53 IDs → SCF controls → Target framework

Usage:
    python scripts/Build-DerivedMappings.py
    python scripts/Build-DerivedMappings.py --secframe C:/git/SecFrame --output data/derived-mappings.json
"""
import argparse
import io
import json
import re
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path

if sys.stdout.encoding != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent

# Target frameworks with their SCF database framework IDs
TARGET_FRAMEWORKS = {
    "fedramp": {
        "framework_id": 118,  # US FedRAMP R5
        "display_name": "FedRAMP Rev 5",
    },
    "gdpr": {
        "framework_id": 175,  # EMEA EU GDPR
        "display_name": "EU GDPR",
    },
    "essential-eight": {
        "framework_id": 219,  # APAC Australia Essential 8
        "display_name": "Essential Eight",
    },
    "cis-controls-v8": {
        "framework_id": 4,  # CIS CSC 8.1
        "display_name": "CIS Controls v8.1",
    },
    "mitre-attack": {
        "framework_id": 33,  # MITRE ATT&CK 10
        "display_name": "MITRE ATT&CK v10",
    },
}

# NIST 800-53 framework ID in the SCF database
NIST_800_53_FW_ID = 103  # NIST 800-53 R5


def normalize_nist_id(control_id: str) -> str:
    """Normalize NIST 800-53 control ID for matching.

    Converts parenthesized enhancement notation to dot notation
    and uppercases for consistency with SCF.
    """
    cid = control_id.strip().upper()
    # AC-6(5) → AC-6.5 (but SCF might use parenthesized form too)
    return cid


def build_scf_bridge(db_path: Path) -> tuple[dict, dict]:
    """Build SCF-based mapping tables.

    Returns:
        nist_to_scf: dict mapping NIST 800-53 control ID → set of SCF control IDs
        scf_to_targets: dict mapping (framework_key, scf_id) → framework control ID
    """
    conn = sqlite3.connect(str(db_path))

    # First, find the correct NIST 800-53 R5 framework_id
    nist_fw = conn.execute(
        "SELECT framework_id, name FROM frameworks WHERE name LIKE '%NIST 800-53 R5%'"
    ).fetchall()
    if not nist_fw:
        # Fallback: try broader search
        nist_fw = conn.execute(
            "SELECT framework_id, name FROM frameworks WHERE name LIKE '%NIST SP 800-53%' AND name LIKE '%R5%'"
        ).fetchall()

    print(f"  NIST 800-53 R5 frameworks found: {nist_fw}")
    nist_fw_id = nist_fw[0][0] if nist_fw else NIST_800_53_FW_ID

    # NIST 800-53 control → SCF controls
    nist_to_scf: dict[str, set[str]] = defaultdict(set)
    rows = conn.execute(
        "SELECT scf_id, framework_control_id FROM control_mappings WHERE framework_id = ?",
        (nist_fw_id,),
    ).fetchall()
    for scf_id, nist_ctrl in rows:
        nist_to_scf[nist_ctrl.strip().upper()].add(scf_id)
    print(f"  NIST → SCF bridge: {len(rows)} mappings, {len(nist_to_scf)} unique NIST IDs")

    # SCF controls → target framework controls
    scf_to_targets: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))
    for fw_key, fw_info in TARGET_FRAMEWORKS.items():
        fw_id = fw_info["framework_id"]
        rows = conn.execute(
            "SELECT scf_id, framework_control_id FROM control_mappings WHERE framework_id = ?",
            (fw_id,),
        ).fetchall()
        for scf_id, target_ctrl in rows:
            scf_to_targets[scf_id][fw_key].append(target_ctrl.strip())
        print(f"  SCF → {fw_key}: {len(rows)} mappings")

    conn.close()
    return dict(nist_to_scf), dict(scf_to_targets)


def derive_mappings(
    registry_path: Path,
    nist_to_scf: dict[str, set[str]],
    scf_to_targets: dict[str, dict[str, list[str]]],
) -> dict:
    """Derive new framework mappings for each check in the registry."""
    with open(registry_path, encoding="utf-8") as f:
        registry = json.load(f)

    results = {}
    stats = defaultdict(int)

    for check in registry["checks"]:
        check_id = check["checkId"]
        frameworks = check.get("frameworks", {})

        # Get NIST 800-53 control IDs for this check
        nist_entry = frameworks.get("nist-800-53")
        if not nist_entry:
            continue

        nist_ids = [cid.strip() for cid in nist_entry["controlId"].split(";")]

        # Find all SCF controls that map to these NIST IDs
        scf_controls = set()
        for nist_id in nist_ids:
            normalized = normalize_nist_id(nist_id)
            if normalized in nist_to_scf:
                scf_controls.update(nist_to_scf[normalized])
            # Also try without enhancement: AC-6(5) → AC-6
            base = re.sub(r'\(\d+\)$', '', normalized)
            if base != normalized and base in nist_to_scf:
                scf_controls.update(nist_to_scf[base])

        if not scf_controls:
            continue

        # Collect target framework control IDs through SCF bridge
        check_mappings = {}
        for scf_id in scf_controls:
            if scf_id not in scf_to_targets:
                continue
            for fw_key, ctrl_ids in scf_to_targets[scf_id].items():
                if fw_key not in check_mappings:
                    check_mappings[fw_key] = set()
                check_mappings[fw_key].update(ctrl_ids)

        # Convert sets to sorted semicolon-joined strings
        if check_mappings:
            entry = {}
            for fw_key in sorted(check_mappings.keys()):
                ctrl_list = sorted(check_mappings[fw_key])
                # Limit MITRE ATT&CK to avoid explosion (keep first 10)
                if fw_key == "mitre-attack" and len(ctrl_list) > 10:
                    ctrl_list = ctrl_list[:10]
                entry[fw_key] = ";".join(ctrl_list)
                stats[fw_key] += 1
            results[check_id] = entry

    return results, dict(stats)


def main():
    parser = argparse.ArgumentParser(description="Derive framework mappings from SCF")
    parser.add_argument(
        "--secframe",
        type=Path,
        default=Path("C:/git/SecFrame"),
        help="Path to SecFrame repository",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=REPO_ROOT / "data" / "derived-mappings.json",
        help="Output JSON path",
    )
    args = parser.parse_args()

    db_path = args.secframe / "SCF" / "scf.db"
    registry_path = REPO_ROOT / "data" / "registry.json"

    if not db_path.exists():
        print(f"ERROR: SCF database not found at {db_path}")
        sys.exit(1)

    print("Building derived framework mappings from SCF database...")
    print(f"  Database: {db_path}")

    # Build the bridge tables
    nist_to_scf, scf_to_targets = build_scf_bridge(db_path)

    # Derive mappings for each check
    mappings, stats = derive_mappings(registry_path, nist_to_scf, scf_to_targets)

    # Write output
    output = {
        "description": "Derived framework mappings via SCF transitive bridge (NIST 800-53 → SCF → Target)",
        "source": "SecFrame SCF database",
        "frameworks": {
            k: {"displayName": v["display_name"]} for k, v in TARGET_FRAMEWORKS.items()
        },
        "mappings": mappings,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\nWritten to {args.output}")
    print(f"Checks with derived mappings: {len(mappings)}")
    print("Coverage per framework:")
    for fw_key, count in sorted(stats.items()):
        print(f"  {fw_key}: {count} checks")


if __name__ == "__main__":
    main()
