import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The stm32h7xx start-up's check of its entry privilege (all profiles).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def core_checks():
    # The core must be parked at __gnat_handover_unprivileged: thread mode (IPSR 0) and still unprivileged
    # (CONTROL.nPRIV). The output alone shows only that nothing more was printed.
    return [
        ("parked in thread mode", "reg", "xpsr", 0x1FF, {0}),
        ("still unprivileged", "reg", "control", 0x1, {1}),
    ]
