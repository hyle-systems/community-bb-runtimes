import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # Embedded's fault path runs in handler mode on the interrupt stack: the
    # measurement is of that profile (light-tasking's handler is a direct call).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if target_info.runtime_profile != "embedded":
        pytest.skip(f"Test measures the embedded profile")


def crate_config_values(target_info: support.target_info.TargetInfo):
    # Room to measure in: an 8 KB fault stack, the guard off (the default)
    return {
        f"{target_info.runtime_crate_name}.Fault_Stack_Size": 8192,
    }


def source_dirs(target_info: support.target_info.TargetInfo):
    return ["lch_embedded"]
