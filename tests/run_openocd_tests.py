#!/usr/bin/env python3
"""Run the test_execute_on_target testcases one at a time, each against a fresh OpenOCD instance.

Usage:
    python run_openocd_tests.py --target stm32g4xx --profile light-tasking
    python run_openocd_tests.py --target stm32g4xx --profile embedded hello_world task_delays
OpenOCD is taken from --openocd, else from the OPENOCD environment variable, else from the PATH.
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

# Each target's own testcases (every testcase whose opt.py requires the target), run after the generic list.
FAMILY_TESTCASES = {
    "stm32h7xx": [
        "test_guard_off",
        "test_guard_regions",
        "test_fault_bus",
        "test_fault_usage",
        "test_fault_escalated",
        "test_ecc_initialised",
        "test_ecc_initialised_ram",   # must follow its ROM twin, whose run leaves the probe words non-zero
        "test_tcm_sharing",
        "test_supply_config",
        "test_memory_map",
        "test_ram_loader",
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
        "test_ecc_survey",   # skips itself unless ECC_SURVEY=1; only meaningful right after a power cycle
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
        "test_guard_fp_frame",
        "test_fault_svc",
        "test_fault_cause_stale",
        "test_interrupt_id_range",
        "test_clock_point_q",
        "test_handover_in_handler",
        "test_handover_unprivileged",
        "test_fault_cause_usage",
        "test_guard_not_armed",
        "test_guard_not_armed_park",
    ],
}


def start_openocd(openocd: str, target: str, gdb_port: int, sh_port: int, log: pathlib.Path,
                  telnet_port: int = 4444):
    """Start OpenOCD with semihosting redirected to a TCP port, and wait until it is ready.

    One instance per test: with OpenOCD 0.12.0 a single instance did not always survive a whole pytest run (it
    sometimes exited when the harness closed the semihosting connection at the end of a test).

    OpenOCD connects with reset asserted and halts the core at reset before GDB connects. A target that
    sleeps in WFI with the debug clock gated (a Ravenscar idle loop) cannot be examined otherwise."""
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
    """Wait until the server's log says the semihosting port is open, else raise RuntimeError. A server
    still running then is killed first, or it would hold the ports for every later test."""
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


def stop_openocd(p, telnet_port=4444):
    """Stop OpenOCD between tests.

    The process is killed after "poll off" over the telnet port and a 0.3 s pause, so that the probe is idle
    when it dies: without the pause an ST-LINK V3 wedged twice between a passing test's kill and the next start
    (a wedged probe answers as V0J8S3, VID:PID 0000:0000, until replugged). A telnet "shutdown" made the wedges
    more frequent (OpenOCD's exit sequence on the probe is the suspect)."""
    if p.poll() is not None:
        return
    try:
        with socket.create_connection(("localhost", telnet_port), timeout=2) as s:
            s.sendall(b"poll off\n")
            time.sleep(0.3)
    except OSError:
        pass
    p.kill()
    p.wait()


def openocd_commands(commands, telnet_port=4444, timeout=5.0):
    """Send commands to OpenOCD's telnet port one at a time and return its answers, one per command.
    A command that needs a halted target needs a "halt" before it in the list. An answer is empty when
    OpenOCD does not reply in time, and a connection error ends the list with a "(telnet: ...)" entry."""
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


# What the runner logs about the core after a failure: where it stopped and why (the fault status registers:
# PM0253 4.3.10 to 4.3.14). DHCSR is read after the halt, which clears S_LOCKUP (see run_core_checks).
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
    """Return the value in OpenOCD's answer to "mdw <addr> 1", or None."""
    m = re.search(r"0x[0-9a-fA-F]+:\s+([0-9a-fA-F]{8})", answer)
    return int(m.group(1), 16) if m else None


def read_reg(answer: str):
    """Return the value in OpenOCD's answer to "reg <name>" (e.g. "xpsr (/32): 0x...", "control (/8): 0x01"),
    or None."""
    m = re.search(r"\(/\d+\):\s*0x([0-9a-fA-F]+)", answer)
    return int(m.group(1), 16) if m else None


def load_core_checks(tc: str):
    """Return the testcase's core checks, or an empty list: its opt.py's core_checks(), the state the core
    must be in once the program's output has been read, as a list of (description, kind, address or register,
    mask, expected values), where kind is "mem" or "reg"."""
    opt = TESTS_DIR / "testcases" / tc / "opt.py"
    if not opt.exists():
        return []
    spec = importlib.util.spec_from_file_location(f"opt_{tc}", opt)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return list(mod.core_checks()) if hasattr(mod, "core_checks") else []


def run_core_checks(checks, telnet_port):
    """Run the checks and return the failures, an empty list when all hold.

    DHCSR's S_LOCKUP bit (bit 19) clears when the core enters debug state (ARMv7-M ARM C1.6.3), and GDB's exit
    at the end of the test has halted the core. The memory checks therefore resume the core and wait 200 ms
    before reading: in that time a parked core spins in its loop again, and a locked-up one locks up again at
    once. A check without a readable answer fails too, since it proves nothing: as "not run" when answers are
    missing (the telnet connection failed), as "read None" when its answer is empty or unreadable."""
    mem = [c for c in checks if c[1] == "mem"]
    reg = [c for c in checks if c[1] != "mem"]
    failures = []
    if mem:
        answers = openocd_commands(["resume", "sleep 200"] + [f"mdw {a:#x} 1" for _, _, a, _, _ in mem],
                                   telnet_port)
        failures += _judge(mem, answers[2:] if len(answers) == len(mem) + 2 else [], read_word)
    if reg:
        answers = openocd_commands(["halt"] + [f"reg {a}" for _, _, a, _, _ in reg], telnet_port)
        failures += _judge(reg, answers[1:] if len(answers) == len(reg) + 1 else [], read_reg)
    return failures


def openocd_saw_lockup(log):
    """Return True when OpenOCD's log records a locked-up core. OpenOCD's poller halts such a core itself
    ("clearing lockup after double fault"), which clears DHCSR.S_LOCKUP, so the log is where a lockup shows."""
    try:
        return "clearing lockup" in pathlib.Path(log).read_text(errors="replace")
    except OSError:
        return False


def _judge(checks, answers, read):
    if len(answers) != len(checks):
        return [f"{desc}: not run (no answer)" for desc, _, _, _, _ in checks]
    failures = []
    for (desc, _, _, mask, expected), answer in zip(checks, answers):
        value = read(answer)
        if value is None or (value & mask) not in expected:
            failures.append(f"{desc}: read {value if value is None else hex(value)}")
    return failures


# The testcases of the default list that skip on each profile through their own opt.py conditions. A skip of
# any other testcase is a failure, and so is a run of one listed here; otherwise an opt.py condition gone wrong
# would count as a pass.
_H7_LIGHT_SKIPS = {
    "task_delays", "test_interrupts", "test_interrupt_nesting", "test_exceptions", "test_crate_using_runtime",
    "test_guard_off", "test_guard_regions", "test_vector_last", "test_stack_alignment", "test_fpu_context",
    "test_interrupt_stack_size", "test_timer_clock", "test_bsp_verifier", "test_clock_reference",
    "test_clock_point_400", "test_clock_point_170", "test_clock_hsi64", "test_stack_check", "test_stack_check_margin",
    "test_stack_check_with_guard", "test_guard_map", "test_guard_taskless", "test_guard_taskless_hit",
    "test_fault_stack_default", "test_fault_stack_use", "test_fault_in_handler", "test_guard_switch",
    "test_fault_fpu_lazy", "test_guard_taskless_faultstack", "test_guard_idle", "test_clock_point_32",
    "test_clock_point_st", "test_clock_csi", "test_ecc_survey", "test_guard_switch_twice", "test_guard_small_task",
    "test_handover_pll", "test_handover_regions", "test_fault_default_lch", "test_fault_stack_use_alloc",
    "test_guard_rnr", "test_guard_app_region", "test_clock_point_m3", "test_ceiling_masking",
    "test_guard_fp_frame", "test_interrupt_id_range", "test_guard_not_armed", "test_guard_not_armed_park",
}
EXPECTED_SKIPS = {
    "stm32h7xx": {
        "light": _H7_LIGHT_SKIPS,
        "light-tasking": {"test_exceptions", "test_fault_stack_use", "test_ecc_survey", "test_fault_default_lch",
                          "test_fault_stack_use_alloc", "test_guard_not_armed_park"},
        "embedded": {"test_guard_taskless_faultstack", "test_ecc_survey", "test_guard_not_armed"},
    },
}


def skip_verdict(target, profile, tc, verdict):
    """Return the verdict checked against the table of expected skips. A target without a table keeps it."""
    table = EXPECTED_SKIPS.get(target, {}).get(profile)
    if table is None:
        return verdict
    if os.environ.get("ECC_SURVEY") == "1":
        table = table - {"test_ecc_survey"}   # asked for, so it runs (test_ecc_survey/opt.py)
    if verdict == "SKIP" and tc not in table:
        return "FAIL"
    if verdict == "PASS" and tc in table:
        return "FAIL"
    return verdict


def run_with_timeout(cmd, cwd, timeout, env=None):
    """Run cmd and return its output and exit status. The status is None when the timeout stopped it.

    The output goes to a file, not a pipe: the processes cmd starts (alr, gprbuild, the compiler, GDB) inherit
    it, and with a pipe the wait after a kill would last until the last of them had exited (on Windows,
    subprocess.run reads the pipe to its end). On a timeout, or when the runner itself is interrupted (Ctrl-C,
    re-raised after), the whole tree is stopped: taskkill /T on Windows, the process group elsewhere."""
    import tempfile
    with tempfile.TemporaryFile() as f:
        if os.name == "nt":
            proc = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=f, stderr=subprocess.STDOUT,
                                    creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
        else:
            proc = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=f, stderr=subprocess.STDOUT,
                                    start_new_session=True)
        timed_out = False
        try:
            returncode = proc.wait(timeout=timeout)
        except BaseException as e:
            if os.name == "nt":
                subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)
            else:
                import signal
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            proc.wait()
            if not isinstance(e, subprocess.TimeoutExpired):
                raise
            timed_out = True
            returncode = None
        f.seek(0)
        out = f.read().decode(errors="replace")
    if timed_out:
        out += f"\nTIMEOUT after {timeout:.0f} s\n"
    return out, returncode


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
    if args.working_dir:
        # pytest runs from tests/, the runner from anywhere: one absolute path keeps logs and builds together
        args.working_dir = os.path.abspath(args.working_dir)
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
            "--private-runtime-builds",
            "-p", "no:cacheprovider",
        ]
        # On Windows the backslashes are doubled first, so that shlex keeps a path's C:\w as it is
        extra = args.pytest_args.replace("\\", "\\\\") if os.name == "nt" else args.pytest_args
        pytest_cmd += shlex.split(extra) if extra else ["-q", "--tb=line"]
        if args.working_dir:
            pytest_cmd.append(f"--working-dir={args.working_dir}")

        # An error or a Ctrl-C must not leave OpenOCD holding the probe and the ports for the next run
        try:
            out, returncode = run_with_timeout(pytest_cmd, cwd=TESTS_DIR, timeout=args.test_timeout,
                                               env=dict(os.environ, RUN_OPENOCD_TESTS="1"))

            summary = out.strip().splitlines()[-1] if out.strip() else ""   # e.g. "=== 1 skipped in 3.2s ==="
            if returncode is None:
                verdict = "TIMEOUT"
            elif returncode != 0:
                verdict = "FAIL"
            elif re.search(r"\b\d+ skipped\b", summary):
                verdict = "SKIP"
            else:
                verdict = "PASS"

            checked = skip_verdict(args.target, args.profile, tc, verdict)
            if checked != verdict:
                out += f"\nverdict {verdict}, but the table of expected skips says otherwise for {args.profile}\n"
                verdict = checked

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
        finally:
            stop_openocd(p, telnet_port=args.telnet_port)
        if verdict in ("PASS", "SKIP") and openocd_saw_lockup(log):
            out += "\nthe core locked up during the test (OpenOCD: clearing lockup after double fault)\n"
            verdict = "FAIL"
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
