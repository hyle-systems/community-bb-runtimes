"""Board-less check of the GDB interface's constructor: when it raises after
starting GDB (the server refused the connection, say), it must shut GDB down
before letting the exception out.

Run with ``pytest test_harness_gdb_constructor.py`` from ``tests/``; no board,
no toolchain needed.
"""
import pathlib
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import support.target_interface as target_interface  # noqa: E402


class FakeController:
    """pygdbmi's controller as the constructor sees it: answers nothing,
    remembers whether it was told to exit."""

    instances = []

    def __init__(self, *args, **kwargs):
        self.exited = False
        FakeController.instances.append(self)

    def get_gdb_response(self, timeout_sec=None, raise_error_on_timeout=True):
        return []

    def write(self, *args, **kwargs):
        return []

    def exit(self):
        self.exited = True


def test_gdb_constructor_failure_shuts_the_debugger_down(monkeypatch, tmp_path):
    """The `with` block's clean-up never runs for a constructor that raised,
    so GDB stayed alive holding the ELF (on Windows the temporary directory's
    removal then fails with a permission error that buries the cause)."""
    FakeController.instances.clear()
    monkeypatch.setattr(target_interface, "find_gdb", lambda crate, prefix: tmp_path / "arm-eabi-gdb")
    monkeypatch.setattr(target_interface.pygdbmi.gdbcontroller, "GdbController", FakeController)

    def refused(self, timeout_sec=None):
        raise RuntimeError("connection refused")

    monkeypatch.setattr(target_interface.GdbTargetInterface, "_wait_for_result", refused)
    with pytest.raises(RuntimeError, match="connection refused"):
        target_interface.GdbTargetInterface(tmp_path, tmp_path / "test", 3333, None)
    assert FakeController.instances and FakeController.instances[0].exited, "GDB was left running"
