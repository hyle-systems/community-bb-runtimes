import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")
    if target_info.runtime_profile != "light_tasking":
        pytest.skip("light-tasking only: embedded floors the fault stack at 2 KB, light has no guard")


def crate_config_values(target_info: support.target_info.TargetInfo):
    return {
        f"{target_info.runtime_crate_name}.Stack_Guard": True,
        f"{target_info.runtime_crate_name}.Stack_Guard_Bytes": 512,
        f"{target_info.runtime_crate_name}.Fault_Stack_Size": 512,
    }


def source_dirs(target_info: support.target_info.TargetInfo):
    return ["lch_embedded"] if target_info.runtime_profile == "embedded" else ["lch_light"]
