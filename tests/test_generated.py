"""Checks on the generated stm32h7xx crates themselves; no board needed.

 - Every hand-written source of the family (``stm32h7_src/**/*.ads|adb|S``, templates excluded) is present
   in at least one generated crate, and the installed copy is byte-identical to the family's. Presence alone
   is not enough: a family file that the generator never registers can be shadowed by a same-named file from
   another family's directory, which is how the H7's ``s-bbbosu.adb`` once went missing from the crates.
 - The crate manifests carry the repository's maintainer identity, taken from the stm32g4xx template, so the
   crates can be published from the upstream repository's index account.
 - The light-tasking crate carries the stack-checking unit that ``patch-runtime.py`` adds for the family.

Run with ``pytest test_generated.py`` from ``tests/`` after ``../generate-runtimes.sh --target stm32h7xx``.
"""
import pathlib
import re

import pytest

REPO = pathlib.Path(__file__).resolve().parent.parent
INSTALL = REPO / "install"
FAMILY = REPO / "stm32h7_src"
SIBLING_TEMPLATE = REPO / "stm32g4_src" / "templates" / "alire.toml.in"
PROFILES = ["light", "light-tasking", "embedded"]


def crate(profile: str) -> pathlib.Path:
    return INSTALL / f"{profile}-stm32h7xx"


def installed():
    return [crate(p) for p in PROFILES if crate(p).is_dir()]


pytestmark = pytest.mark.skipif(not installed(), reason="stm32h7xx runtimes are not generated in install/")


def family_sources():
    for p in sorted(FAMILY.rglob("*")):
        if p.is_file() and p.suffix in (".ads", ".adb", ".S") and "templates" not in p.parts:
            yield p


def normalised(path: pathlib.Path) -> bytes:
    return path.read_bytes().replace(b"\r\n", b"\n")


# The family's tasking units live in the two tasking crates only; every other family file is in all three.
# A file missing from one profile's crate links the sibling family's copy or nothing - this is where it shows.
TASKING_ONLY = {'s-bbbosu.adb', 'a-intnam.ads', 's-bbcppr.adb'}


@pytest.mark.parametrize("src", list(family_sources()), ids=lambda p: "stm32h7xx:" + str(p.relative_to(FAMILY)).replace("\\", "/"))
def test_family_source_is_installed_unchanged(src: pathlib.Path):
    copies = [f for c in installed() for f in c.rglob(src.name) if f.is_file()]
    assert copies, f"{src.relative_to(FAMILY)} is in no generated crate"
    expected = {"light-tasking", "embedded"} if src.name in TASKING_ONLY else {"light", "light-tasking", "embedded"}
    present = {f.relative_to(INSTALL).parts[0].rsplit("-stm32h7xx", 1)[0] for f in copies}
    assert expected <= present, f"{src.relative_to(FAMILY)} is missing from {sorted(expected - present)}"
    wrong = [f for f in copies if normalised(f) != normalised(src)]
    assert not wrong, (
        f"{src.relative_to(FAMILY)}: the installed copy differs from the family's in "
        + ", ".join(str(f.relative_to(INSTALL)) for f in wrong)
        + " (another family's file of the same name, or the generator patched it)"
    )


def manifest_field(text: str, field: str) -> str:
    m = re.search(rf"^{field}\s*=\s*(.+)$", text, re.MULTILINE)
    assert m, f"{field} missing"
    return m.group(1).strip()


@pytest.mark.parametrize("field", ["maintainers", "maintainers-logins", "website"])
@pytest.mark.parametrize("profile", PROFILES, ids=[f"{p}-stm32h7xx" for p in PROFILES])
def test_manifest_identity_matches_sibling_family(profile: str, field: str):
    if not crate(profile).is_dir():
        pytest.skip(f"{profile} crate not generated")
    expected = manifest_field(SIBLING_TEMPLATE.read_text(encoding="utf-8"), field)
    actual = manifest_field((crate(profile) / "alire.toml").read_text(encoding="utf-8"), field)
    assert actual == expected, f"{profile}: {field} = {actual}, the sibling family has {expected}"


def test_light_tasking_stm32h7xx_has_stack_checking_unit():
    if not crate("light-tasking").is_dir():
        pytest.skip("light-tasking crate not generated")
    for unit in ("s-btstch.ads", "s-btstch.adb"):
        assert list(crate("light-tasking").rglob(unit)), f"{unit} missing from the light-tasking crate"
