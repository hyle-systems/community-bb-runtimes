import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The NMI vector's routing is the stm32h7xx family's (all profiles).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def source_dirs(target_info: support.target_info.TargetInfo):
    # The shared last-chance handler (tests/support), in the shape each profile's runtime calls it.
    return ["../../support/lch_embedded"] if target_info.runtime_profile == "embedded" else ["../../support/lch_light"]
