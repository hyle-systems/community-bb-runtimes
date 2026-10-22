"""Negative builds for the stm32h7xx crates: configurations that must be refused at compile time, each
with the message expected, plus the default configuration as the positive control. No board needed; each row
builds the hello_world testcase (or the one the row names) against the generated crate with the row's configuration values, so the
runtime's compile-time checks (setup_pll.adb, s-bbcppr.adb) are what refuse it.

Run with ``pytest test_negative_builds.py`` from ``tests/`` after ``../generate-runtimes.sh --target stm32h7xx``.
Not to be run while the on-target runner is building against the same crates. About 15 s per row.
"""
import pathlib
import shutil
import subprocess

import pytest

from support.harnesses import TestHarness
from support.target_info import TargetInfo

REPO = pathlib.Path(__file__).resolve().parent.parent
INSTALL = REPO / "install"
TESTCASES = REPO / "tests" / "testcases"

# (profile, configuration values, fragment of the expected error; None = must build
#  [, extra linker switches [, testcase directory, default hello_world]])
ROWS = [
    ("light", {}, None),
    # The clock tree's own checks (DS13313 Tables 12 and 39-40, RM0468 Table 16 and 8.7.11)
    ("light", {"PLL_M_Div": 16}, "between 1 and 16 MHz"),                        # 0.5 MHz into the PLL
    ("light", {"PLL_N_Mul": 10}, "VCO"),                                           # VCO 80 MHz, below both ranges
    ("light", {"PLL_P_Div": 3}, "must be 1 or even"),
    ("light", {"PLL_N_Mul": 69}, "CPU clock above the maximum"),                   # 552 MHz: the boost point is unsupported
    ("light", {"Voltage_Scaling": "VOS1"}, "CPU clock above the maximum"),         # 520 MHz at scale 1
    ("light", {"HPRE": "DIV1"}, "AXI/AHB clock above the maximum"),                # 520 MHz on the AXI
    ("light", {"D2PPRE1": "DIV1"}, "APB clock is above half"),                     # 260 MHz on APB1
    # The input range is coupled to the VCO range (DS13313 Table 39: wide 2-16 MHz; Table 40: medium 1-2 MHz)
    ("light", {"PLL_M_Div": 8, "PLL_N_Mul": 400}, "medium range"),   # 1 MHz in selects the medium range: VCO 400 MHz is in it, but P out 400 MHz is above its 210 MHz
    ("light", {"PLL_N_Mul": 20}, "wide range"),                      # 8 MHz in selects the wide range: VCO 160 MHz is below its 192 MHz
    ("light", {"PLL_M_Div": 8, "PLL_N_Mul": 100}, "medium range"),    # 1 MHz in selects the medium range: VCO 100 MHz is below its 150 MHz
    # The guard-size option
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 100}, "Stack_Guard_Bytes must be"),
    ("light", {"Stack_Guard": True, "Stack_Guard_Bytes": 100}, "Stack_Guard_Bytes"),  # the option is meaningless in light and must not be accepted silently
    # Every guarded stack is at least four times the window (the window sits inside the stack at its bottom)
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 1024, "Interrupt_Stack_Size": 2048}, "four times"),   # a 2 KB interrupt stack against a 1 KB window
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 256}, None),           # exactly four times: builds
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 1024, "Interrupt_Stack_Size": 4096},
     "environment stack smaller than four guard windows", ["-Wl,--defsym=__stack_size=3072"]),  # a 3 KB environment stack against a 1 KB window: the linker refuses
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 1024, "Interrupt_Stack_Size": 4096},
     None, ["-Wl,--defsym=__stack_size=4096"]),                                       # exactly four windows: links
    # The supply configuration (RM0468 Table 30): every value must build; only LDO can run on this board
    ("light", {"Supply_Configuration": "SMPS"}, None),
    ("light", {"Supply_Configuration": "SMPS_1V8_Supplies_LDO"}, None),
    ("light", {"Supply_Configuration": "SMPS_2V5_Supplies_LDO"}, None),
    ("light", {"Supply_Configuration": "SMPS_1V8_Supplies_External_And_LDO"}, None),
    ("light", {"Supply_Configuration": "SMPS_2V5_Supplies_External_And_LDO"}, None),
    ("light", {"Supply_Configuration": "SMPS_1V8_Supplies_External_LDO_Bypass"}, None),
    ("light", {"Supply_Configuration": "SMPS_2V5_Supplies_External_LDO_Bypass"}, None),
    ("light", {"Supply_Configuration": "Bypass"}, None),
    ("light", {"Supply_Configuration": "Foo"}, "Supply_Configuration"),  # an unknown value must be refused (an unknown *variable* is silently ignored by Alire)
    # The flash-size variants (L1): the 128 KB and 512 KB maps must link a small program
    ("light", {"MCU_Flash_Memory_Size": "B"}, None),
    ("light", {"MCU_Flash_Memory_Size": "E"}, None),
    # The interrupt stack (finding 7, decided 2026-10-22): 4096 by default; embedded refuses less than 2048 plus the
    # window, because a fault's handling runs on it in handler mode (1792 bytes measured); light-tasking has no floor
    ("embedded", {"Interrupt_Stack_Size": 1024}, "at least 2048 bytes"),
    ("embedded", {"Stack_Guard": True, "Stack_Guard_Bytes": 256, "Interrupt_Stack_Size": 2048}, "at least 2048 bytes"),  # 2048 < 2048 + 256
    ("embedded", {"Stack_Guard": True, "Stack_Guard_Bytes": 256, "Interrupt_Stack_Size": 2304}, None),                   # exactly the floor: builds
    ("light-tasking", {"Interrupt_Stack_Size": 1024}, None),                                                             # no floor there
    ("light", {"Interrupt_Stack_Size": 1024}, "have no"),                                                                # no longer the default: the light crate refuses it
    # L2: a program larger than the 128 KB map (192 KB of constants) fails at the link with a region overflow,
    # and links against the default map
    ("light", {"MCU_Flash_Memory_Size": "B"}, "`flash' overflowed", [], "big_program"),
    ("light", {}, None, [], "big_program"),
]


def row_id(row):
    profile, values, expected = row[:3]
    return (profile + ":" + (",".join(f"{k}={v}" for k, v in values.items()) or "default")
            + (":" + ",".join(row[3]) if len(row) > 3 and row[3] else "")
            + (":" + row[4] if len(row) > 4 else "") + (":builds" if expected is None else ""))


@pytest.mark.parametrize("row", ROWS, ids=row_id)
def test_negative_build(row, tmp_path):
    profile, values, expected = row[:3]
    switches = row[3] if len(row) > 3 else []
    testcase = TESTCASES / (row[4] if len(row) > 4 else "hello_world")
    crate_dir = INSTALL / f"{profile}-stm32h7xx"
    if not crate_dir.is_dir():
        pytest.skip(f"{profile} crate not generated")
    if shutil.which("alr") is None:
        pytest.skip("alr not on PATH")
    target_info = TargetInfo(crate_dir, values)
    working_dir = tmp_path / "crate"
    harness = TestHarness(testcase, working_dir, target_info)
    harness.setup()
    if switches:
        gpr = working_dir / "test.gpr"
        text = gpr.read_text(encoding="utf-8")
        marker = '"-Wl,--fatal-warnings"'
        assert marker in text
        gpr.write_text(text.replace(marker, marker + "".join(f', "{sw}"' for sw in switches)), encoding="utf-8")
    r = subprocess.run(["alr", "build"], cwd=working_dir, capture_output=True, text=True, errors="replace")
    output = r.stdout + r.stderr
    if expected is None:
        assert r.returncode == 0, "the default configuration must build:\n" + output[-3000:]
    else:
        assert r.returncode != 0, f"the build must be refused ({expected}) but succeeded"
        assert expected in output, f"refused, but not with the expected message ({expected}):\n" + output[-3000:]
