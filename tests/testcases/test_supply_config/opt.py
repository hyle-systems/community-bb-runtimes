import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The supply configuration is written by the stm32h7xx start-up (all profiles).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
