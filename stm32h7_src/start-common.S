## -*- asm -*- ##############################################################
#                                                                           #
#                 GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                  #
#                                                                           #
#                                 C A C H E                                 #
#                                                                           #
#                               Assembly File                               #
#                                                                           #
#                      Copyright (C) 2012-2016 AdaCore                      #
#                                                                           #
#  GNAT is free software;  you can  redistribute it  and/or modify it under #
#  terms of the  GNU General Public License as published  by the Free Soft- #
#  ware  Foundation;  either version 3,  or (at your option) any later ver- #
#  sion.  GNAT is distributed in the hope that it will be useful, but WITH- #
#  OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY #
#  or FITNESS FOR A PARTICULAR PURPOSE.                                     #
#                                                                           #
#  As a special exception under Section 7 of GPL version 3, you are granted #
#  additional permissions described in the GCC Runtime Library Exception,   #
#  version 3.1, as published by the Free Software Foundation.               #
#                                                                           #
#  You should have received a copy of the GNU General Public License and    #
#  a copy of the GCC Runtime Library Exception along with this program;     #
#  see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    #
#  <http://www.gnu.org/licenses/>.                                          #
#                                                                           #
#############################################################################

/* The STM32H7 family's start-up, derived from bb-runtimes'
   arm/stm32/start-common.S (the submodule at v16.1.0-1, d7ab8df). */

	.syntax unified
	.cpu cortex-m7
	.thumb

	.text
	.thumb_func
	.globl	_stm32_start_common
	.type _stm32_start_common, %function
_stm32_start_common:

        /* Called from start-rom.S and start-ram.S before anything else, with
           nothing on the stack: it uses r0 .. r8 and r11 freely, the
           callee-saved ones included, and sets the main stack pointer;
           both callers expect exactly that. */

        /* The vector table from handler.S, in every profile, before the first
           instruction that can fault. Upstream's start-rom.S carries a five-
           entry table for the light runtime whose fault entries hang, and the
           tasking runtimes installed handler.S's table only from
           System.BB.CPU_Primitives, i.e. only in programs that use tasking.
           The memory-management, bus and usage fault exceptions are enabled
           here as well, so that a fault keeps its own name in the report
           instead of escalating to HardFault. */
        /* What a bootloader may leave that would interrupt the start-up or
           that the runtime assumes at its reset value (an image entered by
           a branch, not by a reset; nothing to do after a reset): the
           SysTick stopped, every interrupt disabled and unpended, the
           PendSV and SysTick requests cleared (PM0253 4.3.3, 4.4.1, 4.2);
           BASEPRI at zero, the thread on the main stack (CONTROL = 0,
           privileged, no floating-point context), the main stack pointer
           at the top of the environment stack (start-rom.S never loads it:
           the core does, from the vector table, on a reset only); the MPU
           off before the first RAM write, so that a region left over the
           ITCM or the AXI SRAM cannot fault the ECC zeroing below (the
           guard, when on, is programmed again at guard_init); lazy
           floating-point stacking, ASPEN and LSPEN in FPCCR, as at reset
           (PM0253 4.7.2), which the tasking runtime's context switch
           relies on. PRIMASK, which a bootloader sets before its jump, is
           cleared once the vector table is in place, nothing being left
           that can interrupt: the light profile never clears it, and with
           it set a configurable fault would escalate to HardFault. This
           runs before any stack use: nothing has been pushed yet. */
        ldr     r0, =0xE000E010         /* SYST_CSR */
        movs    r1, #0
        str     r1, [r0]
        ldr     r0, =0xE000E180         /* NVIC_ICER0; ICPR0 at +0x100 */
        mov     r1, #0xFFFFFFFF
        movs    r2, #8
0:      str     r1, [r0, #0x100]
        str     r1, [r0], #4
        subs    r2, r2, #1
        bne     0b
        ldr     r0, =0xE000ED04         /* ICSR */
        ldr     r1, =0x0A000000         /* PENDSVCLR, PENDSTCLR */
        str     r1, [r0]
        movs    r1, #0
        msr     basepri, r1
        msr     control, r1
        isb
        ldr     r0, =__stack_end
        mov     sp, r0
        ldr     r0, =0xE000ED94         /* MPU_CTRL */
        str     r1, [r0]
        ldr     r0, =0xE000EF34         /* FPCCR */
        ldr     r1, [r0]
        orr     r1, r1, #0xC0000000     /* ASPEN, LSPEN */
        str     r1, [r0]
        dsb
        isb

        ldr     r0, =__vectors
        ldr     r1, =0xE000ED08         /* SCB VTOR */
        str     r0, [r1]
        ldr     r1, =0xE000ED24         /* SCB SHCSR */
        ldr     r2, [r1]
        orr     r2, r2, #0x00070000     /* USGFAULTENA, BUSFAULTENA, MEMFAULTENA */
        str     r2, [r1]
        dsb
        isb
        cpsie   i                       /* PRIMASK at its reset value */

        /* The core's supply arrangement (RM0468 6.4, Table 30), from the crate
           option Supply_Configuration through __supply_cr3 (a --defsym from the
           runtime's project file): the lower byte of PWR_CR3, written once after
           a power-on reset and before the voltage scaling, the clock change and
           - per 6.4.1 - any write to RAM, so it is the first thing after the
           vector table. The upper bits are kept. Then wait until the voltage
           levels are valid (ACTVOSRDY in PWR_CSR1). An arrangement the board is
           not wired for never becomes valid: the bounded wait below parks at
           __gnat_supply_not_ready, where that shows. */
        ldr     r0, =0x5802480C         /* PWR_CR3 */
        ldr     r1, [r0]
        bic     r1, r1, #0x3F
        ldr     r2, =__supply_cr3
        orr     r1, r1, r2
        str     r1, [r0]
        /* The byte is write-once until a power-on reset (RM0468 6.8.4): a
           different arrangement left locked by a bootloader or by a previous
           image makes the write above a no-op. Read back and compared before
           the wait, so that a mismatch parks at the label that names it
           rather than at the wait's. */
        ldr     r1, [r0]
        and     r1, r1, #0x3F
        ldr     r2, =__supply_cr3
        cmp     r1, r2
        bne     __gnat_supply_mismatch
        /* Bounded at 2**21 polls of PWR_CSR1 - a few hundred milliseconds on
           the 64 MHz reset clock, from the flash with seven wait states and
           the caches off (not measured), where the level is specified in
           microseconds; ST's HAL bounds the same wait and returns an error.
           On expiry a park a debugger can name, instead of a spin somewhere
           in the start-up. A board wired for another arrangement ends
           here. */
        ldr     r0, =0x58024804         /* PWR_CSR1 */
        ldr     r3, =0x200000
1:      ldr     r1, [r0]
        tst     r1, #0x2000             /* ACTVOSRDY */
        bne     4f
        subs    r3, r3, #1
        bne     1b
        b       __gnat_supply_not_ready
4:

        /* The four arrangements in which the converter supplies external
           circuits (SDEXTHP, bit 3 of the byte): wait for SDEXTRDY (PWR_CR3
           bit 16) as well, as HAL_PWREx_ConfigSupply does - the external
           rail must be up before the voltage scaling changes. Untested
           here: this board has no converter. */
        ldr     r2, =__supply_cr3
        tst     r2, #0x08               /* SDEXTHP */
        beq     3f
        ldr     r0, =0x5802480C         /* PWR_CR3 */
        ldr     r3, =0x200000           /* the same bound */
2:      ldr     r1, [r0]
        tst     r1, #0x10000            /* SDEXTRDY */
        bne     3f
        subs    r3, r3, #1
        bne     2b
        b       __gnat_supply_not_ready
3:
        /* The fault report's re-entry latch (System.BB.Faults.Reporting) lives
           in .bss, which is zeroed later, while the fault vectors are already
           live - and the DTCM keeps it across a warm reset. Cleared here, the
           first RAM write, now that the supply is valid */
        ldr     r0, =__gnat_fault_reporting
        movs    r1, #0
        strb    r1, [r0]

        /************************
        * Enable debug Monitor *
        ************************/

        /* Debug register definition */
        .set    DEMCR,  0xE000EDFC
          
        /* Enable the debug monitor so that bkpt instructions are not treated
        * as hard fault when no debugger is attached */
        ldr     r0, =DEMCR
        ldr     r1, [r0]
        orr     r1, r1, #0x10000 /* Set MON_EN in DEMCR */
        str     r1, [r0]

        /**************/
        /* Enable FPU */
        /**************/

        movw     r0,#0xED88
        movt     r0,#0xE000
        ldr      r1,[r0]
        orr      r1,r1,#(0xF << 20)
        str      r1,[r0]

        dsb
        isb

        /* The STM32H72x/H73x family is Cortex-M7 only: the caches and the
           TCM interfaces are initialised unconditionally. (AdaCore's version
           of this file reads the F4/F7 DBGMCU_IDCODE at 0xE0042000 and
           initialises the caches for the F7 device IDs only; on the H7 the
           identity register is DBGMCU_IDC at 0x5C001000, DEV_ID 0x483.)
           Sequence per PM0253 4.8.5: invalidate the data cache by set/way,
           invalidate the instruction cache, enable both in CCR; then enable
           the TCMs (PM0253 4.9.1; already enabled by hardware at reset on
           the H7, so this only confirms them). */

        /* ECC initialisation of the AXI SRAM and the ITCM, this family's
           addition. Their ECC is computed over 64-bit words (RM0468 2.4:
           8 ECC bits per 64-bit word for AXI-SRAM and ITCM-RAM), so the
           first sub-word write to a word nobody has written since power-up,
           by this start-up's 32-bit copy of .axisram, by a task or by a DMA,
           is a read-modify-write against an ECC that is garbage, and the
           RAMECC monitor flags it (measured: D1 monitor 1 read 0x7 after one
           program that used the AXI SRAM). Both regions are zeroed here with
           64-bit stores while the data cache is still off, so every word
           carries a valid ECC before anything touches it; .axisram is copied
           afterwards. The bounds come from the device's TCM_AXI_SHARED option
           byte (see ecc_init), so every sharing boots with every word valid.
           It runs before the clock set-up, on the 64 MHz reset clock; the
           time it takes is not measured. The TCM enables come first (the
           ITCM is zeroed below; both are on at reset on this part, PM0253
           4.9, and the order is now the safe one either way). */
        /*****************************
         * TCM Memory initialisation *
        *****************************/
tcm_init:
        .set    CM7_ITCMCR, 0xE000EF90
        .set    CM7_DTCMCR, 0xE000EF94

        ldr     r0, =CM7_ITCMCR
        ldr     r1, [r0]
        orr     r1, r1, #0x1 /* set the EN field */
        str     r1, [r0]

        ldr     r0, =CM7_DTCMCR
        ldr     r1, [r0]
        orr     r1, r1, #0x1 /* set the EN field */
        str     r1, [r0]

        dsb
        isb

        /* Every line of the data cache through \op - DCISW invalidates,
           DCCISW cleans and invalidates - set by set and way by way, from
           CCSIDR's geometry (PM0253 4.8). Clobbers r0 .. r8 and r11. */
        .macro  dcache_setway op
        mov     r0, #0x0
        ldr     r11, =0xE000ED84        /* CSSELR: the data cache */
        str     r0, [r11]
        dsb
        ldr     r11, =0xE000ED80        /* CCSIDR */
        ldr     r2, [r11]
        and     r1, r2, #0x7            /* words per line (log2 - 2) */
        add     r7, r1, #0x4
        ubfx    r4, r2, #3, #10         /* ways - 1 */
        ubfx    r2, r2, #13, #15        /* sets - 1 */
        clz     r6, r4                  /* the way field's offset */
        ldr     r11, =\op
1:      mov     r1, r4
        lsls    r8, r2, r7
2:      lsls    r3, r1, r6
        orrs    r3, r3, r8
        str     r3, [r11]
        subs    r1, r1, #1
        bge     2b
        subs    r2, r2, #1
        bge     1b
        dsb
        .endm

        /* A hand-over with the data cache on: the
           zeroing below must reach memory, and the invalidate before the
           enable (init_cache) would discard dirty lines, so a cache found on
           is cleaned and invalidated and turned off first. A cold start
           keeps the invalidate alone: its lines are random and must not be
           cleaned. */
        ldr     r11, =0xE000ED14        /* CCR */
        ldr     r0, [r11]
        tst     r0, #0x10000            /* DC */
        beq     ecc_init
        dcache_setway 0xE000EF74        /* DCCISW */
        ldr     r11, =0xE000ED14
        ldr     r0, [r11]
        bic     r0, r0, #0x10000
        str     r0, [r11]
        dsb
        isb

ecc_init:
        /* The sizes come from the device, not from the map: TCM_AXI_SHARED in
           FLASH_OPTSR2_CUR (RM0468 4.9.24) gives 64, 128, 192 or 256 KB of ITCM
           as (field + 1) * 64 KB, and the AXI SRAM is 384 KB minus that. The
           two numbers are left in __ecc_itcm_bytes and __ecc_axisram_bytes (two
           words the linker places outside .bss, so the later zeroing of .bss
           keeps them) for inspection. The linker scripts describe the default
           sharing; a device set otherwise has less AXI SRAM than they declare. */
        ldr     r0,=0x52002070          /* FLASH_OPTSR2_CUR */
        ldr     r0,[r0]
        and     r0,r0,#3                /* TCM_AXI_SHARED */
        adds    r0,#1
        lsls    r4,r0,#16               /* ITCM bytes = (field + 1) * 64 KB */
        ldr     r5,=0x60000             /* 384 KB */
        subs    r5,r5,r4                /* AXI SRAM bytes */
        ldr     r0,=__ecc_itcm_bytes
        str     r4,[r0]
        ldr     r0,=__ecc_axisram_bytes
        str     r5,[r0]
        /* The map describes the default sharing: an .axisram, or a RAM-loaded
           image, that reaches beyond the device's AXI SRAM would bus-fault
           before main. Compared here against the device's size; a mismatch
           parks at a label a debugger can name.
           __ccmdata_end is weak: a user script may not define it. */
        .weak   __ccmdata_end
        movw    r0,#:lower16:__axisram_start
        movt    r0,#:upper16:__axisram_start
        adds    r1,r0,r5                /* the device's end of the AXI SRAM */
        ldr     r0,=__ccmdata_end
        cmp     r0,r1
        bhi     __gnat_axisram_mismatch
        ldr     r0,=__ecc_axisram_zero_start
        cmp     r0,r1
        bhi     __gnat_axisram_mismatch
        .weak   __axisram_bss_end
        ldr     r0,=__axisram_bss_end
        cmp     r0,r1
        bhi     __gnat_axisram_mismatch
        movs    r2,#0
        movs    r3,#0
        movw    r0,#:lower16:__axisram_start
        movt    r0,#:upper16:__axisram_start
        adds    r1,r0,r5                /* end = start + the device's size */
        movw    r0,#:lower16:__ecc_axisram_zero_start
        movt    r0,#:upper16:__ecc_axisram_zero_start
                                        /* flash loader: the start; RAM loader:
                                           after the loaded image */
0:      cmp     r0,r1
        bhs     1f
        strd    r2,r3,[r0],#8
        b       0b
1:      movw    r0,#:lower16:__itcm_start
        movt    r0,#:upper16:__itcm_start
        adds    r1,r0,r4                /* end = start + the device's size */
0:      cmp     r0,r1
        bhs     1f
        strd    r2,r3,[r0],#8
        b       0b
1:      dsb

sram_init:
        /* .sram12 and .sram4 from their load images (the linker scripts):
           their objects' initial values, the implicit ones too. The SRAM1
           and SRAM2 clocks are off after reset (RM0468 8.7.41): enabled
           first when .sram12 is not empty, and read back so that the
           enable has taken effect before the first access; SRAM4's is on.
           Whole-word copies, so every word carries a valid ECC. The data
           cache is still off. The symbols are weak: a user script may
           define neither section. */
        .weak   __sram12_start
        .weak   __sram12_end
        .weak   __sram12_load
        .weak   __sram4_start
        .weak   __sram4_end
        .weak   __sram4_load
        ldr     r0, =__sram12_start
        ldr     r1, =__sram12_end
        cmp     r0, r1
        bhs     2f
        ldr     r2, =0x580244DC         /* RCC_AHB2ENR */
        ldr     r3, [r2]
        orr     r3, r3, #0x60000000     /* SRAM1EN, SRAM2EN */
        str     r3, [r2]
        ldr     r3, [r2]
        dsb
        ldr     r2, =__sram12_load
0:      cmp     r0, r1
        bhs     2f
        ldr     r3, [r2], #4
        str     r3, [r0], #4
        b       0b
2:      ldr     r0, =__sram4_start
        ldr     r1, =__sram4_end
        ldr     r2, =__sram4_load
0:      cmp     r0, r1
        bhs     1f
        ldr     r3, [r2], #4
        str     r3, [r0], #4
        b       0b
1:      dsb

init_cache:
        /********************
         * Enable I/D cache *
        ********************/

        /* Register definition for cache handling */
        .set    CCSIDR,  0xE000ED80
        .set    CSSELR,  0xE000ED84
        .set    DCISW,   0xE000EF60
        .set    ICIALLU, 0xE000EF50
        .set    CCR,     0xE000ED14

        /* First invalidate the data cache (a cache found on at entry was
           cleaned and invalidated before the ECC zeroing, above) */
        dcache_setway 0xE000EF60        /* DCISW */

        /* Now invalidate the instruction cache */
        mov     r0, #0x0
        ldr     r11, =ICIALLU
        str     r0, [r11]

        dsb
        isb

        /* Finally enable Instruction and Data cache */
        ldr     r11, =CCR
        ldr     r0, [r11]
        orr     r0, r0, #(0x30000) /* Sets the I and D cache enabled fields */
        str     r0, [r11]

        dsb
        isb

        /* Wait for store to complete and reset pipeline with FPU enabled  */
        dsb
        isb

guard_init:
        /* Stack_Guard, a crate option of the tasking profiles: the two
           static guards - MPU region 13, a no-access window at the bottom of
           the interrupt stack where there is one, and region 14, the same
           under the environment stack - programmed here, once, for every
           program; the tasking runtime checks that this block ran and adds
           each task's window as it switches. A light-tasking program with no
           tasking unit never runs the tasking runtime's initialisation, and
           had no guard at all before this block existed.
           __stack_guard_bytes is the crate's --defsym: the window, 32 .. 512
           (a power of two) when the option is on, 8 (an alignment only) when
           it is off, and the block is skipped below 32; the weak reference
           reads 0 under a user linker script that omits it. The values
           mirror Set_Guard in s-bbcppr.adb: RBAR = base | VALID | region,
           RASR = XN | SIZE << 1 | ENABLE with AP = 000 (no access for
           anyone), SIZE = log2 (bytes) - 1 (PM0253 Tables 90 and 93),
           MPU_CTRL = ENABLE | PRIVDEFENA. */
        .weak   __stack_guard_bytes
        ldr     r0, =__stack_guard_bytes
        cmp     r0, #32
        blo     mpu_off
        /* The MPU off and every region cleared first (PM0253 4.6.9): a
           bootloader, or a debugger's reload without a reset, may have left
           regions enabled */
        ldr     r2, =0xE000ED94         /* MPU_CTRL */
        movs    r3, #0
        str     r3, [r2]
        dsb
        isb
        ldr     r2, =0xE000ED90         /* MPU_TYPE */
        ldr     r3, [r2]
        ubfx    r3, r3, #8, #8          /* DREGION */
        ldr     r2, =0xE000ED98         /* MPU_RNR; RASR at +8 */
        movs    r1, #0
4:      subs    r3, r3, #1
        blo     5f
        str     r3, [r2]
        str     r1, [r2, #8]
        b       4b
5:      clz     r1, r0
        rsb     r1, r1, #30             /* SIZE = log2 (bytes) - 1 */
        lsl     r1, r1, #1
        orr     r1, r1, #0x10000000     /* XN */
        orr     r1, r1, #1              /* ENABLE */
        sub     r4, r0, #1              /* the window's alignment mask */
        ldr     r2, =0xE000ED9C         /* MPU_RBAR; RASR at +4 */
        /* Region 13 only where there is an interrupt stack: a light-tasking
           program without a tasking unit has none (the section is empty,
           start = end), and a window at its start would sit on the fault
           stack that follows it. */
        ldr     r3, =__interrupt_stack_start
        ldr     r0, =__interrupt_stack_end
        cmp     r3, r0
        beq     2f
        add     r3, r3, r4
        bic     r3, r3, r4              /* rounded up to the window */
        orr     r3, r3, #0x1D           /* VALID, region 13 */
        str     r3, [r2]
        str     r1, [r2, #4]
2:      ldr     r3, =__stack_start
        add     r3, r3, r4
        bic     r3, r3, r4
        orr     r3, r3, #0x1E           /* VALID, region 14 */
        str     r3, [r2]
        str     r1, [r2, #4]
        movs    r3, #5                  /* ENABLE, PRIVDEFENA */
        ldr     r2, =0xE000ED94         /* MPU_CTRL */
        str     r3, [r2]
        dsb
        isb
        b       end

mpu_off:
        /* The guard off: the MPU at its reset state, whatever a bootloader
           left */
        movs    r3, #0
        ldr     r2, =0xE000ED94         /* MPU_CTRL */
        str     r3, [r2]
        dsb
        isb
end:
        bx lr
        .size _stm32_start_common, . - _stm32_start_common

        /* Parking places, named for a debugger: the locked supply byte
           differs from the crate's; the map's .axisram exceeds the device's
           AXI SRAM at its TCM sharing. */
        .globl  __gnat_supply_mismatch
        .type   __gnat_supply_mismatch, %function
        .thumb_func
__gnat_supply_mismatch:
        b       __gnat_supply_mismatch
        .globl  __gnat_axisram_mismatch
        .type   __gnat_axisram_mismatch, %function
        .thumb_func
__gnat_axisram_mismatch:
        b       __gnat_axisram_mismatch
        /* The supply's voltage levels, or the external converter, not ready
           within the bound: the arrangement is not the board's. */
        .globl  __gnat_supply_not_ready
        .type   __gnat_supply_not_ready, %function
        .thumb_func
__gnat_supply_not_ready:
        b       __gnat_supply_not_ready
        /* The clock set-up's bounded waits (setup_pll.adb): the HSE never
           ready (no clock on the input, or a crystal configured as a bypass
           or the reverse), PLL1 never locked, or another clock state that
           did not come within the bound. */
        .globl  __gnat_hse_not_ready
        .type   __gnat_hse_not_ready, %function
        .thumb_func
__gnat_hse_not_ready:
        b       __gnat_hse_not_ready
        .globl  __gnat_pll_not_locked
        .type   __gnat_pll_not_locked, %function
        .thumb_func
__gnat_pll_not_locked:
        b       __gnat_pll_not_locked
        .globl  __gnat_clock_not_ready
        .type   __gnat_clock_not_ready, %function
        .thumb_func
__gnat_clock_not_ready:
        b       __gnat_clock_not_ready
