import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The check is the tasking runtime's.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if not target_info.has_libgnarl:
        pytest.skip(f"Test requires a runtime with libgnarl")
    if target_info.runtime_profile == "embedded":
        pytest.skip("embedded parks instead of reporting: test_guard_not_armed_park")


def crate_config_values(target_info: support.target_info.TargetInfo):
    return {f"{target_info.runtime_crate_name}.Stack_Guard": True}


def linker_switches(target_info: support.target_info.TargetInfo):
    # After the crate's own --defsym; a user linker script that dropped the crate's symbol has the same effect.
    return ["-Wl,--defsym=__stack_guard_bytes=8"]


def source_dirs(target_info: support.target_info.TargetInfo):
    # The shared last-chance handler (tests/support), in the shape each profile's runtime calls it.
    return ["../../support/lch_embedded"] if target_info.runtime_profile == "embedded" else ["../../support/lch_light"]
