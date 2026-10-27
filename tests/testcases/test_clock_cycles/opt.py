import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The CPU clock against the board's LSE crystal without Ada.Real_Time: every profile, light included.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def io_timeout(target_info: support.target_info.TargetInfo):
    # The LSE can take up to 5 s to start after a power cycle, and the measurement one second more.
    return 12.0
