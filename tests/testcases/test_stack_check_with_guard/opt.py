import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # As in test_stack_check.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def compiler_switches(target_info: support.target_info.TargetInfo):
    return ["-fstack-check"]


def linker_switches(target_info: support.target_info.TargetInfo):
    # As in test_stack_check: the main program is checked too.
    return ["-Wl,--defsym=__stack_size=16384"]


def crate_config_values(target_info: support.target_info.TargetInfo):
    # The MPU guard on, with its default 128-byte window.
    return {f"{target_info.runtime_crate_name}.Stack_Guard": True}


def source_dirs(target_info: support.target_info.TargetInfo):
    # test_stack_check's program with the MPU guard on: the compiler's check must fire first, with the
    # guard as the net behind it, and the depth band of test_stack_check applies.
    return ["../test_stack_check", "../test_stack_check/lch_embedded" if target_info.runtime_profile == "embedded"
            else "../test_stack_check/lch_light"]
