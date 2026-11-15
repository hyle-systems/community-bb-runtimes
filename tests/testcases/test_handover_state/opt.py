import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The hand-over is the stm32h7xx start-up's (all profiles).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
