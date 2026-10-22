import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The MPU stack guard is an option of the stm32h7xx family's tasking runtimes.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def crate_config_values(target_info: support.target_info.TargetInfo):
    # The default stacks, on purpose: with the old 1 KB interrupt stack, on
    # embedded the fault path overflowed it once the window took its bottom
    # and the window write ended in a hard fault instead of the memory
    # management fault; the fault stack carries the path now.
    return {
        f"{target_info.runtime_crate_name}.Stack_Guard": True,
        f"{target_info.runtime_crate_name}.Stack_Guard_Bytes": 256,
    }


def source_dirs(target_info: support.target_info.TargetInfo):
    return ["lch_embedded"] if target_info.runtime_profile == "embedded" else ["lch_light"]
