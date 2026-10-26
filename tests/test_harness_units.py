"""Board-less checks of the harness itself, from the second review of the stm32h7xx branch: the
private-runtime-copy rule, the GDB error path, the OpenOCD runner's failed start, the CI's selection of
the generator check. Each was written red, before the behaviour it pins existed.

Run with ``pytest test_harness_units.py`` from ``tests/``; no board, no toolchain needed.
"""
import pathlib
import shutil
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


def _testcase_with_opt(tmp_path, name, opt_source):
    """A copy of hello_world with the given opt.py (the harness caches opt modules by testcase name: one name per unit)."""
    tc = tmp_path / name
    shutil.copytree(HELLO, tc)
    (tc / "opt.py").write_text(opt_source, encoding="utf-8")
    return tc


def test_values_for_another_crate_share_the_installed_crate(tmp_path):
    """Z10: upstream's test_rp2040_hal returns crate_config_values for the rp2040_hal crate, not for the runtime; such
    values must not take the private runtime copy (seen red: every RP2040 row rebuilt its runtime on this branch)."""
    crate = fake_crate(tmp_path)
    tc = _testcase_with_opt(tmp_path, "tc_values_of_another_crate",
                            "def crate_config_values(target_info):\n    return {'rp2040_hal.Use_Startup': False}\n")
    harness = TestHarness(tc, tmp_path / "wd", TargetInfo(crate, {}))
    harness.setup()
    assert not (tmp_path / "wd" / crate.name).exists(), "a private copy was made for another crate's values"


def test_values_for_the_runtime_crate_take_a_private_copy(tmp_path):
    """The complement of the unit above: values for the runtime crate itself do take the copy."""
    crate = fake_crate(tmp_path)
    tc = _testcase_with_opt(tmp_path, "tc_values_of_the_runtime",
                            "def crate_config_values(target_info):\n"
                            "    return {target_info.runtime_crate_name + '.Time_Base': 'RTC1'}\n")
    harness = TestHarness(tc, tmp_path / "wd", TargetInfo(crate, {}))
    harness.setup()
    assert (tmp_path / "wd" / crate.name).is_dir(), "no private copy for the runtime crate's own values"


def test_negative_rows_carry_the_target():
    """Z17: upstream's Windows per-target job selects with ``-k "not execute_on_target and <target>"``; a negative row
    whose id carries no target never runs there (seen red: no row did)."""
    import test_negative_builds as nb
    without = [nb.row_id(r) for r in nb.ROWS if "stm32h7xx" not in nb.row_id(r)]
    assert without == [], f"negative rows whose id carries no target ({len(without)}): {without[:3]} ..."


def test_io_timeout_hook_default_and_override(tmp_path):
    """Z14: a testcase may ask for a longer read budget through opt.py (the clock tests wait up to 5 s for a cold LSE
    against the harness's 5 s default); without the hook the default stands."""
    crate = fake_crate(tmp_path)
    plain = TestHarness(HELLO, tmp_path / "wd_plain", TargetInfo(crate, {}))
    assert plain.io_timeout() == 5.0
    tc = _testcase_with_opt(tmp_path, "tc_io_timeout", "def io_timeout(target_info):\n    return 12.0\n")
    assert TestHarness(tc, tmp_path / "wd_hook", TargetInfo(crate, {})).io_timeout() == 12.0


class FakeController:
    """pygdbmi's controller as the constructor sees it: answers nothing, remembers whether it was told to exit."""
    instances = []

    def __init__(self, *args, **kwargs):
        self.exited = False
        FakeController.instances.append(self)

    def get_gdb_response(self, timeout_sec=None, raise_error_on_timeout=True):
        return []

    def write(self, *args, **kwargs):
        return []

    def exit(self):
        self.exited = True


def test_gdb_constructor_failure_shuts_the_debugger_down(monkeypatch, tmp_path):
    """The GDB interface spawns arm-eabi-gdb in its constructor and the ^error path can raise there; the `with`
    block's clean-up never runs for a constructor that raised, so the debugger stayed alive holding the ELF
    (on Windows the temporary directory's removal then fails with a permission error that buries the cause).
    The constructor must shut the debugger down before letting the exception out."""
    FakeController.instances.clear()
    monkeypatch.setattr(target_interface, "find_gdb", lambda crate, prefix: tmp_path / "arm-eabi-gdb")
    monkeypatch.setattr(target_interface.pygdbmi.gdbcontroller, "GdbController", FakeController)

    def refused(self, timeout_sec=None):
        raise target_interface.GdbCommandError("GDB command failed: connection refused")

    monkeypatch.setattr(target_interface.GdbTargetInterface, "_wait_for_result", refused)
    with pytest.raises(target_interface.GdbCommandError):
        target_interface.GdbTargetInterface(tmp_path, tmp_path / "test", 3333, None)
    assert FakeController.instances and FakeController.instances[0].exited, "the debugger was left running"


def test_unknown_configuration_key_is_refused():
    """get_config_values merged the crate's declared variables with the overrides by iterating the declared
    ones, so an override for a name the crate does not declare was dropped and the default built: a misspelt
    key in a positive row of the negative table would report green for a configuration never compiled."""
    import support.target_info as target_info
    declared = {"PLL_N_Mul": {"type": "Integer", "default": 65}}
    assert target_info.get_config_values(declared, {"PLL_N_Mul": 69}) == {"PLL_N_Mul": 69}
    with pytest.raises(ValueError):
        target_info.get_config_values(declared, {"PLL_N_Mull": 69})
