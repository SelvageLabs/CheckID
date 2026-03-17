"""Tests for the CheckID Python client."""

import pathlib
import pytest

# Locate registry.json relative to this file
_REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent.parent
_REGISTRY_PATH = _REPO_ROOT / "data" / "registry.json"

from checkid import CheckIDRegistry


@pytest.fixture(scope="module")
def reg() -> CheckIDRegistry:
    return CheckIDRegistry(registry_path=_REGISTRY_PATH)


# ---------------------------------------------------------------------------
# Basic loading
# ---------------------------------------------------------------------------

class TestRegistryLoading:
    def test_loads_at_least_233_checks(self, reg):
        assert len(reg) >= 233

    def test_schema_version_is_semver(self, reg):
        import re
        assert re.match(r"^\d+\.\d+\.\d+$", reg.schema_version)

    def test_data_version_is_date(self, reg):
        import re
        assert re.match(r"^\d{4}-\d{2}-\d{2}$", reg.data_version)

    def test_repr_contains_check_count(self, reg):
        assert "checks=" in repr(reg)

    def test_custom_path_loads_same_data(self):
        reg2 = CheckIDRegistry(registry_path=_REGISTRY_PATH)
        assert len(reg2) >= 233


# ---------------------------------------------------------------------------
# get_by_id
# ---------------------------------------------------------------------------

class TestGetById:
    def test_returns_check_for_known_id(self, reg):
        check = reg.get_by_id("ENTRA-ADMIN-001")
        assert check is not None
        assert check["checkId"] == "ENTRA-ADMIN-001"

    def test_returns_none_for_unknown_id(self, reg):
        assert reg.get_by_id("DOES-NOT-EXIST-999") is None

    def test_returned_check_has_frameworks(self, reg):
        check = reg.get_by_id("ENTRA-ADMIN-001")
        assert "frameworks" in check
        assert isinstance(check["frameworks"], dict)

    def test_returned_check_has_name(self, reg):
        check = reg.get_by_id("ENTRA-ADMIN-001")
        assert check["name"]


# ---------------------------------------------------------------------------
# search
# ---------------------------------------------------------------------------

class TestSearch:
    def test_search_by_framework_returns_results(self, reg):
        results = reg.search(framework="stig")
        assert len(results) > 0

    def test_search_by_framework_all_have_that_framework(self, reg):
        results = reg.search(framework="hipaa")
        assert all("hipaa" in r["frameworks"] for r in results)

    def test_search_by_keyword_case_insensitive(self, reg):
        upper = reg.search(keyword="MFA")
        lower = reg.search(keyword="mfa")
        assert len(upper) == len(lower)
        assert len(upper) > 0

    def test_search_by_keyword_all_match_name(self, reg):
        results = reg.search(keyword="MFA")
        assert all("mfa" in r["name"].lower() for r in results)

    def test_search_by_control_id_returns_results(self, reg):
        results = reg.search(control_id="AC-6")
        assert len(results) > 0

    def test_search_control_id_scoped_to_framework(self, reg):
        results = reg.search(framework="nist-800-53", control_id="AC-6")
        assert len(results) > 0
        for r in results:
            assert "nist-800-53" in r["frameworks"]
            assert "AC-6" in r["frameworks"]["nist-800-53"]["controlId"]

    def test_search_combined_framework_and_keyword(self, reg):
        results = reg.search(framework="hipaa", keyword="password")
        assert len(results) > 0
        for r in results:
            assert "hipaa" in r["frameworks"]
            assert "password" in r["name"].lower()

    def test_search_no_criteria_returns_all(self, reg):
        results = reg.search()
        assert len(results) == len(reg)

    def test_search_no_match_returns_empty(self, reg):
        results = reg.search(keyword="ZZZZZNOMATCH99999")
        assert results == []


# ---------------------------------------------------------------------------
# framework_coverage
# ---------------------------------------------------------------------------

class TestFrameworkCoverage:
    def test_returns_at_least_14_entries(self, reg):
        cov = reg.framework_coverage()
        assert len(cov) >= 14

    def test_every_entry_has_required_keys(self, reg):
        for entry in reg.framework_coverage():
            assert "framework_key" in entry
            assert "check_count" in entry
            assert "automated_count" in entry
            assert "manual_count" in entry

    def test_automated_plus_manual_equals_total(self, reg):
        for entry in reg.framework_coverage():
            assert entry["automated_count"] + entry["manual_count"] == entry["check_count"], (
                f"{entry['framework_key']}: automated + manual != check_count"
            )

    def test_known_frameworks_have_positive_count(self, reg):
        known = {
            "cis-m365-v6", "nist-800-53", "nist-csf", "iso-27001", "stig",
            "pci-dss", "cmmc", "hipaa", "cisa-scuba", "soc2",
            "fedramp", "cis-controls-v8", "essential-eight", "mitre-attack",
        }
        by_key = {e["framework_key"]: e for e in reg.framework_coverage()}
        for fw in known:
            assert fw in by_key, f"Framework '{fw}' missing from coverage"
            assert by_key[fw]["check_count"] > 0, f"Framework '{fw}' has zero checks"

    def test_superseded_checks_excluded(self, reg):
        active_count = sum(1 for c in reg.checks if "supersededBy" not in c)
        for entry in reg.framework_coverage():
            assert entry["check_count"] <= active_count, (
                f"{entry['framework_key']} check_count ({entry['check_count']}) "
                f"exceeds active check count ({active_count})"
            )

    def test_results_sorted_alphabetically(self, reg):
        keys = [e["framework_key"] for e in reg.framework_coverage()]
        assert keys == sorted(keys)


# ---------------------------------------------------------------------------
# Iteration
# ---------------------------------------------------------------------------

class TestIteration:
    def test_iteration_yields_all_checks(self, reg):
        count = sum(1 for _ in reg)
        assert count == len(reg)

    def test_checks_property_matches_iteration(self, reg):
        assert len(reg.checks) == len(reg)
