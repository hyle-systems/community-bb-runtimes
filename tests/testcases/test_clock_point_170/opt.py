import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # Needs Ada.Real_Time, so it runs on the stm32h7xx tasking runtimes only.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def crate_config_values(target_info):
    # 8 MHz x 85 is a 680 MHz VCO, and /4 gives 170 MHz at voltage scaling 3,
    # with the AXI clock at 85 MHz and APB at 42.5 MHz.
    return {f"{target_info.runtime_crate_name}.PLL_N_Mul": 85,
            f"{target_info.runtime_crate_name}.PLL_P_Div": 4,
            f"{target_info.runtime_crate_name}.Voltage_Scaling": "VOS3"}


def io_timeout(target_info: support.target_info.TargetInfo):
    # As in test_clock_reference.
    return 12.0


def source_dirs(target_info: support.target_info.TargetInfo):
    # The program is test_clock_reference's; this test only sets other clock values.
    return ["../test_clock_reference"]
