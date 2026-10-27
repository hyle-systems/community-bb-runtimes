"""Board-less check of the source_dirs hook's default: a testcase without it
has no additional source directories - an empty list, as the annotation
says.

Run with ``pytest test_harness_source_dirs.py`` from ``tests/``; no board, no
toolchain needed.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from support.harnesses import TestHarness   # noqa: E402
from support.target_info import TargetInfo  # noqa: E402

TESTS = pathlib.Path(__file__).resolve().parent
HELLO = TESTS / "testcases" / "hello_world"
NL = chr(10)


def test_source_dirs_default_is_an_empty_list(tmp_path):
    crate = tmp_path / "light-tasking-nrf52832"
    crate.mkdir()
    (crate / "alire.toml").write_text('name = "light_tasking_nrf52832"' + NL, encoding="utf-8")
    harness = TestHarness(HELLO, tmp_path / "wd", TargetInfo(crate, {}))
    assert harness.source_dirs() == []
