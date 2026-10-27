"""Board-less check of the opt.py io_timeout hook: a testcase may ask for a
longer wait for its output than the harness's 5 s.

Run with ``pytest test_harness_io_timeout.py`` from ``tests/``; no board, no
toolchain needed.
"""
import pathlib
import shutil
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from support.harnesses import TestHarness   # noqa: E402
from support.target_info import TargetInfo  # noqa: E402

TESTS = pathlib.Path(__file__).resolve().parent
HELLO = TESTS / "testcases" / "hello_world"


def fake_crate(tmp_path, name="light-tasking-nrf52832"):
    """A runtime crate directory with the one thing the harness reads from it:
    the configuration variables."""
    crate = tmp_path / name
    crate.mkdir()
    (crate / "alire.toml").write_text(
        'name = "' + name.replace("-", "_") + '"' + chr(10)
        + "[configuration.variables]" + chr(10)
        + 'Time_Base = { type = "Enum", values = ["RTC0", "RTC1"], default = "RTC0" }' + chr(10),
        encoding="utf-8")
    return crate


def test_io_timeout_hook_default_and_override(tmp_path):
    """The clock tests of a family may wait seconds for a cold low-speed
    crystal before printing, against the harness's fixed 5 s."""
    crate = fake_crate(tmp_path)
    plain = TestHarness(HELLO, tmp_path / "wd_plain", TargetInfo(crate, {}))
    assert plain.io_timeout() == 5.0

    tc = tmp_path / "tc_io_timeout"
    shutil.copytree(HELLO, tc)
    (tc / "opt.py").write_text("def io_timeout(target_info):" + chr(10) + "    return 12.0" + chr(10),
                               encoding="utf-8")
    assert TestHarness(tc, tmp_path / "wd_hook", TargetInfo(crate, {})).io_timeout() == 12.0
