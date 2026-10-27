import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The data cache and the BDMA into SRAM4 (.sram4): the stm32h7xx start-up turns the cache on (all profiles).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
