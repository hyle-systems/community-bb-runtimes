import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The NMI vector's routing is the stm32h7xx family's (all profiles).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
