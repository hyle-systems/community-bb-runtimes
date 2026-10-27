import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # Build-only: the flash-overflow rows of test_negative_builds.py build this program
    # against the 128 KB map (must fail) and the default map (must link).
    pytest.skip("build-only testcase for test_negative_builds.py")
