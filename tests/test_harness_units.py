"""Board-less checks of the harness itself, from the second review of the stm32h7xx branch: the
private-runtime-copy rule, the GDB error path, the OpenOCD runner's failed start, the CI's selection of
the generator check. Each was written red, before the behaviour it pins existed.

Run with ``pytest test_harness_units.py`` from ``tests/``; no board, no toolchain needed.
"""
import pathlib
import subprocess
import sys

import pytest

TESTS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TESTS))

from support.harnesses import TestHarness            # noqa: E402
from support.target_info import TargetInfo           # noqa: E402
import support.target_interface as target_interface  # noqa: E402
import run_openocd_tests                             # noqa: E402

HELLO = TESTS / "testcases" / "hello_world"


def fake_crate(tmp_path, name="light-tasking-nrf52832"):
    """A runtime crate directory with the one thing the harness reads from it: the configuration variables."""
    crate = tmp_path / name
    crate.mkdir()
    (crate / "alire.toml").write_text(
        'name = "' + name.replace("-", "_") + '"\n'
        "[configuration.variables]\n"
        'Time_Base = { type = "Enum", values = ["RTC0", "RTC1"], default = "RTC0" }\n',
        encoding="utf-8")
    (crate / "runtime_build.gpr").write_text("project Runtime_Build is\nend Runtime_Build;\n", encoding="utf-8")
    return crate


def test_configured_row_of_another_family_shares_the_installed_crate(tmp_path):
    """A configuration row that arrives through the target description - the repository's own rows for nrf52,
    rp2040/2350 and stm32f4xx in support/test_configs.py - builds against the installed crate, as upstream
    always did. A private copy of the runtime, a full rebuild, is made only when the caller asks for it (the
    negative table) or when the testcase sets values itself through opt.py."""
    crate = fake_crate(tmp_path)
    harness = TestHarness(HELLO, tmp_path / "wd", TargetInfo(crate, {"Time_Base": "RTC1"}))
    harness.setup()
    assert not (tmp_path / "wd" / crate.name).exists(), "a private copy was made for an ordinary configured row"


def test_private_copy_when_asked(tmp_path):
    crate = fake_crate(tmp_path)
    info = TargetInfo(crate, {"Time_Base": "RTC1"}, private_runtime_crate=True)
    harness = TestHarness(HELLO, tmp_path / "wd", info)
    harness.setup()
    assert (tmp_path / "wd" / crate.name).is_dir()


class FakeGdb:
    def __init__(self, responses):
        self._responses = list(responses)

    def get_gdb_response(self, timeout_sec=None, raise_error_on_timeout=True):
        return self._responses.pop(0) if self._responses else []


def test_gdb_error_record_raises():
    """A GDB ^error - a monitor command OpenOCD refused: a flash write that failed, a load_image of a wrong
    path - must stop the test instead of letting it run whatever is in flash."""
    tif = target_interface.GdbTargetInterface.__new__(target_interface.GdbTargetInterface)
    tif.gdb = FakeGdb([[{"type": "result", "message": "error", "payload": {"msg": "boom"}}]])
    with pytest.raises(RuntimeError):
        tif._wait_for_result(timeout_sec=1.0)


def test_gdb_done_record_returns():
    tif = target_interface.GdbTargetInterface.__new__(target_interface.GdbTargetInterface)
    tif.gdb = FakeGdb([[{"type": "result", "message": "done", "payload": None}]])
    assert tif._wait_for_result(timeout_sec=1.0)["message"] == "done"


def test_openocd_that_never_comes_up_is_killed(tmp_path):
    """The runner waits for OpenOCD's ready line; when it never comes, the server it started must not be left
    holding the ports for every test after it."""
    log = tmp_path / "openocd.log"
    log.write_text("", encoding="utf-8")
    p = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
    try:
        with pytest.raises(RuntimeError):
            run_openocd_tests.wait_for_openocd(p, log, sh_port=4445, timeout=1.0)
        try:
            p.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        assert p.poll() is not None, "the server outlived the failed start"
    finally:
        if p.poll() is None:
            p.kill()


def test_generator_check_ids_carry_the_target():
    """The CI's per-target job selects tests by the target's name in the id; the generator check must be in it
    (it normalises line endings for the Windows job in particular)."""
    r = subprocess.run([sys.executable, "-m", "pytest", "--collect-only", "-q", "-p", "no:cacheprovider",
                        "test_generated.py", "-k", "stm32h7xx"], cwd=TESTS, capture_output=True, text=True)
    assert "test_generated.py::" in r.stdout, r.stdout[-600:]


def test_expected_outputs_end_at_the_marker():
    # The harness reads the target's output up to "===TEST COMPLETE===" and compares it with test.out
    # as a whole, so a test.out that carries anything after the marker (a final line break, typically)
    # can never match. A test.out without the marker is a test that parks by design (test_fault_in_fault)
    # and is compared on the read's timeout; it is not this check's business.
    marker = b"===TEST COMPLETE==="
    offenders = []
    for out in sorted((TESTS / "testcases").glob("*/test.out")):
        data = out.read_bytes()
        if marker in data and not data.endswith(marker):
            offenders.append(f"{out.parent.name}: {data[data.index(marker) + len(marker):]!r} after the marker")
    assert offenders == [], "\n".join(offenders)


def test_runner_default_list_carries_every_family_test():
    """run_openocd_tests.py without a test list runs the generic tests plus the target's own: every testcase
    whose opt.py requires the stm32h7xx target must be in FAMILY_TESTCASES['stm32h7xx'], or the default run
    silently leaves it out."""
    family = set(run_openocd_tests.FAMILY_TESTCASES["stm32h7xx"])
    requiring = set()
    for opt in sorted((TESTS / "testcases").glob("*/opt.py")):
        if "stm32h7xx" in opt.read_text(encoding="utf-8"):
            requiring.add(opt.parent.name)
    assert requiring, "no testcase names the target in its opt.py: the scan is broken"
    missing = sorted(requiring - family)
    assert missing == [], f"family testcases absent from the runner's default list: {missing}"
    unknown = sorted(name for name in family if not (TESTS / "testcases" / name).is_dir())
    assert unknown == [], f"names in the runner's family list without a testcase: {unknown}"
