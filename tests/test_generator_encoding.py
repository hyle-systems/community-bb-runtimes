"""Board-less check that the generator reads and writes its templates as
UTF-8 whatever the host's locale (Windows defaults to cp1252).

Run with ``pytest test_generator_encoding.py`` from ``tests/``; no board, no
toolchain needed.
"""
import importlib.util
import pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent


def load_patch_runtime():
    spec = importlib.util.spec_from_file_location("patch_runtime", REPO / "patch-runtime.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_template_with_non_ascii_text(tmp_path):
    """A UTF-8 template holding characters outside cp1252 (here U+0401 and
    U+2192) failed or came out garbled on Windows."""
    patch_runtime = load_patch_runtime()
    text = "description = \"Ё → $(target)\"\n"
    template = tmp_path / "alire.toml.in"
    template.write_bytes(text.encode("utf-8"))
    out = tmp_path / "alire.toml"
    patch_runtime.gen_from_template(template, out, {"target": "stm32g4xx"})
    assert out.read_bytes() == text.replace("$(target)", "stm32g4xx").encode("utf-8")
