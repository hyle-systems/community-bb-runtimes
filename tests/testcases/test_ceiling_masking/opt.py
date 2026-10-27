import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # Ceiling locking against the interrupt priorities (tasking runtimes) on the stm32h7xx family's 4 priority bits.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")
