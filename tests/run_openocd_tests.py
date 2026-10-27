#!/usr/bin/env python3
"""Run the on-target tests one at a time through OpenOCD, restarting OpenOCD before
every test.

OpenOCD (0.12.0) exits when the harness drops the semihosting TCP connection at the
end of a test, so a single OpenOCD instance cannot serve a whole pytest run. This
script starts OpenOCD with semihosting redirected to a TCP port, runs one
test_execute_on_target testcase against it, stops OpenOCD, and repeats.

It connects with reset asserted and halts the core at reset before GDB arrives:
a target that sleeps in WFI with the debug clock gated (a Ravenscar idle loop)
cannot be examined otherwise.

Usage:
    python run_openocd_tests.py --target stm32g4xx --profile light-tasking
    python run_openocd_tests.py --target stm32g4xx --profile embedded hello_world task_delays

The OpenOCD executable is taken from --openocd, else from the OPENOCD environment
variable, else from the PATH.
"""
import argparse
import importlib.util
import os
import pathlib
import re
import shlex
import socket
import shutil
import subprocess
import sys
import time

TESTS_DIR = pathlib.Path(__file__).resolve().parent

TARGET_CFG = {
    "stm32f0xx": "target/stm32f0x.cfg",
    "stm32g0xx": "target/stm32g0x.cfg",
    "stm32g4xx": "target/stm32g4x.cfg",
    "stm32f4xx": "target/stm32f4x.cfg",
    "stm32h7xx": "target/stm32h7x.cfg",
}

DEFAULT_TESTCASES = [
    "hello_world",
    "task_delays",
    "test_interrupts",
    "test_interrupt_nesting",
    "single_floating_point",
    "double_floating_point",
    "heap_alloc",
    "test_exceptions",
    "test_crate_using_runtime",
]

# A target's own testcases, run after the generic list when no testcase is named on the command line
# (test_harness_units.py checks the list against the testcases that require the target).
FAMILY_TESTCASES = {
    "stm32h7xx": [
        "test_guard_off",
        "test_guard_regions",
        "test_fault_bus",
        "test_fault_usage",
        "test_fault_escalated",
        "test_ecc_initialised",
        "test_tcm_sharing",
        "test_supply_config",
        "test_memory_map",
        "test_ram_loader",
        "test_ecc_initialised_ram",
        "test_startup_state",
        "test_vector_last",
        "test_stack_alignment",
        "test_fpu_context",
        "test_interrupt_stack_size",
        "test_timer_clock",
        "test_dma_cache",
        "test_bsp_verifier",
        "test_clock_reference",
        "test_clock_point_400",
        "test_clock_point_170",
        "test_clock_hsi64",
        "test_stack_check",
        "test_stack_check_margin",
        "test_stack_check_with_guard",
        "test_guard_map",
        "test_guard_taskless",
        "test_guard_taskless_hit",
        "test_fault_stack_default",
        "test_fault_stack_use",
        "test_fault_in_handler",
        "test_fault_in_fault",
        "test_guard_switch",
        "test_fault_fpu_lazy",
        "test_guard_taskless_faultstack",
        "test_guard_idle",
        "test_clock_point_32",
        "test_clock_point_st",
        "test_clock_csi",
        "test_ecc_survey",   # skips itself unless ECC_SURVEY=1: meaningful right after a power cycle only
        "test_guard_switch_twice",
        "test_guard_small_task",
        "test_handover_pll",
        "test_handover_dcache",
        "test_handover_state",
        "test_handover_regions",
        "test_fault_default_lch",
        "test_fault_stack_use_alloc",
        "test_guard_rnr",
        "test_guard_app_region",
        "test_nmi_hook",
        "test_fault_nmi",
        "test_sram_init",
        "test_clock_point_m3",
        "test_ceiling_masking",
        "test_dma_sram12",
        "test_dma_sram4",
        "test_clock_cycles",
    ],
}



def start_openocd(openocd: str, target: str, gdb_port: int, sh_port: int, log: pathlib.Path,
                  telnet_port: int = 4444):
    cmd = [
        openocd,
        "-f", "interface/stlink.cfg",
        "-f", TARGET_CFG[target],
        "-c", f"gdb_port {gdb_port}",
        "-c", f"telnet_port {telnet_port}",
        "-c", "reset_config srst_only srst_nogate connect_assert_srst",
        "-c", "init",
        "-c", "reset halt",
        "-c", "arm semihosting enable",
        "-c", f"arm semihosting_redirect tcp {sh_port}",
    ]
    with open(log, "w") as f:
        p = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT)
    return wait_for_openocd(p, log, sh_port)


def wait_for_openocd(p, log: pathlib.Path, sh_port: int, timeout: float = 15.0):
    """Wait for the server's ready line (the semihosting port open) in its log. A server that dies
    reports so; one that never comes up is killed before the error, so it does not hold the ports
    for every test after it."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        time.sleep(0.3)
        if p.poll() is not None:
            break
        if f"Listening on port {sh_port}" in log.read_text(errors="replace"):
            return p
    if p.poll() is None:
        p.kill()
        p.wait()
    raise RuntimeError(f"OpenOCD did not come up; see {log}")


def stop_openocd(p, graceful=False, quiesce=True, telnet_port=4444):
    """Stop OpenOCD between tests. The default is the hard kill the harness
    always used: a clean "shutdown" over the telnet port was tried
    after an ST-LINK V3 wedged (probe answering V0J8S3, VID:PID
    0000:0000, until replugged) and the wedges became more frequent, not
    less - OpenOCD's exit sequence on the probe is the suspect. Kept as an
    option for experiments. The default now first turns the target
    polling off over the telnet port and waits a moment, so the probe is
    idle when the process dies (two more wedges came right after a passing
    test, between the kill and the next start)."""
    if p.poll() is not None:
        return
    if quiesce and not graceful:
        try:
            with socket.create_connection(("localhost", telnet_port), timeout=2) as s:
                s.sendall(b"poll off\n")
                time.sleep(0.3)
        except OSError:
            pass
    if graceful:
        try:
            with socket.create_connection(("localhost", telnet_port), timeout=2) as s:
                s.sendall(b"shutdown\n")
        except OSError:
            pass
        try:
            p.wait(timeout=5)
            return
        except subprocess.TimeoutExpired:
            pass
    p.kill()
    p.wait()


def openocd_commands(commands, telnet_port=4444, timeout=5.0):
    """Send commands to OpenOCD's telnet port, one at a time, and return what it answered (the target
    halted first by the caller's own "halt" when it needs one). Empty when the port does not answer."""
    out = []
    try:
        with socket.create_connection(("localhost", telnet_port), timeout=timeout) as s:
            s.settimeout(0.5)

            def drain():
                data = b""
                end = time.time() + timeout
                while time.time() < end:
                    try:
                        chunk = s.recv(4096)
                    except socket.timeout:
                        if data.rstrip().endswith(b">"):
                            break
                        continue
                    if not chunk:
                        break
                    data += chunk
                    if data.rstrip().endswith(b">"):
                        break
                return data.decode(errors="replace")

            drain()   # the banner and prompt
            for cmd in commands:
                s.sendall(cmd.encode() + b"\n")
                out.append(drain())
    except OSError as e:
        out.append(f"(telnet: {e})")
    return out


# The core's state after a failure: where it stopped and why (PM0253 4.3.10 - 4.3.14, the debug halting
# control and status register 0xE000EDF0: S_LOCKUP bit 19)
DIAGNOSTICS = [
    "halt",
    "reg pc",
    "reg xpsr",
    "reg lr",
    "reg msp",
    "reg psp",
    "mdw 0xE000ED28 1",   # CFSR
    "mdw 0xE000ED2C 1",   # HFSR
    "mdw 0xE000ED34 1",   # MMFAR
    "mdw 0xE000ED38 1",   # BFAR
    "mdw 0xE000EDF0 1",   # DHCSR
]


def read_word(answer: str):
    """The value of an OpenOCD "mdw <addr> 1" answer, or None."""
    m = re.search(r"0x[0-9a-fA-F]+:\s+([0-9a-fA-F]{8})", answer)
    return int(m.group(1), 16) if m else None


def read_reg(answer: str):
    """The value of an OpenOCD "reg <name>" answer, or None."""
    m = re.search(r"\(/32\):\s*0x([0-9a-fA-F]+)", answer)
    return int(m.group(1), 16) if m else None


def load_core_checks(tc: str):
    """A testcase's opt.py may define core_checks(): what the core's state must be once the program's
    output has been read - a list of (description, kind, address or register, mask, expected values),
    kind "mem" or "reg". Checked with the core halted after a passing run."""
    opt = TESTS_DIR / "testcases" / tc / "opt.py"
    if not opt.exists():
        return []
    spec = importlib.util.spec_from_file_location(f"opt_{tc}", opt)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return list(mod.core_checks()) if hasattr(mod, "core_checks") else []


def run_core_checks(checks, telnet_port):
    """Halt the core and check each item; returns the failures (empty when all hold)."""
    failures = []
    answers = openocd_commands(["halt"] + [f"mdw {a:#x} 1" if k == "mem" else f"reg {a}"
                                           for _, k, a, _, _ in checks], telnet_port)
    for (desc, kind, _, mask, expected), answer in zip(checks, answers[1:]):
        value = read_word(answer) if kind == "mem" else read_reg(answer)
        if value is None or (value & mask) not in expected:
            failures.append(f"{desc}: read {value if value is None else hex(value)}")
    return failures


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--target", required=True, choices=TARGET_CFG.keys())
    ap.add_argument("--profile", required=True, choices=["light", "light-tasking", "embedded"])
    ap.add_argument("--openocd", default=os.environ.get("OPENOCD") or shutil.which("openocd"))
    ap.add_argument("--gdb-port", type=int, default=3333)
    ap.add_argument("--semihosting-port", type=int, default=4445)
    ap.add_argument("--telnet-port", type=int, default=4444, help="OpenOCD's telnet port, used to quiesce the target before the kill")
    ap.add_argument("--working-dir", default=None, help="passed to pytest --working-dir")
    ap.add_argument("--log-dir", default=None, help="where the per-test logs go (default: <working-dir>/openocd-runs)")
    ap.add_argument("--pytest-args", default="",
                    help="extra arguments for pytest, replacing the default \"-q --tb=line\" (e.g. \"-vv --tb=short --keep-build-files\" to see a failing comparison in full)")
    ap.add_argument("--test-timeout", type=float, default=900.0,
                    help="seconds one test (build, load, run) may take before it is stopped and counted as TIMEOUT")
    ap.add_argument("testcases", nargs="*", default=None,
                    help="testcases to run (default: the generic list plus the target's own)")
    args = ap.parse_args()
    testcases = args.testcases or DEFAULT_TESTCASES + FAMILY_TESTCASES.get(args.target, [])

    if not args.openocd:
        sys.exit("openocd not found: pass --openocd, set OPENOCD, or put it on the PATH")

    log_dir = pathlib.Path(args.log_dir) if args.log_dir else pathlib.Path(args.working_dir or ".") / "openocd-runs"
    log_dir.mkdir(parents=True, exist_ok=True)

    results = []
    for tc in testcases:
        test_id = f"test_runtimes.py::test_execute_on_target[{tc}_{args.profile}-{args.target}_]"
        log = log_dir / f"openocd_{tc}_{args.profile}.log"
        t0 = time.time()
        try:
            p = start_openocd(args.openocd, args.target, args.gdb_port, args.semihosting_port, log,
                              args.telnet_port)
        except RuntimeError as e:
            print(e)
            results.append((tc, "NO-OPENOCD"))
            continue

        pytest_cmd = [
            sys.executable, "-m", "pytest", test_id,
            f"--target-board={args.target}",
            "--target-if=openocd-gdbserver",
            f"--gdbserver-port={args.gdb_port}",
            f"--text-io-port={args.semihosting_port}",
            "-p", "no:cacheprovider",
        ]
        pytest_cmd += shlex.split(args.pytest_args) if args.pytest_args else ["-q", "--tb=line"]
        if args.working_dir:
            pytest_cmd.append(f"--working-dir={args.working_dir}")

        try:
            r = subprocess.run(pytest_cmd, cwd=TESTS_DIR, capture_output=True, text=True,
                               timeout=args.test_timeout)
            out = r.stdout + r.stderr
            returncode = r.returncode
        except subprocess.TimeoutExpired as e:
            out = ((e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")) \
                + f"\nTIMEOUT after {args.test_timeout:.0f} s\n"
            returncode = None

        summary = out.strip().splitlines()[-1] if out.strip() else ""   # pytest's "=== 1 skipped in 3.2s ==="
        if returncode is None:
            verdict = "TIMEOUT"
        elif returncode != 0:
            verdict = "FAIL"
        elif re.search(r"\b\d+ skipped\b", summary):
            verdict = "SKIP"
        else:
            verdict = "PASS"

        # A passing run's core checks (opt.py core_checks); after a failure, the core's state for the log
        if verdict == "PASS":
            checks = load_core_checks(tc)
            if checks:
                failures = run_core_checks(checks, args.telnet_port)
                out += "\ncore checks: " + ("all hold" if not failures else "; ".join(failures)) + "\n"
                if failures:
                    verdict = "FAIL"
        if verdict in ("FAIL", "TIMEOUT"):
            answers = openocd_commands(DIAGNOSTICS, args.telnet_port)
            out += "\n--- the core after the failure ---\n" + "".join(
                f"> {c}\n{a.strip()}\n" for c, a in zip(DIAGNOSTICS, answers))
        stop_openocd(p, telnet_port=args.telnet_port)
        (log_dir / f"pytest_{tc}_{args.profile}.log").write_text(out, errors="replace")
        results.append((tc, verdict))
        print(f"{verdict:5} {tc:28} {time.time() - t0:5.1f} s", flush=True)

    print(f"\n=== {args.target} {args.profile}: "
          f"{sum(v == 'PASS' for _, v in results)} passed, "
          f"{sum(v == 'SKIP' for _, v in results)} skipped, "
          f"{sum(v not in ('PASS', 'SKIP') for _, v in results)} failed")
    sys.exit(0 if all(v in ("PASS", "SKIP") for _, v in results) else 1)


if __name__ == "__main__":
    main()
