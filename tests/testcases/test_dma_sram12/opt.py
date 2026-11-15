import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The start-up turns the data cache and the SRAM1/SRAM2 clocks on in every profile, so all of them run it.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
