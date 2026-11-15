"""Board-less checks of the generated stm32h7xx crates against the family's sources, and of the upstream files
the family's copies derive from.

Run from tests/ with ``pytest test_generated.py`` after ``../generate-runtimes.sh --target stm32h7xx``.
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
    return [crate(p) for p in PROFILES]


# Only a tree with no generated runtimes at all skips. A generator that stops producing a stm32h7xx crate
# fails here instead of turning every check into a skip.
pytestmark = pytest.mark.skipif(not INSTALL.is_dir(), reason="no runtimes generated in install/")


@pytest.mark.parametrize("profile", PROFILES, ids=[f"{p}-stm32h7xx" for p in PROFILES])
def test_crate_is_generated(profile: str):
    assert crate(profile).is_dir(), f"the generator did not produce {crate(profile).name}"


def family_sources():
    for p in sorted(FAMILY.rglob("*")):
        if p.is_file() and p.suffix in (".ads", ".adb", ".S") and "templates" not in p.parts:
            yield p


def normalised(path: pathlib.Path) -> bytes:
    return path.read_bytes().replace(b"\r\n", b"\n")


@pytest.mark.parametrize("script", sorted(p.relative_to(FAMILY / "ld").as_posix() for p in (FAMILY / "ld").rglob("*.ld")),
                         ids=lambda s: "stm32h7xx:ld/" + s)
def test_family_linker_script_is_installed_unchanged(script: str):
    """Each linker script is installed unchanged in every generated crate. The scripts are matched by their
    path under ld/, since three of them share the name memory-ROM.ld."""
    src = FAMILY / "ld" / script
    for c in installed():
        copy = c / "ld" / script
        assert copy.is_file(), f"ld/{script} is missing from {c.name}"
        assert normalised(copy) == normalised(src), f"ld/{script}: the copy in {c.name} differs from the family's"


# The family's tasking units are only in the two tasking crates; every other family file is in all three.
# A file missing from one profile's crate links the sibling family's copy, or nothing, and this is where it shows.
TASKING_ONLY = {'a-intnam.ads', 's-bbcppr.adb', 's-bcpcst.adb'}


@pytest.mark.parametrize("src", list(family_sources()), ids=lambda p: "stm32h7xx:" + str(p.relative_to(FAMILY)).replace("\\", "/"))
def test_family_source_is_installed_unchanged(src: pathlib.Path):
    """Every hand-written source of the family (``stm32h7_src/**/*.ads|adb|S``, templates excluded) is in the
    crates of the profiles that use it, byte for byte. Presence alone is not enough: a family file that the
    generator never registers can be shadowed by a same-named file from another family's directory."""
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
    """The crate manifests carry the repository's maintainer identity, taken from the stm32g4xx template, so
    that the crates can be published from the upstream repository's index account."""
    expected = manifest_field(SIBLING_TEMPLATE.read_text(encoding="utf-8"), field)
    actual = manifest_field((crate(profile) / "alire.toml").read_text(encoding="utf-8"), field)
    assert actual == expected, f"{profile}: {field} = {actual}, the sibling family has {expected}"


def test_light_tasking_stm32h7xx_has_stack_checking_unit():
    """The light-tasking crate has the stack-checking unit that ``patch-runtime.py`` adds for the family."""
    for unit in ("s-btstch.ads", "s-btstch.adb"):
        assert list(crate("light-tasking").rglob(unit)), f"{unit} missing from the light-tasking crate"


# The addresses and sizes the three flash maps and the RAM map must carry (RM0468 Table 6, DS13313 and DS13311):
# flash 128 KB on the H730, 512 KB on the E parts, 1 MB on the G parts; DTCM and AXI SRAM at the default TCM
# sharing; SRAM1 and SRAM2, contiguous, as one region.
MEMORY_REGIONS = {
    "ld/flash-128/memory-ROM.ld": {"flash": (0x0800_0000, "128K")},
    "ld/flash-512/memory-ROM.ld": {"flash": (0x0800_0000, "512K")},
    "ld/flash-1024/memory-ROM.ld": {"flash": (0x0800_0000, "1024K")},
    "ld/ram-h72x/memory-RAM.ld": {"itcm": (0x0000_0000, "64K"), "dtcm": (0x2000_0000, "128K"),
                                  "axisram": (0x2400_0000, "320K"), "sram12": (0x3000_0000, "32K"),
                                  "sram4": (0x3800_0000, "16K")},
}


@pytest.mark.parametrize("crate_dir", installed(), ids=lambda p: p.name)
@pytest.mark.parametrize("script", sorted(MEMORY_REGIONS), ids=lambda s: "stm32h7xx:" + s)
def test_memory_maps_carry_the_parts_sizes(crate_dir: pathlib.Path, script: str):
    text = (crate_dir / script).read_text(encoding="utf-8")
    for region, (origin, length) in MEMORY_REGIONS[script].items():
        m = re.search(r"^\s*" + region + r"\s*\([a-z!]+\)\s*:\s*ORIGIN\s*=\s*(0x[0-9A-Fa-f]+)\s*,\s*LENGTH\s*=\s*(\S+)",
                      text, re.M)
        assert m, f"{script}: no {region} region"
        assert int(m.group(1), 16) == origin, f"{script}: {region} ORIGIN = {m.group(1)}, expected {origin:#x}"
        assert m.group(2) == length, f"{script}: {region} LENGTH = {m.group(2)}, expected {length}"


# Digests of the upstream originals of the family's copies, as they were when the copies were last compared
# with them: the bb-runtimes submodule at v16.1.0-1 (d7ab8df) and this repository's stm32g4xx linker scripts.
UPSTREAM_ORIGINALS = {
    "bb-runtimes/src/s-bbcppr__armv7m.adb":
        ("stm32h7_src/s-bbcppr.adb", "569b386ca25cc8acdde224258caf55331379def0dd89b140c2a34d77a169b057"),
    "bb-runtimes/src/s-bcpcst__pendsv.adb":
        ("stm32h7_src/s-bcpcst.adb", "39cc4cab32808b2c62fe5944b36ca3e201702f82d4fabbdf05908d5c49ef9f87"),
    "bb-runtimes/arm/stm32/start-common.S":
        ("stm32h7_src/start-common.S", "bd03e512ce07793053dad19d01f7e84790a8af403f8a4f52f60502b709cd3711"),
    # These two are linked as they are, not copied. The family's start-common.S follows their entry and
    # register use, and its linker scripts' ASSERTs encode their copy loops (the symbols and the 16-bit word
    # counts).
    "bb-runtimes/arm/stm32/start-rom.S":
        ("stm32h7_src/start-common.S and the ASSERTs in stm32h7_src/ld",
         "3a04f80cd8aaeaeceb768a88166878847de9657c9e531f0cabf7b18e522c909e"),
    "bb-runtimes/arm/stm32/start-ram.S":
        ("stm32h7_src/start-common.S and the ASSERTs in stm32h7_src/ld",
         "99f9ee007af54cd9795c467471850dd39884d48bce6ca312f1f67fe9c549b45b"),
    "stm32g4_src/ld/common-ROM.ld":
        ("stm32h7_src/ld/common-ROM.ld", "1bc68e64a78012dc3e1c5425db7ef75270ecbf916b639c661061a8462f3738e7"),
    "stm32g4_src/ld/common-RAM.ld":
        ("stm32h7_src/ld/common-RAM.ld", "2e6ba130a2ee56139bc603c417ca2c2106971b2e8ce81a49bea72c6827761dbe"),
}


@pytest.mark.parametrize("original", sorted(UPSTREAM_ORIGINALS), ids=lambda o: "stm32h7xx:" + o)
def test_upstream_original_unchanged(original):
    import hashlib
    path = REPO / original
    if not path.is_file():
        pytest.skip(f"{original} not checked out (the bb-runtimes submodule?)")
    copy, expected = UPSTREAM_ORIGINALS[original]
    # The digests are of the files as git stores them (LF); a checkout may have CRLF (core.autocrlf on Windows)
    digest = hashlib.sha256(normalised(path)).hexdigest()
    assert digest == expected, (
        f"{original} changed upstream: compare {copy} with it, then update UPSTREAM_ORIGINALS")
