"""Negative builds for the stm32h7xx crates: configurations that must be refused at compile time, each
with the message expected, plus the default configuration as the positive control. No board needed; each row
builds the hello_world testcase (or the one the row names) against the generated crate with the row's configuration values, so the
crate refuses it: its compile-time checks (s-bbpara.ads for the options, setup_pll.adb for the clock tree,
s-bbcppr.adb for the guard window) or, for a value outside the manifest's range or enumeration, Alire's own
validation of the configuration (the rows say which).

Run with ``pytest test_negative_builds.py`` from ``tests/`` after ``../generate-runtimes.sh --target stm32h7xx``.
Not to be run while the on-target runner is building against the same crates. About 25 s per row with configuration values (a private runtime copy), a few seconds without.
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
#  [, extra linker switches ({crate} = the runtime crate's directory) [, testcase directory, default hello_world
#  [, gprbuild arguments after "--", e.g. -XLOADER=USER]]])
ROWS = [
    ("light", {}, None),
    # The clock tree's own checks (DS13313 Tables 12 and 39-40, RM0468 Table 16 and 8.7.11)
    ("light", {"PLL_M_Div": 16}, "between 1 and 16 MHz"),                        # 0.5 MHz into the PLL
    ("light", {"PLL_N_Mul": 10}, "VCO must be 192 .. 836 MHz"),                                           # VCO 80 MHz, below both ranges
    ("light", {"PLL_P_Div": 3}, "must be 1 or even"),
    ("light", {"PLL_N_Mul": 69}, "CPU clock above the maximum"),                   # 552 MHz: the boost point is unsupported
    ("light", {"Voltage_Scaling": "VOS1"}, "CPU clock above the maximum"),         # 520 MHz at scale 1
    ("light", {"HPRE": "DIV1"}, "AXI/AHB clock above the maximum"),                # 520 MHz on the AXI
    ("light", {"D2PPRE1": "DIV1"}, "APB clock is above half"),                     # 260 MHz on APB1
    # The input range is coupled to the VCO range (DS13313 Table 39: wide 2-16 MHz; Table 40: medium 1-2 MHz)
    ("light", {"PLL_M_Div": 8, "PLL_N_Mul": 400}, "medium range"),   # 1 MHz in selects the medium range: VCO 400 MHz is in it, but P out 400 MHz is above its 210 MHz
    ("light", {"PLL_N_Mul": 20}, "wide range"),                      # 8 MHz in selects the wide range: VCO 160 MHz is below its 192 MHz
    ("light", {"PLL_M_Div": 8, "PLL_N_Mul": 100}, "medium range"),    # 1 MHz in selects the medium range: VCO 100 MHz is below its 150 MHz
    # The PLL1 P output has its own ceiling (DS13313 Table 39: 550/400/300/170 MHz per VOS, 520 at VOS0 as the CPU's),
    # which D1CPRE does not lift: VOS3, N = 85, P = 2, D1CPRE = 2 gives a 170 MHz CPU from a 340 MHz P output
    ("light", {"Voltage_Scaling": "VOS3", "PLL_N_Mul": 85, "PLL_P_Div": 2, "D1CPRE": "DIV2", "HPRE": "DIV2"}, "PLL1 P output above"),
    ("light", {"Voltage_Scaling": "VOS3", "PLL_N_Mul": 85, "PLL_P_Div": 4, "HPRE": "DIV2"}, None),   # P out 170: builds
    # At exactly 2 MHz of PLL1 input the loop filter's code says 1-2 MHz: the VCO must be the medium one too
    # (RM0468 8.5.5), whose outputs are limited to 210 MHz: M = 4 from 8 MHz, N = 200 -> 400 MHz is refused there
    ("light", {"PLL_M_Div": 4, "PLL_N_Mul": 200}, None),   # 2 MHz in selects the wide range, as ST does (CubeH7 template): VCO 400 MHz, P out 400 MHz, builds
    ("light", {"PLL_M_Div": 4, "PLL_N_Mul": 100}, None),   # 200 MHz: builds, VCO 200 MHz at the wide range's floor
    # The guard-size option
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 100}, "Stack_Guard_Bytes must be"),
    ("light", {"Stack_Guard": True, "Stack_Guard_Bytes": 100}, "Stack_Guard_Bytes"),  # the option is meaningless in light and must not be accepted silently
    # Every guarded stack is at least four times the window (the window sits inside the stack at its bottom)
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 512, "Interrupt_Stack_Size": 1024}, "four times"),   # a 1 KB interrupt stack against a 512-byte window
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 256, "Interrupt_Stack_Size": 1024}, None),   # exactly four times: builds
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 512, "Interrupt_Stack_Size": 4096},
     "environment stack smaller than four guard windows", ["-Wl,--defsym=__stack_size=1536"]),  # a 1.5 KB environment stack against a 512-byte window: the linker refuses
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 512, "Interrupt_Stack_Size": 4096},
     None, ["-Wl,--defsym=__stack_size=2048"]),                                       # exactly four windows: links
    # The supply configuration (RM0468 Table 30): every value must build on a part with the converter (the H725);
    # only LDO can run on this board
    ("light", {"MCU_Sub_Family": "H725", "Supply_Configuration": "SMPS"}, None),
    ("light", {"MCU_Sub_Family": "H725", "Supply_Configuration": "SMPS_1V8_Supplies_LDO"}, "2.5 V"),   # at VOS0 (the default) a converter feeding the LDO must output 2.5 V, DS13311 Table 14
    ("light", {"MCU_Sub_Family": "H725", "Supply_Configuration": "SMPS_2V5_Supplies_LDO"}, None),
    ("light", {"MCU_Sub_Family": "H725", "Supply_Configuration": "SMPS_1V8_Supplies_External_And_LDO"}, "2.5 V"),
    ("light", {"MCU_Sub_Family": "H725", "Voltage_Scaling": "VOS1", "PLL_N_Mul": 50, "Supply_Configuration": "SMPS_1V8_Supplies_LDO"}, None),   # 1.8 V into the LDO is listed from VOS1 down
    ("light", {"MCU_Sub_Family": "H725", "Supply_Configuration": "SMPS_2V5_Supplies_External_And_LDO"}, None),
    ("light", {"MCU_Sub_Family": "H725", "Supply_Configuration": "SMPS_1V8_Supplies_External_LDO_Bypass"}, None),
    ("light", {"MCU_Sub_Family": "H725", "Supply_Configuration": "SMPS_2V5_Supplies_External_LDO_Bypass"}, None),
    ("light", {"MCU_Sub_Family": "H725", "Supply_Configuration": "Bypass"}, None),
    ("light", {"Supply_Configuration": "Foo"}, "Supply_Configuration"),  # an unknown value must be refused - by Alire, against the manifest's enumeration (an unknown *variable* is silently ignored by Alire)
    # The flash-size variants (L1): the 128 KB and 512 KB maps must link a small program
    ("light", {"MCU_Sub_Family": "H730", "MCU_Flash_Memory_Size": "B"}, None),   # the one part with 128 KB
    ("light", {"MCU_Flash_Memory_Size": "E"}, None),
    # The interrupt stack: 4096 by default, no floor since a fault's handling moved to the fault stack (the embedded
    # rows at 1024 and 2048 were refused while it ran there; they are positive controls now)
    ("embedded", {"Interrupt_Stack_Size": 1024}, None),
    ("embedded", {"Stack_Guard": True, "Stack_Guard_Bytes": 256, "Interrupt_Stack_Size": 2048}, None),
    ("embedded", {"Stack_Guard": True, "Stack_Guard_Bytes": 256, "Interrupt_Stack_Size": 2304}, None),
    ("light-tasking", {"Interrupt_Stack_Size": 1024}, None),
    ("light", {"Interrupt_Stack_Size": 1024}, "have no effect in the light profile"),                                                                # no longer the default: the light crate refuses it
    # The fault stack (Fault_Stack_Size, 4096 by default): every fault's handling runs on it; embedded refuses
    # less than 2048 (the path measured 1792 bytes); the light crate accepts the option (its faults are routed too)
    ("embedded", {"Fault_Stack_Size": 1024}, "at least 2048 bytes"),
    ("embedded", {"Fault_Stack_Size": 2048}, None),
    ("light", {"Fault_Stack_Size": 1024}, None),
    # L2: a program larger than the 128 KB map (192 KB of constants) fails at the link with a region overflow,
    # and links against the default map
    ("light", {"MCU_Sub_Family": "H730", "MCU_Flash_Memory_Size": "B"}, "`flash' overflowed", [], "big_program"),
    ("light", {}, None, [], "big_program"),
    # --- The second review (2026-10): each row seen red before its fix ---
    # The idle task's 2 KB stack (the runtime's own, 8-aligned) bounds the window at 512: a 1 KB window rounded up inside
    # it can leave eight bytes of stack
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 1024}, "Stack_Guard_Bytes : Integer range 32 .. 512"),   # refused by Alire against the manifest's last = 512 (its message, not the runtime's)
    ("light-tasking", {"Stack_Guard": True, "Stack_Guard_Bytes": 512}, None),
    # Parts without a step-down converter refuse the SMPS arrangements (an invalid PWR_CR3 byte is ignored and locks
    # the register until a power cycle, RM0468 6.8.4); the H725/H735 have the converter, the H730 exists both ways
    ("light", {"MCU_Sub_Family": "H723", "Supply_Configuration": "SMPS"}, "has no SMPS"),
    ("light", {"MCU_Sub_Family": "H733", "Supply_Configuration": "SMPS_1V8_Supplies_LDO"}, "has no SMPS"),
    ("light", {"MCU_Sub_Family": "H730", "MCU_Flash_Memory_Size": "B", "Supply_Configuration": "SMPS_2V5_Supplies_External_LDO_Bypass"}, None),
    ("light", {"MCU_Sub_Family": "H730", "MCU_Flash_Memory_Size": "B", "Supply_Configuration": "LDO"}, None),
    ("light", {"MCU_Sub_Family": "H735", "Supply_Configuration": "Bypass"}, None),
    # The flash size follows the part: H730 128 KB only, H733/H735 1 MB only, H723/H725 512 KB or 1 MB
    ("light", {"MCU_Sub_Family": "H730", "MCU_Flash_Memory_Size": "G"}, "MCU_Flash_Memory_Size"),
    ("light", {"MCU_Sub_Family": "H735", "MCU_Flash_Memory_Size": "E"}, "MCU_Flash_Memory_Size"),
    ("light", {"MCU_Sub_Family": "H725", "MCU_Flash_Memory_Size": "E"}, None),
    ("light", {"MCU_Sub_Family": "H733"}, None),   # hello_world on every sub-family: H733 (G, no converter)
    ("embedded", {"MCU_Sub_Family": "H735"}, None),   # and H735 (G, converter) - H723, H725 and H730 have rows above
    # ST's own 520 MHz point for the NUCLEO-H723ZG (the CubeH7 template): 2 MHz into the wide VCO, M = 4, N = 260
    ("light", {"PLL_M_Div": 4, "PLL_N_Mul": 260}, None),   # ST's own 520 MHz point for the NUCLEO-H723ZG: 2 MHz in, wide VCO 520 MHz
    # The Q and R outputs have the P output's ceiling in the wide range too (DS13313 Table 39): VCO 400 MHz at VOS2,
    # P 200 within, Q 400 above 300
    ("light", {"Voltage_Scaling": "VOS2", "PLL_N_Mul": 50, "PLL_P_Div": 2, "PLL_Q_Enable": True, "PLL_Q_Div": 1}, "Q output above"),
    # A crystal is 4 to 48 MHz (RM0468 8.4.1); 50 MHz is for an external clock in bypass
    ("light", {"HSE_Bypass": False, "HSE_Clock_Frequency": 50000000, "PLL_M_Div": 5, "PLL_N_Mul": 52}, "crystal"),
    ("light", {"HSE_Bypass": False, "HSE_Clock_Frequency": 48000000, "PLL_M_Div": 6, "PLL_N_Mul": 65}, None),
    # The interrupt stack has a floor of 1 KB: the tick's handler and the scheduler run there
    ("light-tasking", {"Interrupt_Stack_Size": 64}, "Interrupt_Stack_Size : Integer range 1024"),   # Z16: the manifest's floor, refused by Alire (the runtime's floor stays behind it)
    # A user linker script (LOADER=USER) links with the crate's own scripts named by hand: the three link-time
    # symbols must come from the crate in every loader case
    ("light", {}, None, ["-L{crate}/ld", "-L{crate}/ld/flash-1024", "-L{crate}/ld/ram-h72x", "-Tcommon-ROM.ld",
      "-Wl,--no-warn-rwx-segments"],   # the crate adds this switch for ROM and RAM; a user script adds it itself
     "hello_world", ["-XLOADER=USER"]),
    # --- The fourth review (2026-10): each row seen red before its fix ---
    # Z7: the P-output ceilings bind the P output only when it is used; SYSCLK from the crystal with only the Q
    # output on may run the VCO high at PLL_P_Div = 1 (DIVP1EN = 0): wide range, then medium
    ("light", {"SYSCLK_Src": "HSE", "PLL_Q_Enable": True, "PLL_N_Mul": 104, "PLL_P_Div": 1}, None),   # P nominally 832 MHz, Q 208
    ("light", {"SYSCLK_Src": "HSE", "PLL_Q_Enable": True, "PLL_M_Div": 8, "PLL_N_Mul": 400, "PLL_P_Div": 1}, None),   # P nominally 400, Q 100
    # Z2: an initialised .axisram beyond what the start-up's copy loop can count (upstream's start-rom.S loads the word
    # count with one movw: 65 535 words, 256 KB) must be refused at the link; below it the program links
    ("light", {}, "initialised .axisram above 256 KB", [], "big_axisram"),
    ("light", {}, None, [], "big_axisram_ok"),
    # S33: the load images of .data and .axisram take their addresses from expressions, which ld never checks against
    # the flash region: 200 KB of initial values must be refused on the 128 KB map
    ("light", {"MCU_Sub_Family": "H730", "MCU_Flash_Memory_Size": "B"}, "initial values exceed the flash", [], "big_axisram_ok"),
]


def row_id(row):
    """The id carries the target first, so that upstream's Windows per-target job
    (``-k "not execute_on_target and stm32h7xx"``) selects the table (Z17)."""
    profile, values, expected = row[:3]
    return ("stm32h7xx:" + profile + ":" + (",".join(f"{k}={v}" for k, v in values.items()) or "default")
            + (":" + ",".join(row[3]) if len(row) > 3 and row[3] else "")
            + (":" + row[4] if len(row) > 4 else "") + (":" + " ".join(row[5]) if len(row) > 5 else "")
            + (":builds" if expected is None else ""))


@pytest.mark.parametrize("row", ROWS, ids=row_id)
def test_negative_build(row, tmp_path):
    profile, values, expected = row[:3]
    switches = row[3] if len(row) > 3 else []
    testcase = TESTCASES / (row[4] if len(row) > 4 else "hello_world")
    build_args = row[5] if len(row) > 5 else []
    crate_dir = INSTALL / f"{profile}-stm32h7xx"
    if not crate_dir.is_dir():
        pytest.skip(f"{profile} crate not generated")
    if shutil.which("alr") is None:
        pytest.skip("alr not on PATH")
    target_info = TargetInfo(crate_dir, values, private_runtime_crate=bool(values))
    working_dir = tmp_path / "crate"
    harness = TestHarness(testcase, working_dir, target_info)
    harness.setup()
    if switches:
        switches = [sw.replace("{crate}", crate_dir.resolve().as_posix()) for sw in switches]
        gpr = working_dir / "test.gpr"
        text = gpr.read_text(encoding="utf-8")
        marker = '"-Wl,--fatal-warnings"'
        assert marker in text
        gpr.write_text(text.replace(marker, marker + "".join(f', "{sw}"' for sw in switches)), encoding="utf-8")
    r = subprocess.run(["alr", "build"] + (["--"] + build_args if build_args else []),
                       cwd=working_dir, capture_output=True, text=True, errors="replace")
    output = r.stdout + r.stderr
    if expected is None:
        assert r.returncode == 0, "the default configuration must build:\n" + output[-3000:]
    else:
        assert r.returncode != 0, f"the build must be refused ({expected}) but succeeded"
        assert expected in output, f"refused, but not with the expected message ({expected}):\n" + output[-3000:]
