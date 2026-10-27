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
        # 8 MHz / 3 = 2.666... MHz into the wide VCO, x 195 = 520 MHz exactly: an M that does not divide
        # the input must not truncate it before N multiplies it (2 666 666 x 195 = 519 999 870 Hz)
        f"{target_info.runtime_crate_name}.PLL_M_Div": 3,
        f"{target_info.runtime_crate_name}.PLL_N_Mul": 195,
    }


def io_timeout(target_info: support.target_info.TargetInfo):
    # The LSE can take up to 5 s to start after a power cycle (the test waits that long for it), and the
    # measurement one second more: beyond the harness's 5 s default.
    return 12.0
