import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The stm32h7xx start-up's check of its entry mode (all profiles).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def core_checks():
    # The core must be parked at __gnat_handover_in_handler with the NMI
    # still active (IPSR 2); the output alone shows only that nothing more
    # was printed.
    return [
        ("parked in the NMI's handler mode", "reg", "xpsr", 0x1FF, {2}),
    ]
