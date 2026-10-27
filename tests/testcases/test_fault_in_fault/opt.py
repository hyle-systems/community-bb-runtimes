import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The fault report and its guard are the family's, in every profile.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def source_dirs(target_info: support.target_info.TargetInfo):
    # The test's own last-chance handler, in the shape each profile's runtime calls it; it
    # counts its entries, prints, then faults on purpose.
    return ["lch_embedded"] if target_info.runtime_profile == "embedded" else ["lch_light"]


def core_checks():
    # The output alone cannot tell the latch's park from a lockup or a silent hang: once the output has been
    # read, the runner halts the core and checks that it is not locked up (DHCSR S_LOCKUP, bit 19) and that
    # it stops inside a fault handler (IPSR, the low bits of xPSR: HardFault .. UsageFault), where the second
    # report parks (README section 4).
    return [
        ("core not locked up", "mem", 0xE000EDF0, 1 << 19, {0}),
        ("parked in a fault handler", "reg", "xpsr", 0x1FF, {3, 4, 5, 6}),
    ]
