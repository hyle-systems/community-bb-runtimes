import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The stm32h7xx start-up turns the data cache on in every profile, so all of them run this BDMA test.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
