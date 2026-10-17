import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # Fault routing into the last-chance handler is part of the stm32h7xx family's start-up:
    # every profile, tasking or not.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def source_dirs(target_info: support.target_info.TargetInfo):
    # The test's own last-chance handler, in the shape each profile's runtime calls it:
    # (Msg, Line) in light and light-tasking, an Exception_Occurrence in embedded.
    return ["lch_embedded"] if target_info.runtime_profile == "embedded" else ["lch_light"]
