# STM32H72x/H73x runtimes (`*_stm32h7xx` crates)

This family provides the light, light-tasking and embedded GNAT runtimes for the STM32H723, H725,
H730, H733 and H735 (reference manual RM0468). The repository's generator builds them from the
compiler's bb-runtimes sources, in the same shape as its other families.

Beyond what the other families do, the start-up writes the board's core-supply configuration and
initialises the ECC of the AXI SRAM and the ITCM. The runtime keeps its data, stacks and heap in
the DTCM, with named sections for the other SRAMs. Processor faults are reported as Ada exceptions,
on a stack of their own, in every profile. The tasking profiles can put an MPU guard under every
stack, and light-tasking supports the compiler's stack check. The start-up re-establishes the reset
state it relies on, so an image can be started from a bootloader.

The family was developed and tested on the STM32H723ZG of the NUCLEO-H723ZG (silicon revision Z).
On that board the on-board ST-LINK feeds 8 MHz into the HSE input, and the default configuration
runs PLL1 at 520 MHz at voltage scaling VOS0, with the AXI/AHB clock at 260 MHz and the APB clocks
at 130 MHz. Nothing in the family is specific to a particular product. Each measurement quoted
below names the testcase that reproduces it, or says that it was taken outside the test suite. All
were taken with gnat_arm_elf 16.1.0 and OpenOCD 0.12.0.

## 1. Getting the crates

```sh
./generate-runtimes.sh --target stm32h7xx
```
This writes three crates: `install/light-stm32h7xx`, `install/light-tasking-stm32h7xx` and
`install/embedded-stm32h7xx`. They hold sources; the library is compiled by the first build that
uses it. The generator does not overwrite a crate, so delete `install/<profile>-stm32h7xx` before
running it again.

The crates are for the RM0468 parts only. The STM32H74x/H75x/H7Ax are a different line, with
another memory map, flash table and supply, and must not be built with them.

Pin the crate you want by path and depend on it:

```toml
[[depends-on]]
light_tasking_stm32h7xx = "*"

[[pins]]
light_tasking_stm32h7xx = { path = "../community-bb-runtimes/install/light-tasking-stm32h7xx" }
```
In the project file, add `with "runtime_build.gpr";` (and `with "ravenscar_build.gpr";` in the
tasking profiles), `for Target use Runtime_Build'Target;` and `for Runtime ("Ada") use Runtime_Build'Runtime ("Ada");`,
and put `Runtime_Build.Linker_Switches` in the linker's switches. The linker switches carry the
memory map and the three link-time symbols that the start-up reads. The crate's own
`long-description` repeats these steps and lists the options.

A path-pinned crate is configured and built in place. Alire writes the configuration package into
the pinned directory, and the runtime library is compiled there, under `runtimes/<MCU_Sub_Family>`.
Two workspaces that pin the same directory with different configuration values therefore overwrite
each other's configuration and objects. Give each configuration its own copy of the crate, or
depend on a release from the index.

### Choosing a profile

The three profiles share one start-up, one vector table and one memory map.

- light has no tasking and no exception propagation. A raise goes straight to the last-chance
  handler.
- light-tasking adds Ravenscar tasking, still without propagation.
- embedded adds exception propagation and the full library.

### The main subprogram must not return

If the main subprogram returns, the start file calls `exit`, which resets the board
(`System.Machine_Reset`, SYSRESETREQ). This also happens in the tasking profiles while
library-level tasks are still running. In a program whose main subprogram only elaborates and
returns, the tasks never get past their first activation, and the board reboots in a loop. The
behaviour comes from upstream's start file and binder, and was measured on both tasking profiles.

On the tasking profiles, end the main subprogram with `loop delay until Ada.Real_Time.Time_Last; end loop;`.
A busy loop would stop the tasks at its priority and below from running. On light, end it in a
loop.

## 2. Configuration

Every option is an Alire crate configuration value, set under `[configuration.values]` as
`light_tasking_stm32h7xx.Option = value`. The crate refuses at compile time a configuration that
breaks a limit of the chip, with a message that names the limit.

| Option | Values (default) | What it does |
|---|---|---|
| `MCU_Sub_Family` | H723, H725, H730, H733, H735 (H723) | Selects the device's register description. All five use the STM32H723's, so the interrupts of the H730/H733/H735 crypto peripherals (CRYP 79, OTFDEC1 151, OTFDEC2 152) have slots but no names in `Ada.Interrupts.Names`. |
| `MCU_Flash_Memory_Size` | B, E, G (G) | The flash map: 128 KB, 512 KB or 1 MB. It must match the part: B only on the H730, G only on the H733 and H735, E or G on the H723 and H725. |
| `HSE_Clock_Frequency` | 4 MHz .. 50 MHz (8 000 000) | The frequency of the external clock (up to 50 MHz) or of the crystal (up to 48 MHz, the reference manual's figure in RM0468 8.5; the datasheet's Table 33 says 50). |
| `HSE_Bypass` | true/false (true) | True for a clock signal, such as the ST-LINK's MCO; false for a crystal. |
| `HSI_Div` | DIV1 .. DIV8 (DIV1) | The divider of the 64 MHz internal oscillator. |
| `PLL_Src` | HSE, HSI (HSE) | PLL1's input. |
| `PLL_M_Div`, `PLL_N_Mul`, `PLL_P_Div` | 1..63 (1), 4..512 (65), 1..128 (1) | PLL1's input divider, multiplier and system-clock divider. |
| `PLL_Q_Div`, `PLL_R_Div`, `PLL_Q_Enable`, `PLL_R_Enable` | 1..128 (4, 2), false | PLL1's other two outputs. |
| `SYSCLK_Src` | HSI, CSI, HSE, PLL1 (PLL1) | The source of the system clock. |
| `Voltage_Scaling` | VOS0 .. VOS3 (VOS0) | The core's voltage scaling, which sets the clock maxima. VOS0 limits the junction temperature to 105 °C, against 125 °C at VOS1 to VOS3 (DS13313 Table 13). |
| `D1CPRE`, `HPRE`, `D1PPRE`, `D2PPRE1`, `D2PPRE2`, `D3PPRE` | DIV1 .. (DIV1, DIV2, DIV2, DIV2, DIV2, DIV2) | The core, AXI/AHB and APB prescalers. |
| `Supply_Configuration` | nine arrangements (LDO) | The board's core supply (RM0468 Table 30). The SMPS arrangements apply only to parts with the converter. See below. |
| `Interrupt_Stack_Size` | bytes, at least 1024 (4096) | The interrupt stack, shared by every interrupt priority. |
| `Fault_Stack_Size` | bytes, at least 512, or 3072 on embedded (4096) | The fault stack, on which every fault is handled (section 4). |
| `Stack_Guard` | true/false (false) | An MPU no-access window under every stack (section 5). |
| `Stack_Guard_Bytes` | 128, 256, 512 (128) | The size of the window. It is at least the core's own exception frame with the FPU in use: below 128 bytes, the frame's integer part can land under the window unseen. It is at most what the runtime's idle task, with its 2 KB stack, allows. Size it by rule 2 of section 5. |

The crate refuses the following, and each item names where the check lives:

- A PLL1 input outside 1 to 16 MHz after the M divider. The comparison is exact: the frequencies
  are computed from the source with one division each, so an M that does not divide the source
  loses nothing (`test_clock_point_m3` runs such a point). (`setup_pll.adb`)
- A VCO outside its range. An input of 2 to 16 MHz runs the wide range, 192 to 836 MHz. An input
  below 2 MHz runs the medium range, 150 to 420 MHz, whose outputs are also limited. Exactly 2 MHz
  runs the wide range, as in ST's own configuration for the NUCLEO-H723ZG. (`setup_pll.adb`;
  DS13313 Tables 39 and 40)
- An odd P divider other than 1. (`setup_pll.adb`)
- A CPU, AXI/AHB or APB clock above the maximum of the selected voltage scaling: 520, 275 and
  137.5 MHz at VOS0. The flash wait states follow RM0468 Table 16. (`setup_pll.adb`; DS13313
  Table 12)
- A used PLL1 output above the ceiling of the voltage scaling. P counts when it drives the system
  clock, Q and R when they are enabled. (`setup_pll.adb`)
- A crystal above 48 MHz. DS13313 Table 33 allows 50, but the crate keeps the figure of RM0468 8.5.
  (`setup_pll.adb`)
- An SMPS arrangement on the STM32H723 or STM32H733, which have no converter, and a flash size the
  part does not come in. (`System.BB.Parameters`)
- At VOS0, a converter that feeds the LDO at 1.8 V. (`System.BB.Parameters`)
- On the tasking runtimes, a CPU clock below 1 MHz, at which the 1 ms tick would take the
  processor, and an interrupt stack below 1 KB, which is also the manifest's floor.
  (`System.BB.Parameters`)
- In the light crate, `Interrupt_Stack_Size`, `Stack_Guard` or `Stack_Guard_Bytes` set away from its
  default. The light runtime has no interrupt stack, no context switch and no MPU code of its own;
  the start-up's guard block exists in every profile and is skipped when the option is off.
  (`System.BB.Parameters`)
- On embedded, a `Fault_Stack_Size` below 3072 bytes. Section 5 explains the figure.
  (`System.BB.Parameters`)
- A `Stack_Guard_Bytes` other than 128, 256 or 512, and, with the guard on, an interrupt stack
  smaller than four windows. (`System.BB.CPU_Primitives`)
- With the guard on, an environment stack smaller than four windows. The linker scripts check this
  at link time with an assertion against `__stack_size`, whose message is "environment stack
  smaller than four guard windows".
- At run time, with the guard on, a task stack smaller than four windows. The first switch to the
  task reports `Storage_Error` with "task stack below four guard windows" through the fault path
  (section 5).

`tests/test_negative_builds.py` holds every refusal that the manifest's own ranges do not
pre-empt, and the configurations that must build.

### The supply configuration

`Supply_Configuration` is the board's core-supply arrangement, from RM0468 Table 30: `LDO` (the
NUCLEO-H723ZG, and every part without the SMPS step-down converter), `SMPS`,
`SMPS_1V8_Supplies_LDO`, `SMPS_2V5_Supplies_LDO`, `SMPS_1V8_Supplies_External_And_LDO`,
`SMPS_2V5_Supplies_External_And_LDO`, `SMPS_1V8_Supplies_External_LDO_Bypass`,
`SMPS_2V5_Supplies_External_LDO_Bypass` or `Bypass`.

The start-up writes it into PWR_CR3 before anything touches RAM, then waits for the voltage levels
to be valid (ACTVOSRDY). The register is write-once until a power-on reset. A changed value
therefore takes effect only after a power cycle, and an arrangement the board is not wired for
leaves the core unsupplied until one. Read the schematic before changing it.

The converter exists on the STM32H725 and STM32H735, and on the STM32H730 variants with the Q
suffix. The crate refuses the SMPS arrangements for the STM32H723 and STM32H733. In the four
arrangements where the converter also supplies external circuits, the start-up waits for the
converter's external-ready flag (SDEXTRDY), as ST's HAL does. None of the SMPS arrangements is
tested here.

`test_supply_config` reads the bits back. Since the register is write-once, the read cannot tell
the start-up's write from a value that an earlier image left. If the locked arrangement differs
from the crate's, the start-up parks at `__gnat_supply_mismatch` before the ready wait, where a
debugger can name it.

On this family every voltage scaling, VOS0 included, is reachable from every supply source
(DS13311 Table 14). The restriction of VOS0 to the LDO belongs to the STM32H74x/75x. There is one
condition: at VOS0, a converter that feeds the LDO must output 2.5 V. The crate therefore refuses
`SMPS_1V8_Supplies_LDO` and `SMPS_1V8_Supplies_External_And_LDO` at VOS0, and accepts them from
VOS1 down.

The datasheet's supply floors are the board's to meet (DS13313 Table 13). For VOS0, VDD must be at
least 2.2 V when the converter supplies the core, and 3 V when the converter feeds the LDO. With
the LDO alone, VDD and VDDLDO must be at least 1.7 V for VOS0, against 1.62 V at VOS1 to VOS3.

## 3. Memory map and placement

| Region | Address | Size | Use |
|---|---|---|---|
| flash | 0x0800_0000 | 128 KB / 512 KB / 1 MB by `MCU_Flash_Memory_Size` | Code, constants, initial values |
| ITCM | 0x0000_0000 | 64 KB (default sharing) | No output section yet: these scripts place no code there |
| DTCM | 0x2000_0000 | 128 KB | The runtime's home: data, zeroed data, every stack, the heap |
| AXI SRAM | 0x2400_0000 | 320 KB (default sharing) | `.axisram`, with initial values copied by the start-up; `.axisram_bss`, zeroed and not stored in the flash |
| SRAM1 + SRAM2 | 0x3000_0000 | 32 KB | `.sram12`, with initial values copied by the start-up; `.sram12_noinit`, untouched |
| SRAM4 | 0x3800_0000 | 16 KB | `.sram4`, with initial values copied by the start-up; `.sram4_noinit`, untouched |

### Placing objects

Place an object with `Linker_Section => ".axisram"` or one of the other section names in the
table. `Linker_Section` needs a library-level object.

An object in `.axisram`, `.sram12` or `.sram4` takes its initial value from a load image that the
start-up copies (`test_sram_init`). This includes the implicit initial values, such as a null
access or a record's default components, which GNAT emits as data. The image counts against the
flash, zeroes included. Put a large zero-only buffer in `.axisram_bss` instead: the start-up's ECC
initialisation zeroes it, and the flash does not hold it.

`.sram12_noinit` and `.sram4_noinit` are neither loaded nor zeroed. They are for buffers that need
no initial value, and for records that must survive a reset (SRAM4 keeps its contents while
powered). Such a record must reach the memory before the reset. The three SRAMs are cacheable
write-back in the default memory map, and a reset discards a dirty cache line. Clean the record's
lines (`DCCMVAC`, then `DSB`) before requesting the reset, or give the record an MPU region of its
own that is not cacheable. The family's tests that keep a mark across a reset do the former.

The start-up enables the SRAM1 and SRAM2 clocks (`RCC_AHB2ENR` SRAM1EN / SRAM2EN, off after reset)
when `.sram12` is not empty. A program that uses only `.sram12_noinit` enables them itself.

Write the words of `.sram12_noinit` and `.sram4_noinit` whole before any sub-word use. The ECC of
SRAM1, SRAM2 and SRAM4 is not initialised beyond the loaded sections, and their monitors flag the
first read-modify-write after power-up. `test_ecc_survey` shows this. It is an opt-in test that is
meaningful only right after a power cycle, so it skips itself unless `ECC_SURVEY=1` is set and is
not part of the gate (section 7). It finds the single-error-corrected and double-error-detected
flags set on each of the three, with the monitor reading 3. It finds none on the DTCM, although
RM0468 2.4 describes ECC there too (a measurement, not the manual's word), and none on the backup
SRAM.

### DMA buffers and the cache

**DMA1, DMA2 and the BDMA cannot reach the DTCM.** The MDMA can, through the core's AHBS port
(RM0468 2.4). The DTCM holds `.data`, `.bss`, every stack and the heap, so no local variable,
task-stack buffer or default-placed library-level object can be a DMA1, DMA2 or BDMA buffer. For
DMA1, DMA2 and the MDMA, put the buffer in `.axisram` (or `.axisram_bss`) or `.sram12`. For the
BDMA, which reaches only the D3 domain (RM0468 2.1), put it in `.sram4`.

All three placements are cacheable in the default memory map, and a cache line is 32 bytes
(PM0253 4.8). Align a DMA buffer to 32 bytes and make its size a multiple of 32
(`with Alignment => 32`), so that no maintenance on it touches a neighbour's line. Invalidating a
shared line discards the neighbour's writes, and cleaning it while the DMA writes overwrites the
DMA's data. Then maintain the cache around each transfer:

- Clean the buffer's lines before a DMA reads the buffer.
- Before a DMA writes the buffer, clean or invalidate its lines so that none is dirty while the
  transfer runs. A write-back during the transfer would overwrite the DMA's data.
- Invalidate the lines after the DMA has written.
- Put a barrier between a cache maintenance operation and the store that follows it (errata
  ES0491 2.1.4).

Alternatively, give the buffer an MPU region of its own, in regions 0 to 11.

`test_dma_cache` holds the rule. A DMA1 memory-to-memory transfer between two `.axisram` buffers
reads stale data without the maintenance, and none with it (0 errors in 10 000 transfers).
`test_dma_sram12` repeats the measurement in SRAM1/SRAM2, and `test_dma_sram4` in SRAM4 with the
BDMA. The debug host also reads semihosting text buffers from memory, behind the cache; the
runtime's own text buffers are in the DTCM. `test_memory_map` holds the placements.

### ECC at start-up

The AXI SRAM and the ITCM carry 8 ECC bits per 64-bit word (RM0468 2.4). The first sub-word write
to a word that nobody has written since power-up is a read-modify-write against a garbage ECC, and
the RAMECC monitor flags it. That write can come from the start-up's own copy of `.axisram`, from a
task or from a DMA.

The start-up (`start-common.S`, `ecc_init`) therefore zeroes both memories with 64-bit stores. It
does so before the data cache is enabled and before the PLL, at the 64 MHz reset clock; how long
this takes has not been measured. It zeroes exactly the sizes that the device's `TCM_AXI_SHARED`
option gives (FLASH_OPTSR2_CUR). The ITCM is (field + 1) × 64 KB and the AXI SRAM is the rest of
384 KB: 64/320 by default, then 128/256, 192/192 and 256/128.

The linker scripts describe the default sharing. The start-up compares the used end of `.axisram`
(and of a RAM-loaded image) with the device's size, and parks at `__gnat_axisram_mismatch` when the
map exceeds it. A device with another sharing therefore needs a user linker script.

`test_ecc_initialised` reads the monitors after start-up and finds zero on every profile.
`test_tcm_sharing` checks the sizes the start-up computed against the option byte it reads. The
monitors themselves belong to the application: read them once after start-up, clear them, and arm
the ECC interrupt if wanted.

### A user linker script

Build with `-XLOADER=USER`, and the crate passes no `-T`, only the three `--defsym`s
(`__supply_cr3`, `__stack_guard_bytes`, `__fault_stack_size`). The generated `runtime.xml` still
passes `-L` for an `ld` and an `ld_user` directory under the compiled runtime's own directory.
Those directories do not exist there, which is harmless.

The start-up and the fault trap read the scripts' symbols: `__stack_start` / `__stack_end`,
`__interrupt_stack_start` / `__interrupt_stack_end`, `__fault_stack_start` / `__fault_stack_end`,
`__data_*`, `__bss_*`, `__heap_*`, `__ccmdata_*`, `__axisram_start`, `__ecc_axisram_zero_start`,
`__itcm_start`, `__ecc_itcm_bytes`, `__ecc_axisram_bytes`, and the weak `__axisram_bss_end`,
`__sram12_*` and `__sram4_*`. `__vectors` comes from `handler.S`. Start from a copy of
`common-ROM.ld` (or `common-RAM.ld`) and change its memory map.

The copy keeps `INCLUDE memory-ROM.ld` (or `memory-RAM.ld`) and `INCLUDE common-sections.ld`,
the sections both loaders share. They resolve only through the crate's `-L` directories (`ld`,
`ld/flash-<size>`, `ld/ram-h72x`). Pass them, or inline the `MEMORY` block and the shared
sections. Add `-Wl,--no-warn-rwx-segments` yourself; the crate adds it only for its own two loaders.

The scripts do not place sections they do not name. An input section of the application's own
(`.itcm`, `.noinit`, `.ramfunc`) lands silently wherever ld's orphan rules put it.
`-Wl,--orphan-handling=warn` makes ld report it.

The ITCM at address 0 holds no section and is readable and writable. A null access in code compiled
with checks off therefore reads or writes it without a fault. An MPU region of the application's,
with no access over the ITCM's first bytes, makes such an access fault.

### From a bootloader

A bootloader must branch to the image's reset entry in thread mode, privileged, with the
peripherals and DMA streams it used stopped. The runtime cannot know which those are, so a DMA still
writing or an interrupt source still asserting is the bootloader's to stop. An entry in handler
mode, from inside the bootloader's exception handler, parks at `__gnat_handover_in_handler`
(`test_handover_in_handler`). An unprivileged entry (CONTROL.nPRIV set) parks at
`__gnat_handover_unprivileged` (`test_handover_unprivileged`), before its first access to the
system control space would fault into the bootloader's vector table.

The start-up computes everything else from the reset state, and re-establishes it rather than
assume it. First, before any RAM write, it:

- invalidates the instruction cache, since the bootloader may just have written this image;
- stops the SysTick, disables and unpends every interrupt, clears the PendSV and SysTick requests
  and sets BASEPRI to zero;
- puts the thread on the main stack, with the main stack pointer at the top of the environment
  stack;
- turns the MPU off;
- turns lazy floating-point stacking on (FPCCR ASPEN and LSPEN), with no lazy save pending;
- returns the floating-point defaults (FPDSCR) and the sleep behaviour (SCR) to their reset values.
  SCR at reset means no deep sleep, which the tasking runtime's idle `wfi` would otherwise enter;
- clears CCR's UNALIGN_TRP and BFHFNMIGN. With UNALIGN_TRP left set, every unaligned access the
  compiler emits (packed records, for example) is a UsageFault;
- enables the TCM interfaces.

With the vector table in place and nothing left that can interrupt, it clears PRIMASK and
FAULTMASK. A bootloader masks interrupts before its jump; an exception it lets in before the jump
is taken by its own vector table, before the image's first instruction.

Then the start-up:

- turns every PLL off before it writes the PLL source and the HSI divider, and reads the source
  back. A PLL left running makes both writes no-ops (RM0468 8.7.10 and 8.7.2);
- returns the whole `RCC_CFGR` to its reset value;
- raises the flash latency to at least one wait state before the prescalers return to reset, and
  again before the voltage scaling changes;
- turns the HSE off, and confirms it is off, before it writes the bypass bit (RM0468 8.7.2);
- latches PLL1's fraction as zero;
- cleans and invalidates a data cache that it finds on, before the ECC zeroing;
- clears every MPU region, with the guard on or off (with the guard on, before the two static
  guard regions are programmed);
- compares the supply arrangement with the locked byte.

A clock security system that a bootloader armed stays armed, because software cannot clear
HSECSSON. An HSE failure then raises the NMI (section 4).

Four testcases hand the start-up a prepared state by branching to the reset entry:
`test_handover_pll`, `test_handover_dcache`, `test_handover_state` and `test_handover_regions`.

### Loading into RAM

Build with `-XLOADER=RAM`, and the image links into the AXI SRAM, with `.data` in the DTCM and the
vector table at the image's start. The ECC zeroing then begins after the loaded image. The test
harness loads such an image with `load_image` and starts it from its vector table
(`test_ram_loader`, `test_ecc_initialised_ram`).

## 4. Faults

The vector table (`stm32h72x/svd/handler.S`) sends HardFault, MemManage, BusFault, UsageFault and
SVCall to `__gnat_fault_trap`. The runtime makes no supervisor calls, so an SVCall is reported as
"unhandled trap" (`test_fault_svc`). The NMI goes to the weak name `__gnat_nmi_trap`, which is the
same trap unless the application defines it as a parameterless procedure exported with
`Convention => C`. An HSE failure under the clock security system is such an NMI, and its handler
must clear HSECSSF (RM0468 8.5; `test_nmi_hook`, and `test_fault_nmi` for the default).

The trap reads IPSR and calls `System.BB.Faults.Report` (`s-bbfaul`), which raises:

- `Program_Error` with "non-maskable interrupt", "hard fault" or "bus fault";
- `Storage_Error` with "memory management fault";
- `Constraint_Error` with "usage fault".

The start-up sets VTOR to this table and enables the three configurable faults in SHCSR in every
profile, so a program without tasking faults the same way as one with tasking.

In light and light-tasking, the raise goes straight to the last-chance handler,
`procedure Last_Chance_Handler (Msg : System.Address; Line : Integer)`, with the message in `Msg`.
In embedded it propagates and reaches
`procedure Last_Chance_Handler (Except : Ada.Exceptions.Exception_Occurrence)`. The default
handler prints the exception through semihosting, then resets the board (SYSRESETREQ).

**Without a debugger, the default handler's message is lost.** Its `bkpt` runs at the fault's
priority, which the DebugMonitor cannot pre-empt, so it escalates to HardFault. That is a fault
inside the fault handling, which resets the board when no debugger is attached (see below). A
deployed program therefore installs its own last-chance handler, one that records the cause where
it survives the reset (a record in `.sram4_noinit`, cleaned to memory, section 3) and then requests
the reset. It also arms the independent watchdog, the only bound on any park. A debugger attached
across repeated self-resets can lose the probe, so a test program's handler parks in a loop
instead.

`test_fault_bus`, `test_fault_usage` and `test_fault_escalated` hold the three paths on every
profile. A fault whose handler cannot run escalates to a hard fault and is reported as one. This
happens when the fault occurs at a priority the handler cannot pre-empt, or when a second fault
occurs in the handler.

### Every fault is handled on the fault stack

Before it reports, the trap moves the main stack pointer to the top of a dedicated region. The
region's size is `Fault_Stack_Size`, 4 KB by default, and it lies between the interrupt and the
environment stacks. A fault's handling therefore never runs on the stack that overflowed, and does
not walk below it.

The core imposes one exception. A fault at a priority that the configurable handlers cannot
pre-empt (the tick's, or inside a PRIMASK section) escalates to HardFault. The core pushes the
HardFault's entry frame before the trap moves the stack pointer, and the guard window is no barrier
to that push (HFNMIENA clear). The report then says "hard fault" (`test_fault_escalated`).

For the first fault, the trap keeps the stack pointer it found in `__gnat_fault_sp`, and the fault
status in `__gnat_fault_cfsr`, `__gnat_fault_hfsr`, `__gnat_fault_mmfar` and `__gnat_fault_bfar`
(PM0253 4.3.10 to 4.3.14). The two addresses are meaningful only when CFSR's MMARVALID or
BFARVALID says so. These words are for a handler and for a debugger. They tell a stack overflow
(MSTKERR, DACCVIOL) from an execute-never violation, a lazy floating-point stacking fault (MLSPERR)
or an imprecise bus error (IMPRECISERR, whose address the core does not keep). A fault inside the
handling leaves them as the first fault wrote them (`test_fault_bus`).

A task stack below four guard windows (section 5) is reported through the same path, with its own
message, and so, on light-tasking, is a guard that the start-up did not arm ("stack guard not armed
by the start-up", `test_guard_not_armed`). The embedded runtime cannot report that one: the check
runs while the runtime initialises the CPU, before its exception propagation is up, and a raise
there faults again. It parks at `__gnat_guard_not_armed_park` instead, in thread mode and before the
application runs (`test_guard_not_armed_park`); without a debugger the board stays there rather
than resetting into the same start. Both reports store a cause byte and then execute an undefined
instruction. The report uses the cause only when the kept CFSR shows that undefined instruction
(UNDEFINSTR), so an interrupt that takes another usage fault in between keeps its own name
(`test_fault_cause_usage`, and `test_fault_cause_stale` for a cause left over from an earlier run).

`test_fault_in_handler` overflows the interrupt stack from an interrupt handler under the guard. It
checks that the report, a memory management fault, runs above that stack, and that the faulting
stack pointer lay inside it. Without a fault stack, the MemManage handler's own first push lands
inside the window it has just hit. The fault then escalates, and the hard-fault path runs below
the interrupt stack, over the ECC words and `.bss`, while reporting.

The trap sets the report's latch before it keeps anything. A fault inside the handling itself (the
last-chance handler faulting, a second overflow, the default handler's print without a debugger),
or an NMI during it, finds the latch set. It then goes to `__gnat_fault_in_fault` instead of
reporting again without end, and leaves the first fault's evidence and its frames on the fault
stack as they are. With a debugger attached (DHCSR.C_DEBUGEN), the core parks there and the
debugger finds both (`test_fault_in_fault`: the handler faults on purpose, and nothing more is
printed). Without one, the board is reset, since nobody would ever look at a parked core whose
outputs stay as they were. The name is weak, so an application may put its own action there. That
action runs in handler mode, at the fault's priority, and never returns.

This holds when the second fault can pre-empt the first report. A second fault inside a report
that is already running at the HardFault or NMI priority is a lockup by the core's rule
(PM0253 2.5.5), and only the watchdog ends it.

### Text output

`Ada.Text_IO` and the default last-chance handlers write through semihosting, a `bkpt #0xAB` that
the debugger serves. Under a debugger, each character halts the core while the host reads it. A
hardware-started independent watchdog keeps counting through these halts, because its debug freeze
(DBGMCU) is off at reset. Without a debugger, the runtime's DebugMonitor handler skips the output in
thread mode; in a handler, the output escalates as described above. A deployed program writes its
output to a peripheral of its own.

### The last-chance handler on embedded

On embedded, a last-chance handler runs in handler mode, on the fault stack, after the unwinder.
The secondary stack it may use is the interrupted task's, not the fault stack. The embedded crate's
default handler builds its lines with it and runs: `test_fault_default_lch` takes a bus fault with
no handler of its own, reads the default handler's four lines (LF-terminated, from `System.IO`; the
message carries the raising unit's name) and finds the program restarted by the reset the handler
performs.

What the handler needs is fault stack. The default 4 KB holds the default handler.
`test_fault_stack_use`'s minimal handler, with fixed buffers and `Put` only, shows that the path
itself takes 1.8 KB (section 5).

## 5. Stacks: the guard, the compiler's check and the sizes

### The MPU stack guard

With `Stack_Guard = true`, the runtime keeps a no-access, execute-never window of
`Stack_Guard_Bytes` at the bottom of every stack. The first write past a stack's bottom is then a
precise MemManage fault, reported as "memory management fault", instead of a silent walk into the
memory below.

The windows use the four highest MPU regions. Where regions overlap, the highest number decides
(PM0253 4.6), so an application's region over a stack cannot disarm its window
(`test_guard_app_region`). The regions are used as follows:

- Regions 12 and 15 hold the tasks' windows, alternately. The PendSV handler programs the incoming
  task's window in whichever of the two does not hold the outgoing task's. It does so after it has
  saved the outgoing task's registers and before it loads the incoming task's, so both stacks are
  guarded through the switch, however many times the switch was requested.
- Region 13 holds the interrupt stack's window.
- Region 14 holds the environment stack's window.

The start-up (`start-common.S`, `guard_init`) programs region 14, and region 13 where an interrupt
stack exists, for every program, tasking or not. It takes the size from the link-time symbol
`__stack_guard_bytes` that the crate passes, and programs the regions after every region has been
cleared (`test_handover_regions`). Regions 12 and 15 follow the tasks once the tasking runtime is
up. A program with no tasking unit has only the environment stack, and that stack is guarded
(`test_guard_taskless`, `test_guard_taskless_hit`). `test_guard_switch` and
`test_guard_switch_twice` hold the switch, requested once, and requested again inside a storm of
interrupts.

The default memory map stays in force everywhere else (PRIVDEFENA). The MPU is off inside
HardFault and NMI handlers (HFNMIENA clear). Applications that use the MPU themselves use regions
0 to 11. The switch puts `MPU_RNR` back as it found it, so a task can be preempted between
selecting its region and writing it (`test_guard_rnr`). An interrupt handler that programs the MPU
must restore `MPU_RNR` itself, since it can preempt the switch.

`test_guard_regions` reads the regions back. `test_guard_map` writes and reads every memory of the
map, and a peripheral, under the guard. `test_guard_off` holds the default.

### Sizing guarded stacks

The window sits inside the stack, at its bottom. The interrupt and environment stacks, which the
linker aligns to the window, lose exactly one window. A task's stack, which the compiler aligns to
8, loses between one and two. Three rules apply:

1. **Every guarded stack is at least four windows.** The crate checks the interrupt stack at
   compile time, the environment stack at link time and each task's stack at the first switch to
   it. A task stack that is too small is reported as `Storage_Error` with "task stack below four
   guard windows", through the fault path like a fault: interrupts masked, on the fault stack
   (`test_guard_small_task`, with the smallest interrupt stack the crate accepts). A task's
   `Storage_Size` is the application's. The application can state the rule next to the task, so
   that the compiler reports it first:
   ```ada
   pragma Compile_Time_Error
     (Light_Tasking_Stm32h7xx_Config.Stack_Guard
        and then My_Task_Stack_Size < 4 * Light_Tasking_Stm32h7xx_Config.Stack_Guard_Bytes,
      "My_Task's stack is smaller than four guard windows");
   ```
2. **The window is at least the largest frame of code that is not compiled with `-fstack-check`,
   and at least 128 bytes.** A frame whose first write lands more than one window below the
   previous stack pointer steps over the window. The core's own exception frame is such a frame.
   With the floating-point context active it is 104 bytes, and lazy stacking writes only its 32
   integer bytes, at the bottom. A narrower window would let an interrupt write those bytes below
   the stack unseen (`test_guard_fp_frame`). The runtime refuses less than 128.
3. **A stack that runs code compiled with `-fstack-check` holds its peak use plus the probe's
   margin.** The margin is about 4.4 KB in the light and light-tasking profiles, and about 12.2 KB
   in embedded, whose code carries exception tables. It comes from GCC's `STACK_CHECK_PROTECT`,
   which is 4 KB without exception tables and 12 KB with them. Below a 260-byte frame,
   gnat_arm_elf 16.1.0 emits `sub r3, sp, #4384` without them and `#12224` with them. A 16 KB task
   with 280-byte frames hits the check at the thirteenth frame on embedded, and at the fortieth on
   light-tasking. See the next subsection.

### The compiler's stack check

With `-fstack-check`, every subprogram entry calls `__gnat_stack_check`. The light-tasking crate
carries the embedded profile's `System.BB.Threads.Stack_Checking` (`s-btstch`, copied in by
`patch-runtime.py`), so the call resolves there too. It raises `Storage_Error` from `s-btstch.adb`
into the last-chance handler. The unit is linked only when an application compiles with the
switch.

The check compares the probe address with the running task's stack bottom, so it fires when the
frame plus the margin would not fit. A task whose stack is smaller than the margin cannot even
start under the check (`test_stack_check`, `test_stack_check_margin`). Both tests run on
light-tasking and on embedded, whose own copy of the unit is the same.

**Keep the last-chance handler itself out of the checked units.** A handler compiled with
`-fstack-check` re-raises from its own prologue when it is entered below the limit, and the
re-raises walk the stack into the guard window or out of the memory.

With the guard on as well, the check fires first (`test_stack_check_with_guard`). Together, the
probe catches overflows in checked Ada code before the frame is used, the guard catches everything
else at the boundary, and the fault routing reports what remains. Measured outside the test suite,
the probe costs about 250 ns on an interrupt-to-pin path at 520 MHz.

### Stack sizes

The environment stack (the main program's) is 4 KB by default. Set it at link time with
`-Wl,--defsym=__stack_size=<bytes>` in the program's linker switches. Code compiled with
`-fstack-check` needs rule 3's margin on top of its use; the stack-check testcases link with 16 KB.

The interrupt stack is 4 KB by default. Size it for the deepest interrupt nesting (each level a
frame plus the FPU's lazy-stacking space) and the guard window. `test_interrupt_stack_size` holds
the option.

The fault stack carries every fault's handling. On embedded, that is the raise in
`System.BB.Faults.Report`, the unwinder and the last-chance handler, about 1.8 KB including the
handler's own frame. `test_fault_stack_use` fills the fault stack with a pattern, takes a bus fault
and finds the lowest word the path touched: 1792 bytes, rounded up to 256, with gnat_arm_elf
16.1.0. A change in that number is worth a look. A handler that builds its lines through the
secondary stack, as the default one does, uses 2048 bytes (`test_fault_stack_use_alloc`). The
embedded crate refuses a fault stack below 3072 bytes, which is the allocating handler's figure
with half again. `test_fault_stack_default` holds a window write with the default fault stack and
a 1 KB interrupt stack, the smallest the crate accepts. Light-tasking's handler is a direct call and
needs less.

### The FPU

The start-up enables the FPU (CP10 and CP11). Lazy stacking is the core's reset default. The
start-up re-establishes it after a bootloader, and `test_startup_state` reads it back.

`test_fpu_context` runs two double-precision chains that switch every millisecond under a thousand
interrupts that use the FPU, and checks every result. It then holds live values in all sixteen
double registers inside one loop. Meanwhile a task preempts the loop every millisecond, and a timer
interrupt whose handler uses the FPU fires every 100 µs; both load other values into the registers.

`test_stack_alignment` holds the 8-byte alignment of the stack pointer in the main program, at a
task's start and inside a handler. `test_startup_state` holds the start-up's end state: caches on,
VTOR, CPACR, FPCCR, the TCM enables, and the MPU off by default. The branch-prediction bit it also
prints reads as one on this core.

## 6. Clocks and time

PLL1 drives the system clock by default; section 2 lists the constraints the crate enforces. The
outputs of PLL1 that the configuration does not use have their dividers set to zero, as well as
their enables (RM0468 8.5.5). `test_startup_state` reads them back.

Every clock wait is bounded. If the state does not come, the start-up parks at a label that a
debugger can name: `__gnat_hse_not_ready` (no clock on the HSE input, or a crystal configured as a
bypass or the reverse), `__gnat_pll_not_locked` or `__gnat_clock_not_ready`.

The flash latency is programmed in two steps when the target needs fewer wait states than the
64 MHz reset clock: when the frequency falls, the clock changes first and the latency after
(RM0468 4.3.8). The latency is raised before the voltage scaling changes. Every PLL is turned off
before the PLL source is written, and the source is read back. The HSI divider is written whatever
its value, the whole `RCC_CFGR` is reset, and the CSI is enabled and waited for when it is the
system clock. A state left by a bootloader therefore does not stand behind the runtime's arithmetic
(section 3, "From a bootloader"). The clock tests read back the voltage scaling applied, and the
flash wait states, against RM0468 Table 16 as computed in the test.

### What the application configures

The runtime configures the supply, the voltage scaling, PLL1, the system clock switch and the
D1/D2/D3 prescalers, and nothing else. PLL2 and PLL3 are off: `Reset_Clocks` turns them off, and
their M dividers stay as found (the reset value or a bootloader's). The HSE is off unless the
configuration uses it. Every peripheral's kernel clock is at its reset selection.

The FDCAN kernel clock, for example, is the HSE after reset (RM0468 8.7.19, FDCANSEL = 00), so the
HSE must then be on. On the NUCLEO-H723ZG the HSE is the ST-LINK's 8 MHz, which is about one
percent high (measured, below), far outside what CAN bit timing tolerates. Select PLL1 Q
(`PLL_Q_Enable`, `PLL_Q_Div`) or a PLL2 output, and a clock with a known accuracy.

The application owns the kernel clock selections (RCC_D1CCIPR, D2CCIP1R, D2CCIP2R, D3CCIPR), the
peripheral clock enables, PLL2 and PLL3, the watchdogs, the reset-cause flags (RCC_RSR, which the
start-up leaves for the application to read and clear) and the option bytes (BOR level, the
watchdogs' hardware start).

### HSE failure

The runtime does not arm the HSE clock security system. An external clock that stops then leaves
PLL1 without its reference, with no fault and no interrupt (RM0468 8.5). If the application or a
bootloader arms it, the hardware switches the system clock to the HSI, turns the PLLs off and
raises the NMI (section 4). A hook that clears HSECSSF and returns leaves `Ada.Real_Time` counting
the PLL's frequency on the HSI's: 520 against 64 MHz at the default point, about eight times slow.
Every kernel clock taken from a PLL is also stopped. Treat the failure as fatal (record, reset), or
reconfigure the clocks before returning.

### `Ada.Real_Time`

`Ada.Real_Time` is kept by SysTick. **Code at the tick's level must finish within one tick period
(1 ms).** This covers the timing events' handlers, which run inside the SysTick handler, protected
actions at `Interrupt_Priority'Last`, and sections with interrupts masked. The clock counts the
tick's wraps, one per read of its counter. While the tick is held off, every wrap after the first is
lost for good. A timing-event handler that holds the processor for 5 ms leaves `Ada.Real_Time` 4 ms
behind (measured on both tasking profiles; the clock is upstream's `Read_Clock`).

The runtime's second is cross-checked against the board's 32.768 kHz crystal, the one clock that
does not descend from the PLL. LPTIM1, clocked from the LSE and counted over one second of
`Ada.Real_Time`, agrees within 2 % at the default point, at ST's own 520 MHz point, at 400 MHz
(VOS1), at 170 MHz (VOS3), at 32 MHz on the halved HSI (VOS3) and on the HSI at 64 MHz
(`test_clock_reference`, `test_clock_point_st`, `test_clock_point_400`, `test_clock_point_170`,
`test_clock_point_32`, `test_clock_hsi64`). It agrees within 8 % on the 4 MHz CSI, an RC oscillator
(`test_clock_csi`). On this board the ST-LINK's 8 MHz is about one percent high, which the PLL
inherits; that figure was measured outside the test suite against the LSE. The clock tests
themselves ask for 2 %, and 8 % on the CSI.

The timer kernel clocks equal the AHB clock for an APB prescaler of 1 or 2 (TIMPRE = 0,
RM0468 8.7.6). At the default prescaler of 2 they are therefore twice the APB clocks the runtime
computes. TIM2 and TIM1, free-running against the runtime's second, give the ratio 1.000
(`test_timer_clock`).

On the NUCLEO-H723ZG, leave the user button (PC13) alone while the LSE serves as a reference
(ES0491 2.2.6).

### Measured timing

These figures were measured outside the test suite, with purpose-built programs on the
NUCLEO-H723ZG at 520 MHz and an FX2-based logic analyser (+44 ppm against the host; 8 MHz samples
for the latency figures, 200 kHz for the ten-minute ones):

- Interrupt latency, from the hardware edge to the handler's edge: p99 0.750 µs, maximum 0.875 µs
  over 106 241 events, none lost, and the same under task load. The MPU guard and the compiler's
  stack check cost 0.25 µs on this path against an unguarded build.
- Two periodic tasks of 100 and 500 ms, over ten minutes: within ±8 µs of their periods, once
  normalised to the board's clock.
- `delay until`: never early, and at most 1 001 µs late over 10 000 wake-ups sweeping the
  deadline's phase.

The latency has not yet been measured at a second clock point.

A soak test ran for 17.7 hours on the runtime's clock with everything together: five periodic tasks
at four priorities, a 10 kHz timer interrupt into a protected handler, double-precision chains at
two priorities (one of them the environment task, never pausing), DMA transfers through the data
cache with the maintenance sequence of section 3, and a heartbeat on a pin every minute. It was
read off the board through the debug port without halting it, and showed:

- 636 million interrupts, with their count against the clock drifting by 0 (none missed, none
  doubled), and a latency of at most 1.035 µs;
- every heartbeat interval exactly 60 000 ms on the runtime's clock;
- no wake-up early, and none more than 819 µs late (the tick's phase);
- 16.2 million rounds of a 4 096-step chain, and 636 000 blocks at the second priority, without a
  mismatch;
- 6.36 million DMA transfers without a wrong word;
- the runtime's second at 0.9899 of the crystal's, which is the clock source's error again.

## 7. Testing

The family uses the repository's harness in `tests/`. `test_runtimes.py` builds each testcase
against each profile's crate, runs it on the board through OpenOCD, and compares the semihosting
output with the testcase's `test.out` (CRLF, which is what `Put_Line` emits).
`tests/run_openocd_tests.py` starts and stops OpenOCD around each test:

```sh
cd tests
python run_openocd_tests.py --target stm32h7xx --profile light-tasking \
    --openocd /path/to/openocd --working-dir /path/to/work --log-dir /path/to/logs \
    --pytest-args "-vv --tb=short" hello_world test_guard_regions
```

`tests/README.md` lists the hooks a testcase's `opt.py` may define. A few behave in ways specific
to this family's tests:

- With `crate_config_values`, the test builds a private copy of the runtime crate with those
  values. The shared installed crate is never rebuilt in place for another configuration. Each
  copy takes about 45 s, so pytest skips such tests unless it is given
  `--private-runtime-builds`, which the OpenOCD runner passes.
- `compiler_switches` applies to the program's own units. The last-chance handler unit
  `test_lch.adb` stays unswitched.
- `source_dirs` supplies the per-profile handlers: the shared pair in `tests/support/lch_light/`
  and `tests/support/lch_embedded/`, or a test's own `lch_light/` and `lch_embedded/`. It also
  lets a test reuse another's program: the clock points build `test_clock_reference`'s, and
  `test_ecc_initialised_ram` builds `test_ecc_initialised`'s. Sources shared by several tests sit
  in `tests/support/`, since every directory under `testcases/` is a test.
- `core_checks` gives the core's state that the OpenOCD runner reads back after a passing run.
  For example, `test_fault_in_fault` must end parked in a fault handler. Under plain pytest such
  a test skips on the target, since its output alone does not show a pass.

A core that locks up during any test fails it. OpenOCD halts a locked-up core itself and says so
in its log, which the runner reads. The runner stops a test after `--test-timeout` seconds, and
after any failure it logs the core's state (PC, xPSR, LR, the stack pointers, the fault status
registers, DHCSR).

Two modules need no board. `tests/test_generated.py` checks that the generated crates carry the
family's sources byte for byte, and checks the manifests' identity and the memory maps. It skips
only when nothing is generated at all, and fails when a stm32h7xx crate is missing.
`tests/test_negative_builds.py`
builds the refusals and the positive controls. Its table has 76 rows; a row with configuration
values takes about 45 s and runs only with `--private-runtime-builds`, and a full run of the
table at 72 rows took 54 minutes.

The gate, run before each change to the family is committed, consists of the generator check, the
runner's default list (upstream's generic testcases and the family's) on the three profiles, and
then the negative table with `--private-runtime-builds`.

The OpenOCD runner stops the server with a kill, after turning the target polling off, after
every test, also when the test fails or the runner is interrupted. A graceful `shutdown` wedged the
ST-LINK V3 more often than the kill. A wedged probe reports `VID:PID 0000:0000` and needs a USB
replug.

## 8. Errata (ES0491 rev 9, device revision Z)

| Erratum | Status (rev Z) | Bearing on the runtime |
|---|---|---|
| 2.1.1 PLD may line-fill an address that would fault | A | Does not arise as configured: both conditions require the default memory map to be off, and the guard keeps it on (PRIVDEFENA). An application that turns it off follows the sheet's workaround, which uses region 0. That region is free, since the guard holds 12 to 15. |
| 2.1.2 MBIST errors not reported for ICACHE | N | Online MBIST is not used. |
| 2.1.3 ECC error with both data-cache error banks locked | A | The runtime locks neither DEBR0 nor DEBR1. An application must not lock both. |
| 2.1.4 Store after cache invalidate without a barrier | A | The runtime does no cache maintenance. The DMA rule in section 3 includes the barrier, and `test_dma_cache` holds it. |
| 2.2.1 to 2.2.5 tamper, OTFDEC, SFI, LSE CSS, USB DFU | A, A, N, P, P | Not used by the runtime. |
| 2.2.6 LSE disturbed by transitions on PC13 | N | The runtime does not use the LSE, but the clock cross-check tests do. Keep PC13 (the user button) quiet while they run. |
| 2.3 to 2.7 MDMA, BDMA, DMA with USART, DMAMUX, FMC | various | Not used by the runtime. `test_dma_cache` uses DMA1 memory-to-memory, which 2.5.1 does not cover. |
| 2.14 TIM, 2.15 LPTIM | various | The runtime's time base is SysTick. The tests use TIM1/TIM2 free-running and LPTIM1 polled. 2.15.1 to 2.15.3 concern Stop mode, the interrupt flag and one-cycle event delays, none of which the tests touch. |
| 2.16.1 WWDG not functional below 2.7 V at VOS0/VOS1 | N | The crate's default is VOS0. An application that uses the window watchdog on a supply below 2.7 V must choose VOS2 or VOS3. |
| the rest (peripherals) | – | Outside the runtime. |

No erratum in the sheet concerns the RCC, the PWR supply configuration, the flash wait states,
SysTick or the coupled memories.

## 9. Changes against the upstream generator and families

In the family's own folder:

- the start-up (`start-common.S`): the supply configuration first, the ECC zeroing sized by
  `TCM_AXI_SHARED`, the TCM enables and the static stack guards;
- the vector table, with the five faults and SVCall routed to the fault stack;
- `System.BB.Faults`: the report, and a second entry that parks under a debugger and resets
  without one;
- the stack guard, in the family's copies of the Armv7-M CPU primitives (`s-bbcppr`) and of the
  PendSV handler (`s-bcpcst`);
- `System.BB.Parameters`, with the profile checks and the fault-stack floor;
- a profile package generated from the manifest (`STM32H7xx_Runtime_Profile`);
- the linker scripts: the DTCM as the runtime's home, `.axisram`, `.sram12`, `.sram4`, the window
  alignment and the four-windows assertion, the fault stack, and a RAM-load script, with the
  sections both loaders share in `common-sections.ld`;
- `setup_pll.adb`, with the range coupling and the hand-over reset.

In the generator, `build-rts.py` registers the family's CPU unit and PendSV unit, and
`patch-runtime.py` copies `s-btstch` into light-tasking and generates the profile package. The
link-time symbols come from the crate's project template (`runtime_build.gpr.in`).

In the harness: the `opt.py` hooks of section 7, the RAM-image load path, the private runtime copy
for configured builds and its `--private-runtime-builds` option, the sorted test order, the
quiesce before the kill, the target's own testcases run by default (`FAMILY_TESTCASES`), the
shared test sources in `tests/support/`, and the modules `test_generated.py` and
`test_negative_builds.py`.
