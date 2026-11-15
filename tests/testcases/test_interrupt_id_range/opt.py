import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The stm32h7xx interrupt list; Ada.Interrupts is in libgnarl (tasking).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")
