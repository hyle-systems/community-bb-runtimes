import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    pytest.skip("build-only testcase for test_negative_builds.py")
