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
import os
import pathlib
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
        # the fourth review's testcases
        "test_guard_switch_twice",
        "test_guard_small_task",
        "test_handover_pll",
        "test_handover_dcache",
        "test_handover_state",
        "test_handover_regions",
        "test_fault_default_lch",
    ],
}



def start_openocd(openocd: str, target: str, gdb_port: int, sh_port: int, log: pathlib.Path):
    cmd = [
        openocd,
        "-f", "interface/stlink.cfg",
        "-f", TARGET_CFG[target],
        "-c", f"gdb_port {gdb_port}",
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


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--target", required=True, choices=TARGET_CFG.keys())
    ap.add_argument("--profile", required=True, choices=["light", "light-tasking", "embedded"])
    ap.add_argument("--openocd", default=os.environ.get("OPENOCD") or shutil.which("openocd"))
    ap.add_argument("--gdb-port", type=int, default=3333)
    ap.add_argument("--semihosting-port", type=int, default=4445)
    ap.add_argument("--working-dir", default=None, help="passed to pytest --working-dir")
    ap.add_argument("--log-dir", default=None, help="where the per-test logs go (default: <working-dir>/openocd-runs)")
    ap.add_argument("--pytest-args", default="",
                    help="extra arguments for pytest, replacing the default \"-q --tb=line\" (e.g. \"-vv --tb=short --keep-build-files\" to see a failing comparison in full)")
    ap.add_argument("testcases", nargs="*", default=None,
                    help="testcases to run (default: the generic list plus the target's own)")
    args = ap.parse_args()
    testcases = args.testcases or DEFAULT_TESTCASES + FAMILY_TESTCASES.get(args.target, [])

    if not args.openocd:
        sys.exit("openocd not found: pass --openocd, set OPENOCD, or put it on the PATH")

    log_dir = pathlib.Path(args.log_dir or (args.working_dir or ".") ) / "openocd-runs"
    log_dir.mkdir(parents=True, exist_ok=True)

    results = []
    for tc in testcases:
        test_id = f"test_runtimes.py::test_execute_on_target[{tc}_{args.profile}-{args.target}_]"
        log = log_dir / f"openocd_{tc}_{args.profile}.log"
        t0 = time.time()
        try:
            p = start_openocd(args.openocd, args.target, args.gdb_port, args.semihosting_port, log)
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

        r = subprocess.run(pytest_cmd, cwd=TESTS_DIR, capture_output=True, text=True)
        stop_openocd(p)

        out = r.stdout + r.stderr
        (log_dir / f"pytest_{tc}_{args.profile}.log").write_text(out, errors="replace")
        if r.returncode != 0:
            verdict = "FAIL"
        elif "skipped" in out:
            verdict = "SKIP"
        else:
            verdict = "PASS"
        results.append((tc, verdict))
        print(f"{verdict:5} {tc:28} {time.time() - t0:5.1f} s", flush=True)

    print(f"\n=== {args.target} {args.profile}: "
          f"{sum(v == 'PASS' for _, v in results)} passed, "
          f"{sum(v == 'SKIP' for _, v in results)} skipped, "
          f"{sum(v not in ('PASS', 'SKIP') for _, v in results)} failed")
    sys.exit(0 if all(v in ("PASS", "SKIP") for _, v in results) else 1)


if __name__ == "__main__":
    main()
