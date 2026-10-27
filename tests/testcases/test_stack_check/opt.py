import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The compiler's stack check: light-tasking through the family's copy of
    # System.BB.Threads.Stack_Checking, embedded through its own (the same unit).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def compiler_switches(target_info: support.target_info.TargetInfo):
    return ["-fstack-check"]


def linker_switches(target_info: support.target_info.TargetInfo):
    # The environment stack holds the probe's margin (about 4.4 KB) and the elaboration
    return ["-Wl,--defsym=__stack_size=16384"]


def source_dirs(target_info: support.target_info.TargetInfo):
    return ["lch_embedded"] if target_info.runtime_profile == "embedded" else ["lch_light"]
