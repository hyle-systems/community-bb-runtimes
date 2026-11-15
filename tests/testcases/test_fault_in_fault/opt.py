import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The fault report and its guard are the family's, in every profile.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def source_dirs(target_info: support.target_info.TargetInfo):
    # The test's own last-chance handler, in the shape each profile's runtime calls it.
    return ["lch_embedded"] if target_info.runtime_profile == "embedded" else ["lch_light"]


def core_checks():
    # The output alone cannot tell the latch's park from a lockup or a silent hang. After it, the runner checks
    # S_LOCKUP (DHCSR bit 19, read after a resume) is clear and IPSR (xPSR's low bits) is HardFault .. UsageFault,
    # where the second report parks under a debugger (README section 4). These checks alone passed a runtime whose
    # park was a lockup: OpenOCD halts a locked-up core itself ("clearing lockup after double fault"), clearing
    # S_LOCKUP before anything can read it, so the runner also catches a lockup from OpenOCD's log, for every test.
    return [
        ("core not locked up", "mem", 0xE000EDF0, 1 << 19, {0}),
        ("parked in a fault handler", "reg", "xpsr", 0x1FF, {3, 4, 5, 6}),
    ]
