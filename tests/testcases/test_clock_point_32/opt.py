import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # Needs Ada.Real_Time, so it runs on the stm32h7xx tasking runtimes only.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def crate_config_values(target_info):
    # The HSI divided by 2, 32 MHz, at voltage scaling 3.
    return {
        f"{target_info.runtime_crate_name}.SYSCLK_Src": "HSI",
        f"{target_info.runtime_crate_name}.HSI_Div": "DIV2",
        f"{target_info.runtime_crate_name}.Voltage_Scaling": "VOS3",
    }


def io_timeout(target_info: support.target_info.TargetInfo):
    # As in test_clock_reference.
    return 12.0


def source_dirs(target_info: support.target_info.TargetInfo):
    # The program is test_clock_reference's; this test only sets other clock values.
    return ["../test_clock_reference"]
