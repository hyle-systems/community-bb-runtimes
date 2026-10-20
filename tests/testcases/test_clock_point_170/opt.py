import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The runtime's second against the board's LSE crystal (needs Ada.Real_Time: tasking runtimes).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def crate_config_values(target_info):
    # 8 MHz x 85 = 680 MHz VCO, /4 = 170 MHz at voltage scaling 3; AXI 85, APB 42.5
    return {f"{target_info.runtime_crate_name}.PLL_N_Mul": 85,
            f"{target_info.runtime_crate_name}.PLL_P_Div": 4,
            f"{target_info.runtime_crate_name}.Voltage_Scaling": "VOS3"}
