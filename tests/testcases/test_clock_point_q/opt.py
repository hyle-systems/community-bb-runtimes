import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # A register read-back of PLL1's Q output, so every profile runs it.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def crate_config_values(target_info: support.target_info.TargetInfo):
    # The default point (VCO at 520 MHz) with Q at /4, 130 MHz. R stays off.
    return {f"{target_info.runtime_crate_name}.PLL_Q_Enable": True,
            f"{target_info.runtime_crate_name}.PLL_Q_Div": 4}
