"""Board-less check of the st-util interface's output reader: the
semihosting text st-util writes to its stderr pipe must be readable on
every host, Windows included (where select() takes sockets only).

A child Python process stands in for st-util and GDB is not started.

Run with ``pytest test_harness_stutil_io.py`` from ``tests/``; no board, no
toolchain needed.
"""
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import support.target_interface as target_interface  # noqa: E402

FAKE_STUTIL = (
    "import sys, time; sys.stderr.write('hello'); sys.stderr.flush(); time.sleep(10)"
)


def test_stutil_output_is_read(monkeypatch, tmp_path):
    real_popen = subprocess.Popen

    def fake_popen(args, **kwargs):
        assert args[0] == "st-util"
        return real_popen([sys.executable, "-c", FAKE_STUTIL], **kwargs)

    monkeypatch.setattr(target_interface.subprocess, "Popen", fake_popen)
    monkeypatch.setattr(target_interface.GdbTargetInterface, "__init__", lambda self, **kwargs: None)
    monkeypatch.setattr(target_interface.GdbTargetInterface, "shutdown", lambda self: None)

    tif = target_interface.StUtilInterface(tmp_path, tmp_path / "test", 4242, None)
    try:
        data = bytes()
        for _ in range(20):
            data += tif.read_io(timeout=0.5)
            if b"hello" in data:
                break
        assert b"hello" in data
    finally:
        tif.stutil.kill()
        tif.shutdown()
