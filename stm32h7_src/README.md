# STM32H7xx Runtimes

Work in progress: GNAT runtimes (light, light-tasking, embedded) for the STM32H723 / H725 / H730 / H733 /
H735 line (reference manual RM0468), generated from the compiler's bb-runtimes sources with this
repository's generator. First target: the STM32H723ZG on the NUCLEO-H723ZG (8 MHz external clock from
the on-board ST-LINK, PLL1 to 520 MHz).

The usage and configuration documentation follows the stm32g4xx family's once the crates are generated.

## Faults are reported, not looped

SVD2Ada's vector table sends NMI, HardFault, MemManage, BusFault and UsageFault to `fault: b fault`, an
endless loop: a faulted board is silent until reset. This family routes those five vectors to
`__gnat_fault_trap` (`stm32h72x/svd/handler.S`), a `Fault_Handler` in the family's copy of the generic
Armv7-M CPU primitives (`s-bbcppr.adb`, registered through `CortexMArch_H7` in `build-rts.py`) that reads
IPSR and raises the fault through `GNAT_Error_Handler`, so it ends in the last-chance handler with a report
(`bus fault`, `hard fault`, `usage fault`, `memory management fault`, `non-maskable interrupt`) and then in
`Machine_Reset.Stop`. The handler.S keeps a weak `__gnat_fault_trap` stub, so a profile without the Ada
handler links and behaves as before. The upstream unit is otherwise unchanged; the change is a candidate
for bb-runtimes itself. Measured on the NUCLEO-H723ZG, 2026-10-17: ten induced stack overflows, ten identical
reports, ten self-resets.

## Stack guard (MPU), an option

`Stack_Guard = true` in the crate configuration keeps a 32-byte no-access MPU region at the lowest
32-byte-aligned address of every stack: region 0 for the running thread, re-programmed before each
context switch from the next thread's stack bottom; region 1 for the interrupt stack; region 2 for the
environment task's stack. The first write past a stack's bottom is then a precise MemManage fault,
reported as `memory management fault` through the fault routing above, instead of a silent walk into
the memory below. The default memory map stays in force elsewhere (PRIVDEFENA), the MPU is off in
HardFault and NMI handlers, each stack loses 32 to 63 bytes at its bottom, and applications that use the
MPU themselves should start at region 3. Off by default. Measured on the NUCLEO-H723ZG, 2026-10-17: see
the commit message.

## Compiler stack checking (`-fstack-check`) in light-tasking

The light-tasking profile carries the embedded profile's `System.BB.Threads.Stack_Checking`
(`s-btstch`, copied in by `patch-runtime.py`), the `__gnat_stack_check` that `-fstack-check` calls at
every subprogram entry; it raises `Storage_Error`, which under `No_Exception_Propagation` goes straight
to the last-chance handler. Linked only when an application compiles with `-fstack-check`. **Size the
stacks for it:** the compiler's generic probe asks for about 4 400 bytes free below each new frame
(`sp - 4392` on this target), so every stack it can run on must hold its peak use plus that margin:
the environment task's (`-Wl,--defsym=__stack_size=16384` for example), each task's `Storage_Size`,
and the interrupt stack (`Interrupt_Stack_Size`, 8192 for example), because a checked prologue in a
protected handler probes against the interrupt stack. With 4 KB stacks every first probe fails.
Measured on the NUCLEO-H723ZG, 2026-10-17: ten induced overflows, ten `Storage_Error` reports from
`s-btstch.adb`, no fault; the probe costs about 250 ns on an interrupt-to-pin path. The complete
picture with the stack guard above: the probe catches overflows in checked Ada code before the frame is
used, the MPU guard catches everything else at the boundary, and the fault routing reports what remains.

## ECC RAM initialisation and the TCM size check at start-up

The AXI SRAM and the ITCM carry 8 ECC bits per 64-bit word (RM0468 2.4). The first sub-word write to a
word nobody has written since power-up, by the start-up's own 32-bit copy of `.axisram`, by a task or by
a DMA, is a read-modify-write against an ECC that is garbage, and the RAMECC monitor flags it (measured:
D1 monitor 1 read 0x7 after one program that used the AXI SRAM). The family's `start-common.S` zeroes
both regions with 64-bit stores before the data cache is enabled, so every word carries a valid ECC
before anything touches it (about 200 µs at 520 MHz). The bounds are the linker's `__axisram_*` and
`__itcm_*`, the memory map's 320 KB and 64 KB of the default TCM_AXI_SHARED option bytes.
`Initialize_Board` then checks the core's ITCMCR / DTCMCR sizes against that map (DTCM 128 KB, ITCM at
least 64 KB) and raises `Program_Error` into the last-chance handler if they differ. The RAMECC monitors
themselves are left to the application: read them once after start-up, clear them, then arm the ECC
interrupt if wanted.

Regions 1 and 2 are programmed by the start-up (`start-common.S`, `guard_init`) for every program,
tasking or not, from the crate's `__stack_guard_bytes`; region 0 follows the running task once the
tasking runtime is up. A program with no tasking unit has only the environment stack, and it is
guarded; `test_guard_taskless` and `test_guard_taskless_hit` hold this.

The stack guard's window is configurable, `Stack_Guard_Bytes` = 32 (default), 64, 128, 256, 512 or
1024: size it to the largest frame of code that is not compiled with `-fstack-check`.

The interrupt stack is 4 KB by default (`Interrupt_Stack_Size`). On embedded a fault's handling - the
raise, the unwinder and the last-chance handler - runs in handler mode on it and needs about 1.8 KB
before the application's handler does anything (1792 bytes measured, `test_fault_stack_use`); with the
old 1 KB default and a window at the stack's bottom the path overflowed into the window and the fault
escalated to a hard fault, and with the guard off it walked silently below the stack. The embedded
crate refuses less than 2048 bytes plus the window; `test_fault_stack_default` holds the window write
with the default stack.
