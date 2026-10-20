import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The compiler's stack check is the light-tasking profile's addition (the family copies
    # System.BB.Threads.Stack_Checking into it); embedded has its own.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if target_info.runtime_profile not in ("light-tasking", "light_tasking"):
        pytest.skip(f"Test is for the light-tasking profile")


def compiler_switches(target_info: support.target_info.TargetInfo):
    return ["-fstack-check"]


def linker_switches(target_info: support.target_info.TargetInfo):
    # The environment stack holds the probe's margin (about 4.4 KB) and the elaboration
    return ["-Wl,--defsym=__stack_size=16384"]


def crate_config_values(target_info: support.target_info.TargetInfo):
    return {f"{target_info.runtime_crate_name}.Stack_Guard": True}


def source_dirs(target_info: support.target_info.TargetInfo):
    return ["lch_light"]
