# STM32H7xx runtimes

GNAT runtimes - light, light-tasking and embedded - for the STM32H723, H725, H730, H733 and H735
line (reference manual RM0468), generated from the compiler's bb-runtimes sources by this
repository's generator, in the shape of its other families. Developed and tested on the
STM32H723ZG of the NUCLEO-H723ZG (silicon revision Z): 8 MHz from the on-board ST-LINK into the
HSE input, PLL1 to 520 MHz at voltage scaling VOS0, the AXI/AHB clock at 260 MHz and the APB
clocks at 130 MHz. Nothing in the family is specific to any product; the measurements quoted
below name the testcase that reproduces them, or say that they were taken outside the test suite,
with the toolchain they were taken with
(gnat_arm_elf 16.1.0, OpenOCD 0.12.0).

## 1. Getting the crates

```sh
./generate-runtimes.sh --target stm32h7xx
```
writes three crates, `install/light-stm32h7xx`, `install/light-tasking-stm32h7xx` and
`install/embedded-stm32h7xx` (sources; the library is compiled by the first build that uses it).
Pin the one you want by path and depend on it:

```toml
[[depends-on]]
light_tasking_stm32h7xx = "*"

[[pins]]
light_tasking_stm32h7xx = { path = "../community-bb-runtimes/install/light-tasking-stm32h7xx" }
```
and in the project file `with "runtime_build.gpr";` (plus `with "ravenscar_build.gpr";` in the
tasking profiles), `for Target use Runtime_Build'Target;`, `for Runtime ("Ada") use
Runtime_Build'Runtime ("Ada");`, and `Runtime_Build.Linker_Switches` in the linker's switches:
they carry the memory map and three link-time symbols the start-up reads. The crate's own
`long-description` repeats this with the option list.

A path-pinned crate is configured and built in place: Alire writes the configuration package into
the pinned directory and the runtime library compiles under `runtimes/<MCU_Sub_Family>` there. Two
workspaces that pin the same directory with different configuration values overwrite each other's
configuration and objects; give each configuration its own copy (or depend on an index release).

Which profile: **light** has no tasking and no exception propagation (a raise goes straight to
the last-chance handler); **light-tasking** adds Ravenscar tasking, still without propagation;
**embedded** adds exception propagation and the full library. The three share one start-up,
one vector table and one memory map.

## 2. Configuration

Every option is an Alire crate configuration value (`light_tasking_stm32h7xx.Option = value` under
`[configuration.values]`). The crate refuses a configuration that breaks a limit of the chip at
compile time, with a message naming the limit.

| Option | Values (default) | What it does |
|---|---|---|
| `MCU_Sub_Family` | H723, H725, H730, H733, H735 (H723) | selects the device's register description (the STM32H723's: the H730/H733/H735 crypto peripherals' interrupts, CRYP 79, OTFDEC1 151, OTFDEC2 152, have slots but no names in `Ada.Interrupts.Names`) |
| `MCU_Flash_Memory_Size` | B, E, G (G) | the flash map: 128 KB, 512 KB, 1 MB; tied to the part (H730 B only, H733/H735 G only, H723/H725 E or G) |
| `HSE_Clock_Frequency` | 4 MHz .. 50 MHz (8 000 000) | the external clock (to 50 MHz) or crystal (to 48 MHz: the reference manual's figure, RM0468 8.5; the datasheet's Table 33 says 50) |
| `HSE_Bypass` | true/false (true) | true for a clock signal (the ST-LINK's MCO), false for a crystal |
| `HSI_Div` | DIV1 .. DIV8 (DIV1) | the 64 MHz internal oscillator's divider |
| `PLL_Src` | HSE, HSI (HSE) | PLL1's input |
| `PLL_M_Div`, `PLL_N_Mul`, `PLL_P_Div` | 1..63 (1), 4..512 (65), 1..128 (1) | PLL1: input divider, multiplier, system-clock divider |
| `PLL_Q_Div`, `PLL_R_Div`, `PLL_Q_Enable`, `PLL_R_Enable` | 1..128 (4, 2), false | the other two PLL1 outputs |
| `SYSCLK_Src` | HSI, CSI, HSE, PLL1 (PLL1) | the system clock's source |
| `Voltage_Scaling` | VOS0 .. VOS3 (VOS0) | the core's voltage scaling, which sets the clock maxima; VOS0 limits the junction temperature to 105 °C, against 125 °C at VOS1 to VOS3 (DS13313 Table 13) |
| `D1CPRE`, `HPRE`, `D1PPRE`, `D2PPRE1`, `D2PPRE2`, `D3PPRE` | DIV1 .. (DIV1, DIV2, DIV2, DIV2, DIV2, DIV2) | the core, AXI/AHB and APB prescalers |
| `Supply_Configuration` | nine arrangements (LDO) | the board's core supply, RM0468 Table 30; the SMPS arrangements only on parts with the converter; see below |
| `Interrupt_Stack_Size` | bytes, at least 1024 (4096) | the interrupt stack, shared by every interrupt priority |
| `Fault_Stack_Size` | bytes, at least 512, 3072 on embedded (4096) | the fault stack, where every fault's handling runs; section 4 |
| `Stack_Guard` | true/false (false) | an MPU no-access window under every stack; see section 5 |
| `Stack_Guard_Bytes` | 32, 64, 128, 256, 512 (32) | the window's size (the runtime's idle task, 2 KB, bounds it); the default only enables the mechanism - size it by rule 2 of section 5 |

What the crate refuses, and where the check lives:

- A PLL1 input outside 1 .. 16 MHz after the M divider (compared exactly: the frequencies are
  computed from the source with one division each, so an M that does not divide the source loses
  nothing); a VCO outside its range - 192 .. 836 MHz
  when the input is 2 .. 16 MHz (the wide range), 150 .. 420 MHz when it is below 2 MHz (the medium
  range, whose outputs are also limited; exactly 2 MHz runs the wide range, as ST's own configuration
  for the NUCLEO-H723ZG has it); an odd P divider other than 1; a CPU, AXI/AHB or APB clock
  above the maximum of the selected voltage scaling (520 / 275 / 137.5 MHz at VOS0). The flash wait
  states follow RM0468 Table 16. (`setup_pll.adb`; DS13313 Tables 12, 39 and 40.)
- `Interrupt_Stack_Size`, `Stack_Guard` and `Stack_Guard_Bytes` set away from their defaults in the
  light crate, which has no interrupt stack, no context switch and no MPU code of its own (the
  start-up's guard block exists in every profile and is skipped when the option is off)
  (`System.BB.Parameters`).
- A `Stack_Guard_Bytes` that is not one of the five sizes; an interrupt stack smaller than four
  windows; at link time, an environment stack smaller than four windows ("environment stack smaller
  than four guard windows", an assertion of the linker script against `__stack_size`)
  (`System.BB.CPU_Primitives`, the linker scripts).
- On embedded, a `Fault_Stack_Size` below 3072 bytes (`System.BB.Parameters`; section 5 says why).
- An SMPS arrangement on the STM32H723 or STM32H733, which have no converter; a flash size the part
  does not come in; a crystal above 48 MHz (RM0468 8.5; DS13313 Table 33 allows 50 - the manual's
  figure is kept); an interrupt stack below 1 KB on the tasking runtimes (the manifest's floor); a
  used PLL1 output - P when it drives the system clock, Q and R when enabled - above the scaling's
  ceiling; at VOS0, a converter feeding the LDO at 1.8 V; on the tasking runtimes, a CPU clock
  below 1 MHz, against which the 1 ms tick would take the processor (`System.BB.Parameters`,
  `setup_pll.adb`).
- At run time, a task stack smaller than four guard windows: the first switch to the task reports
  `Storage_Error` with "task stack below four guard windows" through the fault path (section 5).

`tests/test_negative_builds.py` holds every refusal and the configurations that must build.

**The supply configuration** is the board's, RM0468 Table 30: `LDO` (the NUCLEO-H723ZG and every
part without the SMPS step-down converter), `SMPS`, `SMPS_1V8_Supplies_LDO`,
`SMPS_2V5_Supplies_LDO`, `SMPS_1V8_Supplies_External_And_LDO`, `SMPS_2V5_Supplies_External_And_LDO`,
`SMPS_1V8_Supplies_External_LDO_Bypass`, `SMPS_2V5_Supplies_External_LDO_Bypass`, `Bypass`. The
start-up writes it into PWR_CR3 before anything touches RAM and waits for the voltage levels to be
valid (ACTVOSRDY). The register is write-once until a power-on reset: a changed value takes effect
after a power cycle, and an arrangement the board is not wired for leaves the core unsupplied
until one. Read the schematic before changing it. The converter exists on the STM32H725 and STM32H735 and on
the STM32H730 variants with the Q suffix; the crate refuses the SMPS arrangements for the STM32H723
and STM32H733. For the four arrangements in which the converter supplies external circuits the
start-up also waits for the converter's external-ready flag (SDEXTRDY), as ST's HAL does; none of
the SMPS arrangements is tested here. `test_supply_config` reads the bits back - which cannot tell the
start-up's write from a value an earlier image left, the register being write-once; a locked
arrangement that differs from the crate's parks the start-up at `__gnat_supply_mismatch` after the
ready wait, where a debugger names it. Every scaling,
VOS0 included, is reachable from every source on this family (DS13311 Table 14; the LDO-only VOS0
is the STM32H74x/75x's), with one condition: at VOS0 a converter that feeds the LDO must output
2.5 V, so the crate refuses `SMPS_1V8_Supplies_LDO` and `SMPS_1V8_Supplies_External_And_LDO` at
VOS0 and accepts them from VOS1 down. The sheet's supply floors are the board's to meet: VDD at
least 2.2 V for VOS0 from the converter, 3 V with the converter feeding the LDO at VOS0.

## 3. Memory map and placement

| Region | Address | Size | Use |
|---|---|---|---|
| flash | 0x0800_0000 | 128 KB / 512 KB / 1 MB by `MCU_Flash_Memory_Size` | code, constants, initial values |
| ITCM | 0x0000_0000 | 64 KB (default sharing) | no output section yet: code is not placed there by these scripts |
| DTCM | 0x2000_0000 | 128 KB | **the runtime's home**: data, zeroed data, every stack, the heap |
| AXI SRAM | 0x2400_0000 | 320 KB (default sharing) | `.axisram`, with initial values, copied by the start-up; `.axisram_bss`, zero, not stored in the flash |
| SRAM1 + SRAM2 | 0x3000_0000 | 32 KB | `.sram12`, with initial values, copied by the start-up; `.sram12_noinit`, untouched |
| SRAM4 | 0x3800_0000 | 16 KB | `.sram4`, with initial values, copied by the start-up; `.sram4_noinit`, untouched |

Place an object with `Linker_Section => ".axisram"` (or one of the other names of the table);
`Linker_Section` needs a library-level object. An object in `.axisram`, `.sram12` or `.sram4`
takes its initial value - the implicit ones too, a null access or a record's default components,
which GNAT emits as data - from a load image the start-up copies (`test_sram_init`); its size
counts in the flash, zeroes included. A large zero-only buffer goes in `.axisram_bss`, which the
start-up's ECC initialisation zeroes and the flash does not hold. `.sram12_noinit` and
`.sram4_noinit` are neither loaded nor zeroed: for buffers that need no initial value and for
records that must survive a reset (SRAM4 keeps its contents while powered). The start-up enables
the SRAM1 and SRAM2 clocks (`RCC_AHB2ENR` SRAM1EN / SRAM2EN, off after reset) when `.sram12` is
not empty; a program that uses only `.sram12_noinit` enables them itself. **DMA1, DMA2 and BDMA
cannot reach the DTCM** (the MDMA can, through the core's AHBS port, RM0468 2.4), and the DTCM holds
`.data`, `.bss`, every stack and the heap - so no local variable, task-stack buffer or
default-placed library-level object can be a DMA1/DMA2/BDMA buffer: a DMA buffer goes in
`.axisram` (or `.axisram_bss`) or `.sram12` for DMA1, DMA2 and the MDMA, and in `.sram4` for the
BDMA, which reaches the D3 domain only (RM0468 2.1). The words of `.sram12_noinit` and
`.sram4_noinit` must be written whole-word before any sub-word use - the ECC of SRAM1, SRAM2 and
SRAM4 is not initialised beyond the loaded sections and their monitors flag the first
read-modify-write after power-up (`test_ecc_survey`, an opt-in test run after a power cycle, outside the gate: the
single-error-corrected and double-error-detected flags on each, the monitor reading 3; none on the
DTCM, whose ECC RM0468 2.4 describes too - a measurement, not the manual's word; none on the backup
SRAM). All three placements are cacheable in the default memory map, and a cache line is 32 bytes
(PM0253 4.8): a DMA buffer is aligned to 32 bytes and its size is a multiple of 32
(`with Alignment => 32`), so that no maintenance on it touches a neighbour's line - invalidating a
shared line discards the neighbour's writes, cleaning it while the DMA writes overwrites the DMA's.
Clean the cache before a DMA reads a buffer; before a DMA writes one, clean or invalidate the buffer's lines so that none is
dirty while the transfer runs (a write-back during it would overwrite the DMA's data); invalidate
after the DMA has written; with a barrier between a cache maintenance operation and the store that
follows (errata ES0491 2.1.4); or give the buffer an MPU region of its own in regions 0 to 11. `test_dma_cache` holds the rule: a DMA1 memory-to-memory transfer between two
`.axisram` buffers reads stale data without the maintenance and none with it (0 errors in 10 000
transfers). Text buffers for semihosting output are read by the host behind the cache too; the
runtime's own live in the DTCM. `test_memory_map` holds the placements.

**ECC at start-up.** The AXI SRAM and the ITCM carry 8 ECC bits per 64-bit word (RM0468 2.4): the
first sub-word write to a word nobody has written since power-up - by the start-up's own copy of
`.axisram`, by a task, by a DMA - is a read-modify-write against an ECC that is garbage, and the
RAMECC monitor flags it. The start-up (`start-common.S`, `ecc_init`) zeroes both with 64-bit stores
before the data cache is enabled and before the PLL, at the 64 MHz reset clock (its duration is not
measured), for exactly the sizes the device's
`TCM_AXI_SHARED` option gives (FLASH_OPTSR2_CUR: the ITCM is (field + 1) × 64 KB, the AXI SRAM the
rest of 384 KB; 64/320 by default, then 128/256, 192/192, 256/128). The linker scripts describe the
default sharing; the start-up compares the used end of `.axisram` (and of a RAM-loaded image) with
the device's size and parks at `__gnat_axisram_mismatch` when the map exceeds it, so a device set
otherwise needs a user linker script. `test_ecc_initialised` reads the monitors after start-up
(zero on every profile); `test_tcm_sharing` checks the sizes the start-up computed against the
option byte it reads. The monitors themselves are the application's: read them once
after start-up, clear them, arm the ECC interrupt if wanted.

**A user linker script.** Build with `-XLOADER=USER` and the crate passes no `-T`, only the
three `--defsym`s (`__supply_cr3`, `__stack_guard_bytes`, `__fault_stack_size`) - the generated
`runtime.xml` still names the crate's `ld` directories with `-L`, harmlessly; the start-up and
the fault trap read the scripts' symbols (`__stack_start` / `__stack_end`,
`__interrupt_stack_start` / `__interrupt_stack_end`, `__fault_stack_start` / `__fault_stack_end`,
`__data_*`, `__bss_*`, `__heap_*`, `__ccmdata_*`, `__axisram_start`, `__ecc_axisram_zero_start`,
`__itcm_start`, `__ecc_itcm_bytes`, `__ecc_axisram_bytes`, and, weak, `__axisram_bss_end`,
`__sram12_*`, `__sram4_*`; `__vectors` is `handler.S`'s), so start from a copy of `common-ROM.ld` (or
`common-RAM.ld`) and change its memory map. The copy keeps `INCLUDE memory-ROM.ld` (or
`memory-RAM.ld`), which resolves only through the crate's `-L` directories (`ld/flash-<size>`,
`ld/ram-h72x`): pass them, or inline the `MEMORY` block. Add `-Wl,--no-warn-rwx-segments` yourself,
which the crate adds for its own two loaders. The scripts do not place sections they do not name:
an input section of the application's own (`.itcm`, `.noinit`, `.ramfunc`) lands wherever ld's
orphan rules put it, silently - `-Wl,--orphan-handling=warn` makes ld say so. The ITCM at address
0 holds no section and is readable and writable: a null access in code compiled with checks off
reads or writes it without a fault; an MPU region of the application's, no access over its first
bytes, makes it fault.

**From a bootloader.** The start-up computes from the reset state and re-establishes what it
needs rather than assume it. First, before any RAM write: the SysTick stopped, every interrupt
disabled and unpended, the PendSV and SysTick requests cleared, BASEPRI at zero, the thread on the
main stack with the main stack pointer at the top of the environment stack, the MPU off, lazy
floating-point stacking on (FPCCR ASPEN and LSPEN); then, the vector table in place and nothing
left that can interrupt, PRIMASK cleared - a bootloader masks interrupts before its jump, and an
exception it lets in before the jump is taken by its own vector table, before the image's first
instruction. Then: every PLL off
before the PLL source and the HSI divider are written (a PLL left running makes both writes
no-ops, RM0468 8.7.10 and 8.7.1, and the source is read back), the whole `RCC_CFGR` at its reset
value, the flash latency raised to at least one wait state before the prescalers return to reset
and again before the voltage scaling changes, the HSE turned off and confirmed off before its
bypass bit is written (RM0468 8.7.1), PLL1's fraction latched as zero, a data cache found on
cleaned and invalidated before the ECC zeroing, the MPU's regions cleared (with the guard, before
the two static ones are programmed), the supply arrangement compared with the locked byte. A clock
security system a bootloader armed stays armed (HSECSSON cannot be cleared by software): an HSE
failure then raises the NMI (section 4). Four testcases hand the start-up a prepared state by branching to
the reset entry: `test_handover_pll`, `test_handover_dcache`, `test_handover_state`,
`test_handover_regions`.

**Loading into RAM.** Build with `-XLOADER=RAM` and the image links into the AXI SRAM (`.data` in the
DTCM), with the vector table at its start; the ECC zeroing then begins after the loaded image. The
test harness loads such an image with `load_image` and starts it from its vector table
(`test_ram_loader`, `test_ecc_initialised_ram`).

## 4. Faults

The vector table (`stm32h72x/svd/handler.S`) sends HardFault, MemManage, BusFault and UsageFault
to `__gnat_fault_trap`, and the NMI to the weak name `__gnat_nmi_trap`, which is the same trap
unless the application defines it - as a parameterless procedure exported with `Convention => C`;
an HSE failure under the clock security system is such an NMI, whose handler must clear HSECSSF
(RM0468 8.5; `test_nmi_hook`, and `test_fault_nmi` for the default). The trap reads IPSR and
calls `System.BB.Faults.Report`
(`s-bbfaul`): `Program_Error` with "non-maskable interrupt", "hard fault" or "bus fault",
`Storage_Error` with "memory management fault", `Constraint_Error` with "usage fault". The start-up
sets VTOR to this table and enables the three configurable faults in SHCSR for every profile, so a
program without tasking faults the same way as one with. In light and light-tasking the raise goes
straight to the last-chance handler, `procedure Last_Chance_Handler (Msg : System.Address; Line :
Integer)` with the message in `Msg`; in embedded it propagates and reaches `procedure
Last_Chance_Handler (Except : Ada.Exceptions.Exception_Occurrence)`. The default handler resets
the board (SYSRESETREQ); a debugger attached across repeated self-resets can lose the probe, so a
test program's handler parks in a loop instead. `test_fault_bus`, `test_fault_usage` and
`test_fault_escalated` hold the three paths on every profile. A fault whose handler cannot run
(the fault at a priority the handler cannot pre-empt, or a second fault in the handler) escalates
to a hard fault and is reported as one.

**Every fault is handled on the fault stack.** The trap moves the main stack pointer to the top of a
dedicated region (`Fault_Stack_Size`, 4 KB by default, placed between the interrupt and the
environment stacks) before it reports, so a fault's handling never runs on the stack that
overflowed and does not walk below it - with one exception the core imposes: a fault at a priority
the configurable handlers cannot pre-empt (the tick's, a PRIMASK section) escalates to HardFault,
and the core pushes the HardFault's entry frame through the guard window, which is no barrier to it
(HFNMIENA clear), before the trap moves the stack pointer; the report then says "hard fault"
(`test_fault_escalated`). For the first fault the trap keeps the stack pointer it found in
`__gnat_fault_sp` and the fault status in `__gnat_fault_cfsr`, `__gnat_fault_hfsr`,
`__gnat_fault_mmfar` and `__gnat_fault_bfar` (PM0253 4.3.10 - 4.3.14; the two addresses are
meaningful when CFSR's MMARVALID or BFARVALID says so), for a handler and for a debugger: they tell
a stack overflow (MSTKERR, DACCVIOL) from an execute-never violation, a lazy floating-point
stacking fault (MLSPERR) or an imprecise bus error (IMPRECISERR, whose address is not kept by the
core); a fault inside the handling leaves them as the first one wrote them (`test_fault_bus`). A
task stack below four guard windows (section 5) is reported by the same path, under its own
message. `test_fault_in_handler` overflows the interrupt stack from an interrupt
handler under the guard and checks that the report, a memory management fault, runs above that
stack and that the faulting stack pointer lay inside it. Before the fault stack, the MemManage handler's own first push landed inside the window
it had just hit, the fault escalated, and the hard-fault path ran below the interrupt stack, over the
ECC words and `.bss`, while reporting. A fault inside the handling itself - the last-chance handler
faulting, a second overflow - finds the report already running and parks on the fault stack instead
of reporting again without end (`test_fault_in_fault`: the handler faults on purpose, nothing more
is printed). That holds when the second fault can pre-empt the first report; a second fault inside a
report already running at the HardFault or NMI priority is a lockup by the core's rule (PM0253
2.5.5) - the same end, without the park.

**A last-chance handler on embedded runs in handler mode, on the fault stack**, after the
unwinder. The secondary stack it may use is the interrupted task's, not the fault stack's: the
embedded crate's default handler builds its lines with it and runs - `test_fault_default_lch` takes
a bus fault with no handler of its own, reads the default handler's four lines (LF-terminated, from
`System.IO`; the message carries the raising unit's name) and finds the program restarted by the
reset the handler performs. What the handler needs is fault stack: the default 4 KB holds the
default handler; `test_fault_stack_use`'s minimal handler, fixed buffers and `Put` only, shows the
path's own 1.8 KB (section 5).

## 5. Stacks: the guard, the compiler's check, the sizes

**The MPU stack guard** (`Stack_Guard = true`) keeps a no-access, execute-never window of
`Stack_Guard_Bytes` at the bottom of every stack, in the four highest MPU regions, because where regions
overlap the highest number decides (PM0253 4.6) and an application's region over a stack must not
disarm its window (`test_guard_app_region`): regions 12 and 15 for the tasks, alternating - the
PendSV handler programs the incoming task's window in the one that does not hold the outgoing task's,
after it has saved the outgoing task's registers and before it loads the incoming task's, so both
stacks are guarded through the switch however many times the switch was requested; region 13 for
the interrupt stack; region 14 for the environment stack. The first write past a stack's bottom is then a precise
MemManage fault, reported as "memory management fault", instead of a silent walk into the memory
below. Region 14, and region 13 where an interrupt stack exists, are programmed by the start-up
(`start-common.S`, `guard_init`) for every program, tasking or not, from the link-time symbol
`__stack_guard_bytes` the crate passes, after
every region has been cleared (`test_handover_regions`); regions 12 and 15 follow the tasks once the
tasking runtime is up (a program with no tasking unit has only the environment stack, and it is
guarded: `test_guard_taskless`, `test_guard_taskless_hit`). `test_guard_switch` and
`test_guard_switch_twice` hold the switch, requested once and requested again inside a storm of
interrupts. The
default memory map stays in force everywhere else (PRIVDEFENA); the MPU is off inside HardFault and
NMI handlers (HFNMIENA clear); applications that use the MPU themselves use regions 0 to 11. The switch
puts `MPU_RNR` back as it found it, so a task can be preempted between selecting its region and
writing it (`test_guard_rnr`); an interrupt handler that programs the MPU must restore `MPU_RNR`
itself, since it can preempt the switch.
`test_guard_regions` reads the regions back; `test_guard_map` writes and reads every memory
of the map and a peripheral under the guard; `test_guard_off` holds the default.

The window sits inside the stack at its bottom: the interrupt and environment stacks, which the
linker aligns to the window, lose exactly one window; a task's stack, aligned by the compiler to
8, loses between one and two. Three sizing rules:

1. **Every guarded stack is at least four windows.** The crate checks the interrupt stack at
   compile time, the environment stack at link time and each task's at the first switch to it,
   where a smaller stack is reported as `Storage_Error` with "task stack below four guard windows"
   - through the fault path, as a fault is: interrupts masked, on the fault stack
   (`test_guard_small_task`, with the smallest interrupt stack the crate accepts); a task's
   `Storage_Size` is the application's, which can state the
   rule next to the task so that the compiler says it first:
   ```ada
   pragma Compile_Time_Error
     (Light_Tasking_Stm32h7xx_Config.Stack_Guard
        and then My_Task_Stack_Size < 4 * Light_Tasking_Stm32h7xx_Config.Stack_Guard_Bytes,
      "My_Task's stack is smaller than four guard windows");
   ```
2. **The window is at least the largest frame of code that is not compiled with `-fstack-check`.**
   A frame whose first write lands more than the window below the previous stack pointer steps
   over it.
3. **A stack that code compiled with `-fstack-check` runs on holds its peak use plus the probe's
   margin**: about 4.4 KB in the light and light-tasking profiles and about 12.2 KB in embedded, whose
   code carries exception tables - GCC's `STACK_CHECK_PROTECT`, 4 KB without them and 12 KB with them
   (`sub r3, sp, #4384` against `#12224` below a 260-byte frame in what gnat_arm_elf 16.1.0 emits; the
   check at the thirteenth 280-byte frame of a 16 KB task on embedded, the fortieth on light-tasking);
   see below.

**The compiler's stack check** (`-fstack-check`) calls `__gnat_stack_check` at every subprogram
entry; the light-tasking crate carries the embedded profile's `System.BB.Threads.Stack_Checking`
(`s-btstch`, copied in by `patch-runtime.py`) so the call resolves there too, and it raises
`Storage_Error` from `s-btstch.adb` into the last-chance handler. Linked only when an application
compiles with the switch. The check compares the probe address with the running task's stack
bottom, so it fires when the frame plus the margin would not fit: a task whose stack is smaller
than the margin cannot even start under the check (`test_stack_check`, `test_stack_check_margin`;
both on light-tasking and on embedded, whose own copy of the unit is the same).
**Keep the last-chance handler itself out of the checked units**: a handler compiled with
`-fstack-check` re-raises from its own prologue when it is entered below the limit, and the
re-raises walk the stack into the guard window or out of the memory. With the guard on as well,
the check fires first (`test_stack_check_with_guard`); the complete picture is: the probe catches
overflows in checked Ada code before the frame is used, the guard catches everything else at the
boundary, the fault routing reports what remains. The probe costs about 250 ns (measured outside the
test suite) on an
interrupt-to-pin path at 520 MHz.

**The environment stack** - the main program's - is 4 KB by default, set at link time with
`-Wl,--defsym=__stack_size=<bytes>` in the program's linker switches; code compiled with
`-fstack-check` needs rule 3's margin on top of its use (the stack-check testcases link with 16 KB).
**The interrupt stack** is 4 KB by default: size it for the deepest interrupt nesting (each level a
frame plus the FPU's lazy-stacking space) and the guard window; `test_interrupt_stack_size` holds
the option. **The fault stack** carries every fault's handling. On embedded that is the raise in
`System.BB.Faults.Report`, the unwinder and the last-chance handler, about 1.8 KB including the
handler's own frame: `test_fault_stack_use` fills the fault stack with a pattern,
takes a bus fault and finds the lowest word the path touched - 1792 bytes, rounded up to 256, with
gnat_arm_elf 16.1.0 (a change in that number is worth a look); a handler that builds its lines through the
secondary stack as the default one does uses 2048 (`test_fault_stack_use_alloc`). The embedded crate refuses a fault
stack below 3072 bytes, the allocating handler's figure with half again; `test_fault_stack_default` holds a window write with the default fault stack
and a 1 KB interrupt stack, the smallest the crate accepts.
Light-tasking's handler is a direct call and needs less.

**The FPU** is enabled at start-up (CP10 and CP11); lazy stacking is the core's reset default, which
the start-up re-establishes after a bootloader and `test_startup_state` reads back;
`test_fpu_context` runs two double-precision chains that switch every millisecond under a thousand
interrupts that use the FPU and checks every result, then holds live values in all sixteen double
registers inside one loop while a task preempts it every millisecond and a timer interrupt whose
handler uses the FPU every 100 µs, both loading other values into the registers. `test_stack_alignment` holds the 8-byte alignment of the stack pointer in
the main program, at a task's start and inside a handler; `test_startup_state` the start-up's end
state (caches on, VTOR, CPACR, FPCCR, TCM enables, MPU off by default; the branch-prediction bit it
also prints reads as one on this core).

## 6. Clocks and time

PLL1 drives the system clock by default; the constraints the crate enforces are in section 2.
PLL1's outputs the configuration does not use have their dividers at zero as well as their enables
(RM0468 8.5.5); `test_startup_state` reads them back. Every clock wait is bounded and ends, if the
state does not come, at a park a debugger can name: `__gnat_hse_not_ready` (no clock on the HSE
input, or a crystal configured as a bypass or the reverse), `__gnat_pll_not_locked`,
`__gnat_clock_not_ready`. The flash latency is programmed in two steps when the target needs fewer
wait states than the 64 MHz reset clock (RM0468 4.3.8: the clock first, then the latency, when the frequency falls), and raised
before the voltage scaling changes; every PLL is turned off before the PLL source is written and the
source read back, the HSI divider is written whatever its value, the whole `RCC_CFGR` is reset and
the CSI is enabled and waited for when it is the system clock, so a bootloader's state does not stand
behind the runtime's arithmetic (section 3, "From a bootloader"). The clock tests read back the
voltage scaling applied and the flash wait states against RM0468 Table 16, computed in the test.

**What is the application's.** The runtime configures the supply, the voltage scaling, PLL1, the
system clock switch and the D1/D2/D3 prescalers, nothing else. PLL2 and PLL3 are off (`Reset_Clocks`
turns them off; their M dividers stay at their reset value), the HSE is off unless the configuration
uses it, and every peripheral's kernel clock is at its reset selection: the FDCAN kernel clock, for
one, is the HSE after reset (RM0468 8.7.19, FDCANSEL = 00) - which then must be on, and on the
NUCLEO-H723ZG is the ST-LINK's 8 MHz, about one percent high (measured, below), far outside what CAN
bit timing tolerates; select PLL1 Q (`PLL_Q_Enable`, `PLL_Q_Div`) or a PLL2 output and a clock with
a known accuracy. The kernel clock selections (RCC_D1CCIPR, D2CCIP1R, D2CCIP2R, D3CCIPR), the
peripheral clock enables, PLL2/PLL3, the watchdogs, the reset-cause flags (RCC_RSR, which the
start-up leaves for the application to read and clear) and the option bytes (BOR level, the
watchdogs' hardware start) are the application's.
`Ada.Real_Time` is kept by SysTick. The runtime's second is cross-checked against
the board's 32.768 kHz crystal, the one clock that does not descend from the PLL: LPTIM1 clocked
from the LSE and counted over one second of `Ada.Real_Time` agrees within 2 % at the default point,
at ST's own 520 MHz point, at 400 MHz (VOS1), at 170 MHz (VOS3), at 32 MHz on the halved HSI (VOS3)
and on the HSI at 64 MHz (`test_clock_reference`, `test_clock_point_st`, `test_clock_point_400`,
`test_clock_point_170`, `test_clock_point_32`, `test_clock_hsi64`), and within 8 % on the 4 MHz CSI,
an RC oscillator (`test_clock_csi`); the ST-LINK's 8 MHz is about one percent high on this board
(measured outside the test suite against the LSE; the clock tests themselves ask for 2 %, 8 % on
the CSI), which the PLL inherits. The timer kernel clocks equal the AHB clock
for an APB prescaler of 1 or 2 (TIMPRE = 0, RM0468 8.7.6), so twice the APB clocks the runtime
computes at the default prescaler of 2: TIM2 and TIM1 free-running against the runtime's second
give the ratio 1.000 (`test_timer_clock`). On the NUCLEO-H723ZG, keep the user
button (PC13) alone while the LSE is a reference (ES0491 2.2.6).

Measured outside the test suite, with purpose-built programs on the NUCLEO-H723ZG at 520 MHz and an
FX2-based logic analyser (+44 ppm against the host; 8 MHz samples for the latency rows, 200 kHz for
the ten-minute rows):
an interrupt's latency from the hardware edge to the handler's edge p99 0.750 µs, maximum 0.875 µs
over 106 241 events, none lost, and the same under task load (the MPU guard and the compiler's
stack check cost 0.25 µs on this path against an unguarded build); two periodic tasks of 100 and
500 ms over ten minutes within ±8 µs of their periods once normalised to the board's clock;
`delay until` never early and at most 1 001 µs late over 10 000 wake-ups sweeping the deadline's
phase.

A soak of 17.7 hours on the runtime's clock with everything together - five periodic tasks at four
priorities, a 10 kHz timer interrupt into a protected handler, double-precision chains at two
priorities (one of them the environment task, never pausing), DMA transfers through the data cache
with the maintenance sequence of section 3, a heartbeat on a pin every minute - read off the board
through the debug port without halting it: 636 million interrupts, their count against the clock
drifting by 0 (none missed, none doubled), latency at most 1.035 µs; every heartbeat interval exactly
60 000 ms on the runtime's clock; no wake-up early and none more than 819 µs late (the tick's phase);
16.2 million rounds of a 4 096-step chain and 636 000 blocks at the second priority without a
mismatch; 6.36 million DMA transfers without a wrong word; the runtime's second 0.9899 of the
crystal's, the clock source's error again.

## 7. Testing

The family uses the repository's harness (`tests/`): `test_runtimes.py` builds each testcase against
each profile's crate and runs it on the board through OpenOCD, comparing the semihosting output
with the testcase's `test.out` (CRLF: what `Put_Line` emits). `tests/run_openocd_tests.py` starts
and stops OpenOCD around each test:

```sh
cd tests
python run_openocd_tests.py --target stm32h7xx --profile light-tasking \
    --openocd /path/to/openocd --working-dir /path/to/work --log-dir /path/to/logs \
    --pytest-args "-vv --tb=short" hello_world test_guard_regions
```

A testcase's `opt.py` may define `check_test_conditions` (skip rules), `crate_config_values`
(the test builds a private copy of the runtime crate with those values - the shared installed
crate is not rebuilt in place for a different configuration), `linker_switches`,
`compiler_switches` (for the program's own units; the last-chance handler unit `test_lch.adb`
stays unswitched; `unswitched_units` lists the units that do, in its place), `build_args` (gprbuild arguments after `--`, e.g. `-XLOADER=RAM`),
`source_dirs` (per-profile handlers, `lch_light/` and `lch_embedded/`), `io_timeout` (seconds to
wait for the completion marker, 5 by default) and, for the OpenOCD runner, `core_checks` (the core's
state the runner reads back after a passing run - `test_fault_in_fault` must end parked in a fault
handler, not locked up). The runner stops a test after `--test-timeout` seconds and, after any
failure, logs the core's state (PC, xPSR, the fault status registers, DHCSR). `tests/test_generated.py`
checks that the generated crates carry the family's sources byte for byte and the manifest's
identity; `tests/test_negative_builds.py` builds the refusals and the positive controls without a
board (about 25 s per row with configuration values).

The gate run before each commit of the family: the generator check, the harness units, the runner's
default list (upstream's generic testcases and the family's) on the three profiles, then the
negative table. The OpenOCD runner stops the server with a kill after
turning the target polling off; a graceful `shutdown` wedged the ST-LINK V3 more often than the
kill (a wedged probe reports `VID:PID 0000:0000` and needs a USB replug).

Not yet measured: the latency measurements at a second clock point.

## 8. Errata (ES0491 rev 9, device revision Z)

| Erratum | Status (rev Z) | Bearing on the runtime |
|---|---|---|
| 2.1.1 PLD may line-fill an address that would fault | A | Not met as configured: both conditions require the default memory map to be off, and the guard keeps it on (PRIVDEFENA). An application that turns it off follows the sheet's workaround, which uses region 0 - free: the guard holds 12 to 15. |
| 2.1.2 MBIST errors not reported for ICACHE | N | Online MBIST is not used. |
| 2.1.3 ECC error with both data-cache error banks locked | A | The runtime locks neither DEBR0 nor DEBR1; an application must not lock both. |
| 2.1.4 Store after cache invalidate without a barrier | A | The runtime does no cache maintenance; the DMA rule in section 3 puts the barrier in, and `test_dma_cache` holds it. |
| 2.2.1 – 2.2.5 tamper, OTFDEC, SFI, LSE CSS, USB DFU | A, A, N, P, P | Not used by the runtime. |
| 2.2.6 LSE disturbed by transitions on PC13 | N | The runtime does not use the LSE; the clock cross-check tests do: keep PC13 (the user button) quiet during them. |
| 2.3 – 2.7 MDMA, BDMA, DMA with USART, DMAMUX, FMC | various | Not used by the runtime; `test_dma_cache` uses DMA1 memory-to-memory, outside 2.5.1. |
| 2.14 TIM, 2.15 LPTIM | various | The runtime's time base is SysTick. The tests use TIM1/TIM2 free-running and LPTIM1 polled (2.15.1 – 2.15.3 concern Stop mode, the interrupt flag and one-cycle event delays, none of which they touch). |
| 2.16.1 WWDG not functional below 2.7 V at VOS0/VOS1 | N | The crate's default is VOS0: an application using the window watchdog on a supply below 2.7 V must choose VOS2 or VOS3. |
| the rest (peripherals) | – | Outside the runtime. |

No erratum of the sheet concerns the RCC, the PWR supply configuration, the flash wait states,
SysTick or the coupled memories.

## 9. Changes against the upstream generator and families

In the family's own folder: the start-up (`start-common.S`: the supply configuration first, the
ECC zeroing sized by `TCM_AXI_SHARED`, the TCM enables, the static stack guards); the vector table
with the five faults routed to the fault stack; `System.BB.Faults` (the report, parked on a second entry); the stack guard in the
family's copies of the Armv7-M CPU primitives (`s-bbcppr`) and of the PendSV handler (`s-bcpcst`);
`System.BB.Parameters` with the profile
checks and the fault-stack floor; a profile package generated from the manifest
(`STM32H7xx_Runtime_Profile`); the linker scripts (DTCM home, `.axisram`, `.sram12`, `.sram4`, the
window alignment and the four-windows assertion, the fault stack, a RAM-load script); `setup_pll.adb` with the
range coupling and the hand-over reset. In the generator: `build-rts.py` registers the family's CPU unit and board support;
`patch-runtime.py` copies `s-btstch` into light-tasking, generates the profile package and the
link-time symbols. In the harness: the `opt.py` hooks above, the RAM-image load path, the private
runtime copy for configured builds, the quiesce before the kill, the target's own testcases run
by default (`FAMILY_TESTCASES`), `test_generated.py`, `test_negative_builds.py`,
`test_harness_units.py`.
