import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The fault report and its guard are the family's, in every profile.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def source_dirs(target_info: support.target_info.TargetInfo):
    # The test's own last-chance handler, in the shape each profile's runtime calls it; it
    # counts its entries, prints, then faults on purpose.
    return ["lch_embedded"] if target_info.runtime_profile == "embedded" else ["lch_light"]
