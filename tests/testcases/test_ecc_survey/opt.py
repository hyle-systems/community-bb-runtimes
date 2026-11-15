import os

import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # The monitors are the STM32H72x/H73x's.
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")
    if os.environ.get("ECC_SURVEY") != "1":
        pytest.skip("The ECC survey is meaningful only right after a power cycle; set ECC_SURVEY=1 to run it")


def source_dirs(target_info: support.target_info.TargetInfo):
    # The ECC probe, shared with the other ECC tests.
    return ["../../support/ecc_probe"]
