import support.target_info
import pytest


def check_test_conditions(target_info: support.target_info.TargetInfo):
    # Build-only: a row of test_negative_builds.py links this program (200 KB of zero-only buffer in
    # .axisram_bss, which takes no flash).
    pytest.skip("build-only testcase for test_negative_builds.py")
