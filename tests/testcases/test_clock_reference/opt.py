import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # Needs Ada.Real_Time, so it runs on the stm32h7xx tasking runtimes only.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def io_timeout(target_info: support.target_info.TargetInfo):
    # Up to 5 s for the LSE to start after a power cycle, then about 1 s of measurement: above the 5 s default.
    return 12.0
