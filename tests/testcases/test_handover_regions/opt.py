import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The MPU stack guard is an option of the stm32h7xx tasking runtimes.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")


def crate_config_values(target_info: support.target_info.TargetInfo):
    return {
        f"{target_info.runtime_crate_name}.Stack_Guard": True,
        f"{target_info.runtime_crate_name}.Stack_Guard_Bytes": 256,
    }


def source_dirs(target_info: support.target_info.TargetInfo):
    # The hand-over to _start_rom, shared with the other hand-over tests.
    return ["../../support/handover"]
