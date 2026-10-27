"""Board-less check of the GDB interface's result wait: a GDB ^error record
(a monitor command the server refused, such as a flash write that failed)
must stop the test instead of being taken for success.

Run with ``pytest test_harness_gdb_error.py`` from ``tests/``; no board, no
toolchain needed.
"""
import pathlib
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import support.target_interface as target_interface  # noqa: E402


class FakeGdb:
    """Stands in for pygdbmi's controller: hands out canned response lists."""

    def __init__(self, responses):
        self._responses = list(responses)

    def get_gdb_response(self, timeout_sec=None, raise_error_on_timeout=True):
        return self._responses.pop(0) if self._responses else []


def interface_with(responses):
    tif = target_interface.GdbTargetInterface.__new__(target_interface.GdbTargetInterface)
    tif.gdb = FakeGdb(responses)
    return tif


def test_gdb_error_record_raises():
    """Without the raise, a failed flash write was followed by a run of
    whatever image was already in flash."""
    tif = interface_with([[{"type": "result", "message": "error", "payload": {"msg": "boom"}}]])
    with pytest.raises(target_interface.GdbCommandError, match="boom"):
        tif._wait_for_result(timeout_sec=1.0)


def test_gdb_done_record_returns():
    tif = interface_with([[{"type": "result", "message": "done", "payload": None}]])
    assert tif._wait_for_result(timeout_sec=1.0)["message"] == "done"
