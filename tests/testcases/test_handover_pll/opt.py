import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def io_timeout(target_info: support.target_info.TargetInfo):
    # Two passes through the start-up, the LSE's start (up to 5 s) and a one-second measurement.
    return 15.0
