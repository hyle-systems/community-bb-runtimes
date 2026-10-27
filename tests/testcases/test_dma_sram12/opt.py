import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The data cache and a DMA into SRAM1/SRAM2 (.sram12): the stm32h7xx start-up turns the cache on and
    # enables the RAMs' clocks (all profiles).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
