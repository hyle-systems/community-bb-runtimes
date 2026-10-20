import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # test_ecc_initialised linked for the RAM loader: the start-up must still initialise the ECC of
    # the AXI SRAM above the loaded image (the probe uses the last kilobyte).
    if target_info.target != "stm32h7xx":
        pytest.skip(f"Test requires target 'stm32h7xx'")


def build_args(target_info: support.target_info.TargetInfo):
    return ["-XLOADER=RAM"]
