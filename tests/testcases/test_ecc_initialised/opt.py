import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The ECC initialisation is part of the stm32h7xx start-up in every profile.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def source_dirs(target_info: support.target_info.TargetInfo):
    # The ECC probe, shared with the other ECC tests.
    return ["../../support/ecc_probe"]
