import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The RAM loader is an stm32h7xx family link option (all profiles).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def build_args(target_info: support.target_info.TargetInfo):
    return ["-XLOADER=RAM"]
