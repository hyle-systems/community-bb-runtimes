"""Board-less check of the configuration merge: a value for a variable the
runtime crate does not declare must be refused, not dropped.

Run with ``pytest test_harness_config_values.py`` from ``tests/``; no board,
no toolchain needed.
"""
import pathlib
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import support.target_info as target_info  # noqa: E402

DECLARED = {"Time_Base": {"type": "Enum", "values": ["RTC0", "RTC1"], "default": "RTC0"}}


def test_declared_key_is_applied():
    assert target_info.get_config_values(DECLARED, {"Time_Base": "RTC1"}) == {"Time_Base": "RTC1"}


def test_undeclared_key_is_refused():
    """The merge iterated the declared variables only, so a misspelt key was
    dropped and the default built: the test then reported on a configuration
    it never compiled. Alire itself refuses unknown variables."""
    with pytest.raises(ValueError, match="Time_Bsae"):
        target_info.get_config_values(DECLARED, {"Time_Bsae": "RTC1"})
