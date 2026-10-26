import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The runtime's second against the board's LSE crystal (needs Ada.Real_Time: tasking runtimes).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def crate_config_values(target_info):
    return {
        f"{target_info.runtime_crate_name}.PLL_M_Div": 4,
        f"{target_info.runtime_crate_name}.PLL_N_Mul": 260,
    }


def io_timeout(target_info: support.target_info.TargetInfo):
    # The LSE can take up to 5 s to start after a power cycle (the test waits that long for it), and the
    # measurement one second more: beyond the harness's 5 s default.
    return 12.0
