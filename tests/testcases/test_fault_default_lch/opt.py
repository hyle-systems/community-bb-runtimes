import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if target_info.runtime_profile != "embedded":
        pytest.skip("the embedded profile's default last-chance handler")
