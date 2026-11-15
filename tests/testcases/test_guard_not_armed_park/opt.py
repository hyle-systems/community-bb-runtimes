import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # test_guard_not_armed's program on embedded. There the runtime cannot report the guard the start-up did
    # not arm (its exception propagation is not up while it initialises the CPU), so it parks at
    # __gnat_guard_not_armed_park before the application runs: nothing is printed.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if target_info.runtime_profile != "embedded":
        pytest.skip("light-tasking reports instead of parking: test_guard_not_armed")


def crate_config_values(target_info: support.target_info.TargetInfo):
    return {f"{target_info.runtime_crate_name}.Stack_Guard": True}


def linker_switches(target_info: support.target_info.TargetInfo):
    # As in test_guard_not_armed: an 8-byte window, so the start-up skips its guard block.
    return ["-Wl,--defsym=__stack_guard_bytes=8"]


def source_dirs(target_info: support.target_info.TargetInfo):
    return ["../test_guard_not_armed", "../../support/lch_embedded"]


def core_checks():
    # The output is empty either way, so the core's state is the evidence: the park is a loop in thread mode
    # with the MPU still off. A raise that faulted again would leave the core in a fault handler instead
    # (__gnat_fault_in_fault, IPSR 3).
    return [
        ("core not locked up", "mem", 0xE000EDF0, 1 << 19, {0}),
        ("the MPU still off", "mem", 0xE000ED94, 0x1, {0}),
        ("parked in thread mode", "reg", "xpsr", 0x1FF, {0}),
    ]
