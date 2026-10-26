import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # Build-only: the Z2 rows of test_negative_builds.py link this program (an initialised .axisram beyond, or
    # within, what the start-up's copy loop can count).
    pytest.skip("build-only testcase for test_negative_builds.py")
