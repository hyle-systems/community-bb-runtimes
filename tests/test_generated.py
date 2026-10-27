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
TASKING_ONLY = {'a-intnam.ads', 's-bbcppr.adb', 's-bcpcst.adb'}


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


# The three flash maps and the RAM map carry the parts' addresses and sizes (RM0468 Table 6, DS13313 / DS13311:
# 128 KB on the H730, 512 KB on the E parts, 1 MB on the G parts; the DTCM 128 KB and the AXI SRAM 320 KB at the
# default TCM sharing; SRAM1 + SRAM2 contiguous as one 32 KB region; SRAM4 16 KB).
MEMORY_REGIONS = {
    "ld/flash-128/memory-ROM.ld": {"flash": (0x0800_0000, "128K")},
    "ld/flash-512/memory-ROM.ld": {"flash": (0x0800_0000, "512K")},
    "ld/flash-1024/memory-ROM.ld": {"flash": (0x0800_0000, "1024K")},
    "ld/ram-h72x/memory-RAM.ld": {"itcm": (0x0000_0000, "64K"), "dtcm": (0x2000_0000, "128K"),
                                  "axisram": (0x2400_0000, "320K"), "sram12": (0x3000_0000, "32K"),
                                  "sram4": (0x3800_0000, "16K")},
}


@pytest.mark.parametrize("crate_dir", installed(), ids=lambda p: p.name)
@pytest.mark.parametrize("script", sorted(MEMORY_REGIONS))
def test_memory_maps_carry_the_parts_sizes(crate_dir: pathlib.Path, script: str):
    text = (crate_dir / script).read_text(encoding="utf-8")
    for region, (origin, length) in MEMORY_REGIONS[script].items():
        m = re.search(r"^\s*" + region + r"\s*\([a-z!]+\)\s*:\s*ORIGIN\s*=\s*(0x[0-9A-Fa-f]+)\s*,\s*LENGTH\s*=\s*(\S+)",
                      text, re.M)
        assert m, f"{script}: no {region} region"
        assert int(m.group(1), 16) == origin, f"{script}: {region} ORIGIN = {m.group(1)}, expected {origin:#x}"
        assert m.group(2) == length, f"{script}: {region} LENGTH = {m.group(2)}, expected {length}"

# The upstream originals of the family's copies, as the copies were last compared with them: the bb-runtimes
# submodule at v16.1.0-1 (d7ab8df) and this repository's stm32g4xx scripts. A change to one of them means the
# family's copy must be compared with the new original and this table updated.
UPSTREAM_ORIGINALS = {
    "bb-runtimes/src/s-bbcppr__armv7m.adb":
        ("stm32h7_src/s-bbcppr.adb", "569b386ca25cc8acdde224258caf55331379def0dd89b140c2a34d77a169b057"),
    "bb-runtimes/src/s-bcpcst__pendsv.adb":
        ("stm32h7_src/s-bcpcst.adb", "39cc4cab32808b2c62fe5944b36ca3e201702f82d4fabbdf05908d5c49ef9f87"),
    "bb-runtimes/arm/stm32/start-common.S":
        ("stm32h7_src/start-common.S", "ae729f53b777e2db68f7b835fc6be09975ddc3b8544a26c8a1665c2bc66b6468"),
    "stm32g4_src/ld/common-ROM.ld":
        ("stm32h7_src/ld/common-ROM.ld", "1bc68e64a78012dc3e1c5425db7ef75270ecbf916b639c661061a8462f3738e7"),
    "stm32g4_src/ld/common-RAM.ld":
        ("stm32h7_src/ld/common-RAM.ld", "2e6ba130a2ee56139bc603c417ca2c2106971b2e8ce81a49bea72c6827761dbe"),
}


@pytest.mark.parametrize("original", sorted(UPSTREAM_ORIGINALS))
def test_upstream_original_unchanged(original):
    import hashlib
    path = REPO / original
    if not path.is_file():
        pytest.skip(f"{original} not checked out (the bb-runtimes submodule?)")
    copy, expected = UPSTREAM_ORIGINALS[original]
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest == expected, (
        f"{original} changed upstream: compare {copy} with it, then update UPSTREAM_ORIGINALS")
