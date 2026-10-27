"""Board-less check of the GDB interface's monitor commands: the timeout the
caller gives must reach the wait for GDB's answer.

Run with ``pytest test_harness_monitor_timeout.py`` from ``tests/``; no
board, no toolchain needed.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import support.target_interface as target_interface  # noqa: E402


def test_monitor_command_passes_its_timeout(monkeypatch):
    """A flash write longer than pygdbmi's default timeout was reported as a
    timeout whatever the caller asked for."""
    seen = []
    tif = target_interface.GdbTargetInterface.__new__(target_interface.GdbTargetInterface)
    monkeypatch.setattr(tif, "_write", lambda *args, **kwargs: None, raising=False)
    monkeypatch.setattr(
        tif, "_wait_for_result",
        lambda timeout_sec=None: seen.append(timeout_sec) or {"message": "done"},
        raising=False)
    tif.monitor_command("flash write_image erase test.elf", timeout_sec=42.0)
    assert seen == [42.0]
