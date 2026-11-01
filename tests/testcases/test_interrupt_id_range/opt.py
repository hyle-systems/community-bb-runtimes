import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    if target_info.target != "stm32g4xx":
        pytest.skip(f"Test requires target 'stm32g4xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")
