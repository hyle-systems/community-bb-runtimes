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
